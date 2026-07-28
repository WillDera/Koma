package eu.kanade.tachiyomi.extension

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import eu.kanade.tachiyomi.source.model.toMap
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.net.ServerSocket
import java.net.Socket
import java.nio.charset.StandardCharsets

class DalvikServer(
    var engine: KeiyoushiEngine? = null,
) {
    companion object {
        private const val TAG = "DalvikServer"
        @Volatile
        private var instance: DalvikServer? = null

        fun getInstance(): DalvikServer = instance ?: synchronized(this) {
            instance ?: DalvikServer().also { instance = it }
        }
    }
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var serverSocket: ServerSocket? = null
    private var isRunning = false
    private var _port = -1

    val port: Int
        get() = _port

    fun start(): Int {
        if (isRunning) return _port
        serverSocket = ServerSocket(0)
        _port = serverSocket!!.localPort
        isRunning = true
        Log.d(TAG, "start: listening on port $_port")
        scope.launch {
            while (isRunning) {
                try {
                    val client = serverSocket?.accept() ?: break
                    Log.d(TAG, "start: accepted connection")
                    scope.launch { handleClient(client) }
                } catch (e: Throwable) {
                    Log.e(TAG, "start: accept loop caught", e)
                    break
                }
            }
            Log.d(TAG, "start: accept loop ended, isRunning=$isRunning")
        }
        return _port
    }

    fun stop() {
        isRunning = false
        try {
            serverSocket?.close()
        } catch (_: Throwable) {
        }
        serverSocket = null
        _port = -1
    }

    private fun handleClient(socket: Socket) {
        Log.d(TAG, "handleClient: accepted")
        try {
            val input = BufferedReader(InputStreamReader(socket.getInputStream(), StandardCharsets.UTF_8))
            val output: OutputStream = socket.getOutputStream()

            val requestLine = input.readLine()
            Log.d(TAG, "handleClient: requestLine=$requestLine")
            if (requestLine == null || requestLine.isEmpty()) {
                Log.w(TAG, "handleClient: empty request line")
                return
            }

            val parts = requestLine.split(" ")
            if (parts.size < 2) {
                Log.w(TAG, "handleClient: malformed request line: $requestLine")
                return
            }
            val path = parts[1]
            Log.d(TAG, "handleClient: path=$path")

            if (path != "/dalvik") {
                Log.w(TAG, "handleClient: unknown path: $path")
                sendResponse(output, 404, "{}")
                return
            }

            var contentLength = 0
            var line = input.readLine()
            while (line != null && line.isNotEmpty()) {
                val colonIdx = line.indexOf(':')
                if (colonIdx > 0) {
                    val key = line.substring(0, colonIdx).trim().lowercase()
                    if (key == "content-length") {
                        contentLength = line.substring(colonIdx + 1).trim().toIntOrNull() ?: 0
                    }
                }
                line = input.readLine()
            }
            Log.d(TAG, "handleClient: contentLength=$contentLength")

            val body = CharArray(contentLength)
            var read = 0
            while (read < contentLength) {
                val n = input.read(body, read, contentLength - read)
                Log.d(TAG, "handleClient: body read $n / $read / $contentLength")
                if (n == -1) break
                read += n
            }
            val bodyStr = String(body, 0, read)
            Log.d(TAG, "handleClient: bodyStr.length=${bodyStr.length}")

            val response = handleRequest(bodyStr)
            Log.d(TAG, "handleClient: response=${response.take(100)}")
            sendResponse(output, 200, response)
            Log.d(TAG, "handleClient: response sent")
        } catch (e: Throwable) {
            Log.e(TAG, "handleClient: caught", e)
        } finally {
            try {
                Log.d(TAG, "handleClient: closing socket")
                socket.close()
            } catch (_: Throwable) {
            }
        }
    }

    private fun Any?.toJsonElement(): JsonElement = when (this) {
        null -> JsonNull
        is String -> JsonPrimitive(this)
        is Number -> JsonPrimitive(this)
        is Boolean -> JsonPrimitive(this)
        is Map<*, *> -> @Suppress("UNCHECKED_CAST") (this as Map<String, Any?>).toJsonObject()
        is List<*> -> JsonArray(this.map { it.toJsonElement() })
        else -> JsonPrimitive(this.toString())
    }

    private fun Map<String, Any?>.toJsonObject(): JsonObject = JsonObject(
        this.mapValues { it.value.toJsonElement() }
    )

    private fun handleRequest(body: String): String {
        return try {
            val eng = engine ?: return errorJson("engine not initialized")
            val jsonObj = json.parseToJsonElement(body).jsonObject
            val method = jsonObj["method"]?.jsonPrimitive?.content ?: return errorJson("missing method")

            val result = when (method) {
                "loadExtension" -> {
                    val apkPath = jsonObj["apkPath"]?.jsonPrimitive?.content ?: return errorJson("missing apkPath")
                    val className = jsonObj["className"]?.jsonPrimitive?.content
                    val desc = eng.loadExtension(apkPath, className)
                    json.encodeToString(desc.toJsonObject())
                }
                "unloadExtension" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    eng.unloadExtension(sourceId)
                    json.encodeToString(JsonNull)
                }
                "listLoadedExtensions" -> {
                    val list = eng.listLoaded()
                    json.encodeToString(list.map { it.toJsonObject() })
                }
                "getPopularManga" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val page = jsonObj["page"]?.jsonPrimitive?.content?.toIntOrNull() ?: 1
                    val pageResult = eng.getPopularManga(sourceId, page)
                    json.encodeToString(buildJsonObject {
                        put("mangas", JsonArray(pageResult.mangas.map { it.toMap().toJsonObject() }))
                        put("hasNextPage", pageResult.hasNextPage)
                    })
                }
                "getLatestUpdates" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val page = jsonObj["page"]?.jsonPrimitive?.content?.toIntOrNull() ?: 1
                    val pageResult = eng.getLatestUpdates(sourceId, page)
                    json.encodeToString(buildJsonObject {
                        put("mangas", JsonArray(pageResult.mangas.map { it.toMap().toJsonObject() }))
                        put("hasNextPage", pageResult.hasNextPage)
                    })
                }
                "searchManga" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val page = jsonObj["page"]?.jsonPrimitive?.content?.toIntOrNull() ?: 1
                    val query = jsonObj["query"]?.jsonPrimitive?.content ?: ""
                    val pageResult = eng.searchManga(sourceId, query, page)
                    json.encodeToString(buildJsonObject {
                        put("mangas", JsonArray(pageResult.mangas.map { it.toMap().toJsonObject() }))
                        put("hasNextPage", pageResult.hasNextPage)
                    })
                }
                "getMangaDetails" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val url = jsonObj["url"]?.jsonPrimitive?.content ?: return errorJson("missing url")
                    val manga = eng.getMangaDetails(sourceId, url)
                    json.encodeToString(manga.toMap().toJsonObject())
                }
                "getMangaUpdate" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val url = jsonObj["url"]?.jsonPrimitive?.content ?: return errorJson("missing url")
                    val (manga, chapters) = eng.getMangaUpdateCombined(sourceId, url)
                    json.encodeToString(buildJsonObject {
                        put("manga", manga.toMap().toJsonObject())
                        put("chapters", JsonArray(chapters.map { it.toMap().toJsonObject() }))
                    })
                }
                "getChapterList" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val url = jsonObj["url"]?.jsonPrimitive?.content ?: return errorJson("missing url")
                    val chapters = eng.getChapterList(sourceId, url)
                    json.encodeToString(JsonArray(chapters.map { it.toMap().toJsonObject() }))
                }
                "getPageList" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val url = jsonObj["url"]?.jsonPrimitive?.content ?: return errorJson("missing url")
                    val pages = eng.getPageList(sourceId, url)
                    json.encodeToString(pages.toJsonElement())
                }
                "searchAllInstalled" -> {
                    val query = jsonObj["query"]?.jsonPrimitive?.content ?: ""
                    val page = jsonObj["page"]?.jsonPrimitive?.content?.toIntOrNull() ?: 1
                    val results = eng.searchAllInstalled(query, page)
                    json.encodeToString(results.toJsonElement())
                }
                "downloadChapters" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val mangaUrl = jsonObj["mangaUrl"]?.jsonPrimitive?.content ?: return errorJson("missing mangaUrl")
                    val chapterUrls = jsonObj["chapterUrls"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList()
                    val chapterNames = jsonObj["chapterNames"]?.jsonArray?.map { it.jsonPrimitive.content } ?: emptyList()
                    val result = eng.downloadChapters(sourceId, mangaUrl, chapterUrls, chapterNames)
                    json.encodeToString(result.toJsonElement())
                }
                "getLocalPages" -> {
                    val sourceId = jsonObj["sourceId"]?.jsonPrimitive?.content ?: return errorJson("missing sourceId")
                    val mangaUrl = jsonObj["mangaUrl"]?.jsonPrimitive?.content ?: return errorJson("missing mangaUrl")
                    val chapterUrl = jsonObj["chapterUrl"]?.jsonPrimitive?.content ?: return errorJson("missing chapterUrl")
                    val pages = eng.getLocalPages(sourceId, mangaUrl, chapterUrl)
                    json.encodeToString(pages.toJsonElement())
                }
                "headersManga", "headersAnime" -> {
                    json.encodeToString(buildJsonObject { })
                }
                "supportLatestManga", "supportLatestAnime" -> {
                    json.encodeToString(JsonPrimitive(true))
                }
                "filtersManga", "filtersAnime" -> {
                    json.encodeToString(JsonArray(emptyList()))
                }
                "preferencesManga", "preferencesAnime" -> {
                    json.encodeToString(JsonArray(emptyList()))
                }
                else -> {
                    errorJson("unknown method: $method")
                }
            }
            result
        } catch (e: Throwable) {
            Log.e(TAG, "handleRequest: error", e)
            errorJson("error: ${e.message}")
        }
    }

    private fun errorJson(message: String): String {
        return json.encodeToString(buildJsonObject {
            put("error", message)
            put("code", 500)
        })
    }

    private fun sendResponse(output: OutputStream, statusCode: Int, body: String) {
        val bodyBytes = body.toByteArray(StandardCharsets.UTF_8)
        val response = "HTTP/1.1 $statusCode OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: ${bodyBytes.size}\r\n" +
            "Connection: close\r\n" +
            "\r\n"
        output.write(response.toByteArray(StandardCharsets.UTF_8))
        output.write(bodyBytes)
        output.flush()
    }
}
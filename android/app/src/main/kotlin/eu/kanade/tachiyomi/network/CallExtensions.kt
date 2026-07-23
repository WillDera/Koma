package eu.kanade.tachiyomi.network

import eu.kanade.tachiyomi.source.model.Page
import okhttp3.Call
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response

fun OkHttpClient.newCachelessCallWithProgress(
    request: Request,
    page: Page,
    existingSize: Long = 0L,
): Call = newCall(request)

suspend fun Call.awaitSuccess(): Response = execute()

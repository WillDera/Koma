package com.koma.koma

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.ForegroundInfo
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

/**
 * Mihon [AppUpdateDownloadJob] parity: APK download runs in a WorkManager
 * foreground worker (`dataSync`) so backgrounding the UI does not kill it.
 *
 * Progress updates go through [NotificationManager] + [setProgressAsync] only.
 * Calling [setForegroundAsync] on every tick can fail the ListenableFuture and
 * mark the whole job FAILED near 99% on a large APK — do not do that.
 */
class AppUpdateDownloadJob(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val url = inputData.getString(EXTRA_DOWNLOAD_URL)
        if (url.isNullOrEmpty()) return Result.failure()
        val expectedBytes = inputData.getLong(EXTRA_EXPECTED_BYTES, -1L)

        setForeground(createForegroundInfo(0))

        return try {
            withContext(Dispatchers.IO) { downloadApk(url, expectedBytes) }
            setProgressAsync(workDataOf(PROGRESS to 100, EXTRA_DOWNLOAD_URL to url))
            Result.success(workDataOf(PROGRESS to 100, EXTRA_DOWNLOAD_URL to url))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "APK download failed", e)
            updateApk(applicationContext).delete()
            Result.failure()
        }
    }

    private fun downloadApk(url: String, expectedBytes: Long) {
        val client = OkHttpClient.Builder()
            .connectTimeout(60, TimeUnit.SECONDS)
            // Large release APKs (~170MB+) need a generous stall timeout.
            .readTimeout(15, TimeUnit.MINUTES)
            .writeTimeout(60, TimeUnit.SECONDS)
            .callTimeout(0, TimeUnit.MILLISECONDS) // no overall cap; FGS keeps us alive
            .followRedirects(true)
            .followSslRedirects(true)
            .build()
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "Koma-AppUpdate")
            .header("Accept", "application/vnd.android.package-archive,*/*")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("HTTP ${response.code}")
            }
            val body = response.body ?: throw IllegalStateException("empty body")
            val total = when {
                body.contentLength() > 0L -> body.contentLength()
                expectedBytes > 0L -> expectedBytes
                else -> -1L
            }
            val apk = updateApk(applicationContext)
            apk.parentFile?.mkdirs()
            // Write to a temp file then rename so a failed/partial download never
            // looks like a finished APK to the Dart snapshot poller.
            val tmp = File(apk.parentFile, "${apk.name}.part")
            if (tmp.exists()) tmp.delete()
            if (apk.exists()) apk.delete()
            var received = 0L
            var savedProgress = 0
            var lastTick = 0L
            body.byteStream().use { input ->
                FileOutputStream(tmp).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        received += read
                        if (total > 0) {
                            val progress = ((100 * received) / total).toInt().coerceIn(0, 99)
                            val now = System.currentTimeMillis()
                            if (progress > savedProgress && now - lastTick > 200) {
                                savedProgress = progress
                                lastTick = now
                                setProgressAsync(
                                    workDataOf(PROGRESS to progress, EXTRA_DOWNLOAD_URL to url),
                                )
                                // Update the existing FGS notification directly —
                                // never call setForegroundAsync here (see class KDoc).
                                notifyProgress(progress)
                            }
                        }
                    }
                    output.flush()
                }
            }
            if (total > 0L && received != total) {
                tmp.delete()
                throw IllegalStateException(
                    "APK size mismatch: got $received bytes, expected $total",
                )
            }
            if (received <= 0L) {
                tmp.delete()
                throw IllegalStateException("APK download empty")
            }
            if (!tmp.renameTo(apk)) {
                tmp.copyTo(apk, overwrite = true)
                tmp.delete()
            }
            notifyProgress(100)
        }
    }

    private fun notifyProgress(progress: Int) {
        try {
            ensureChannel()
            val manager =
                applicationContext.getSystemService(Context.NOTIFICATION_SERVICE)
                    as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(progress))
        } catch (e: Exception) {
            Log.w(TAG, "notifyProgress($progress) failed", e)
        }
    }

    private fun createForegroundInfo(progress: Int): ForegroundInfo {
        ensureChannel()
        val notification = buildNotification(progress)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            ForegroundInfo(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(progress: Int) =
        NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("Downloading update")
            .setContentText(if (progress > 0) "$progress%" else "Starting…")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress.coerceIn(0, 100), progress <= 0)
            .build()

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            "App updates",
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val TAG = "AppUpdateDownload"
        const val PROGRESS = "progress"
        const val EXTRA_DOWNLOAD_URL = "DOWNLOAD_URL"
        const val EXTRA_EXPECTED_BYTES = "EXPECTED_BYTES"
        private const val CHANNEL_ID = "koma_app_update_download"
        private const val NOTIFICATION_ID = 1201

        fun updateApk(context: Context): File =
            File(context.externalCacheDir ?: context.cacheDir, "update.apk")

        fun start(context: Context, url: String, expectedBytes: Long = -1L) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            // No setExpedited — large APKs exceed expedited runtime quotas and
            // get killed near completion (user sees ~99% then Retry).
            val request = OneTimeWorkRequestBuilder<AppUpdateDownloadJob>()
                .setConstraints(constraints)
                .addTag(TAG)
                .setInputData(
                    workDataOf(
                        EXTRA_DOWNLOAD_URL to url,
                        EXTRA_EXPECTED_BYTES to expectedBytes,
                    ),
                )
                .build()
            WorkManager.getInstance(context)
                .enqueueUniqueWork(TAG, ExistingWorkPolicy.REPLACE, request)
        }

        fun stop(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(TAG)
        }

        fun snapshot(context: Context): Map<String, Any?> {
            val infos = WorkManager.getInstance(context)
                .getWorkInfosForUniqueWork(TAG)
                .get()
            val info = infos.firstOrNull()
            val state = info?.state?.name ?: "IDLE"
            val progress = if (info == null) {
                0
            } else when (info.state) {
                WorkInfo.State.SUCCEEDED ->
                    info.outputData.getInt(PROGRESS, 100)
                WorkInfo.State.RUNNING,
                WorkInfo.State.ENQUEUED,
                WorkInfo.State.BLOCKED,
                ->
                    info.progress.getInt(PROGRESS, 0)
                else ->
                    info.progress.getInt(PROGRESS, 0)
            }
            val apk = updateApk(context)
            val apkReady = info?.state == WorkInfo.State.SUCCEEDED &&
                apk.exists() &&
                apk.length() > 0L
            return mapOf(
                "state" to state,
                "progress" to progress,
                "apkPath" to if (apkReady) apk.absolutePath else null,
                "apkReady" to apkReady,
            )
        }
    }
}

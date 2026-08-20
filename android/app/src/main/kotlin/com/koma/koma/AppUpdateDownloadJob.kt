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
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
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
 */
class AppUpdateDownloadJob(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result {
        val url = inputData.getString(EXTRA_DOWNLOAD_URL)
        if (url.isNullOrEmpty()) return Result.failure()

        setForeground(createForegroundInfo(0))

        return try {
            withContext(Dispatchers.IO) { downloadApk(url) }
            Result.success(workDataOf(PROGRESS to 100, EXTRA_DOWNLOAD_URL to url))
        } catch (e: Exception) {
            Log.e(TAG, "APK download failed", e)
            updateApk(applicationContext).delete()
            Result.failure()
        }
    }

    private fun downloadApk(url: String) {
        val client = OkHttpClient.Builder()
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(5, TimeUnit.MINUTES)
            .build()
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "Koma-AppUpdate")
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IllegalStateException("HTTP ${response.code}")
            }
            val body = response.body ?: throw IllegalStateException("empty body")
            val total = body.contentLength()
            val apk = updateApk(applicationContext)
            apk.parentFile?.mkdirs()
            var received = 0L
            var savedProgress = 0
            var lastTick = 0L
            body.byteStream().use { input ->
                FileOutputStream(apk).use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read < 0) break
                        output.write(buffer, 0, read)
                        received += read
                        if (total > 0) {
                            val progress = ((100 * received) / total).toInt().coerceIn(0, 100)
                            val now = System.currentTimeMillis()
                            if (progress > savedProgress && now - lastTick > 200) {
                                savedProgress = progress
                                lastTick = now
                                setProgressAsync(
                                    workDataOf(PROGRESS to progress, EXTRA_DOWNLOAD_URL to url),
                                )
                                // Refresh FGS notification progress.
                                try {
                                    setForegroundAsync(createForegroundInfo(progress))
                                } catch (_: Exception) {
                                }
                            }
                        }
                    }
                    output.flush()
                }
            }
        }
    }

    private fun createForegroundInfo(progress: Int): ForegroundInfo {
        ensureChannel()
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setContentTitle("Downloading update")
            .setContentText(if (progress > 0) "$progress%" else "Starting…")
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, progress.coerceIn(0, 100), progress <= 0)
            .build()

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
        private const val CHANNEL_ID = "koma_app_update_download"
        private const val NOTIFICATION_ID = 1201

        fun updateApk(context: Context): File =
            File(context.externalCacheDir ?: context.cacheDir, "update.apk")

        fun start(context: Context, url: String) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = OneTimeWorkRequestBuilder<AppUpdateDownloadJob>()
                .setConstraints(constraints)
                .addTag(TAG)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .setInputData(workDataOf(EXTRA_DOWNLOAD_URL to url))
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
            val progress = info?.progress?.getInt(PROGRESS, 0)
                ?: if (info?.state == WorkInfo.State.SUCCEEDED) 100 else 0
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

package com.campusauth.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * WorkManager 后台任务：定期检查网络状态并自动认证
 */
class CampusAuthWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {
    
    companion object {
        private const val TAG = "CampusAuthWorker"
        const val WORK_NAME = "campus_auth_periodic"
        private const val NOTIFICATION_CHANNEL_ID = "campus_auth_service"
        
        /**
         * 注册周期性任务（每15分钟检查一次）
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            
            val request = PeriodicWorkRequestBuilder<CampusAuthWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES // 灵活区间
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.DEFAULT_BACKOFF_DELAY_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
            
            Log.i(TAG, "后台认证任务已注册")
        }
        
        /**
         * 立即执行一次认证检查
         */
        fun runOnce(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            
            val request = OneTimeWorkRequestBuilder<CampusAuthWorker>()
                .setConstraints(constraints)
                .build()
            
            WorkManager.getInstance(context).enqueue(request)
            Log.i(TAG, "立即认证任务已提交")
        }
        
        /**
         * 取消所有任务
         */
        fun cancel(context: Context) {
            WorkManager.getInstance(context)
                .cancelUniqueWork(WORK_NAME)
            Log.i(TAG, "后台认证任务已取消")
        }
    }
    
    override suspend fun doWork(): Result {
        Log.i(TAG, "后台认证任务开始执行")
        
        return try {
            // 检查是否需要认证（通过访问公网检测）
            val needsAuth = checkNeedsAuthentication()
            
            if (!needsAuth) {
                Log.i(TAG, "网络已连接，无需认证")
                return Result.success()
            }
            
            // 读取配置（从 SharedPreferences）
            val prefs = applicationContext.getSharedPreferences(
                "FlutterSharedPreferences", 
                Context.MODE_PRIVATE
            )
            val configJson = prefs.getString("flutter.portal_config", null)
            
            if (configJson == null) {
                Log.w(TAG, "未找到认证配置")
                return Result.success()
            }
            
            Log.i(TAG, "发现配置，尝试执行认证...")
            // TODO: 解析配置并执行HTTP认证
            // 由于复杂认证逻辑在Flutter层实现，这里通知Flutter层处理
            
            showNotification("正在自动认证校园网...")
            
            Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "后台认证任务失败: ${e.message}")
            Result.retry()
        }
    }
    
    /**
     * 检查是否需要认证
     */
    private suspend fun checkNeedsAuthentication(): Boolean {
        return try {
            val url = java.net.URL("http://connectivitycheck.gstatic.com/generate_204")
            val conn = url.openConnection() as java.net.HttpURLConnection
            conn.connectTimeout = 5000
            conn.readTimeout = 5000
            conn.instanceFollowRedirects = false
            conn.connect()
            
            val code = conn.responseCode
            conn.disconnect()
            
            // 204 = 在线，200/302 = 需要认证
            code != 204
        } catch (e: Exception) {
            Log.w(TAG, "网络检测失败: ${e.message}")
            false
        }
    }
    
    /**
     * 显示通知
     */
    private fun showNotification(message: String) {
        val notificationManager = applicationContext.getSystemService(
            Context.NOTIFICATION_SERVICE
        ) as NotificationManager
        
        // 创建通知渠道（Android 8.0+）
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "校园网认证",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "校园网自动认证通知"
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(applicationContext, NOTIFICATION_CHANNEL_ID)
                .setContentTitle("校园网认证")
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(applicationContext)
                .setContentTitle("校园网认证")
                .setContentText(message)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .build()
        }
        
        notificationManager.notify(1001, notification)
    }
}

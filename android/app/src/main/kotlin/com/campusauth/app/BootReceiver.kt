package com.campusauth.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机自启动广播接收器
 * 系统启动后自动启动后台监听服务
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Log.i(TAG, "系统启动完成，准备启动校园网认证服务")
                
                try {
                    // 启动后台监听服务
                    // 这里可以启动 WorkManager 定期任务或前台服务
                    startAuthService(context)
                } catch (e: Exception) {
                    Log.e(TAG, "启动服务失败: ${e.message}")
                }
            }
        }
    }
    
    private fun startAuthService(context: Context) {
        // TODO: 根据用户配置决定是否启动后台服务
        // 可以读取 SharedPreferences 检查用户是否开启了自动登录
        Log.i(TAG, "校园网认证服务已准备就绪")
    }
}

package com.campusauth.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.util.Log

/**
 * WiFi 状态变化广播接收器
 * 监听WiFi连接状态，触发认证检查
 */
class WiFiReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "WiFiReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            WifiManager.WIFI_STATE_CHANGED_ACTION -> {
                val wifiState = intent.getIntExtra(
                    WifiManager.EXTRA_WIFI_STATE,
                    WifiManager.WIFI_STATE_UNKNOWN
                )
                
                when (wifiState) {
                    WifiManager.WIFI_STATE_ENABLED -> {
                        Log.i(TAG, "WiFi已启用")
                    }
                    WifiManager.WIFI_STATE_DISABLED -> {
                        Log.i(TAG, "WiFi已禁用")
                    }
                }
            }
            
            ConnectivityManager.CONNECTIVITY_ACTION,
            "android.net.conn.CONNECTIVITY_CHANGE" -> {
                if (isWiFiConnected(context)) {
                    Log.i(TAG, "WiFi已连接，准备触发认证检查")
                    // 延迟3秒后触发认证（等待网络稳定）
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        triggerAuthentication(context)
                    }, 3000)
                } else {
                    Log.i(TAG, "WiFi未连接")
                }
            }
        }
    }
    
    /**
     * 检查WiFi是否已连接
     */
    private fun isWiFiConnected(context: Context): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) 
            as ConnectivityManager
        
        val network = connectivityManager.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        
        return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
    }
    
    /**
     * 触发认证检查（通过WorkManager后台任务）
     */
    private fun triggerAuthentication(context: Context) {
        try {
            // 通知 Flutter 层进行认证检查
            // 这里使用 MethodChannel 或者直接启动 WorkManager 任务
            Log.i(TAG, "触发认证检查任务")
            
            // TODO: 实际实现可以通过 MethodChannel 通知 Flutter
            // 或者直接在原生层调用HTTP认证逻辑
            
        } catch (e: Exception) {
            Log.e(TAG, "触发认证失败: ${e.message}")
        }
    }
}

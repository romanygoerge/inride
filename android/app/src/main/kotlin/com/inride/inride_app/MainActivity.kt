package com.inride.inride_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.inride.app/lifecycle"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        
        // Start TaskRemovalService to detect when app is swiped away
        try {
            val intent = Intent(this, TaskRemovalService::class.java)
            startService(intent)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start TaskRemovalService: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateSessionInfo") {
                val requestId = call.argument<String>("requestId")
                val role = call.argument<String>("role")
                val rideStatus = call.argument<String>("rideStatus")
                
                val prefs = getSharedPreferences("inride_prefs", Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putString("current_request_id", requestId)
                    putString("current_role", role)
                    putString("ride_status", rideStatus)
                    apply()
                }
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "high_importance_channel"
            val channelName = "High Importance Notifications"
            val channelDescription = "This channel is used for important notifications."
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                enableLights(true)
                enableVibration(true)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}

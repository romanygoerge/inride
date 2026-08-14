package com.inride.inride_app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.os.Process
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

class TaskRemovalService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d("TaskRemovalService", "onTaskRemoved called - App is being swiped away")

        val prefs = getSharedPreferences("inride_prefs", Context.MODE_PRIVATE)
        val requestId = prefs.getString("current_request_id", null)
        val userRole = prefs.getString("current_role", null)
        val rideStatus = prefs.getString("ride_status", "idle")
        val accessToken = prefs.getString("access_token", null)
        Log.d("TaskRemovalService", "Saved requestId: $requestId, role: $userRole, status: $rideStatus, hasToken: ${accessToken != null}")

        if (requestId != null && userRole == "rider" && rideStatus == "searching") {
            Thread {
                try {
                    val anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5bHJ1ZXZma3NtcW5reWtxa2luIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NTY3NDYsImV4cCI6MjEwMDMzMjc0Nn0.u5NVng7fsptjQOnNlEYP7MzNDp8_ssN94xSxzg8VYi4"
                    val authHeader = if (!accessToken.isNullOrEmpty()) accessToken else anonKey

                    val url = URL("https://fylruevfksmqnkykqkin.supabase.co/rest/v1/ride_requests?id=eq.$requestId")
                    val conn = url.openConnection() as HttpURLConnection
                    conn.requestMethod = "PATCH"
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.setRequestProperty("apikey", anonKey)
                    conn.setRequestProperty("Authorization", "Bearer $authHeader")
                    conn.doOutput = true

                    val jsonInputString = "{\"status\": \"Cancelled\", \"cancel_reason\": \"تم إلغاء الرحلة لإغلاق التطبيق\"}"
                    conn.outputStream.use { os ->
                        val input = jsonInputString.toByteArray(charset("utf-8"))
                        os.write(input, 0, input.size)
                    }

                    val code = conn.responseCode
                    Log.d("TaskRemovalService", "Supabase update response code: $code")
                } catch (e: Exception) {
                    Log.e("TaskRemovalService", "Failed to cancel ride via Supabase REST: ${e.message}")
                } finally {
                    Process.killProcess(Process.myPid())
                }
            }.start()
        } else {
            Process.killProcess(Process.myPid())
        }

        super.onTaskRemoved(rootIntent)
    }
}

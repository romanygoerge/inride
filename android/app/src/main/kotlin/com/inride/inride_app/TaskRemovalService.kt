package com.inride.inride_app

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log

class TaskRemovalService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        Log.d("TaskRemovalService", "onTaskRemoved called - App is being swiped away. Preserving active ride state.")
        // Do NOT cancel the ride! Rides must remain active on the server so users can re-open the app and seamlessly resume.
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }
}

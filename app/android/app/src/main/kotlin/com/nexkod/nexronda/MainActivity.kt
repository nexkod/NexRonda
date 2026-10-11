package com.nexkod.nexronda

import android.app.ActivityManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.nexkod.nexronda/navigation"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "bringToFront") {
                try {
                    // Method 1: ActivityManager moveTaskToFront
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    if (activityManager != null) {
                        activityManager.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
                    }

                    // Method 2: PendingIntent (Allowed even from background overlay)
                    val notifyIntent = Intent(this, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                        flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val pendingIntent = PendingIntent.getActivity(this, 0, notifyIntent, flags)
                    pendingIntent.send()

                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val fallbackIntent = Intent(this, MainActivity::class.java).apply {
                            action = Intent.ACTION_MAIN
                            addCategory(Intent.CATEGORY_LAUNCHER)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                        }
                        startActivity(fallbackIntent)
                        result.success(true)
                    } catch (err: Exception) {
                        result.error("ERROR", err.message, null)
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }
}

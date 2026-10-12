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
    companion object {
        const val CHANNEL = "com.nexkod.nexronda/navigation"
        private const val OVERLAY_ENGINE_TAG = "myCachedEngine"

        fun bringMainActivityToFront(context: Context, taskId: Int? = null) {
            try {
                // Method 1: ActivityManager moveTaskToFront if taskId is known
                if (taskId != null && taskId > 0) {
                    val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                    activityManager?.moveTaskToFront(taskId, ActivityManager.MOVE_TASK_WITH_HOME)
                }

                // Method 2: PendingIntent with FLAG_ACTIVITY_REORDER_TO_FRONT (Allowed even from background overlay / MIUI)
                val notifyIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_MAIN
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
                }
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
                val pendingIntent = PendingIntent.getActivity(context, 0, notifyIntent, flags)
                pendingIntent.send()
            } catch (e: Exception) {
                try {
                    val fallbackIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
                    }
                    context.startActivity(fallbackIntent)
                } catch (err: Exception) {
                    android.util.Log.e("MainActivity", "Error bringing MainActivity to front", err)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        fun setupNavigationChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
            MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToFront" -> {
                        bringMainActivityToFront(this, taskId)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        // 1. Channel on primary FlutterEngine
        setupNavigationChannel(flutterEngine.dartExecutor.binaryMessenger)

        // Handler to attach navigation channel to Overlay FlutterEngine whenever requested
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToFront" -> {
                    bringMainActivityToFront(this, taskId)
                    result.success(true)
                }
                "registerOverlayEngine" -> {
                    try {
                        val overlayEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_TAG)
                        if (overlayEngine != null) {
                            setupNavigationChannel(overlayEngine.dartExecutor.binaryMessenger)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. Also attach channel to Overlay FlutterEngine if already cached
        try {
            val overlayEngine = io.flutter.embedding.engine.FlutterEngineCache.getInstance().get(OVERLAY_ENGINE_TAG)
            if (overlayEngine != null) {
                setupNavigationChannel(overlayEngine.dartExecutor.binaryMessenger)
            }
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Overlay engine channel setup deferred: ${e.message}")
        }
    }
}

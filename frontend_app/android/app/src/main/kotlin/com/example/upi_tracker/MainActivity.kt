package com.example.upi_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "upi_tracker/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        UpiNotificationService.methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    val enabled = android.provider.Settings.Secure.getString(
                        contentResolver,
                        "enabled_notification_listeners"
                    )?.contains(packageName) == true
                    result.success(enabled)
                }
                "openNotificationSettings" -> {
                    startActivity(
                        android.content.Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Release channel reference so it can be recreated on next launch (#9)
        UpiNotificationService.methodChannel = null
    }
}

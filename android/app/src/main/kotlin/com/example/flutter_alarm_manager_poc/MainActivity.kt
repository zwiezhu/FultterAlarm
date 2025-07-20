package com.example.flutter_alarm_manager_poc

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import com.example.flutter_alarm_manager_poc.receiver.AlarmReceiver

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example/alarm_manager"
    private val ALARM_CHANNEL = "com.example.flutter_alarm_manager_poc/alarm"
    private lateinit var methodChannelHandler: MethodChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannelHandler = MethodChannelHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result -> methodChannelHandler.handle(call, result)
        }
        // Nowy kanał do obsługi alarm_triggered
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "alarm_triggered") {
                // Uruchom AlarmReceiver (czyli całą logikę alarmu)
                val context = applicationContext
                val intent = Intent(context, com.example.flutter_alarm_manager_poc.receiver.AlarmReceiver::class.java)
                intent.action = "com.example.flutter_alarm_manager_poc.ALARM_TRIGGERED"
                // Możesz dodać extras jeśli chcesz przekazać dane alarmu
                context.sendBroadcast(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}

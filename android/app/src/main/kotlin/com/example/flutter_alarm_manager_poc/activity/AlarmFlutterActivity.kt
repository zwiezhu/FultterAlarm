package com.example.flutter_alarm_manager_poc.activity

import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AlarmFlutterActivity : FlutterActivity() {
    private val CHANNEL = "com.example/alarm_manager"
    private lateinit var alarmSoundService: AlarmSoundService

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        alarmSoundService = AlarmSoundServiceImpl(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarmSound" -> {
                        alarmSoundService.startAlarmSound()
                        result.success(null)
                    }
                    "stopAlarmSound" -> {
                        alarmSoundService.stopAlarmSound()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
} 
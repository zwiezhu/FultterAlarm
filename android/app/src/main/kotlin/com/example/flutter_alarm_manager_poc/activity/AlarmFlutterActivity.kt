package com.example.flutter_alarm_manager_poc.activity

import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AlarmFlutterActivity : FlutterActivity() {
    private val CHANNEL = "com.example/alarm_manager"
    private lateinit var alarmSoundService: AlarmSoundService
    
    override fun getInitialRoute(): String? {
        val alarmTime = intent.getLongExtra("alarmTime", System.currentTimeMillis())
        val gameType = intent.getStringExtra("gameType") ?: "piano_tiles"
        
        // Set the initial route with arguments
        return "/alarm_game"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        alarmSoundService = AlarmSoundServiceImpl(this)
        
        val alarmTime = intent.getLongExtra("alarmTime", System.currentTimeMillis())
        val gameType = intent.getStringExtra("gameType") ?: "piano_tiles"
        
        // Pass arguments to Flutter through method channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarmSound" -> {
                    alarmSoundService.startAlarmSound()
                    result.success(null)
                }
                "stopAlarmSound" -> {
                    alarmSoundService.stopAlarmSound()
                    result.success(null)
                }
                "getAlarmArgs" -> {
                    val args = mapOf(
                        "alarmTime" to alarmTime,
                        "gameType" to gameType
                    )
                    result.success(args)
                }
                else -> result.notImplemented()
            }
        }
        
        // Set pending alarm args for Flutter to pick up
        val args = mapOf(
            "alarmTime" to alarmTime,
            "gameType" to gameType
        )
        channel.invokeMethod("setPendingAlarmArgs", args)
    }
} 
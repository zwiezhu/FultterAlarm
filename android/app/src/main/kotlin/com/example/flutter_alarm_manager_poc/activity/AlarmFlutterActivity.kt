package com.example.flutter_alarm_manager_poc.activity

import android.os.Bundle
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log

class AlarmFlutterActivity : FlutterActivity() {
    private val CHANNEL = "com.example/alarm_manager"
    private lateinit var alarmSoundService: AlarmSoundService
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        Log.d("AlarmFlutterActivity", "onCreate called. Intent:  [36m${intent?.extras} [0m")
        
        // Wake up the screen and show on lock screen
        window.addFlags(
            android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            android.view.WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )
        
        // Unlock the screen if it's locked
        val keyguardManager = getSystemService(KEYGUARD_SERVICE) as android.app.KeyguardManager
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            if (keyguardManager.isKeyguardLocked) {
                Log.d("AlarmFlutterActivity", "Screen is locked, attempting to unlock...")
                // Try to dismiss keyguard
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
                    keyguardManager.requestDismissKeyguard(this, object : android.app.KeyguardManager.KeyguardDismissCallback() {
                        override fun onDismissSucceeded() {
                            Log.d("AlarmFlutterActivity", "Keyguard dismissed successfully")
                        }
                        
                        override fun onDismissError() {
                            Log.d("AlarmFlutterActivity", "Keyguard dismiss error")
                        }
                        
                        override fun onDismissCancelled() {
                            Log.d("AlarmFlutterActivity", "Keyguard dismiss cancelled")
                        }
                    })
                }
            }
        }
    }
    
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
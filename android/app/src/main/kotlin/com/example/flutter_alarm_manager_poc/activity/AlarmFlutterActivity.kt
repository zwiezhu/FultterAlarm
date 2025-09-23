package com.example.flutter_alarm_manager_poc.activity

import android.content.Intent
import android.os.Bundle
import com.example.flutter_alarm_manager_poc.MethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import com.example.flutter_alarm_manager_poc.service.RingingService
import android.view.WindowManager
import android.os.PowerManager
import android.content.Context

class AlarmFlutterActivity : FlutterActivity() {

    private val CHANNEL = "com.example/alarm_manager"
    private lateinit var methodChannelHandler: MethodChannelHandler
    private val TAG = "AlarmFlutterActivity"
    // Ringing is controlled by Foreground Service

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Ensure the game screen shows over lock and turns screen on
        setShowWhenLocked(true)
        setTurnScreenOn(true)
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )

        // Acquire a short wake lock to reliably wake screen when launched from background
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
                "flutter_alarm_manager_poc:AlarmFlutterWakeLock"
            )
            wl.acquire(10_000) // 10 seconds is plenty to ensure visibility
            Log.d(TAG, "WakeLock acquired in AlarmFlutterActivity (10s)")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire wake lock: ${e.message}")
        }
        // Mark alarm as active when game activity starts
        getSharedPreferences("alarm_prefs", MODE_PRIVATE).edit().putBoolean("alarm_active", true).apply()
    }

    override fun getInitialRoute(): String? {
        // Always route to '/alarm_game'; we pass args via method channel
        return "/alarm_game"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannelHandler = MethodChannelHandler(this)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result -> methodChannelHandler.handle(call, result) }

        // Provide pending args to Flutter so '/alarm_game' can read them
        val idFromIntent = intent?.getIntExtra("alarmId", -1) ?: -1
        var durationFromIntent = intent?.getIntExtra("durationMinutes", 1) ?: 1
        if (durationFromIntent <= 0 || durationFromIntent == 1) {
            try {
                if (idFromIntent > 0) {
                    val prefs = getSharedPreferences("alarm_prefs", MODE_PRIVATE)
                    val persisted = prefs.getInt("alarm_${idFromIntent}_duration", -1)
                    if (persisted > 0) durationFromIntent = persisted
                }
            } catch (_: Exception) {}
        }
        val args = mapOf(
            "alarmTime" to (intent?.getLongExtra("alarmTime", System.currentTimeMillis()) ?: System.currentTimeMillis()),
            "gameType" to (intent?.getStringExtra("gameType") ?: "piano_tiles"),
            "durationMinutes" to durationFromIntent,
            "alarmId" to idFromIntent
        )
        try {
            channel.invokeMethod("setPendingAlarmArgs", args)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send pending args: ${e.message}")
        }
    }

    override fun onStart() {
        super.onStart()
        // Pause ringing while user is in game
        Log.d(TAG, "onStart: pause ringing service")
        val intent = Intent(this, RingingService::class.java).apply { action = RingingService.ACTION_PAUSE_RING }
        startService(intent)
    }

    override fun onStop() {
        super.onStop()
        val prefs = getSharedPreferences("alarm_prefs", MODE_PRIVATE)
        val active = prefs.getBoolean("alarm_active", false)
        Log.d(TAG, "onStop: alarm_active=$active -> resume ringing")
        if (active) {
            val intent = Intent(this, RingingService::class.java).apply { action = RingingService.ACTION_RESUME_RING }
            startService(intent)
        }
    }
} 

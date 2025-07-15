package com.example.flutter_alarm_manager_poc.activity

import android.content.Intent
import android.os.Bundle
import com.example.flutter_alarm_manager_poc.MethodChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class AlarmFlutterActivity : FlutterActivity() {

    private val CHANNEL = "com.example/alarm_manager"
    private lateinit var methodChannelHandler: MethodChannelHandler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setShowWhenLocked(true)
        setTurnScreenOn(true)
    }

    override fun getInitialRoute(): String? {
        return "/alarm_game"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannelHandler = MethodChannelHandler(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result -> methodChannelHandler.handle(call, result)
        }
    }
} 
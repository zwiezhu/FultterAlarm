package com.example.flutter_alarm_manager_poc

import android.util.Log
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmScheduler
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val ENGINE_ID="alarm_manager_engine"
    private val CHANNEL = "com.example/alarm_manager"
    private val TAG = "POC"

    private lateinit var alarmScheduler: AlarmScheduler
    private lateinit var alarmSoundService: AlarmSoundService


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "configureFlutterEngine called - engine ID: ${flutterEngine.dartExecutor.binaryMessenger.hashCode()}")

        FlutterEngineCache.getInstance().put(ENGINE_ID,flutterEngine)

        alarmScheduler = AlarmSchedulerImpl(this)
        alarmSoundService = AlarmSoundServiceImpl(this)

        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        
        // Set method channel for alarm sound service
        (alarmSoundService as AlarmSoundServiceImpl).setMethodChannel(methodChannel)
        
        Log.d(TAG, "Setting up MethodChannel for engine: ${flutterEngine.dartExecutor.binaryMessenger.hashCode()}")
        
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    Log.d(TAG, "Method Channel Invoked, Alarm Scheduling")
                    scheduleAlarm()
                    result.success(null)
                }
                "alarmAccepted" -> {
                    Log.d(TAG, "Alarm Accepted")
                    // Handle alarm accepted
                    result.success(null)
                }
                "alarmSnoozed" -> {
                    Log.d(TAG, "Alarm Snoozed")
                    // Handle alarm snoozed
                    result.success(null)
                }
                "startAlarmSound" -> {
                    Log.d(TAG, "Starting alarm sound - called from engine: ${flutterEngine.dartExecutor.binaryMessenger.hashCode()}")
                    try {
                        alarmSoundService.startAlarmSound()
                        Log.d(TAG, "Alarm sound start request completed successfully")
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in startAlarmSound: ${e.message}", e)
                        result.error("ALARM_ERROR", "Failed to start alarm sound", e.message)
                    }
                }
                "stopAlarmSound" -> {
                    Log.d(TAG, "Stopping alarm sound - called from engine: ${flutterEngine.dartExecutor.binaryMessenger.hashCode()}")
                    alarmSoundService.stopAlarmSound()
                    result.success(null)
                }
                "setMaxVolume" -> {
                    Log.d(TAG, "Setting max volume")
                    alarmSoundService.forceMaxVolume()
                    result.success(null)
                }
                "restoreOriginalVolume" -> {
                    Log.d(TAG, "Restoring original volume")
                    // Volume will be restored when alarm stops
                    result.success(null)
                }
                "forceMaxVolume" -> {
                    Log.d(TAG, "Forcing max volume")
                    alarmSoundService.forceMaxVolume()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scheduleAlarm() {

        val alarmItem = AlarmItem(
            id = 1,
            message = "Alarm has been ringing"
        )
        alarmScheduler.schedule(alarmItem)
    }
}

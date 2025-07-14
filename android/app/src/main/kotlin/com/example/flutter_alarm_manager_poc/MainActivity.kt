package com.example.flutter_alarm_manager_poc

import android.util.Log
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
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
        
        // Request battery optimization exemption
        // requestBatteryOptimizationExemption()

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
                "scheduleAlarmWithGame" -> {
                    Log.d(TAG, "Method Channel Invoked, Alarm Scheduling with Game")
                    val gameType = call.argument<String>("gameType") ?: "piano_tiles"
                    scheduleAlarmWithGame(gameType)
                    result.success(null)
                }
                "scheduleNativeAlarm" -> {
                    Log.d(TAG, "Method Channel Invoked, Native Alarm Scheduling")
                    val alarmData = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    scheduleNativeAlarm(alarmData)
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
        alarmScheduler.schedule(alarmItem, 5) // Schedule for 5 seconds from now
    }

    private fun scheduleAlarmWithGame(gameType: String) {
        val alarmItem = AlarmItem(
            id = 1,
            message = "Alarm has been ringing",
            gameType = gameType
        )
        alarmScheduler.schedule(alarmItem, 5) // Schedule for 5 seconds from now
    }

    private fun scheduleNativeAlarm(alarmData: Map<*, *>) {
        val id = (alarmData["id"] as? Number)?.toInt() ?: 1
        val name = alarmData["name"] as? String ?: "Alarm"
        val hour = (alarmData["hour"] as? Number)?.toInt() ?: 0
        val minute = (alarmData["minute"] as? Number)?.toInt() ?: 0
        val gameType = alarmData["gameType"] as? String ?: "piano_tiles"
        val selectedDays = alarmData["selectedDays"] as? List<Int> ?: emptyList()
        
        Log.d(TAG, "Scheduling native alarm: $name at $hour:$minute with game: $gameType, selectedDays: $selectedDays")
        
        val alarmItem = AlarmItem(
            id = id,
            message = name,
            gameType = gameType
        )
        
        val now = java.util.Calendar.getInstance()
        val calendar = java.util.Calendar.getInstance()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, hour)
        calendar.set(java.util.Calendar.MINUTE, minute)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)

        // Jeśli selectedDays nie jest puste, znajdź najbliższy dzień tygodnia
        if (selectedDays.isNotEmpty()) {
            val today = now.get(java.util.Calendar.DAY_OF_WEEK) // 1 = niedziela, 2 = poniedziałek, ...
            // Zamień na 1=pon, 7=ndz (jak w Dart)
            val todayDart = if (today == 1) 7 else today - 1
            var minDaysDiff = 7
            var targetDay = todayDart
            for (day in selectedDays) {
                var daysDiff = (day - todayDart + 7) % 7
                if (daysDiff == 0 && calendar.timeInMillis <= now.timeInMillis) {
                    daysDiff = 7 // jeśli dziś, ale godzina już minęła, to za tydzień
                }
                if (daysDiff < minDaysDiff) {
                    minDaysDiff = daysDiff
                    targetDay = day
                }
            }
            calendar.add(java.util.Calendar.DAY_OF_YEAR, minDaysDiff)
        } else {
            // Jeśli alarm na dziś i godzina w przyszłości, nie przesuwaj na jutro
            if (calendar.timeInMillis <= now.timeInMillis + 1000) {
                calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
        }
        val delaySeconds = (calendar.timeInMillis - now.timeInMillis) / 1000
        Log.d(TAG, "Alarm scheduled for $delaySeconds seconds from now (target: ${calendar.time})")
        alarmScheduler.schedule(alarmItem, delaySeconds.toInt())
    }
    
}

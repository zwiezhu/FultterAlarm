package com.example.flutter_alarm_manager_poc

import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.flutter_alarm_manager_poc.activity.AlarmFlutterActivity
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmScheduler
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import io.flutter.plugin.common.MethodChannel

class MethodChannelHandler(private val context: Context) {

    private val TAG = "MethodChannelHandler"
    private val alarmScheduler: AlarmScheduler = AlarmSchedulerImpl(context)
    private val alarmSoundService: AlarmSoundService = AlarmSoundServiceImpl(context)

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleNativeAlarm" -> {
                Log.d(TAG, "Method Channel Invoked, Native Alarm Scheduling")
                val alarmData = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                scheduleNativeAlarm(alarmData)
                result.success(null)
            }
            "startAlarmSound" -> {
                alarmSoundService.startAlarmSound()
                result.success(null)
            }
            "stopAlarmSound" -> {
                alarmSoundService.stopAlarmSound()
                result.success(null)
            }
            "showGameScreen" -> {
                val intent = Intent(context, AlarmFlutterActivity::class.java).apply {
                    putExtra("alarmTime", System.currentTimeMillis())
                    putExtra("gameType", "piano_tiles") // This can be made dynamic
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
                context.startActivity(intent)
                (context as? android.app.Activity)?.finish()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleNativeAlarm(alarmData: Map<*, *>) {
        val id = (alarmData["id"] as? Number)?.toInt() ?: 1
        val name = alarmData["name"] as? String ?: "Alarm"
        val hour = (alarmData["hour"] as? Number)?.toInt() ?: 0
        val minute = (alarmData["minute"] as? Number)?.toInt() ?: 0
        val gameType = alarmData["gameType"] as? String ?: "piano_tiles"
        val durationMinutes = (alarmData["durationMinutes"] as? Number)?.toInt() ?: 1
        val selectedDays = alarmData["selectedDays"] as? List<Int> ?: emptyList()

        Log.d(TAG, "Scheduling native alarm: $name at $hour:$minute with game: $gameType, selectedDays: $selectedDays")

        val alarmItem = AlarmItem(
            id = id,
            message = name,
            gameType = gameType
        )

        val now = java.util.Calendar.getInstance()
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }

        if (selectedDays.isNotEmpty()) {
            val today = now.get(java.util.Calendar.DAY_OF_WEEK) // Sunday = 1, Saturday = 7
            val todayDart = if (today == 1) 7 else today - 1 // Monday = 1, Sunday = 7

            var nextAlarmTime: Long? = null

            for (day in selectedDays) {
                val calendarClone = calendar.clone() as java.util.Calendar
                
                var daysDiff = (day - todayDart + 7) % 7
                if (daysDiff == 0 && calendarClone.timeInMillis <= now.timeInMillis) {
                    daysDiff = 7 // If today, but time has passed, schedule for next week
                }

                calendarClone.add(java.util.Calendar.DAY_OF_YEAR, daysDiff)

                if (nextAlarmTime == null || calendarClone.timeInMillis < nextAlarmTime) {
                    nextAlarmTime = calendarClone.timeInMillis
                }
            }
            
            if (nextAlarmTime != null) {
                val delaySeconds = (nextAlarmTime - now.timeInMillis) / 1000
                if (delaySeconds > 0) {
                    Log.d(TAG, "Alarm scheduled for $delaySeconds seconds from now (target: ${java.util.Date(nextAlarmTime)})")
                    alarmScheduler.schedule(alarmItem, delaySeconds.toInt(), durationMinutes)
                } else {
                    Log.d(TAG, "Alarm time is in the past, not scheduling.")
                }
            } else {
                Log.d(TAG, "No valid future alarm day found.")
            }
        } else {
            if (calendar.timeInMillis <= now.timeInMillis) {
                calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            val delaySeconds = (calendar.timeInMillis - now.timeInMillis) / 1000
            if (delaySeconds > 0) {
                Log.d(TAG, "Alarm scheduled for $delaySeconds seconds from now (target: ${calendar.time})")
                alarmScheduler.schedule(alarmItem, delaySeconds.toInt(), durationMinutes)
            } else {
                Log.d(TAG, "Alarm time is in the past, not scheduling.")
            }
        }
    }
}
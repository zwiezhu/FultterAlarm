package com.example.flutter_alarm_manager_poc.alarmScheduler

import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import com.example.flutter_alarm_manager_poc.receiver.AlarmReceiver
import java.util.Calendar

class AlarmSchedulerImpl(private val context: Context) : AlarmScheduler {
    private val TAG = "AlarmSchedulerImpl"
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    override fun schedule(alarmItem: AlarmItem, delaySeconds: Int, durationMinutes: Int) {
        Log.d(TAG, "Scheduling alarm - ID: ${alarmItem.id}, Message: ${alarmItem.message}, Delay: ${delaySeconds}s, Duration: ${durationMinutes}m")
        
        // Check for exact alarm permissions (Android 12+)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "Cannot schedule exact alarms. Missing permission.")
                // Request permission to schedule exact alarms
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                return
            }
            Log.d(TAG, "Can schedule exact alarms: true")
        }
        
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("ALARM_ID", alarmItem.id)
            putExtra("ALARM_MESSAGE", alarmItem.message)
            putExtra("ALARM_GAME_TYPE", alarmItem.gameType)
            putExtra("ALARM_DURATION", durationMinutes)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmItem.id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        Log.d(TAG, "PendingIntent created: $pendingIntent")
        val triggerTime = System.currentTimeMillis() + (delaySeconds * 1000L)
        
        Log.d(TAG, "Current time: ${System.currentTimeMillis()}, Trigger time: $triggerTime, Delay: ${delaySeconds}s")
        
        // Cancel any existing alarm with the same ID first
        alarmManager.cancel(pendingIntent)
        
        // Use setAlarmClock for maximum reliability - it bypasses Doze mode and battery optimizations
        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerTime, pendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        
        Log.d(TAG, "Alarm scheduled successfully for ${delaySeconds} seconds from now using setAlarmClock")
        
        // Store alarm info in SharedPreferences for persistence across reboots
        val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putLong("alarm_${alarmItem.id}_time", triggerTime)
            putString("alarm_${alarmItem.id}_message", alarmItem.message)
            putString("alarm_${alarmItem.id}_game", alarmItem.gameType)
            putBoolean("alarm_${alarmItem.id}_active", true)
            apply()
        }
        Log.d(TAG, "Alarm info stored in SharedPreferences")
    }

    override fun cancel(alarmItem: AlarmItem) {
        Log.d(TAG, "Cancelling alarm - ID: ${alarmItem.id}")
        
        val intent = Intent(context, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmItem.id,
            intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        )
        
        if (pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "Alarm cancelled successfully")
        } else {
            Log.w(TAG, "No pending intent found to cancel")
        }
        
        // Remove from SharedPreferences
        val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            remove("alarm_${alarmItem.id}_time")
            remove("alarm_${alarmItem.id}_message")
            remove("alarm_${alarmItem.id}_game")
            remove("alarm_${alarmItem.id}_active")
            apply()
        }
        Log.d(TAG, "Alarm info removed from SharedPreferences")
    }
}
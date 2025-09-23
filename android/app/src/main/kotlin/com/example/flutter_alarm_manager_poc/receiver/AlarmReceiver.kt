package com.example.flutter_alarm_manager_poc.receiver

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.flutter_alarm_manager_poc.service.RingingService

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "AlarmReceiver.onReceive called")
        val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        if (intent?.action == "com.example.flutter_alarm_manager_poc.ALARM_TRIGGERED") {
            Log.d(TAG, "AlarmReceiver triggered by android_alarm_manager_plus impulse")
            // Tutaj uruchom całą logikę alarmu jak przy normalnym alarmie
            val alarmIntent = Intent(context, com.example.flutter_alarm_manager_poc.activity.AlarmActivity::class.java)
            alarmIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            context.startActivity(alarmIntent)
            return
        }
        
        val alarmId = intent?.getIntExtra("ALARM_ID", -1) ?: -1
        // Suppression window to avoid immediate re-triggers of the same alarm
        val globalSuppress = prefs.getLong("alarm_suppress_until", 0L)
        val idSuppress = if (alarmId > 0) prefs.getLong("alarm_${alarmId}_suppress_until", 0L) else 0L
        val now = System.currentTimeMillis()
        if (now < globalSuppress || now < idSuppress) {
            Log.w(TAG, "Alarm id=$alarmId suppressed (now=$now, global=$globalSuppress, id=$idSuppress)")
            return
        }
        val message = intent?.getStringExtra("ALARM_MESSAGE") ?: "Alarm!"
        val gameType = intent?.getStringExtra("ALARM_GAME_TYPE") ?: "piano_tiles"
        val alarmTime = System.currentTimeMillis()
        
        Log.d(TAG, "Alarm triggered - ID: $alarmId, Message: $message, Game: $gameType, Time: $alarmTime")
        
        // Start foreground ringing service with all extras instead of local notification
        val duration = intent?.getIntExtra("ALARM_DURATION_MINUTES", 1) ?: 1
        val svcIntent = Intent(context, RingingService::class.java).apply {
            action = RingingService.ACTION_START_RING
            putExtra(RingingService.EXTRA_ALARM_ID, alarmId)
            putExtra(RingingService.EXTRA_ALARM_MESSAGE, message)
            putExtra(RingingService.EXTRA_ALARM_GAME_TYPE, gameType)
            putExtra(RingingService.EXTRA_ALARM_DURATION_MIN, duration)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(svcIntent)
        } else {
            context.startService(svcIntent)
        }
        Log.d(TAG, "RingingService started from AlarmReceiver")
    }
}

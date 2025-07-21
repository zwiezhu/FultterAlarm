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
import androidx.core.content.ContextCompat.getSystemService
import com.example.flutter_alarm_manager_poc.R
import com.example.flutter_alarm_manager_poc.activity.AlarmActivity
import com.example.flutter_alarm_manager_poc.alarmNotificationService.AlarmNotificationService
import com.example.flutter_alarm_manager_poc.alarmNotificationService.AlarmNotificationServiceImpl
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import android.app.ActivityManager

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "AlarmReceiver.onReceive called")
        if (intent?.action == "com.example.flutter_alarm_manager_poc.ALARM_TRIGGERED") {
            Log.d(TAG, "AlarmReceiver triggered by android_alarm_manager_plus impulse")
            // Tutaj uruchom całą logikę alarmu jak przy normalnym alarmie
            val alarmIntent = Intent(context, com.example.flutter_alarm_manager_poc.activity.AlarmActivity::class.java)
            alarmIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            context.startActivity(alarmIntent)
            return
        }
        
        val alarmId = intent?.getIntExtra("ALARM_ID", -1) ?: -1
        val message = intent?.getStringExtra("ALARM_MESSAGE") ?: "Alarm!"
        val gameType = intent?.getStringExtra("ALARM_GAME_TYPE") ?: "piano_tiles"
        val durationMinutes = intent?.getIntExtra("ALARM_DURATION_MINUTES", 1) ?: 1
        val alarmTime = System.currentTimeMillis()
        
        Log.d(TAG, "Alarm triggered - ID: $alarmId, Message: $message, Game: $gameType, Time: $alarmTime")
        
        val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("ALARM_ID", alarmId)
            putExtra("ALARM_MESSAGE", message)
            putExtra("ALARM_GAME_TYPE", gameType)
            putExtra("ALARM_DURATION_MINUTES", durationMinutes)
            putExtra("ALARM_TIME", alarmTime)
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationService: AlarmNotificationService = AlarmNotificationServiceImpl(context)
        notificationService.showNotification(
            alarmItem = AlarmItem(alarmId, message, gameType, durationMinutes),
            alarmTime = alarmTime,
            fullScreenPendingIntent = fullScreenPendingIntent
        )
        Log.d(TAG, "Notification with full-screen intent shown")
    }
}

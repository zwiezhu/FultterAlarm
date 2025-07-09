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


    override fun onReceive(context: Context, intent: Intent?) {
        val alarmId = intent?.getIntExtra("ALARM_ID", -1) ?: -1
        val message = intent?.getStringExtra("ALARM_MESSAGE") ?: "Alarm!"
        val alarmTime = System.currentTimeMillis()
        
        // Always show the AlarmActivity regardless of app state
        val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("ALARM_ID", alarmId)
            putExtra("ALARM_MESSAGE", message)
            putExtra("ALARM_TIME", alarmTime)
        }
        context.startActivity(alarmIntent)
        
        // Also show notification for persistent alarm handling
        val notificationService: AlarmNotificationService = AlarmNotificationServiceImpl(context)
        notificationService.showNotification(AlarmItem(alarmId, message), alarmTime)
    }
}

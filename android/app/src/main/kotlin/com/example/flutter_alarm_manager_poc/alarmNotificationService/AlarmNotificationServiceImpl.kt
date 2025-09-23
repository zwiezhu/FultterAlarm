package com.example.flutter_alarm_manager_poc.alarmNotificationService

import android.media.AudioAttributes
import android.net.Uri
import android.provider.Settings
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.example.flutter_alarm_manager_poc.R
import com.example.flutter_alarm_manager_poc.activity.AlarmActivity
import com.example.flutter_alarm_manager_poc.model.AlarmItem

class AlarmNotificationServiceImpl(private val context: Context) : AlarmNotificationService {
    private val CHANNEL_ID = "alarm_channel"
    private val notificationManager: NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannel()
    }

    override fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Alarm Channel"
            val descriptionText = "Channel for Alarm Notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setBypassDnd(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableLights(true)
                enableVibration(true)
                // Make channel audible using default alarm tone
                val soundUri = Settings.System.DEFAULT_ALARM_ALERT_URI
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    override fun showNotification(alarmItem: AlarmItem, alarmTime: Long, fullScreenPendingIntent: PendingIntent) {
        val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.notification_bell)
            .setContentTitle("Alarm")
            .setContentText(alarmItem.message)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(Settings.System.DEFAULT_ALARM_ALERT_URI)


        val notification = notificationBuilder.build().apply {
            // Repeat sound until user responds and prevent swipe-away
            flags = flags or Notification.FLAG_INSISTENT or Notification.FLAG_NO_CLEAR
        }

        notificationManager.notify(alarmItem.id, notification)
    }

    override fun cancelNotification(id: Int) {
        notificationManager.cancel(id)
    }
}

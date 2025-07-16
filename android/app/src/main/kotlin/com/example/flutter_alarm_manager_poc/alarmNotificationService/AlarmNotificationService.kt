package com.example.flutter_alarm_manager_poc.alarmNotificationService

import com.example.flutter_alarm_manager_poc.model.AlarmItem
import android.app.PendingIntent

interface AlarmNotificationService {
    fun createNotificationChannel()
    fun showNotification(alarmItem: AlarmItem, alarmTime: Long, fullScreenPendingIntent: PendingIntent)
    fun cancelNotification(id: Int)}
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
import com.example.flutter_alarm_manager_poc.activity.AlarmActivity
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import com.example.flutter_alarm_manager_poc.service.RingingService
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    private val TAG = "AlarmReceiver"

    override fun onReceive(context: Context, intent: Intent?) {
        Log.d(TAG, "AlarmReceiver.onReceive called")
        val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        if (intent?.action == "com.example.flutter_alarm_manager_poc.ALARM_TRIGGERED") {
            Log.d(TAG, "AlarmReceiver triggered by android_alarm_manager_plus impulse")
            // Tutaj uruchom całą logikę alarmu jak przy normalnym alarmie
            val alarmIntent = Intent(context, AlarmActivity::class.java)
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

        // Launch the alarm UI immediately while the service takes care of audio.
        // Background activity launches are heavily restricted on recent Android versions,
        // so we trigger it straight from the broadcast while we are still in the
        // allowed execution window of AlarmManager.
        launchAlarmActivity(context, alarmId, message, gameType, duration, alarmTime)
        scheduleNextOccurrence(context, intent, alarmId, message, gameType, duration)
    }

    private fun launchAlarmActivity(
        context: Context,
        alarmId: Int,
        message: String,
        gameType: String,
        durationMinutes: Int,
        alarmTime: Long
    ) {
        try {
            val activityIntent = Intent(context, AlarmActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                putExtra("ALARM_ID", alarmId)
                putExtra("ALARM_MESSAGE", message)
                putExtra("ALARM_GAME_TYPE", gameType)
                putExtra("ALARM_DURATION_MINUTES", durationMinutes)
                putExtra("ALARM_TIME", alarmTime)
            }
            context.startActivity(activityIntent)
            Log.d(TAG, "AlarmActivity launched from AlarmReceiver (screen on/off agnostic)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch AlarmActivity from receiver: ${e.message}", e)
        }
    }

    private fun scheduleNextOccurrence(
        context: Context,
        originalIntent: Intent?,
        alarmId: Int,
        message: String,
        gameType: String,
        durationMinutes: Int
    ) {
        if (alarmId <= 0) {
            Log.d(TAG, "Invalid alarm id=$alarmId; skipping auto-reschedule")
            return
        }
        val hour = originalIntent?.getIntExtra("ALARM_HOUR", -1) ?: -1
        val minute = originalIntent?.getIntExtra("ALARM_MINUTE", -1) ?: -1
        val daysArray = originalIntent?.getIntArrayExtra("ALARM_SELECTED_DAYS") ?: IntArray(0)
        if (hour < 0 || minute < 0) {
            Log.d(TAG, "No hour/minute provided for alarm id=$alarmId; skipping auto-reschedule")
            return
        }

        val selectedDays = daysArray.toList()
        if (selectedDays.isEmpty()) {
            Log.d(TAG, "Alarm id=$alarmId has no repeat days; one-shot alarm, no reschedule")
            return
        }

        val now = Calendar.getInstance()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val today = now.get(Calendar.DAY_OF_WEEK)
        val todayDart = if (today == Calendar.SUNDAY) 7 else today - 1
        var daysDiff = 7
        for (day in selectedDays) {
            var diff = (day - todayDart + 7) % 7
            if (diff == 0 && next.timeInMillis <= now.timeInMillis) {
                diff = 7
            }
            if (diff < daysDiff) {
                daysDiff = diff
            }
        }
        if (daysDiff == 0 && next.timeInMillis <= now.timeInMillis) {
            daysDiff = 7
        }
        if (daysDiff > 0) {
            next.add(Calendar.DAY_OF_YEAR, daysDiff)
        }

        val delaySeconds = ((next.timeInMillis - now.timeInMillis) / 1000L).toInt()
        if (delaySeconds <= 0) {
            Log.w(TAG, "Computed non-positive delay for next occurrence of alarm id=$alarmId; skipping reschedule")
            return
        }

        Log.d(TAG, "Scheduling next occurrence for alarm id=$alarmId in ${delaySeconds}s (target=${next.time})")
        val scheduler = AlarmSchedulerImpl(context)
        val nextAlarmItem = AlarmItem(
            id = alarmId,
            message = message,
            gameType = gameType,
            durationMinutes = durationMinutes,
            hour = hour,
            minute = minute,
            selectedDays = selectedDays
        )
        scheduler.schedule(nextAlarmItem, delaySeconds)
    }
}

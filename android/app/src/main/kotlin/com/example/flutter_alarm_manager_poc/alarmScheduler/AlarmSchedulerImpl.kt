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

    override fun schedule(alarmItem: AlarmItem, delaySeconds: Int) {
        Log.d(TAG, "Scheduling alarm - ID: ${alarmItem.id}, Message: ${alarmItem.message}, Delay: ${delaySeconds}s")
        
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "Cannot schedule exact alarms. Missing permission.")
                return
            }
            Log.d(TAG, "Can schedule exact alarms: true")
        }
        
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("ALARM_ID", alarmItem.id)
            putExtra("ALARM_MESSAGE", alarmItem.message)
            putExtra("ALARM_GAME_TYPE", alarmItem.gameType)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            alarmItem.id,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )
        
        Log.d(TAG, "PendingIntent created: $pendingIntent")

        val triggerTime = Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            add(Calendar.SECOND, delaySeconds)  // Set alarm in delaySeconds seconds
        }.timeInMillis
        
        Log.d(TAG, "Current time: ${System.currentTimeMillis()}, Trigger time: $triggerTime")

        alarmManager.setExact(
            AlarmManager.RTC_WAKEUP,
            triggerTime,
            pendingIntent
        )
        
        Log.d(TAG, "Alarm scheduled successfully for ${delaySeconds} seconds from now")
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
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
            Log.d(TAG, "Alarm cancelled successfully")
        } ?: run {
            Log.w(TAG, "No pending intent found to cancel")
        }
    }
}

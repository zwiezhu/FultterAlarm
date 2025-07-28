package com.example.flutter_alarm_manager_poc.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmScheduler
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl

class BootReceiver : BroadcastReceiver() {
    private val TAG = "BootReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.intent.action.BOOT_COMPLETED") {
            Log.d(TAG, "Boot completed, rescheduling alarms")

            val alarmScheduler: AlarmScheduler = AlarmSchedulerImpl(context)
            val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
            val allAlarms = prefs.all

            for ((key, _) in allAlarms) {
                if (key.startsWith("alarm_") && key.endsWith("_active")) {
                    val idString = key.substringAfter("alarm_").substringBefore("_active")
                    val id = idString.toIntOrNull()

                    if (id != null) {
                        val isActive = prefs.getBoolean(key, false)
                        if (isActive) {
                            val triggerTime = prefs.getLong("alarm_${id}_time", -1)
                            val message = prefs.getString("alarm_${id}_message", "Alarm")
                            val gameType = prefs.getString("alarm_${id}_game", "piano_tiles")
                            val durationMinutes = prefs.getInt("alarm_${id}_duration", 1) // Odczytaj duration

                            if (triggerTime != -1L && System.currentTimeMillis() < triggerTime) {
                                val alarmItem = com.example.flutter_alarm_manager_poc.model.AlarmItem(
                                    id = id,
                                    message = message ?: "Alarm",
                                    gameType = gameType ?: "piano_tiles"
                                )
                                
                                val delaySeconds = ((triggerTime - System.currentTimeMillis()) / 1000).toInt()
                                alarmScheduler.schedule(alarmItem, delaySeconds, durationMinutes)
                                Log.d(TAG, "Rescheduled alarm ID $id for $delaySeconds seconds from now")
                            }
                        }
                    }
                }
            }
        }
    }
} 
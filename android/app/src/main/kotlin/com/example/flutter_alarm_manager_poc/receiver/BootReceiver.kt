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
        Log.d(TAG, "Boot completed, starting alarm scheduler")
        
        // Start the alarm scheduler after boot
        val alarmScheduler: AlarmScheduler = AlarmSchedulerImpl(context)
        
        // Schedule a test alarm for 10 seconds from now to verify it works
        // val testAlarm = com.example.flutter_alarm_manager_poc.model.AlarmItem(
        //     id = 999,
        //     message = "Boot test alarm",
        //     gameType = "piano_tiles"
        // )
        // alarmScheduler.schedule(testAlarm, 10)
        
        // Log.d(TAG, "Test alarm scheduled for 10 seconds from now")
    }
} 
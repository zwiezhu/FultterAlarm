package com.example.flutter_alarm_manager_poc

import android.content.Context
import android.content.Intent
import android.util.Log
import android.os.Build
import android.app.AlarmManager
import android.os.PowerManager
import android.net.Uri
import com.example.flutter_alarm_manager_poc.activity.AlarmFlutterActivity
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmScheduler
import com.example.flutter_alarm_manager_poc.alarmScheduler.AlarmSchedulerImpl
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundService
import com.example.flutter_alarm_manager_poc.alarmSoundService.AlarmSoundServiceImpl
import com.example.flutter_alarm_manager_poc.service.RingingService
import com.example.flutter_alarm_manager_poc.model.AlarmItem
import io.flutter.plugin.common.MethodChannel

class MethodChannelHandler(private val context: Context) {

    private val TAG = "MethodChannelHandler"
    private val alarmScheduler: AlarmScheduler = AlarmSchedulerImpl(context)
    private val alarmSoundService: AlarmSoundService = AlarmSoundServiceImpl(context)
    private val prefs by lazy { context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE) }

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scheduleAlarmWithGame" -> {
                val args = (call.arguments as? Map<*, *>) ?: emptyMap<String, Any>()
                val gameType = args["gameType"] as? String ?: "piano_tiles"
                val delaySeconds = (args["delaySeconds"] as? Number)?.toInt() ?: 10
                val id = (System.currentTimeMillis() and 0x7FFFFFFF).toInt()
                val alarmItem = AlarmItem(id = id, message = "Test Alarm", gameType = gameType)
                Log.d(TAG, "Scheduling test alarm in $delaySeconds s with game=$gameType id=$id")
                alarmScheduler.schedule(alarmItem, delaySeconds)
                result.success(null)
            }
            "scheduleNativeAlarm" -> {
                Log.d(TAG, "Method Channel Invoked, Native Alarm Scheduling")
                val alarmData = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                scheduleNativeAlarm(alarmData)
                result.success(null)
            }
            "isExactAlarmAllowed" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    result.success(alarmManager.canScheduleExactAlarms())
                } else {
                    result.success(true)
                }
            }
            "requestExactAlarmPermission" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to open exact alarm settings: ${e.message}")
                        result.error("REQUEST_EXACT_ALARM_FAILED", e.message, null)
                    }
                } else {
                    result.success(true)
                }
            }
            "isIgnoringBatteryOptimizations" -> {
                try {
                    val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                    val ignoring = pm.isIgnoringBatteryOptimizations(context.packageName)
                    result.success(ignoring)
                } catch (e: Exception) {
                    Log.e(TAG, "isIgnoringBatteryOptimizations check failed: ${e.message}")
                    result.success(false)
                }
            }
            "requestIgnoreBatteryOptimizations" -> {
                try {
                    val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:" + context.packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open ignore battery optimizations: ${e.message}")
                    result.error("REQUEST_IGNORE_BATTERY_OPTIMIZATIONS_FAILED", e.message, null)
                }
            }
            "setAlarmActive" -> {
                val active = (call.arguments as? Boolean) ?: false
                prefs.edit().putBoolean("alarm_active", active).apply()
                Log.d(TAG, "alarm_active set to $active")
                result.success(null)
            }
            "alarmCompleted" -> {
                prefs.edit().putBoolean("alarm_active", false).apply()
                // Stop ringing service entirely
                val intent = Intent(context, RingingService::class.java).apply { action = RingingService.ACTION_STOP_SERVICE }
                context.startService(intent)
                Log.d(TAG, "alarm_active set to false (completed) and service stop requested")
                result.success(null)
            }
            "alarmHandled" -> {
                try {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                    val alarmId = (args["alarmId"] as? Number)?.toInt() ?: -1
                    val suppressSeconds = (args["suppressSeconds"] as? Number)?.toInt() ?: 180
                    val until = System.currentTimeMillis() + suppressSeconds * 1000L
                    if (alarmId > 0) {
                        prefs.edit().putLong("alarm_${alarmId}_suppress_until", until).apply()
                        Log.d(TAG, "Set suppress_until for alarm id=$alarmId to $until")
                    } else {
                        prefs.edit().putLong("alarm_suppress_until", until).apply()
                        Log.d(TAG, "Set global suppress_until to $until (no alarmId provided)")
                    }
                    // Also ensure ringing service is stopped and flag cleared
                    prefs.edit().putBoolean("alarm_active", false).apply()
                    val intent = Intent(context, RingingService::class.java).apply { action = RingingService.ACTION_STOP_SERVICE }
                    context.startService(intent)
                    result.success(null)
                } catch (e: Exception) {
                    Log.e(TAG, "alarmHandled failed: ${'$'}{e.message}")
                    result.error("ALARM_HANDLED_FAILED", e.message, null)
                }
            }
            "startAlarmSound" -> {
                val intent = Intent(context, RingingService::class.java).apply { action = RingingService.ACTION_RESUME_RING }
                context.startService(intent)
                result.success(null)
            }
            "stopAlarmSound" -> {
                val intent = Intent(context, RingingService::class.java).apply { action = RingingService.ACTION_PAUSE_RING }
                context.startService(intent)
                result.success(null)
            }
            "showGameScreen" -> {
                val intent = Intent(context, AlarmFlutterActivity::class.java).apply {
                    putExtra("alarmTime", System.currentTimeMillis())
                    putExtra("gameType", "piano_tiles") // This can be made dynamic
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                }
                context.startActivity(intent)
                (context as? android.app.Activity)?.finish()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun scheduleNativeAlarm(alarmData: Map<*, *>) {
        // Accept both numeric and string IDs from Dart; map to a stable positive int
        val id: Int = when (val rawId = alarmData["id"]) {
            is Number -> rawId.toInt()
            is String -> rawId.hashCode().let { if (it < 0) -it else it }
            else -> 1
        }
        val name = alarmData["name"] as? String ?: "Alarm"
        val hour = (alarmData["hour"] as? Number)?.toInt() ?: 0
        val minute = (alarmData["minute"] as? Number)?.toInt() ?: 0
        val gameType = alarmData["gameType"] as? String ?: "piano_tiles"
        val selectedDays = alarmData["selectedDays"] as? List<Int> ?: emptyList()
        val durationMinutes = (alarmData["durationMinutes"] as? Number)?.toInt() ?: 1

        Log.d(TAG, "Scheduling native alarm: $name at $hour:$minute with game: $gameType, selectedDays: $selectedDays")

        val alarmItem = AlarmItem(
            id = id,
            message = name,
            gameType = gameType,
            durationMinutes = durationMinutes
        )

        val now = java.util.Calendar.getInstance()
        val calendar = java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }

        if (selectedDays.isNotEmpty()) {
            val today = now.get(java.util.Calendar.DAY_OF_WEEK)
            val todayDart = if (today == 1) 7 else today - 1
            var minDaysDiff = 7
            for (day in selectedDays) {
                var daysDiff = (day - todayDart + 7) % 7
                if (daysDiff == 0 && calendar.timeInMillis <= now.timeInMillis) {
                    daysDiff = 7
                }
                if (daysDiff < minDaysDiff) {
                    minDaysDiff = daysDiff
                }
            }
            if (minDaysDiff != 7) { // Add days only if a valid day is found
                calendar.add(java.util.Calendar.DAY_OF_YEAR, minDaysDiff)
            }
        } else {
            if (calendar.timeInMillis <= now.timeInMillis) {
                calendar.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
        }

        val delaySeconds = (calendar.timeInMillis - now.timeInMillis) / 1000
        if (delaySeconds > 0) {
            Log.d(TAG, "Alarm scheduled for $delaySeconds seconds from now (target: ${calendar.time})")
            alarmScheduler.schedule(alarmItem, delaySeconds.toInt())
        } else {
            Log.d(TAG, "Alarm time is in the past, not scheduling.")
        }
    }
}

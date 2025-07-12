import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../hive/models/alarm_settings.dart';
import '../hive/service/database_service.dart';
import '../utils/alarm_method_channel.dart';

class AlarmSchedulerService {
  static AlarmSchedulerService? _instance;
  Timer? _checkTimer;
  List<AlarmSettings> _activeAlarms = [];

  // Private constructor
  AlarmSchedulerService._();

  // Singleton instance getter
  static AlarmSchedulerService get instance {
    _instance ??= AlarmSchedulerService._();
    return _instance!;
  }

  // Start the alarm scheduler
  void startScheduler() {
    _loadActiveAlarms();
    _scheduleNextCheck();
  }

  // Stop the alarm scheduler
  void stopScheduler() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  // Load active alarms from database
  void _loadActiveAlarms() {
    _activeAlarms = DatabaseService.instance
        .getAllAlarmSettings()
        .where((alarm) => alarm.isEnabled)
        .toList();
    
    log('Loaded ${_activeAlarms.length} active alarms');
  }

  // Schedule next check for alarms
  void _scheduleNextCheck() {
    _checkTimer?.cancel();
    
    // Check every minute
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkAlarms();
    });
  }

  // Check if any alarms should trigger
  void _checkAlarms() {
    final now = DateTime.now();
    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    
    for (final alarm in _activeAlarms) {
      // Check if alarm should trigger today
      if (alarm.selectedDays.contains(currentDayOfWeek)) {
        // Check if it's time for this alarm
        if (now.hour == alarm.hour && now.minute == alarm.minute) {
          _triggerAlarm(alarm);
        }
      }
    }
  }

  // Trigger an alarm
  void _triggerAlarm(AlarmSettings alarm) {
    log('Triggering alarm: ${alarm.name} at ${alarm.timeString}');
    
    // Schedule the alarm to trigger in 5 seconds (for testing)
    // In production, this would trigger immediately
    Timer(const Duration(seconds: 5), () {
      AlarmMethodChannel.scheduleAlarm();
    });
  }

  // Refresh alarms (called when alarms are added/removed/modified)
  void refreshAlarms() {
    _loadActiveAlarms();
  }

  // Get next alarm time
  DateTime? getNextAlarmTime() {
    final now = DateTime.now();
    DateTime? nextAlarm;
    
    for (final alarm in _activeAlarms) {
      for (final day in alarm.selectedDays) {
        // Calculate next occurrence of this alarm
        final daysUntilAlarm = (day - now.weekday) % 7;
        final nextOccurrence = now.add(Duration(days: daysUntilAlarm));
        final alarmTime = DateTime(
          nextOccurrence.year,
          nextOccurrence.month,
          nextOccurrence.day,
          alarm.hour,
          alarm.minute,
        );
        
        // If alarm time is in the past today, move to next week
        final finalAlarmTime = alarmTime.isBefore(now) 
            ? alarmTime.add(const Duration(days: 7))
            : alarmTime;
            
        if (nextAlarm == null || finalAlarmTime.isBefore(nextAlarm)) {
          nextAlarm = finalAlarmTime;
        }
      }
    }
    
    return nextAlarm;
  }

  // Get formatted next alarm string
  String getNextAlarmString() {
    final nextAlarm = getNextAlarmTime();
    if (nextAlarm == null) return 'Brak zaplanowanych alarmów';
    
    final now = DateTime.now();
    final difference = nextAlarm.difference(now);
    
    if (difference.inDays > 0) {
      return 'Następny alarm: ${nextAlarm.day}/${nextAlarm.month} o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inDays} dni)';
    } else if (difference.inHours > 0) {
      return 'Następny alarm: o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inHours} godzin)';
    } else {
      return 'Następny alarm: o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inMinutes} minut)';
    }
  }
} 
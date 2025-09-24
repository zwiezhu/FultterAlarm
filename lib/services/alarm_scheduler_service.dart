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
  Set<String> _triggeredAlarms = {}; // Track triggered alarms to avoid duplicates
  bool _isRunning = false;
  DateTime Function() _nowProvider = DateTime.now;
  late void Function(AlarmSettings) _alarmTriggerHandler;
  
  bool get isRunning => _isRunning;

  // Private constructor
  AlarmSchedulerService._() {
    _alarmTriggerHandler = _defaultTriggerHandler;
  }

  // Singleton instance getter
  static AlarmSchedulerService get instance {
    _instance ??= AlarmSchedulerService._();
    return _instance!;
  }

  // Start the alarm scheduler
  void startScheduler() {
    if (_isRunning) return; // Already running
    
    _loadActiveAlarms();
    _scheduleNextCheck();
    _scheduleDailyReset();
    _isRunning = true;
    log('AlarmSchedulerService started');
    
    // Log that we're checking alarms every 10 seconds
    log('AlarmSchedulerService will check alarms every 10 seconds');
  }

  // Stop the alarm scheduler
  void stopScheduler() {
    _checkTimer?.cancel();
    _checkTimer = null;
    _isRunning = false;
    log('AlarmSchedulerService stopped');
  }

  // Schedule daily reset of triggered alarms
  void _scheduleDailyReset() {
    // Calculate time until next midnight
    final now = _nowProvider();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final timeUntilMidnight = tomorrow.difference(now);
    
    Timer(timeUntilMidnight, () {
      _triggeredAlarms.clear();
      log('Cleared triggered alarms for new day');
      _scheduleDailyReset(); // Schedule next reset
    });
  }

  // Load active alarms from database
  void _loadActiveAlarms() {
    _activeAlarms = DatabaseService.instance
        .getAllAlarmSettings()
        .where((alarm) => alarm.isEnabled)
        .toList();
    log('Loaded ${_activeAlarms.length} active alarms: ${_activeAlarms.map((a) => a.name).toList()}');

    // Schedule each active alarm using the native AlarmManager
    for (final alarm in _activeAlarms) {
      AlarmMethodChannel.scheduleNativeAlarm({
        'id': alarm.id,
        'name': alarm.name,
        'hour': alarm.hour,
        'minute': alarm.minute,
        'gameType': alarm.gameType,
        'durationMinutes': alarm.durationMinutes,
        'selectedDays': alarm.selectedDays.toList(),
      });
    }
  }

  // Schedule next check for alarms
  void _scheduleNextCheck() {
    _checkTimer?.cancel();
    
    // Check every 10 seconds for better precision
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkAlarms();
    });
  }

  // Check if any alarms should trigger
  void _checkAlarms({DateTime? nowOverride}) {
    final now = nowOverride ?? _nowProvider();
    final currentDayOfWeek = now.weekday; // 1 = Monday, 7 = Sunday
    final todayKey = '${now.year}-${now.month}-${now.day}';
    
    log('Checking alarms - Current time: ${now.hour}:${now.minute}:${now.second}, Day: $currentDayOfWeek, Active alarms: ${_activeAlarms.length}');
    
    for (final alarm in _activeAlarms) {
      log('Checking alarm: ${alarm.name} at ${alarm.hour}:${alarm.minute}, Days: ${alarm.selectedDays}');
      
      // Check if alarm should trigger today
      if (alarm.selectedDays.contains(currentDayOfWeek)) {
        // Check if it's time for this alarm (within 10 seconds window)
        final alarmTime = DateTime(now.year, now.month, now.day, alarm.hour, alarm.minute);
        final timeDifference = now.difference(alarmTime).abs();
        
        // Create unique key for this alarm on this day
        // Include unique alarm id to avoid collisions when multiple alarms share the same time
        final alarmKey = '${todayKey}-${alarm.id}-${alarm.hour}-${alarm.minute}';
        
        log('Alarm time check - Current: ${now.hour}:${now.minute}:${now.second}, Alarm: ${alarm.hour}:${alarm.minute}, Difference: ${timeDifference.inSeconds}s, Already triggered: ${_triggeredAlarms.contains(alarmKey)}');
        
        // Trigger if within 30 seconds of the alarm time and not already triggered
        if (timeDifference.inSeconds <= 30 && !_triggeredAlarms.contains(alarmKey)) {
          log('TRIGGERING ALARM: ${alarm.name} at ${alarm.hour}:${alarm.minute} with game: ${alarm.gameType}');
          _triggeredAlarms.add(alarmKey);
          _triggerAlarm(alarm);
        }
      }
    }
  }

  // Trigger an alarm
  void _triggerAlarm(AlarmSettings alarm) {
    _alarmTriggerHandler(alarm);
  }

  void _defaultTriggerHandler(AlarmSettings alarm) {
    log('Triggering alarm:  [31m [1m${alarm.name} [0m at ${alarm.timeString} with game: ${alarm.gameType}');
  }

  // Refresh alarms (called when alarms are added/removed/modified)
  void refreshAlarms() {
    _loadActiveAlarms();
  }

  // Get next alarm time
  DateTime? getNextAlarmTime() {
    final now = _nowProvider();
    DateTime? nextAlarm;
    
    for (final alarm in _activeAlarms) {
      for (final day in alarm.selectedDays) {
        // Calculate next occurrence of this alarm
        int daysUntilAlarm = day - now.weekday;
        if (daysUntilAlarm < 0) {
          // If in the past, move to next week
          daysUntilAlarm += 7;
        }
        
        final nextOccurrence = now.add(Duration(days: daysUntilAlarm));
        final alarmTime = DateTime(
          nextOccurrence.year,
          nextOccurrence.month,
          nextOccurrence.day,
          alarm.hour,
          alarm.minute,
        );
        
        // If alarm time is in the past today, check if it's today and move to next occurrence
        DateTime finalAlarmTime;
        if (alarmTime.isBefore(now)) {
          if (daysUntilAlarm == 0) {
            // If it's today but time has passed, move to next occurrence
            finalAlarmTime = alarmTime.add(const Duration(days: 7));
          } else {
            // If it's a future day but time calculation is wrong, skip
            continue;
          }
        } else {
          finalAlarmTime = alarmTime;
        }
            
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

    final now = _nowProvider();
    final difference = nextAlarm.difference(now);
    
    if (difference.inDays > 0) {
      return 'Następny alarm: ${nextAlarm.day}/${nextAlarm.month} o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inDays} dni)';
    } else if (difference.inHours > 0) {
      return 'Następny alarm: o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inHours} godzin)';
    } else {
      return 'Następny alarm: o ${nextAlarm.hour.toString().padLeft(2, '0')}:${nextAlarm.minute.toString().padLeft(2, '0')} (za ${difference.inMinutes} minut)';
    }
  }

  @visibleForTesting
  void setTestOverrides({
    DateTime Function()? nowProvider,
    void Function(AlarmSettings)? triggerHandler,
    List<AlarmSettings>? activeAlarms,
  }) {
    if (nowProvider != null) {
      _nowProvider = nowProvider;
    }
    if (triggerHandler != null) {
      _alarmTriggerHandler = triggerHandler;
    } else {
      _alarmTriggerHandler = _defaultTriggerHandler;
    }
    if (activeAlarms != null) {
      _activeAlarms = activeAlarms;
    }
  }

  @visibleForTesting
  void resetTestOverrides() {
    _nowProvider = DateTime.now;
    _alarmTriggerHandler = _defaultTriggerHandler;
    _activeAlarms = [];
    _triggeredAlarms.clear();
  }

  @visibleForTesting
  void runManualCheck({required DateTime now}) {
    _checkAlarms(nowOverride: now);
  }

  @visibleForTesting
  void clearTriggeredCache() {
    _triggeredAlarms.clear();
  }
}

import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_alarm_manager_poc/hive/service/database_service.dart';
import 'package:flutter_alarm_manager_poc/utils/app_logger.dart';

class AlarmMethodChannel {
  static const name = "Flutter";
  static const platform = MethodChannel('com.example/alarm_manager');

  static Future<void> scheduleAlarmWithGame(String gameType, {int delaySeconds = 10}) async {
    try {
      log(name: name, 'Scheduling alarm with game: $gameType in $delaySeconds s');
      await platform.invokeMethod('scheduleAlarmWithGame', {
        'gameType': gameType,
        'delaySeconds': delaySeconds,
      });
      log(name: name, 'Alarm with game scheduled successfully');
    } on PlatformException catch (e) {
      log("Failed to schedule alarm with game: '${e.message}'.");
    }
  }

  static Future<void> scheduleNativeAlarm(Map<String, dynamic> alarmData) async {
    try {
      log(name: name, 'Scheduling native alarm: ${alarmData['name']} at ${alarmData['hour']}:${alarmData['minute']} with game: ${alarmData['gameType']}');
      await platform.invokeMethod('scheduleNativeAlarm', alarmData);
      log(name: name, 'Native alarm scheduled successfully');
    } on PlatformException catch (e) {
      log("Failed to schedule native alarm: '${e.message}'.");
    }
  }

  static Future<void> startAlarmSound() async {
    try {
      log(name: name, 'Starting alarm sound...');
      await platform.invokeMethod('startAlarmSound');
      log(name: name, 'Alarm sound start request sent successfully');
    } on PlatformException catch (e) {
      log("Failed to start alarm sound: '${e.message}'.");
    }
  }

  static Future<void> stopAlarmSound() async {
    try {
      log(name: name, 'Stopping alarm sound...');
      await platform.invokeMethod('stopAlarmSound');
      log(name: name, 'Alarm sound stop request sent successfully');
    } on PlatformException catch (e) {
      log("Failed to stop alarm sound: '${e.message}'.");
    }
  }

  // Exact alarm + battery optimization helpers
  static Future<bool> isExactAlarmAllowed() async {
    try {
      final allowed = await platform.invokeMethod('isExactAlarmAllowed');
      return (allowed == true);
    } on PlatformException catch (e) {
      log("Failed to check exact alarm permission: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission() async {
    try {
      await platform.invokeMethod('requestExactAlarmPermission');
      return true;
    } on PlatformException catch (e) {
      log("Failed to request exact alarm permission: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final ignoring = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      return (ignoring == true);
    } on PlatformException catch (e) {
      log("Failed to check battery optimizations: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      return true;
    } on PlatformException catch (e) {
      log("Failed to request ignore battery optimizations: '${e.message}'.");
      return false;
    }
  }

  static Future<void> setAlarmActive(bool active) async {
    try {
      await platform.invokeMethod('setAlarmActive', active);
    } on PlatformException catch (e) {
      log("Failed to set alarm_active: '${e.message}'.");
    }
  }

  static Future<void> alarmCompleted() async {
    try {
      await platform.invokeMethod('alarmCompleted');
    } on PlatformException catch (e) {
      log("Failed to mark alarm completed: '${e.message}'.");
    }
  }

  static Future<void> alarmHandled({required int alarmId, int suppressSeconds = 180}) async {
    try {
      await platform.invokeMethod('alarmHandled', {
        'alarmId': alarmId,
        'suppressSeconds': suppressSeconds,
      });
    } on PlatformException catch (e) {
      log("Failed to mark alarm handled: '${e.message}'.");
    }
  }

  static DateTime? _pendingAlarmTime;

  static void setPendingAlarmTime(DateTime alarmTime) {
    _pendingAlarmTime = alarmTime;
  }

  static DateTime? getPendingAlarmTime() {
    final time = _pendingAlarmTime;
    _pendingAlarmTime = null; // Clear after getting
    return time;
  }

  static Map<String, dynamic>? _pendingAlarmArgs;

  static void setPendingAlarmArgs(Map<String, dynamic> args) {
    _pendingAlarmArgs = args;
  }

  static Map<String, dynamic>? getPendingAlarmArgs() {
    // Persist args across rebuilds to avoid falling back to defaults
    return _pendingAlarmArgs;
  }

  static void clearPendingAlarmArgs() {
    _pendingAlarmArgs = null;
  }

  static void initialize() {
    log(name: name, 'Initializing AlarmMethodChannel');
    platform.setMethodCallHandler(_handleMethodCall);
    log(name: name, 'AlarmMethodChannel initialized');
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    log(name: name, 'Received method call: ${call.method}');
    AppLogger.instance.log('MC call: ${call.method}');

    // var alarmBox = Hive.box<AlarmAction>('alarm_actions');

    switch (call.method) {
      case 'alarmAccepted':
        log(name: name, 'Alarm was accepted');
        AppLogger.instance.log('Alarm accepted');
        //   await alarmBox.add(AlarmAction('accept', DateTime.now()));

        await DatabaseService.instance.storeAlarmAction("accept");

        // Handle alarm accepted
        // You can call a function or update state here
        break;
      case 'alarmSnoozed':
        log(name: name, 'Alarm was snoozed');
        AppLogger.instance.log('Alarm snoozed');
        // await alarmBox.add(AlarmAction('snooze', DateTime.now()));

        await DatabaseService.instance.storeAlarmAction("snooze");

        // Handle alarm snoozed
        // You can call a function or update state here
        break;
      case 'navigateToAlarmGame':
        log(name: name, 'Navigating to alarm game');
        AppLogger.instance.log('Navigate to game');
        final args = Map<String, dynamic>.from(call.arguments);
        setPendingAlarmArgs(args);
        final dm = args['durationMinutes'];
        final gt = args['gameType'];
        AppLogger.instance.log('Args: game=$gt, duration=$dm');
        break;
      case 'setPendingAlarmArgs':
        log(name: name, 'Setting pending alarm args');
        final args = Map<String, dynamic>.from(call.arguments);
        setPendingAlarmArgs(args);
        final dm = args['durationMinutes'];
        final gt = args['gameType'];
        AppLogger.instance.log('Pending args: game=$gt, duration=$dm');
        break;
      case 'setMaxVolume':
        log(name: name, 'Setting max volume - handled by native code');
        break;
      case 'restoreOriginalVolume':
        log(name: name, 'Restoring original volume - handled by native code');
        break;
      default:
        log('Unrecognized method ${call.method}');
    }
  }
}

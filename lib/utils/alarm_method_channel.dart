import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_alarm_manager_poc/hive/service/database_service.dart';

class AlarmMethodChannel {
  static const name = "Flutter";
  static const platform = MethodChannel('com.example/alarm_manager');

  static Future<void> scheduleAlarm() async {
    try {
      log(name: name, 'Scheduling alarm...');
      await platform.invokeMethod('scheduleAlarm');
      log(name: name, 'Alarm scheduled successfully');
    } on PlatformException catch (e) {
      log("Failed to schedule alarm: '${e.message}'.");
    }
  }

  static Future<void> scheduleAlarmWithGame(String gameType) async {
    try {
      log(name: name, 'Scheduling alarm with game: $gameType');
      await platform.invokeMethod('scheduleAlarmWithGame', {'gameType': gameType});
      log(name: name, 'Alarm with game scheduled successfully');
    } on PlatformException catch (e) {
      log("Failed to schedule alarm with game: '${e.message}'.");
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
    final args = _pendingAlarmArgs;
    _pendingAlarmArgs = null; // Clear after getting
    return args;
  }

  static void initialize() {
    log(name: name, 'Initializing AlarmMethodChannel');
    platform.setMethodCallHandler(_handleMethodCall);
    log(name: name, 'AlarmMethodChannel initialized');
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    log(name: name, 'Received method call: ${call.method}');

    // var alarmBox = Hive.box<AlarmAction>('alarm_actions');

    switch (call.method) {
      case 'alarmAccepted':
        log(name: name, 'Alarm was accepted');
        //   await alarmBox.add(AlarmAction('accept', DateTime.now()));

        await DatabaseService.instance.storeAlarmAction("accept");

        // Handle alarm accepted
        // You can call a function or update state here
        break;
      case 'alarmSnoozed':
        log(name: name, 'Alarm was snoozed');
        // await alarmBox.add(AlarmAction('snooze', DateTime.now()));

        await DatabaseService.instance.storeAlarmAction("snooze");

        // Handle alarm snoozed
        // You can call a function or update state here
        break;
      case 'navigateToAlarmGame':
        log(name: name, 'Navigating to alarm game');
        final args = Map<String, dynamic>.from(call.arguments);
        setPendingAlarmArgs(args);
        break;
      case 'setPendingAlarmArgs':
        log(name: name, 'Setting pending alarm args');
        final args = Map<String, dynamic>.from(call.arguments);
        setPendingAlarmArgs(args);
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

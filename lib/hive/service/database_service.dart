import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/alarm_action.dart';
import '../models/alarm_settings.dart';

class DatabaseService {
  static const String alarmBoxName = 'alarm_actions';
  static const String alarmSettingsBoxName = 'alarm_settings';
  static DatabaseService? _instance;
  late Box<AlarmAction> _alarmBox;
  late Box<AlarmSettings> _alarmSettingsBox;

  // Private constructor
  DatabaseService._();

  // Singleton instance getter
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  ValueListenable<Box<AlarmAction>> get alarmBoxListenable =>
      _alarmBox.listenable();

  ValueListenable<Box<AlarmSettings>> get alarmSettingsBoxListenable =>
      _alarmSettingsBox.listenable();

  // Initialize Hive and open the alarm actions box
  Future<void> initializeHive() async {
    try {
      await Hive.initFlutter();
      Hive.registerAdapter(AlarmActionAdapter());
      Hive.registerAdapter(AlarmSettingsAdapter());
      _alarmBox = await Hive.openBox<AlarmAction>(alarmBoxName);
      _alarmSettingsBox = await Hive.openBox<AlarmSettings>(alarmSettingsBoxName);
      log('Hive initialized and boxes opened successfully.');
    } catch (e) {
      log('Failed to initialize Hive or open boxes: $e');
    }
  }

  // Add an alarm action to the Hive box
  Future<void> storeAlarmAction(String actionType) async {
    try {
      await _alarmBox.add(
        AlarmAction(actionType, DateTime.now()),
      );
      log('Stored alarm action: $actionType');

      var actions = getAllAlarmActions();
      log('Retrieved ${actions.length} alarm actions.');
    } catch (e) {
      log('Failed to store alarm action: $e');
    }
  }

  // Retrieve all alarm actions from the Hive box
  List<AlarmAction> getAllAlarmActions() {
    try {
      var actions = _alarmBox.values;
      log('Retrieved ${actions.length} alarm actions.');
      return actions.toList();
    } catch (e) {
      log('Failed to retrieve alarm actions: $e');
      return [];
    }
  }

  // Clear all alarm actions (if needed)
  Future<void> clearAllAlarmActions() async {
    try {
      await _alarmBox.clear();
      log('All alarm actions cleared.');
    } catch (e) {
      log('Failed to clear alarm actions: $e');
    }
  }

  // Alarm Settings methods
  Future<void> saveAlarmSettings(AlarmSettings alarmSettings) async {
    try {
      await _alarmSettingsBox.put(alarmSettings.id, alarmSettings);
      log('Saved alarm settings: ${alarmSettings.name}');
    } catch (e) {
      log('Failed to save alarm settings: $e');
    }
  }

  List<AlarmSettings> getAllAlarmSettings() {
    try {
      var settings = _alarmSettingsBox.values.toList();
      log('Retrieved ${settings.length} alarm settings.');
      return settings;
    } catch (e) {
      log('Failed to retrieve alarm settings: $e');
      return [];
    }
  }

  Future<void> deleteAlarmSettings(String id) async {
    try {
      await _alarmSettingsBox.delete(id);
      log('Deleted alarm settings: $id');
    } catch (e) {
      log('Failed to delete alarm settings: $e');
    }
  }

  Future<void> toggleAlarmSettings(String id, bool enabled) async {
    try {
      final alarm = _alarmSettingsBox.get(id);
      if (alarm != null) {
        final updatedAlarm = alarm.copyWith(isEnabled: enabled);
        await _alarmSettingsBox.put(id, updatedAlarm);
        log('Toggled alarm settings: $id to $enabled');
      }
    } catch (e) {
      log('Failed to toggle alarm settings: $e');
    }
  }
}

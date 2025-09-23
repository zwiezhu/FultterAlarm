import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_alarm_manager_poc/hive/models/alarm_settings.dart';
import 'package:flutter_alarm_manager_poc/services/alarm_scheduler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final scheduler = AlarmSchedulerService.instance;

  setUp(() {
    scheduler.stopScheduler();
    scheduler.resetTestOverrides();
  });

  tearDown(() {
    scheduler.resetTestOverrides();
  });

  group('AlarmSchedulerService scheduling', () {
    test('triggers alarm when current time matches scheduled time and day', () {
      final triggered = <AlarmSettings>[];
      final alarm = AlarmSettings(
        id: 'alarm-1',
        hour: 7,
        minute: 30,
        gameType: 'piano_tiles',
        selectedDays: const [DateTime.monday],
        name: 'Poranny alarm',
        durationMinutes: 5,
      );

      scheduler.setTestOverrides(
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) => triggered.add(firedAlarm),
      );

      scheduler.runManualCheck(now: DateTime(2024, 1, 1, 7, 30));

      expect(triggered, hasLength(1));
      expect(triggered.first.id, equals(alarm.id));
    });

    test('does not trigger alarm on days outside of configuration', () {
      final triggered = <AlarmSettings>[];
      final alarm = AlarmSettings(
        id: 'alarm-2',
        hour: 6,
        minute: 45,
        gameType: 'memory_match',
        selectedDays: const [DateTime.tuesday],
        name: 'Wtorkowy alarm',
        durationMinutes: 3,
      );

      scheduler.setTestOverrides(
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) => triggered.add(firedAlarm),
      );

      scheduler.runManualCheck(now: DateTime(2024, 1, 1, 6, 45));

      expect(triggered, isEmpty);
    });

    test('triggers each alarm only once per day within window', () {
      final triggered = <String>[];
      final alarm = AlarmSettings(
        id: 'alarm-3',
        hour: 8,
        minute: 0,
        gameType: 'number_rush',
        selectedDays: const [DateTime.monday],
        name: 'Jednorazowy alarm',
        durationMinutes: 2,
      );

      scheduler.setTestOverrides(
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) => triggered.add(firedAlarm.id),
      );

      final firstCheck = DateTime(2024, 1, 1, 8, 0, 5);
      final secondCheck = firstCheck.add(const Duration(seconds: 20));

      scheduler.runManualCheck(now: firstCheck);
      scheduler.runManualCheck(now: secondCheck);

      expect(triggered, equals(['alarm-3']));
    });

    test('triggers multiple alarms scheduled for the same time', () {
      final triggeredIds = <String>[];
      final alarmA = AlarmSettings(
        id: 'alarm-A',
        hour: 9,
        minute: 15,
        gameType: 'ball_runner',
        selectedDays: const [DateTime.monday],
        name: 'Alarm A',
        durationMinutes: 4,
      );
      final alarmB = AlarmSettings(
        id: 'alarm-B',
        hour: 9,
        minute: 15,
        gameType: 'sudoku',
        selectedDays: const [DateTime.monday],
        name: 'Alarm B',
        durationMinutes: 1,
      );

      scheduler.setTestOverrides(
        activeAlarms: [alarmA, alarmB],
        triggerHandler: (firedAlarm) => triggeredIds.add(firedAlarm.id),
      );

      scheduler.runManualCheck(now: DateTime(2024, 1, 1, 9, 15));

      expect(triggeredIds, containsAll(['alarm-A', 'alarm-B']));
      expect(triggeredIds, hasLength(2));
    });

    test('computes next alarm across week boundary when today has passed', () {
      var now = DateTime(2024, 1, 1, 9, 0); // Monday 09:00
      final alarm = AlarmSettings(
        id: 'alarm-weekly',
        hour: 8,
        minute: 0,
        gameType: 'piano_tiles',
        selectedDays: const [DateTime.monday],
        name: 'Tygodniowy alarm',
        durationMinutes: 5,
      );

      scheduler.setTestOverrides(
        nowProvider: () => now,
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) {},
      );

      final nextAlarm = scheduler.getNextAlarmTime();

      expect(nextAlarm, equals(DateTime(2024, 1, 8, 8, 0)));
    });

    test('selects closest upcoming occurrence among multiple days', () {
      var now = DateTime(2024, 1, 1, 7, 0); // Monday 07:00
      final alarm = AlarmSettings(
        id: 'alarm-multi',
        hour: 8,
        minute: 0,
        gameType: 'swipe_tiles',
        selectedDays: const [DateTime.monday, DateTime.wednesday],
        name: 'Wielodniowy alarm',
        durationMinutes: 1,
      );

      scheduler.setTestOverrides(
        nowProvider: () => now,
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) {},
      );

      final nextAlarm = scheduler.getNextAlarmTime();

      expect(nextAlarm, equals(DateTime(2024, 1, 1, 8, 0)));

      now = DateTime(2024, 1, 1, 9, 0); // Monday 09:00 -> next should be Wednesday
      scheduler.setTestOverrides(
        nowProvider: () => now,
        activeAlarms: [alarm],
        triggerHandler: (firedAlarm) {},
      );

      final secondNextAlarm = scheduler.getNextAlarmTime();
      expect(secondNextAlarm, equals(DateTime(2024, 1, 3, 8, 0)));
    });
  });
}

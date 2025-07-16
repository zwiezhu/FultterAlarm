import 'package:hive/hive.dart';

part 'alarm_settings.g.dart';

@HiveType(typeId: 1)
class AlarmSettings extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final int hour;

  @HiveField(2)
  final int minute;

  @HiveField(3)
  final String gameType;

  @HiveField(4)
  final List<int> selectedDays;

  @HiveField(5)
  final bool isEnabled;

  @HiveField(6)
  final String name;

  @HiveField(7)
  final int durationMinutes;

  AlarmSettings({
    required this.id,
    required this.hour,
    required this.minute,
    required this.gameType,
    required this.selectedDays,
    this.isEnabled = true,
    required this.name,
    this.durationMinutes = 1,
  });

  // Helper method to get time as string
  String get timeString {
    final hourStr = hour.toString().padLeft(2, '0');
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  // Helper method to get days as string
  String get daysString {
    if (selectedDays.isEmpty) return 'Brak dni';
    
    final dayNames = {
      1: 'Pon',
      2: 'Wt',
      3: 'Śr',
      4: 'Czw',
      5: 'Pt',
      6: 'Sob',
      7: 'Ndz',
    };
    
    final sortedDays = selectedDays.toList()..sort();
    return sortedDays.map((day) => dayNames[day] ?? '?').join(', ');
  }

  // Helper method to get game name
  String get gameName {
    final gameNames = {
      'piano_tiles': 'Piano Tiles',
      'swipe_tiles': 'Swipe Tiles',
      'memory_match': 'Memory Match',
      'number_rush': 'Number Rush',
      'sudoku': 'Sudoku',
      'ball_runner': 'Ball Runner',
    };
    return gameNames[gameType] ?? gameType;
  }

  // Create a copy with updated fields
  AlarmSettings copyWith({
    String? id,
    int? hour,
    int? minute,
    String? gameType,
    List<int>? selectedDays,
    bool? isEnabled,
    String? name,
    int? durationMinutes,
  }) {
    return AlarmSettings(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      gameType: gameType ?? this.gameType,
      selectedDays: selectedDays ?? this.selectedDays,
      isEnabled: isEnabled ?? this.isEnabled,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
} 
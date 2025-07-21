import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'hive/models/alarm_settings.dart';
import 'hive/service/database_service.dart';
import 'services/alarm_scheduler_service.dart';
import 'utils/alarm_method_channel.dart';

class AlarmSettingsScreen extends StatefulWidget {
  const AlarmSettingsScreen({super.key});

  @override
  State<AlarmSettingsScreen> createState() => _AlarmSettingsScreenState();
}

class _AlarmSettingsScreenState extends State<AlarmSettingsScreen> {
  TimeOfDay selectedTime = const TimeOfDay(hour: 7, minute: 0);
  String selectedGame = 'piano_tiles';
  Set<int> selectedDays = {1, 2, 3, 4, 5}; // Domyślnie dni robocze (pon-pt)
  int durationMinutes = 1;
  final TextEditingController _nameController = TextEditingController();
  
  final List<Map<String, dynamic>> games = [
    {'id': 'piano_tiles', 'name': 'Piano Tiles', 'description': 'Klasyczna gra z kafelkami'},
    {'id': 'swipe_tiles', 'name': 'Swipe Tiles', 'description': 'Przesuwaj kafelki w odpowiednim kierunku'},
    {'id': 'memory_match', 'name': 'Memory Match', 'description': 'Znajdź pary kart'},
    {'id': 'number_rush', 'name': 'Number Rush', 'description': 'Klikaj liczby w kolejności'},
    {'id': 'sudoku', 'name': 'Sudoku', 'description': 'Rozwiąż łamigłówkę sudoku'},
    {'id': 'ball_runner', 'name': 'Ball Runner', 'description': 'Steruj piłką przez przeszkody'},
    {'id': 'block_drop', 'name': 'Block Drop', 'description': 'Układaj spadające bloki'},
    {'id': 'cave_lander', 'name': 'Cave Lander', 'description': 'Ląduj bezpiecznie w jaskini'},
    {'id': 'icy_tower', 'name': 'Icy Tower', 'description': 'Wspinaj się po lodowej wieży'},
    {'id': 'sky_tower', 'name': 'Sky Tower', 'description': 'Wspinaj się po wieży na niebie'},
    {'id': 'wall_bounce', 'name': 'Wall Bounce', 'description': 'Odbijaj się od ścian'},
    {'id': 'wall_kickers', 'name': 'Wall Kickers', 'description': 'Skacz po ścianach'},
  ];

  final List<Map<String, dynamic>> weekDays = [
    {'id': 1, 'name': 'Poniedziałek', 'short': 'Pon'},
    {'id': 2, 'name': 'Wtorek', 'short': 'Wt'},
    {'id': 3, 'name': 'Środa', 'short': 'Śr'},
    {'id': 4, 'name': 'Czwartek', 'short': 'Czw'},
    {'id': 5, 'name': 'Piątek', 'short': 'Pt'},
    {'id': 6, 'name': 'Sobota', 'short': 'Sob'},
    {'id': 7, 'name': 'Niedziela', 'short': 'Ndz'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia Alarmu'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[850],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Czas alarmu
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Czas Alarmu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _selectTime,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(
                                DateTime(2024, 1, 1, selectedTime.hour, selectedTime.minute),
                              ),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Icon(
                              Icons.access_time,
                              color: Colors.white,
                              size: 24,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            
            
            // Wybór gry
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gra do Wyłączenia Alarmu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200, // Ograniczenie wysokości, aby lista była przewijalna
                      child: ListView.builder(
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final game = games[index];
                          final isSelected = selectedGame == game['id'];
                          return Card(
                            color: isSelected ? Colors.blue.withOpacity(0.5) : Colors.grey[700],
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              title: Text(game['name'], style: const TextStyle(color: Colors.white)),
                              subtitle: Text(game['description'], style: TextStyle(color: Colors.grey[300])),
                              onTap: () {
                                setState(() {
                                  selectedGame = game['id'];
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Wybór czasu gry
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Czas gry do wyłączenia alarmu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListWheelScrollView.useDelegate(
                        itemExtent: 40,
                        diameterRatio: 2.5,
                        perspective: 0.003,
                        physics: FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            durationMinutes = index + 1;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            if (index < 0 || index > 19) return null;
                            return Container(
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1} min',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: durationMinutes == index + 1 ? Colors.blue : Colors.white,
                                  fontWeight: durationMinutes == index + 1 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wybrano: $durationMinutes min',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dni tygodnia
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dni Tygodnia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Pojedyncze dni
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: weekDays.map((day) {
                        final isSelected = selectedDays.contains(day['id']);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selectedDays.remove(day['id']);
                              } else {
                                selectedDays.add(day['id']);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.grey[700],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              day['short'],
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[300],
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Szybkie opcje
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedDays = {1, 2, 3, 4, 5}; // Dni robocze
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Dni Robocze',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedDays = {6, 7}; // Weekend
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Weekend',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedDays = {1, 2, 3, 4, 5, 6, 7}; // Wszystkie dni
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text(
                        'Wszystkie Dni',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Przycisk zapisz
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAlarmSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Zapisz Ustawienia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.grey[800]!,
              hourMinuteTextColor: Colors.white,
              hourMinuteColor: Colors.grey[700]!,
              dialBackgroundColor: Colors.grey[700]!,
              dialHandColor: Colors.blue,
              dialTextColor: Colors.white,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _saveAlarmSettings() async {
    // Sprawdź czy wybrano dni
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proszę wybrać dni tygodnia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Utwórz nowy alarm
    final alarmSettings = AlarmSettings(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hour: selectedTime.hour,
      minute: selectedTime.minute,
      gameType: selectedGame,
      selectedDays: selectedDays.toList(),
      name: "Alarm", // Default name
      durationMinutes: durationMinutes,
    );

    // Zapisz alarm
    await DatabaseService.instance.saveAlarmSettings(alarmSettings);

    // Schedule the native alarm immediately for the next occurrence
    AlarmMethodChannel.scheduleNativeAlarm({
      'id': alarmSettings.id,
      'name': alarmSettings.name,
      'hour': alarmSettings.hour,
      'minute': alarmSettings.minute,
      'gameType': alarmSettings.gameType,
      'selectedDays': alarmSettings.selectedDays,
    });
    
    // Odśwież scheduler
    AlarmSchedulerService.instance.refreshAlarms();

    // Pokaż potwierdzenie
    final selectedDaysList = selectedDays.toList()..sort();
    final daysNames = selectedDaysList.map((day) {
      return weekDays.firstWhere((d) => d['id'] == day)['name'];
    }).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Alarm Zapisany',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Alarm został zapisany:\n\n'
          'Czas: ${alarmSettings.timeString}\n'
          'Gra: ${alarmSettings.gameName}\n'
          'Dni: ${daysNames.join(', ')}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
} 
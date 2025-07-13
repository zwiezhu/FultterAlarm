import 'package:flutter/material.dart';
import 'package:flutter_alarm_manager_poc/alarm_actions_screen.dart';
import 'package:flutter_alarm_manager_poc/game_list_screen.dart';
import 'package:flutter_alarm_manager_poc/alarm_settings_screen.dart';
import 'package:flutter_alarm_manager_poc/alarm_list_screen.dart';
import 'package:flutter_alarm_manager_poc/utils/alarm_method_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive/models/alarm_settings.dart';
import 'hive/service/database_service.dart';
import 'services/alarm_scheduler_service.dart';

class AlarmManagerScreen extends StatefulWidget {
  const AlarmManagerScreen({super.key});

  @override
  State<AlarmManagerScreen> createState() => _AlarmManagerScreenState();
}

class _AlarmManagerScreenState extends State<AlarmManagerScreen> {
  bool _isRequestingPermission = false;

  @override
  void initState() {
    super.initState();
    // Inicjalizuj bazę danych
    DatabaseService.instance.initializeHive();
    // Uruchom scheduler alarmów (jeśli nie jest już uruchomiony)
    if (!AlarmSchedulerService.instance.isRunning) {
      AlarmSchedulerService.instance.startScheduler();
    }
  }

  @override
  void dispose() {
    // Don't stop the scheduler when leaving this screen
    // The scheduler should keep running in the background
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    if (_isRequestingPermission) return;

    setState(() {
      _isRequestingPermission = true;
    });

    try {
      final status = await Permission.notification.request();

      // Sprawdź czy widget jest nadal mounted
      if (!mounted) return;

      if (status.isGranted) {
        await AlarmMethodChannel.scheduleAlarm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Notification permission is required to schedule alarms.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alarm Manager Screen"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.access_alarm),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AlarmActionsScreen()));
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Informacja o następnym alarmie
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AlarmSchedulerService.instance.getNextAlarmString(),
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Lista alarmów
          Expanded(
            child: ValueListenableBuilder<Box<AlarmSettings>>(
              valueListenable: DatabaseService.instance.alarmSettingsBoxListenable,
              builder: (context, box, child) {
                final alarms = box.values.where((alarm) => alarm.isEnabled).toList();
                
                if (alarms.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.alarm_off,
                          size: 64,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Brak aktywnych alarmów',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dodaj swój pierwszy alarm',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = alarms[index];
                    return Card(
                      color: Colors.grey[800],
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.alarm,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          alarm.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${alarm.timeString} • ${alarm.gameName} • ${alarm.daysString}',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Przyciski akcji
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlarmSettingsScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Dodaj Alarm",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlarmListScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Lista Alarmów",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isRequestingPermission
                            ? null
                            : () async {
                                await _requestNotificationPermission();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Test Alarm (10s)",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GameListScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          "Casual Play",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
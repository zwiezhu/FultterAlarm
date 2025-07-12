import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'hive/models/alarm_settings.dart';
import 'hive/service/database_service.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista Alarmów'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[850],
      body: ValueListenableBuilder<Box<AlarmSettings>>(
        valueListenable: DatabaseService.instance.alarmSettingsBoxListenable,
        builder: (context, box, child) {
          final alarms = box.values.toList();
          
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
                    'Brak zapisanych alarmów',
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: alarm.isEnabled ? Colors.blue : Colors.grey[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alarm.isEnabled ? Icons.alarm : Icons.alarm_off,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  title: Text(
                    alarm.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '${alarm.timeString} • ${alarm.gameName}',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alarm.daysString,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Toggle switch
                      Switch(
                        value: alarm.isEnabled,
                        onChanged: (value) async {
                          await DatabaseService.instance.toggleAlarmSettings(alarm.id, value);
                        },
                        activeColor: Colors.blue,
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                        onPressed: () => _showDeleteDialog(alarm),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteDialog(AlarmSettings alarm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: const Text(
          'Usuń Alarm',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Czy na pewno chcesz usunąć alarm "${alarm.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Anuluj',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.instance.deleteAlarmSettings(alarm.id);
              Navigator.of(context).pop();
            },
            child: const Text(
              'Usuń',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
} 
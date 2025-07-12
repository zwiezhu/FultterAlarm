
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AlarmScreen extends StatelessWidget {
  final VoidCallback onPlay;
  final VoidCallback onSnooze;
  final DateTime alarmTime;

  const AlarmScreen({
    Key? key,
    required this.onPlay,
    required this.onSnooze,
    required this.alarmTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm!'),
        automaticallyImplyLeading: false, // No back button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "It's ${DateFormat('HH:mm').format(alarmTime)}",
              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onSnooze,
              child: const Text('Snooze (1 minute)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onPlay,
              child: const Text('Graj w grę'),
            ),
          ],
        ),
      ),
    );
  }
}

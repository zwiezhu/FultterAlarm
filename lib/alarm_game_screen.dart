import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'utils/alarm_method_channel.dart';
import 'swipe_tiles_flutter.dart';
import 'memory_match_flutter.dart';
import 'number_rush_flutter.dart';
import 'sudoku_game_flutter.dart';
import 'ball_runner_flutter.dart';
import 'block_drop_game_flutter.dart';
import 'cave_lander_flutter.dart';
import 'icy_tower_flutter.dart';
import 'sky_tower_game_screen.dart';
import 'wall_bounce_flutter.dart';
import 'wall_kickers_flutter.dart';
import 'game_screen.dart'; // Piano Tiles game

class AlarmGameScreen extends StatefulWidget {
  final DateTime alarmTime;
  final String gameType;
  final int durationMinutes;
  
  const AlarmGameScreen({
    super.key,
    required this.alarmTime,
    required this.gameType,
    this.durationMinutes = 1,
  });

  @override
  State<AlarmGameScreen> createState() => _AlarmGameScreenState();
}

class _AlarmGameScreenState extends State<AlarmGameScreen> {
  // Alarm system state
  bool alarmActive = false; // Start with alarm inactive - it will activate after 15s inactivity
  int remainingSeconds = 60; // 1 minute countdown
  int inactivityTimer = 15; // 15 seconds inactivity timer
  bool showCompletionDialog = false;
  int durationMinutes = 1;

  // Timers
  Timer? _alarmTimer;
  Timer? _inactivityTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    durationMinutes = widget.durationMinutes;
    remainingSeconds = durationMinutes * 60;
    print("AlarmGameScreen: initState called, durationMinutes: $durationMinutes");
    _startAlarmSystem();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No additional initialization required here
  }
  void _startAlarm() async {
    print('AlarmGameScreen: _startAlarm called');
    
    // Start alarm sound through platform channel
    await AlarmMethodChannel.startAlarmSound();
    print('Alarm started at ${widget.alarmTime}');
  }

  void _stopAlarm() async {
    print('AlarmGameScreen: _stopAlarm called');
    
    // Stop alarm sound through platform channel
    await AlarmMethodChannel.stopAlarmSound();
    print('Alarm stopped');
  }

  void _startAlarmSystem() async {
    print('AlarmGameScreen: _startAlarmSystem called');
    
    // Start the 1-minute countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        setState(() {
          remainingSeconds--;
        });
      } else {
        // Full minute completed
        _completeAlarm();
        timer.cancel();
      }
    });

    // Start inactivity timer
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    print('AlarmGameScreen: _startInactivityTimer called - timer: $inactivityTimer');
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (inactivityTimer > 0) {
        setState(() {
          inactivityTimer--;
        });
        print('AlarmGameScreen: Inactivity timer: $inactivityTimer');
      } else {
        // User was inactive for 15 seconds
        print('AlarmGameScreen: User inactive for 15 seconds - starting alarm');
        _handleInactivity();
        timer.cancel();
      }
    });
  }

  void _handleInactivity() async {
    print('AlarmGameScreen: _handleInactivity called');
    
    // Reset the countdown and restart alarm
    setState(() {
      remainingSeconds = 60;
      inactivityTimer = 15;
      alarmActive = true;
    });
    
    _startAlarm(); // Start alarm sound again
    _startInactivityTimer();
  }

  void _completeAlarm() async {
    print('AlarmGameScreen: _completeAlarm called');
    setState(() {
      alarmActive = false;
      showCompletionDialog = true;
    });
    
    _stopAlarm();
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Show completion dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCompletionDialog();
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Alarm wyłączony!',
            style: TextStyle(color: Colors.white, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'Gratulacje! Udało Ci się wyłączyć alarm grając przez pełną minutę.\n\nMożesz teraz zamknąć aplikację.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to main screen
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleUserInteraction() {
    print('AlarmGameScreen: _handleUserInteraction called');
    // Always reset inactivity timer on any user interaction
    setState(() {
      inactivityTimer = 15; // Reset inactivity timer
    });
    _startInactivityTimer(); // Restart the timer
    
    // Stop alarm sound when user interacts (if alarm is currently playing)
    if (alarmActive) {
      print('AlarmGameScreen: Stopping alarm due to user interaction');
      _stopAlarm();
      setState(() {
        alarmActive = false;
      });
    }
  }

  @override
  void dispose() {
    print('AlarmGameScreen: dispose called');
    _stopAlarm();
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return the appropriate game based on gameType
    switch (widget.gameType) {
      case 'piano_tiles':
        return GameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'swipe_tiles':
        return SwipeTilesGameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'memory_match':
        return MemoryMatchGameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'number_rush':
        return NumberRushGameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'sudoku':
        return SudokuGame(
          onScoreChange: (score) => _handleUserInteraction(),
          gameCompleted: false,
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'ball_runner':
        return BallRunnerGame(
          onScoreChange: (score) => _handleUserInteraction(),
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
      case 'block_drop':
        return BlockDropGame(
          onScoreChange: (score) => _handleUserInteraction(),
          gameCompleted: false,
        );
      case 'cave_lander':
        return CaveLanderGameScreen();
      case 'icy_tower':
        return IcyTowerGameScreen();
      case 'sky_tower':
        return SkyTowerGameScreen();
      case 'wall_bounce':
        return WallBounceGame();
      case 'wall_kickers':
        return WallKickersGame();
      default:
        // Default to piano tiles game
        return GameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
        );
    }
  }
} 
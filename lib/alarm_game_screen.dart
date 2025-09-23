import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'utils/alarm_method_channel.dart';
import 'package:flutter/services.dart';
import 'utils/app_logger.dart';
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
  final int? alarmId;
  
  const AlarmGameScreen({
    super.key,
    required this.alarmTime,
    required this.gameType,
    this.durationMinutes = 1,
    this.alarmId,
  });

  @override
  State<AlarmGameScreen> createState() => _AlarmGameScreenState();
}

class _AlarmGameScreenState extends State<AlarmGameScreen> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    // Nie używaj context tutaj!
    // Pozostała inicjalizacja
    print('AlarmGameScreen: initState called');
    durationMinutes = widget.durationMinutes;
    // Try to hydrate from pending args if provided asynchronously by native
    final pending = AlarmMethodChannel.getPendingAlarmArgs();
    if (pending != null) {
      final dm = pending['durationMinutes'];
      if (dm is int && dm > 0) {
        durationMinutes = dm;
      }
      final gt = pending['gameType'];
      AppLogger.instance.log('Pending args: game=$gt, duration=$durationMinutes');
    }
    remainingSeconds = durationMinutes * 60;
    AppLogger.instance.log('Timer set: ${remainingSeconds}s');
    // Re-check pending args shortly after init to avoid race with native invoke
    Future.delayed(const Duration(milliseconds: 200), () {
      final later = AlarmMethodChannel.getPendingAlarmArgs();
      if (later != null) {
        final dm = later['durationMinutes'];
        if (dm is int && dm > 0 && dm != durationMinutes) {
          setState(() {
            durationMinutes = dm;
            remainingSeconds = durationMinutes * 60;
          });
          AppLogger.instance.log('Args late update: duration=$durationMinutes => ${remainingSeconds}s');
        }
      }
    });
    // Mark alarm as active on native side
    AlarmMethodChannel.setAlarmActive(true);
    _startAlarmSystem();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pobierz durationMinutes z argumentów, jeśli dostępne
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['durationMinutes'] != null) {
      durationMinutes = args['durationMinutes'] as int;
      remainingSeconds = durationMinutes * 60;
      print('AlarmGameScreen: didChangeDependencies called, durationMinutes: $durationMinutes');
    }
  }

  void _startAlarm() async {
    print('AlarmGameScreen: _startAlarm called');
    AppLogger.instance.log('Start alarm sound');
    
    // Start alarm sound through platform channel
    await AlarmMethodChannel.startAlarmSound();
    print('Alarm started at ${widget.alarmTime}');
  }

  void _stopAlarm() async {
    print('AlarmGameScreen: _stopAlarm called');
    AppLogger.instance.log('Stop alarm sound');
    
    // Stop alarm sound through platform channel
    await AlarmMethodChannel.stopAlarmSound();
    print('Alarm stopped');
  }

  void _startAlarmSystem() async {
    print('AlarmGameScreen: _startAlarmSystem called');
    AppLogger.instance.log('Start countdown');
    
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
        AppLogger.instance.log('Inactivity reached: restart sound');
        _handleInactivity();
        timer.cancel();
      }
    });
  }

  void _handleInactivity() async {
    print('AlarmGameScreen: _handleInactivity called');
    // Do NOT reset the countdown when user is inactive or loses.
    // Only restart the alarm sound and the inactivity timer.
    setState(() {
      // Keep remainingSeconds unchanged to avoid restarting countdown
      AppLogger.instance.log('Inactivity reached: keep timer at ${remainingSeconds}s');
      inactivityTimer = 15;
      alarmActive = true;
    });
    
    _startAlarm(); // Start alarm sound again
    _startInactivityTimer();
  }

  void _completeAlarm() async {
    print('AlarmGameScreen: _completeAlarm called');
    AppLogger.instance.log('Alarm completed');
    setState(() {
      alarmActive = false;
      showCompletionDialog = true;
    });
    
    _stopAlarm();
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    // Inform native side that alarm is completed
    await AlarmMethodChannel.alarmCompleted();
    // Additionally suppress immediate re-triggers of the same alarm on native side
    if (widget.alarmId != null && widget.alarmId! > 0) {
      await AlarmMethodChannel.alarmHandled(alarmId: widget.alarmId!, suppressSeconds: 300);
    }
    // Clear stored pending args so new alarms can set fresh ones
    AlarmMethodChannel.clearPendingAlarmArgs();
    
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('AlarmGameScreen: AppLifecycleState changed to $state');
    // Do not start alarm sound here to avoid duplication with background notification
    // When returning to foreground, ensure any service-based sound is stopped
    if (state == AppLifecycleState.resumed) {
      print('AlarmGameScreen: App resumed – stopping any background alarm sound');
      _stopAlarm();
      setState(() {
        alarmActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Block back navigation while alarm is active/unfinished
    return WillPopScope(
      onWillPop: () async {
        if (!showCompletionDialog) {
          print('AlarmGameScreen: Back press blocked');
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          _buildGame(),
          Positioned(
            top: 8,
            right: 8,
            child: _buildLogPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: AppLogger.instance.listenable,
      builder: (context, lines, _) {
        if (lines.isEmpty) return const SizedBox.shrink();
        final show = lines.take(10).toList().reversed.toList();
        return Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LOG',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
                    tooltip: 'Kopiuj',
                    onPressed: () async {
                      final text = lines.join('\n');
                      await Clipboard.setData(ClipboardData(text: text));
                      AppLogger.instance.log('Skopiowano logi (${lines.length} linii)');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...show.map((l) => Text(
                    l,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.2),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGame() {
    // Return the appropriate game based on gameType
    switch (widget.gameType) {
      case 'piano_tiles':
        return GameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
          alarmMode: true,
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
          casualMode: false,
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
        return SkyTowerGameScreen(alarmMode: true);
      case 'wall_bounce':
        return WallBounceGame();
      case 'wall_kickers':
        return WallKickersGame();
      default:
    // Reset per-alarm log buffer
    AppLogger.instance.clear();
    AppLogger.instance.log('AlarmGameScreen init');
        // Default to piano tiles game (still force alarm mode UI constraints)
        return GameScreen(
          onUserInteraction: _handleUserInteraction,
          remainingTime: remainingSeconds,
          inactivityTime: inactivityTimer,
          alarmMode: true,
        );
    }
  }
}

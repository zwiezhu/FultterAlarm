import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_alarm_manager_poc/alarm_manager_screen.dart';
import 'package:flutter_alarm_manager_poc/alarm_screen.dart';
import 'package:flutter_alarm_manager_poc/game_screen.dart';
import 'package:flutter_alarm_manager_poc/hive/service/database_service.dart';
import 'package:flutter_alarm_manager_poc/sky_tower_game_screen.dart';
import 'package:flutter_alarm_manager_poc/wall_bounce_flutter.dart';
import 'package:flutter_alarm_manager_poc/icy_tower_flutter.dart';
import 'package:flutter_alarm_manager_poc/cave_lander_flutter.dart';
import 'package:flutter_alarm_manager_poc/wall_kickers_flutter.dart';
import 'package:flutter_alarm_manager_poc/ball_runner_flutter.dart';
import 'package:flutter_alarm_manager_poc/swipe_tiles_flutter.dart';
import 'package:flutter_alarm_manager_poc/memory_match_flutter.dart';
import 'package:flutter_alarm_manager_poc/number_rush_flutter.dart';
import 'package:flutter_alarm_manager_poc/sudoku_game_flutter.dart';
import 'package:flutter_alarm_manager_poc/block_drop_game_flutter.dart';
import 'package:flutter_alarm_manager_poc/alarm_game_screen.dart';
import 'package:flutter_alarm_manager_poc/services/alarm_scheduler_service.dart';
import 'utils/alarm_method_channel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';

const MethodChannel _alarmChannel = MethodChannel('com.example.flutter_alarm_manager_poc/alarm');

void alarmCallback() async {
  try {
    await _alarmChannel.invokeMethod('alarm_triggered');
  } catch (e) {
    print("Error invoking alarm_triggered: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initializeHive();
  AlarmMethodChannel.initialize();
  await AndroidAlarmManager.initialize();
  
  // Start the alarm scheduler
  print('Starting AlarmSchedulerService...');
  AlarmSchedulerService.instance.startScheduler();
  print('AlarmSchedulerService started');
  
  runApp(const MyApp());
}

Future<void> scheduleAlarm(DateTime alarmTime, int alarmId) async {
  await AndroidAlarmManager.oneShotAt(
    alarmTime,
    alarmId,
    alarmCallback,
    exact: true,
    wakeup: true,
    rescheduleOnReboot: true,
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _permissionsRequested = false;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    if (_permissionsRequested) return;
    _permissionsRequested = true;
    // Powiadomienia
    await Permission.notification.request();
    // Dokładne alarmy (Android 12+)
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      // Optymalizacje baterii
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        themeMode: ThemeMode.light,
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFEBEBEB),
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
        ),
        initialRoute: window.defaultRouteName,
        routes: {
          '/': (context) => const AlarmManagerScreen(),
          '/alarm_screen': (context) => AlarmScreen(
            onPlay: () {},
            onSnooze: () {},
            alarmTime: DateTime.now(),
          ),
          '/game': (context) => const GameScreen(),
          '/sky_tower_game': (context) => const SkyTowerGameScreen(),
          '/wall_bounce_game': (context) => const WallBounceGame(),
          '/icy_tower_game': (context) => const IcyTowerGameScreen(),
          '/cave_lander_game': (context) => const CaveLanderGameScreen(),
          '/wall_kickers_game': (context) => const WallKickersGame(),
          '/ball_runner_game': (context) => BallRunnerGame(onScoreChange: (score) {}),
          '/swipe_tiles_game': (context) => const SwipeTilesGameScreen(),
          '/memory_match_game': (context) => const MemoryMatchGameScreen(),
          '/number_rush_game': (context) => const NumberRushGameScreen(),
          '/sudoku_game': (context) => SudokuGame(onScoreChange: (score) {}, gameCompleted: false),
          '/block_drop_game': (context) => BlockDropGame(onScoreChange: (score) {}, gameCompleted: false),
        },
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '');
          if (uri.path == '/alarm_game') {
            final gameType = uri.queryParameters['gameType'] ?? 'piano_tiles';
            final duration = int.tryParse(uri.queryParameters['duration'] ?? '1') ?? 1;
            return MaterialPageRoute(
              builder: (context) => AlarmGameScreen(
                alarmTime: DateTime.now(),
                gameType: gameType,
                durationMinutes: duration,
              ),
              settings: settings,
            );
          }
          return null;
        },
      );
  }
}

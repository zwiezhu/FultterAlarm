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
  
  // Start the alarm scheduler
  print('Starting AlarmSchedulerService...');
  AlarmSchedulerService.instance.startScheduler();
  print('AlarmSchedulerService started');
  
  runApp(const MyApp());
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
      // Spróbuj sprawdzić i poprosić o zgodę na exact alarms przez kanał natywny
      final exactAllowed = await AlarmMethodChannel.isExactAlarmAllowed();
      if (!exactAllowed) {
        await AlarmMethodChannel.requestExactAlarmPermission();
      }
      // Wyłączenie optymalizacji baterii dla niezawodności alarmów
      final ignoring = await AlarmMethodChannel.isIgnoringBatteryOptimizations();
      if (!ignoring) {
        await AlarmMethodChannel.requestIgnoreBatteryOptimizations();
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
          '/alarm_screen': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            final alarmTime = args['alarmTime'] as DateTime;
            return AlarmScreen(
              onPlay: () {
                AlarmMethodChannel.platform.invokeMethod('showGameScreen');
              },
              onSnooze: () {
                // This will be handled by the platform channel
              },
              alarmTime: alarmTime,
            );
          },
          '/alarm_game': (context) {
            // Try to get arguments from route, fallback to method channel
            Map<String, dynamic>? args;
            try {
              args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
            } catch (e) {
              // Arguments not available, try method channel
            }
            
            // If no arguments from route, try to parse from URL parameters
            if (args == null) {
              final uri = Uri.parse(window.defaultRouteName);
              if (uri.path == '/alarm_game') {
                final alarmTimeParam = uri.queryParameters['alarmTime'];
                final gameTypeParam = uri.queryParameters['gameType'];
                final durationParam = uri.queryParameters['durationMinutes'];
                
                if (alarmTimeParam != null && gameTypeParam != null) {
                  args = {
                    'alarmTime': int.tryParse(alarmTimeParam) ?? DateTime.now().millisecondsSinceEpoch,
                    'gameType': gameTypeParam,
                    'durationMinutes': int.tryParse(durationParam ?? '') ?? 1,
                  };
                }
              }
            }
            
            // Prefer pending args from native if available (override partial/empty route args)
            final pendingArgs = AlarmMethodChannel.getPendingAlarmArgs();
            if (pendingArgs != null) {
              if (args == null) {
                args = Map<String, dynamic>.from(pendingArgs);
              } else {
                for (final entry in pendingArgs.entries) {
                  args![entry.key] = entry.value;
                }
              }
            }
            
            DateTime alarmTime;
            String gameType;
            int? alarmId;
            if (args != null) {
              if (args['alarmTime'] is DateTime) {
                alarmTime = args['alarmTime'] as DateTime;
              } else if (args['alarmTime'] is int) {
                alarmTime = DateTime.fromMillisecondsSinceEpoch(args['alarmTime'] as int);
              } else {
                alarmTime = DateTime.now();
              }
              gameType = args['gameType'] as String? ?? 'piano_tiles';
              if (args['alarmId'] is int) {
                alarmId = args['alarmId'] as int;
              }
            } else {
              alarmTime = DateTime.now();
              gameType = 'piano_tiles';
            }
            
            int durationMinutes = 1;
            if (args != null && args['durationMinutes'] != null) {
              durationMinutes = args['durationMinutes'] as int;
            }
            return AlarmGameScreen(alarmTime: alarmTime, gameType: gameType, durationMinutes: durationMinutes, alarmId: alarmId);
          },
          '/game': (context) => const GameScreen(), // Piano Tiles game
          '/sky_tower_game': (context) => const SkyTowerGameScreen(), // Sky Tower game
          '/wall_bounce_game': (context) => const WallBounceGame(), // Wall Bounce game
          '/icy_tower_game': (context) => const IcyTowerGameScreen(), // Icy Tower game
          '/cave_lander_game': (context) => const CaveLanderGameScreen(), // Cave Lander game
          '/wall_kickers_game': (context) => const WallKickersGame(), // Wall Kickers game
          '/ball_runner_game': (context) => BallRunnerGame(onScoreChange: (score) {}), // Ball Runner game
          '/swipe_tiles_game': (context) => const SwipeTilesGameScreen(), // Swipe Tiles game
          '/memory_match_game': (context) => const MemoryMatchGameScreen(), // Memory Match game
          '/number_rush_game': (context) => const NumberRushGameScreen(), // Number Rush game
          '/sudoku_game': (context) => SudokuGame(onScoreChange: (score) {}, gameCompleted: false), // Sudoku Game
          '/block_drop_game': (context) => BlockDropGame(onScoreChange: (score) {}, gameCompleted: false), // Block Drop Game
        });
  }
}

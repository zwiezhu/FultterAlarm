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
import 'utils/alarm_method_channel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.initializeHive();
  AlarmMethodChannel.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
        ),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        initialRoute: window.defaultRouteName,
        routes: {
          '/': (context) => const AlarmManagerScreen(),
          '/alarm_screen': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            final alarmTime = args['alarmTime'] as DateTime;
            return AlarmScreen(
              onPlay: () {
                Navigator.pushNamed(context, '/game'); // Navigate to the actual game screen
              },
              onSnooze: () {
                // This will be handled by the platform channel
              },
              alarmTime: alarmTime,
            );
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
        },
      );
  }
}

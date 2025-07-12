import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'utils/alarm_method_channel.dart';

// Model for a single tile
class Tile {
  final int id;
  final int col;
  double y;
  bool active;

  Tile({
    required this.id,
    required this.col,
    required this.y,
    this.active = true,
  });
}

class AlarmGameScreen extends StatefulWidget {
  final DateTime alarmTime;
  final String gameType;
  
  const AlarmGameScreen({
    super.key,
    required this.alarmTime,
    required this.gameType,
  });

  @override
  State<AlarmGameScreen> createState() => _AlarmGameScreenState();
}

class _AlarmGameScreenState extends State<AlarmGameScreen> {
  // Game constants
  static const int cols = 4;
  static const double initialSpeed = 2.5;
  static const double maxSpeed = 8.0;
  static const double tileHeight = 150.0;
  static const int initialSpawnIntervalMs = 600;

  // Game state
  List<Tile> tiles = [];
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  double speed = initialSpeed;
  int tileId = 0;

  // Alarm system state
  bool alarmActive = false; // Start with alarm inactive - it will activate after 15s inactivity
  int remainingSeconds = 60; // 1 minute countdown
  int inactivityTimer = 15; // 15 seconds inactivity timer
  bool showCompletionDialog = false;

  // Timers
  Timer? _gameLoopTimer;
  Timer? _tileSpawner;
  Timer? _alarmTimer;
  Timer? _inactivityTimer;
  Timer? _countdownTimer;

  // Screen size
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    // Defer game start until we have screen dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _screenSize = MediaQuery.of(context).size;
        });
        resetGame();
        _startAlarmSystem();
      }
    });
  }

  void _startAlarm() async {
    // Start alarm sound through platform channel
    await AlarmMethodChannel.startAlarmSound();
    print('Alarm started at ${widget.alarmTime}');
  }

  void _stopAlarm() async {
    // Stop alarm sound through platform channel
    await AlarmMethodChannel.stopAlarmSound();
    print('Alarm stopped');
  }

  void _startAlarmSystem() {
    // Don't start alarm sound initially - it should be stopped when game opens
    // _startAlarm(); // <- zakomentowane - alarm nie dzwoni od razu
    
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
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (inactivityTimer > 0) {
        setState(() {
          inactivityTimer--;
        });
      } else {
        // User was inactive for 15 seconds
        _handleInactivity();
        timer.cancel();
      }
    });
  }

  void _handleInactivity() {
    // Reset the countdown and restart alarm
    setState(() {
      remainingSeconds = 60;
      inactivityTimer = 15;
      alarmActive = true;
    });
    
    _startAlarm(); // Start alarm sound again
    _startInactivityTimer();
  }

  void _completeAlarm() {
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
    // Always reset inactivity timer on any user interaction
    setState(() {
      inactivityTimer = 15; // Reset inactivity timer
    });
    _startInactivityTimer(); // Restart the timer
    
    // Stop alarm sound when user interacts (if alarm is currently playing)
    if (alarmActive) {
      _stopAlarm();
    }
  }

  // The core game loop
  void _gameLoop(Timer timer) {
    if (gameOver || isPaused || _screenSize == null) return;

    final screenHeight = _screenSize!.height;

    setState(() {
      for (var tile in tiles) {
        if (tile.active) {
          tile.y += speed;
        }
      }

      final missedTile = tiles.any((tile) => tile.active && tile.y > screenHeight);
      if (missedTile) {
        _handleGameOver();
        return;
      }
      
      tiles.removeWhere((tile) => tile.y > screenHeight + 200);
    });
  }

  void _spawnTile() {
    if (isPaused || gameOver) return;

    final random = Random();
    final availableColumns = List.generate(cols, (index) => index);
    
    final occupiedColumns = tiles
        .where((tile) => tile.y < tileHeight * 2)
        .map((tile) => tile.col)
        .toSet();

    availableColumns.removeWhere((col) => occupiedColumns.contains(col));

    if (availableColumns.isNotEmpty) {
      final col = availableColumns[random.nextInt(availableColumns.length)];
      setState(() {
        tiles.add(Tile(
          id: tileId++,
          col: col,
          y: -tileHeight,
        ));
      });
    }
  }

  void _handleTileTap(Tile tile) {
    if (!tile.active || gameOver || isPaused) return;

    // Register user interaction
    _handleUserInteraction();

    setState(() {
      tiles.removeWhere((t) => t.id == tile.id);
      score++;
      speed = min(initialSpeed + score * 0.05, maxSpeed);
      _rescheduleSpawner();
    });
  }

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      isPaused = true;
      _gameLoopTimer?.cancel();
      _tileSpawner?.cancel();
    });
  }

  void _rescheduleSpawner() {
    _tileSpawner?.cancel();
    final newIntervalMs = (initialSpawnIntervalMs * (initialSpeed / speed)).round();
    _tileSpawner = Timer.periodic(Duration(milliseconds: newIntervalMs), (_) {
      _spawnTile();
    });
  }

  void resetGame() {
    final random = Random();
    final initialTiles = <Tile>[];
    final usedColumns = <int>{};
    tileId = 0;

    for (int i = 0; i < 3; i++) {
      int col;
      do {
        col = random.nextInt(cols);
      } while (usedColumns.contains(col));
      usedColumns.add(col);
      initialTiles.add(Tile(
        id: tileId++,
        col: col,
        y: -tileHeight * (i * 1.5 + 1),
      ));
    }

    setState(() {
      tiles = initialTiles;
      score = 0;
      isPaused = false;
      gameOver = false;
      speed = initialSpeed;
    });

    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    _rescheduleSpawner();
  }

  void togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _tileSpawner?.cancel();
    _alarmTimer?.cancel();
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    _stopAlarm();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenSize == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tileWidth = _screenSize!.width / cols;

    return Scaffold(
      backgroundColor: const Color(0xFF202020),
      body: GestureDetector(
        onTap: () {
          // Register any tap on the screen as user interaction
          _handleUserInteraction();
        },
        child: Stack(
        children: [
          // Game tiles
          ...tiles.where((tile) => tile.active).map((tile) {
            return Positioned(
              left: tile.col * tileWidth,
              top: tile.y,
              width: tileWidth,
              height: tileHeight,
              child: GestureDetector(
                onTap: () => _handleTileTap(tile),
                child: Container(
                  margin: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }),
          
          // UI elements
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Score',
                          style: TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                        Text(
                          '$score',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        if (alarmActive) ...[
                          const Text(
                            'Pozostało',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          Text(
                            '${remainingSeconds}s',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Interakcja',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          Text(
                            '${inactivityTimer}s',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: inactivityTimer <= 5 ? Colors.red : Colors.yellow,
                            ),
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _handleUserInteraction();
                        togglePause();
                      },
                      icon: Icon(
                        isPaused && !gameOver ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Pause/Game Over Overlay
          if (isPaused || gameOver)
            GestureDetector(
              onTap: () {
                _handleUserInteraction();
                if (gameOver) {
                  resetGame();
                }
              },
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gameOver ? 'Game Over' : 'Paused',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (gameOver)
                        Text(
                          'Score: $score',
                          style: const TextStyle(
                            fontSize: 28,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (gameOver)
                        const Text(
                          'Tap to play again',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
} 
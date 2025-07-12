import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'utils/alarm_method_channel.dart';
import 'utils/volume_controller.dart';

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

  // Debug state
  String debugInfo = "Initializing...";
  bool showDebugInfo = true;

  // Timers
  Timer? _gameLoopTimer;
  Timer? _tileSpawner;
  Timer? _alarmTimer;
  Timer? _inactivityTimer;
  Timer? _countdownTimer;
  Timer? _debugTimer;

  // Screen size
  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    print('AlarmGameScreen: initState called');
    // Defer game start until we have screen dimensions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _screenSize = MediaQuery.of(context).size;
        });
        resetGame();
        _startAlarmSystem();
        _startDebugTimer();
      }
    });
  }

  void _startDebugTimer() {
    _debugTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          debugInfo = '''
Alarm Active: $alarmActive
Remaining Time: ${remainingSeconds}s
Inactivity Timer: ${inactivityTimer}s
Game Over: $gameOver
Is Paused: $isPaused
Score: $score
Tiles Count: ${tiles.length}
          ''';
        });
      }
    });
  }

  void _startAlarm() async {
    print('AlarmGameScreen: _startAlarm called');
    setState(() {
      debugInfo = "Starting alarm sound...";
    });
    
    // Start alarm sound through platform channel
    await AlarmMethodChannel.startAlarmSound();
    print('Alarm started at ${widget.alarmTime}');
    
    setState(() {
      debugInfo = "Alarm sound started";
    });
  }

  void _stopAlarm() async {
    print('AlarmGameScreen: _stopAlarm called');
    setState(() {
      debugInfo = "Stopping alarm sound...";
    });
    
    // Stop alarm sound through platform channel
    await AlarmMethodChannel.stopAlarmSound();
    print('Alarm stopped');
    
    setState(() {
      debugInfo = "Alarm sound stopped";
    });
  }

  void _startAlarmSystem() async {
    print('AlarmGameScreen: _startAlarmSystem called');
    setState(() {
      debugInfo = "Starting alarm system...";
    });
    
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
    
    setState(() {
      debugInfo = "Alarm system started - waiting for inactivity";
    });
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
    setState(() {
      debugInfo = "User inactive - restarting alarm...";
    });
    
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
      debugInfo = "Alarm completed!";
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
      debugInfo = "User interaction detected - resetting timer";
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

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      debugInfo = "Game Over!";
    });
    
    _stopGame();
    
    // Show game over dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showGameOverDialog();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Przegrałeś!',
            style: TextStyle(color: Colors.red, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Udało Ci się uzyskać $score punktów.\n\nSpróbuj ponownie!',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  resetGame();
                },
                child: const Text(
                  'Spróbuj ponownie',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _stopGame() {
    _gameLoopTimer?.cancel();
    _tileSpawner?.cancel();
  }

  void resetGame() {
    setState(() {
      tiles.clear();
      score = 0;
      gameOver = false;
      isPaused = false;
      speed = initialSpeed;
      tileId = 0;
      debugInfo = "Game reset";
    });

    _stopGame();

    // Start game loop
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    
    // Start tile spawning
    _tileSpawner = Timer.periodic(Duration(milliseconds: initialSpawnIntervalMs), (timer) {
      _spawnTile();
      
      // Increase speed gradually
      if (speed < maxSpeed) {
        speed += 0.1;
      }
    });
  }

  void _onTileTap(Tile tile) {
    if (gameOver || isPaused) return;

    setState(() {
      tile.active = false;
      score += 10;
      debugInfo = "Tile tapped! Score: $score";
    });

    _handleUserInteraction();
  }

  @override
  void dispose() {
    print('AlarmGameScreen: dispose called');
    _stopAlarm();
    _stopGame();
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    _debugTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Game area
          GestureDetector(
            onTapDown: (details) {
              final screenWidth = MediaQuery.of(context).size.width;
              final tileWidth = screenWidth / cols;
              final col = (details.localPosition.dx / tileWidth).floor();
              
              // Find the tile in this column that's closest to being tapped
              Tile? targetTile;
              double minDistance = double.infinity;
              
              for (var tile in tiles) {
                if (tile.active && tile.col == col) {
                  final distance = (tile.y + tileHeight / 2 - details.localPosition.dy).abs();
                  if (distance < minDistance) {
                    minDistance = distance;
                    targetTile = tile;
                  }
                }
              }
              
              if (targetTile != null && minDistance < tileHeight) {
                _onTileTap(targetTile);
              }
            },
            child: Container(
              width: double.infinity,
              height: double.infinity,
              child: CustomPaint(
                painter: GamePainter(
                  tiles: tiles,
                  cols: cols,
                  tileHeight: tileHeight,
                ),
              ),
            ),
          ),
          
          // Debug info overlay
          if (showDebugInfo)
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  debugInfo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          
          // Game UI
          Positioned(
            top: showDebugInfo ? 150 : 50,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pozostało: ${remainingSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nieaktywność: ${inactivityTimer}s',
                  style: TextStyle(
                    color: inactivityTimer <= 5 ? Colors.red : Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wynik: $score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          
          // Toggle debug info button
          Positioned(
            top: 50,
            right: 10,
            child: FloatingActionButton.small(
              onPressed: () {
                setState(() {
                  showDebugInfo = !showDebugInfo;
                });
              },
              backgroundColor: Colors.blue,
              child: Icon(
                showDebugInfo ? Icons.visibility_off : Icons.visibility,
                color: Colors.white,
              ),
            ),
          ),
          
          // Test alarm button
          Positioned(
            top: 120,
            right: 10,
            child: FloatingActionButton.small(
              onPressed: () {
                print('Test button pressed - starting alarm manually');
                _startAlarm();
              },
              backgroundColor: Colors.red,
              child: Icon(
                Icons.alarm,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final List<Tile> tiles;
  final int cols;
  final double tileHeight;

  GamePainter({
    required this.tiles,
    required this.cols,
    required this.tileHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final tileWidth = size.width / cols;

    for (var tile in tiles) {
      if (tile.active) {
        final rect = Rect.fromLTWH(
          tile.col * tileWidth + 10,
          tile.y,
          tileWidth - 20,
          tileHeight - 10,
        );
        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 
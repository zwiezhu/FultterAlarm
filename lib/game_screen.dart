
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
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

  // Timers for game loop and spawning
  Timer? _gameLoopTimer;
  Timer? _tileSpawner;

  // Screen size, initialized once
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
      }
    });
  }

  // The core game loop, driven by a Timer
  void _gameLoop(Timer timer) {
    if (gameOver || isPaused || _screenSize == null) return;

    final screenHeight = _screenSize!.height;

    // This time, we MUST call setState to make changes visible
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

    setState(() {
      // Remove the tapped tile
      tiles.removeWhere((t) => t.id == tile.id);
      score++;
      // Increase speed
      speed = min(initialSpeed + score * 0.05, maxSpeed);
      // Reschedule the spawner to match the new speed
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

  // This function creates a new spawner timer with a duration
  // that is inversely proportional to the current speed.
  void _rescheduleSpawner() {
    _tileSpawner?.cancel();
    // As speed increases, the interval decreases, making tiles spawn faster.
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

    // Cancel any existing timers before starting new ones
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
    
    // Initial spawner schedule
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
    // IMPORTANT: Cancel timers to prevent memory leaks
    _gameLoopTimer?.cancel();
    _tileSpawner?.cancel();
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
      body: Stack(
        children: [
          // Render all active tiles
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
          // Static UI elements
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
                    IconButton(
                      onPressed: togglePause,
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
              onTap: gameOver ? resetGame : null,
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
                      const SizedBox(height: 48),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        onPressed: () {
                          // Pop the game screen to go back to the list
                          Navigator.of(context).pop();
                        },
                        child: const Text('Exit to Menu', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Tile {
  final int id;
  final int col;
  double y;
  final double speed;
  bool active;
  bool clicked;

  Tile({
    required this.id,
    required this.col,
    required this.y,
    required this.speed,
    this.active = true,
    this.clicked = false,
  });
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const int cols = 4;
  static const double initSpeed = 3.0;
  static const double maxSpeed = 8.0;

  List<Tile> tiles = [];
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  double speed = initSpeed;

  int tileId = 0;
  late AnimationController _controller;
  Timer? _tileSpawner;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_gameLoop);

    resetGame();
  }

  void _gameLoop() {
    if (gameOver || isPaused) return;

    setState(() {
      for (var tile in tiles) {
        if (tile.active) {
          tile.y += tile.speed;
        }
      }

      tiles.removeWhere((tile) => tile.y >= MediaQuery.of(context).size.height);

      for (var tile in tiles) {
        if (tile.active && tile.y >= MediaQuery.of(context).size.height - 50) {
          _handleGameOver();
        }
      }
    });
  }

  void _spawnTile() {
    final random = Random();
    final availableColumns = List.generate(cols, (index) => index);
    final occupiedColumns = tiles
        .where((tile) => tile.y < 150)
        .map((tile) => tile.col)
        .toSet();

    availableColumns.removeWhere((col) => occupiedColumns.contains(col));

    if (availableColumns.isNotEmpty) {
      final col = availableColumns[random.nextInt(availableColumns.length)];
      setState(() {
        tiles.add(Tile(
          id: tileId++,
          col: col,
          y: -100,
          speed: speed,
        ));
      });
    }
  }

  void _handleTileTap(Tile tile) {
    if (!tile.active || gameOver || isPaused || tile.clicked) return;

    setState(() {
      tile.active = false;
      tile.clicked = true;
      score++;
      speed = min(initSpeed + score * 0.04, maxSpeed);
    });
  }

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      isPaused = true;
      _tileSpawner?.cancel();
    });
  }

  void resetGame() {
    setState(() {
      tiles.clear();
      score = 0;
      isPaused = false;
      gameOver = false;
      speed = initSpeed;
      tileId = 0;
    });

    _tileSpawner?.cancel();
    _tileSpawner = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _spawnTile();
    });
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
    _controller.removeListener(_gameLoop);
    _controller.dispose();
    _tileSpawner?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tileWidth = size.width / cols;
    final tileHeight = size.height / (size.height / (size.width / cols));

    return Scaffold(
      backgroundColor: const Color(0xFF333333),
      body: Stack(
        children: [
          ...tiles.where((tile) => tile.active).map((tile) {
            return Positioned(
              left: tile.col * tileWidth,
              top: tile.y,
              width: tileWidth,
              height: tileHeight,
              child: GestureDetector(
                onTap: () => _handleTileTap(tile),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1a1a1a),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            );
          }),
          if (isPaused || gameOver)
            GestureDetector(
              onTap: gameOver ? resetGame : null,
              child: Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gameOver ? 'Game Over!' : 'Paused',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (gameOver)
                        Text(
                          'Score: $score',
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (gameOver)
                        const Text(
                          'Tap to play again',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text(
                      'Score',
                      style: TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF26de81),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: togglePause,
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
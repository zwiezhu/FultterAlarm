import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a single block in the tower
class Block {
  final int id;
  final double width;
  final double x;
  final Color color;

  Block({required this.id, required this.width, required this.x, required this.color});
}

class SkyTowerGameScreen extends StatefulWidget {
  const SkyTowerGameScreen({super.key});

  @override
  State<SkyTowerGameScreen> createState() => _SkyTowerGameScreenState();
}

class _SkyTowerGameScreenState extends State<SkyTowerGameScreen> {
  // Game constants
  static const double initialBlockWidth = 120;
  static const double blockHeight = 30;
  static const double groundHeight = 40;
  final List<Color> blockColors = [
    const Color(0xFFff6b6b),
    const Color(0xFF4ecdc4),
    const Color(0xFF45b7d1),
    const Color(0xFFf7b731),
    const Color(0xFFa55eea),
    const Color(0xFF26de81),
  ];

  // Game state
  List<Block> blocks = [];
  Block? currentBlock;
  double currentBlockX = 0;
  double currentSpeed = 3.5;
  int direction = 1;
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  double cameraY = 0;

  Timer? _gameLoopTimer;

  

  @override
  void initState() {
    super.initState();
    // Game will be reset and started when build method is called for the first time
  }

  void resetGame() {
    final gameWidth = MediaQuery.of(context).size.width;
    setState(() {
      blocks = [Block(id: 0, width: initialBlockWidth, x: (gameWidth - initialBlockWidth) / 2, color: blockColors[0])];
      score = 0;
      gameOver = false;
      isPaused = false;
      cameraY = 0;
    });
    _createNewBlock();
  }

  void _createNewBlock() {
    if (gameOver) return;
    final gameWidth = MediaQuery.of(context).size.width;
    final lastBlock = blocks.last;
    final newWidth = max(40.0, lastBlock.width - (Random().nextDouble() * 10));
    final random = Random();

    setState(() {
      currentBlock = Block(
        id: blocks.length,
        width: newWidth,
        x: 0,
        color: blockColors[blocks.length % blockColors.length],
      );
      currentBlockX = random.nextBool() ? 0 : gameWidth - newWidth;
      direction = currentBlockX == 0 ? 1 : -1;
      currentSpeed = (random.nextDouble() * 1.5 + 2.0);
    });

    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }

  void _gameLoop(Timer timer) {
    if (isPaused || gameOver || currentBlock == null) return;

    final gameWidth = MediaQuery.of(context).size.width;

    setState(() {
      currentBlockX += direction * currentSpeed;
      final maxX = gameWidth - currentBlock!.width;
      if (currentBlockX >= maxX) {
        currentBlockX = maxX;
        direction = -1;
      } else if (currentBlockX <= 0) {
        currentBlockX = 0;
        direction = 1;
      }
    });
  }

  void _dropBlock() {
    if (currentBlock == null || gameOver || isPaused) return;

    final gameWidth = MediaQuery.of(context).size.width;

    final lastBlock = blocks.last;
    final overlap = max(0.0, min(lastBlock.x + lastBlock.width, currentBlockX + currentBlock!.width) - max(lastBlock.x, currentBlockX));

    if (overlap == 0) {
      setState(() => gameOver = true);
      _gameLoopTimer?.cancel();
      return;
    }

    final newX = max(lastBlock.x, currentBlockX);
    final newBlock = Block(
      id: currentBlock!.id,
      width: overlap,
      x: newX,
      color: currentBlock!.color,
    );

    setState(() {
      blocks.add(newBlock);
      score += (overlap * 10).round();
      currentBlock = null;

      // Update camera to keep tower visible
      if (blocks.length > 6) {
        cameraY = (blocks.length - 6) * blockHeight;
      }
    });

    _gameLoopTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 300), _createNewBlock);
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final gameWidth = mediaQuery.size.width;
    final gameHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: GestureDetector(
        onTap: _dropBlock,
        child: Stack(
          children: [
            // Game Area
            Container(
              width: gameWidth,
              height: gameHeight,
              color: const Color(0xFF1a1a1a),
              child: Stack(
                children: [
                  // Game area with tower
                  Positioned.fill(
                    child: Stack(
                      children: [
                        // Ground - always at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: groundHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2d2d2d),
                              border: Border(
                                top: BorderSide(color: Colors.white24, width: 2),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'GROUND',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Tower blocks - positioned above ground
                        ...blocks.map((block) {
                          return Positioned(
                            bottom: groundHeight + (block.id * blockHeight) - cameraY,
                            left: block.x,
                            child: Container(
                              width: block.width,
                              height: blockHeight,
                              decoration: BoxDecoration(
                                color: block.color,
                                border: Border.all(color: Colors.white12, width: 1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Center(
                                child: Text(
                                  '${block.id + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),

                        // Current moving block
                        if (currentBlock != null && !gameOver)
                          Positioned(
                            bottom: groundHeight + (blocks.length * blockHeight) + (2 * blockHeight) - cameraY,
                            left: currentBlockX,
                            child: Container(
                              width: currentBlock!.width,
                              height: blockHeight,
                              decoration: BoxDecoration(
                                color: currentBlock!.color,
                                border: Border.all(color: Colors.white38, width: 2),
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: currentBlock!.color.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${currentBlock!.id + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // UI Overlay
            if (gameOver || isPaused)
              Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gameOver ? 'Game Over' : 'Paused',
                        style: const TextStyle(
                          fontSize: 48,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Height: ${blocks.length - 1}',
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                      Text(
                        'Score: $score',
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: resetGame,
                            child: const Text('Restart'),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Exit'),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

            // Top HUD
            if (!gameOver)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          'Height: ${blocks.length - 1}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Score: $score',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                          ),
                          onPressed: () => setState(() => isPaused = !isPaused),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Instructions
            if (blocks.length == 1 && currentBlock != null)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Tap to drop the block!\nTry to stack them as precisely as possible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
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
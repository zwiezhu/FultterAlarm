
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
  static const double blockHeight = 20;
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

  Size? _screenSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _screenSize = MediaQuery.of(context).size;
        });
        resetGame();
      }
    });
  }

  void resetGame() {
    if (_screenSize == null) return; // Ensure _screenSize is initialized
    final gameWidth = _screenSize!.width;
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
    if (gameOver || _screenSize == null) return;
    final gameWidth = _screenSize!.width;
    final lastBlock = blocks.last;
    final newWidth = max(40.0, lastBlock.width - (Random().nextDouble() * 10));
    final random = Random();

    setState(() {
      currentBlock = Block(
        id: blocks.length,
        width: newWidth,
        x: 0, // This x is for the model, the animated x is currentBlockX
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
    if (isPaused || gameOver || currentBlock == null || _screenSize == null) return;

    final gameWidth = _screenSize!.width;

    setState(() {
      currentBlockX += direction * currentSpeed;
      final max_X = gameWidth - currentBlock!.width;
      if (currentBlockX >= max_X) {
        currentBlockX = max_X;
        direction = -1;
      } else if (currentBlockX <= 0) {
        currentBlockX = 0;
        direction = 1;
      }
    });
  }

  void _dropBlock() {
    if (currentBlock == null || gameOver || isPaused || _screenSize == null) return;

    final gameWidth = _screenSize!.width;

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
      if (blocks.length > 8) {
        cameraY = (blocks.length - 8) * blockHeight;
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
    if (_screenSize == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }


    final gameWidth = _screenSize!.width;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: GestureDetector(
        onTap: _dropBlock,
        child: Stack(
          children: [
            // Game Area
            Align(
              alignment: Alignment.center,
              child: Container(
                width: gameWidth,
                height: _screenSize!.height,
                color: const Color(0xFF1a1a1a),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Tower Blocks
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        transform: Matrix4.translationValues(0, -cameraY, 0),
                        child: Stack(
                          children: blocks.map((block) {
                            return Positioned(
                              bottom: (block.id * blockHeight),
                              left: block.x,
                              child: Container(
                                width: block.width,
                                height: blockHeight,
                                color: block.color,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    // Current Moving Block
                    if (currentBlock != null && !gameOver)
                      Positioned(
                        bottom: (blocks.length * blockHeight) - cameraY,
                        left: currentBlockX,
                        child: Container(
                          width: currentBlock!.width,
                          height: blockHeight,
                          color: currentBlock!.color,
                        ),
                      ),
                  ],
                ),
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
                      Text(gameOver ? 'Game Over' : 'Paused', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text('Height: ${blocks.length - 1}', style: const TextStyle(fontSize: 24, color: Colors.white)),
                      Text('Score: $score', style: const TextStyle(fontSize: 24, color: Colors.white)),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(onPressed: resetGame, child: const Text('Restart')),
                          const SizedBox(width: 20),
                          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Exit')),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            // Top HUD
            if (!gameOver)
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text('Height: ${blocks.length - 1}', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Score: $score', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        IconButton(icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white), onPressed: () => setState(() => isPaused = !isPaused)),
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

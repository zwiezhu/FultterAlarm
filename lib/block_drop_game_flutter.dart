import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a single block in the tetris piece
class GameBlock {
  final int x;
  final int y;
  final Color color;

  GameBlock({required this.x, required this.y, required this.color});
}

// Model for a tetris piece shape
class PieceShape {
  final List<List<int>> blocks;
  final Color color;

  PieceShape({required this.blocks, required this.color});
}

class BlockDropGame extends StatefulWidget {
  final Function(int) onScoreChange;
  final bool gameCompleted;
  final bool casualMode;

  const BlockDropGame({
    super.key,
    required this.onScoreChange,
    required this.gameCompleted,
    this.casualMode = false,
  });

  @override
  State<BlockDropGame> createState() => _BlockDropGameState();
}

class _BlockDropGameState extends State<BlockDropGame> {
  // Game constants
  static const int gridWidth = 10;
  static const int gridHeight = 16;
  static const double cellSize = 25.0;
  static const double gameWidth = gridWidth * cellSize;
  static const double gameHeight = gridHeight * cellSize;

  // Tetris piece shapes
  final List<PieceShape> pieceShapes = [
    PieceShape(blocks: [[0, 0], [1, 0], [2, 0], [3, 0]], color: const Color(0xFFff6b6b)), // I-piece
    PieceShape(blocks: [[0, 0], [1, 0], [0, 1], [1, 1]], color: const Color(0xFF4ecdc4)), // O-piece
    PieceShape(blocks: [[1, 0], [0, 1], [1, 1], [2, 1]], color: const Color(0xFF45b7d1)), // T-piece
    PieceShape(blocks: [[0, 1], [1, 1], [1, 0], [2, 0]], color: const Color(0xFFf7b731)), // S-piece
  ];

  // Game state
  List<List<GameBlock?>> grid = [];
  List<GameBlock> currentPiece = [];
  double pieceX = 4;
  double pieceY = 0;
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  int level = 1;
  int linesCleared = 0;
  bool fastDrop = false;

  Timer? _gameLoopTimer;
  final Random _random = Random();
  double _dragAccumulatedDx = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeGrid();
    _createNewPiece();
  }

  void _initializeGrid() {
    grid = List.generate(
      gridHeight,
      (index) => List.generate(gridWidth, (index) => null),
    );
  }

  void _createNewPiece() {
    if (gameOver) return;

    final shape = pieceShapes[_random.nextInt(pieceShapes.length)];
    final piece = shape.blocks.map((block) => GameBlock(
      x: block[0],
      y: block[1],
      color: shape.color,
    )).toList();

    // Check if game is over
    if (_checkCollision(piece, 4, 0)) {
      setState(() {
        gameOver = true;
      });
      _gameLoopTimer?.cancel();
      return;
    }

    setState(() {
      currentPiece = piece;
      pieceX = 4;
      pieceY = 0;
      fastDrop = false;
    });

    _startGameLoop();
  }

  bool _checkCollision(List<GameBlock> piece, double x, double y) {
    for (final block in piece) {
      final newX = (block.x + x).round();
      final newY = (block.y + y).round();

      if (newX < 0 || newX >= gridWidth || newY >= gridHeight) return true;
      if (newY >= 0 && grid[newY][newX] != null) return true;
    }
    return false;
  }

  void _placePiece() {
    if (currentPiece.isEmpty) return;

    setState(() {
      for (final block in currentPiece) {
        final x = (block.x + pieceX).round();
        final y = (block.y + pieceY).round();

        if (y >= 0 && y < gridHeight && x >= 0 && x < gridWidth) {
          grid[y][x] = GameBlock(x: x, y: y, color: block.color);
        }
      }
    });

    _gameLoopTimer?.cancel();
    
    // Check for line clears after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _checkAndClearLines();
      _createNewPiece();
    });
  }

  void _checkAndClearLines() {
    final linesToClear = <int>[];

    // Find complete lines
    for (int y = 0; y < gridHeight; y++) {
      if (grid[y].every((cell) => cell != null)) {
        linesToClear.add(y);
      }
    }

    if (linesToClear.isNotEmpty) {
      setState(() {
        // Remove complete lines from bottom to top
        for (int i = linesToClear.length - 1; i >= 0; i--) {
          final lineIndex = linesToClear[i];
          grid.removeAt(lineIndex);
          grid.insert(0, List.generate(gridWidth, (index) => null));
        }

        // Update score and stats
        final points = linesToClear.length * 100 * level;
        score += points;
        linesCleared += linesToClear.length;
        widget.onScoreChange(score);

        // Level up every 10 lines
        if (linesCleared ~/ 10 > level - 1) {
          level++;
        }
      });
    }
  }

  void _movePiece(String direction) {
    if ((widget.gameCompleted && !widget.casualMode) || isPaused || gameOver) return;

    double deltaX = 0;
    double deltaY = 0;

    switch (direction) {
      case 'left':
        deltaX = -1;
        break;
      case 'right':
        deltaX = 1;
        break;
      case 'down':
        deltaY = 1;
        break;
    }

    final newX = pieceX + deltaX;
    final newY = pieceY + deltaY;

    if (!_checkCollision(currentPiece, newX, newY)) {
      setState(() {
        pieceX = newX;
        pieceY = newY;
      });
    } else if (direction == 'down') {
      _placePiece();
    }
  }

  void _rotatePiece() {
    if ((widget.gameCompleted && !widget.casualMode) || isPaused || currentPiece.isEmpty || gameOver) return;

    final rotated = currentPiece.map((block) => GameBlock(
      x: -block.y,
      y: block.x,
      color: block.color,
    )).toList();

    if (!_checkCollision(rotated, pieceX, pieceY)) {
      setState(() {
        currentPiece = rotated;
      });
    }
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    
    if ((widget.gameCompleted && !widget.casualMode) || isPaused || gameOver) return;

    final baseSpeed = max(300, 1000 - (level - 1) * 100);
    final gameSpeed = fastDrop ? 50 : baseSpeed;

    _gameLoopTimer = Timer.periodic(Duration(milliseconds: gameSpeed), (timer) {
      _movePiece('down');
    });
  }

  void _resetGame() {
    setState(() {
      _initializeGrid();
      score = 0;
      level = 1;
      linesCleared = 0;
      gameOver = false;
      isPaused = false;
      _dragAccumulatedDx = 0;
      widget.onScoreChange(0);
    });
    
    Future.delayed(const Duration(milliseconds: 100), _createNewPiece);
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
      
      if (isPaused) {
        _gameLoopTimer?.cancel();
      } else {
        _startGameLoop();
      }
    }
  }

  void _handleTap() {
    if (!fastDrop) {
      _rotatePiece();
    }
  }

  void _handleLongPressStart() {
    if (gameOver || isPaused || (widget.gameCompleted && !widget.casualMode)) return;
    
    setState(() {
      fastDrop = true;
    });
    _startGameLoop();
  }

  void _handleLongPressEnd() {
    setState(() {
      fastDrop = false;
    });
    _startGameLoop();
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0f0f0f),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    const Text(
                      'Score',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    Text(
                      score.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00d4aa),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    Text(
                      'Lines: $linesCleared',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                  ),
                  onPressed: _togglePause,
                ),
              ],
            ),
          ),

          // Game Area
          Expanded(
            child: GestureDetector(
              onTap: _handleTap,
              onLongPressStart: (_) => _handleLongPressStart(),
              onLongPressEnd: (_) => _handleLongPressEnd(),
              onPanStart: (_) {
                _dragAccumulatedDx = 0;
              },
              onPanUpdate: (details) {
                if ((widget.gameCompleted && !widget.casualMode) || isPaused || gameOver) return;

                _dragAccumulatedDx += details.delta.dx;

                while (_dragAccumulatedDx >= cellSize) {
                  _movePiece('right');
                  _dragAccumulatedDx -= cellSize;
                }

                while (_dragAccumulatedDx <= -cellSize) {
                  _movePiece('left');
                  _dragAccumulatedDx += cellSize;
                }
              },
              onPanEnd: (_) {
                _dragAccumulatedDx = 0;
              },
              child: Container(
                width: gameWidth,
                height: gameHeight,
                color: const Color(0xFF0f0f0f),
                child: Stack(
                  children: [
                    // Grid
                    ...List.generate(gridHeight, (row) {
                      return List.generate(gridWidth, (col) {
                        final cell = grid[row][col];
                        return Positioned(
                          left: col * cellSize,
                          top: row * cellSize,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: cell?.color ?? Colors.transparent,
                              border: Border.all(
                                color: cell != null ? Colors.white : const Color(0xFF333333),
                                width: 0.5,
                              ),
                            ),
                          ),
                        );
                      });
                    }).expand((element) => element).toList(),

                    // Current falling piece
                    if (!gameOver && !isPaused && !(widget.gameCompleted && !widget.casualMode) && currentPiece.isNotEmpty)
                      ...currentPiece.map((block) {
                        return Positioned(
                          left: (block.x + pieceX) * cellSize,
                          top: (block.y + pieceY) * cellSize,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            decoration: BoxDecoration(
                              color: block.color,
                              border: Border.all(color: Colors.white, width: 0.5),
                            ),
                          ),
                        );
                      }).toList(),

                    // Overlay
                    if (isPaused || gameOver || (widget.gameCompleted && !widget.casualMode))
                      Container(
                        color: Colors.black.withOpacity(0.8),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                gameOver ? 'Game Over!' : widget.gameCompleted ? 'Game Complete!' : 'Paused',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (gameOver)
                                ElevatedButton(
                                  onPressed: _resetGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00d4aa),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Play Again'),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton('←', () => _movePiece('left')),
                const SizedBox(width: 16),
                _buildControlButton('↻', _rotatePiece),
                const SizedBox(width: 16),
                _buildControlButton('→', () => _movePiece('right')),
                const SizedBox(width: 16),
                _buildControlButton('↓', () => _movePiece('down'), isSpecial: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(String text, VoidCallback onPressed, {bool isSpecial = false}) {
    return GestureDetector(
      onTap: gameOver || isPaused || (widget.gameCompleted && !widget.casualMode) ? null : onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSpecial ? const Color(0xFF00d4aa) : const Color(0xFF333333),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
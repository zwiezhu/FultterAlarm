import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a single tile
class GameTile {
  final int id;
  final int col;
  double y;
  final TileType type;
  final Direction? direction; // for swipe tiles
  final double? holdHeight; // for hold tiles
  bool holding;
  double holdProgress;
  double? holdStartY;

  GameTile({
    required this.id,
    required this.col,
    required this.y,
    required this.type,
    this.direction,
    this.holdHeight,
    this.holding = false,
    this.holdProgress = 0.0,
    this.holdStartY,
  });

  GameTile copyWith({
    int? id,
    int? col,
    double? y,
    TileType? type,
    Direction? direction,
    double? holdHeight,
    bool? holding,
    double? holdProgress,
    double? holdStartY,
  }) {
    return GameTile(
      id: id ?? this.id,
      col: col ?? this.col,
      y: y ?? this.y,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      holdHeight: holdHeight ?? this.holdHeight,
      holding: holding ?? this.holding,
      holdProgress: holdProgress ?? this.holdProgress,
      holdStartY: holdStartY ?? this.holdStartY,
    );
  }
}

// Flash effect model
class FlashEffect {
  final int id;
  final double x;
  final double y;
  final double width;
  final double height;
  double opacity;
  final Color color;

  FlashEffect({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.opacity,
    required this.color,
  });
}

enum TileType { swipe, hold }
enum Direction { up, down, left, right }

class SwipeTilesGameScreen extends StatefulWidget {
  const SwipeTilesGameScreen({super.key});

  @override
  State<SwipeTilesGameScreen> createState() => _SwipeTilesGameScreenState();
}

class _SwipeTilesGameScreenState extends State<SwipeTilesGameScreen> {
  // Game constants
  static const int cols = 4;
  static const double tileSpeedStart = 2.4;
  static const double tileSpeedInc = 0.09;
  static const double minDistanceBetweenTiles = 200.0;
  
  // Game state
  List<GameTile> tiles = [];
  List<FlashEffect> flashEffects = [];
  int score = 0;
  double tileSpeed = tileSpeedStart;
  bool isPaused = false;
  bool gameOver = false;
  int gameKey = 0;
  
  // UI variables
  late double gameWidth;
  late double gameHeight;
  late double tileSize;
  
  // Timers
  Timer? _gameLoopTimer;
  Timer? _tileGenerationTimer;
  Timer? _flashTimer;
  
  // Counters
  int _tileId = 1;
  int _flashId = 1;
  
  // Touch handling
  Offset? _panStart;
  Set<int> _holdingTiles = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  void _initializeGame() {
    final mediaQuery = MediaQuery.of(context);
    gameWidth = mediaQuery.size.width;
    gameHeight = mediaQuery.size.height - mediaQuery.padding.top;
    tileSize = gameWidth / cols;
    
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      tiles = [];
      flashEffects = [];
      score = 0;
      tileSpeed = tileSpeedStart;
      isPaused = false;
      gameOver = false;
      gameKey++;
      _tileId = 1;
      _flashId = 1;
      _holdingTiles.clear();
    });
    
    _startGameLoop();
    _startTileGeneration();
    _startFlashAnimation();
    
    // Add first tile
    _addTile();
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (isPaused || gameOver) return;
      _updateTiles();
      _checkGameOver();
    });
  }

  void _startTileGeneration() {
    _tileGenerationTimer?.cancel();
    _tileGenerationTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (isPaused || gameOver) return;
      _addTile();
      setState(() {
        tileSpeed = min(tileSpeed + tileSpeedInc, 7.5);
      });
    });
  }

  void _startFlashAnimation() {
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (flashEffects.isEmpty) return;
      setState(() {
        flashEffects = flashEffects.map((flash) {
          flash.opacity = max(0, flash.opacity - 0.05);
          return flash;
        }).where((flash) => flash.opacity > 0).toList();
      });
    });
  }

  void _updateTiles() {
    setState(() {
      tiles = tiles.map((tile) {
        if (tile.type == TileType.hold) {
          final newY = tile.y + tileSpeed;
          
          if (tile.holding) {
            final holdStartY = tile.holdStartY ?? tile.y;
            final totalDistance = tile.holdHeight ?? tileSize * 0.85;
            final traveledDistance = newY - holdStartY;
            final progress = max(0.0, min(1.0, traveledDistance / totalDistance));
            
            if (progress >= 0.9) {
              _addFlashEffect(tile, const Color(0xFFa55eea));
              _updateScore(1);
              return null; // Remove tile
            }
            
            return tile.copyWith(y: newY, holdProgress: progress);
          } else {
            if (newY + (tile.holdHeight ?? tileSize * 0.85) >= gameHeight - 2) {
              if (tile.holdProgress < 0.9) {
                _handleGameOver();
              }
              return null; // Remove tile
            }
            return tile.copyWith(y: newY);
          }
        } else {
          // Swipe tile
          return tile.copyWith(y: tile.y + tileSpeed);
        }
      }).where((tile) => tile != null).cast<GameTile>().toList();
      
      // Remove tiles that are off screen
      tiles = tiles.where((tile) => tile.y < gameHeight + tileSize).toList();
    });
  }

  void _checkGameOver() {
    for (final tile in tiles) {
      if (tile.type == TileType.swipe && tile.y + tileSize > gameHeight - 3) {
        _handleGameOver();
        break;
      }
    }
  }

  void _addTile() {
    final hasActiveHold = tiles.any((t) => t.type == TileType.hold && t.y > -tileSize * 2);
    
    final availableColumns = <int>[];
    for (int col = 0; col < cols; col++) {
      if (_canAddTileInColumn(col, tileSize)) {
        availableColumns.add(col);
      }
    }
    
    if (availableColumns.isEmpty) return;
    
    setState(() {
      if (!hasActiveHold && Random().nextDouble() < 0.2 && tiles.length > 1) {
        // Add hold tile
        final holdHeight = tileSize * (0.7 + Random().nextDouble() * 0.3);
        final availableForHold = availableColumns.where((col) => 
          _canAddTileInColumn(col, holdHeight)).toList();
        
        if (availableForHold.isNotEmpty) {
          final col = availableForHold[Random().nextInt(availableForHold.length)];
          tiles.add(GameTile(
            id: _tileId++,
            col: col,
            y: -holdHeight,
            type: TileType.hold,
            holdHeight: holdHeight,
          ));
          return;
        }
      }
      
      // Add swipe tile
      final col = availableColumns[Random().nextInt(availableColumns.length)];
      tiles.add(GameTile(
        id: _tileId++,
        col: col,
        y: -tileSize,
        type: TileType.swipe,
        direction: _randomDirection(col),
      ));
    });
  }

  bool _canAddTileInColumn(int col, double newTileHeight) {
    final tilesInColumn = tiles.where((tile) => tile.col == col).toList();
    
    if (tilesInColumn.isEmpty) return true;
    
    for (final tile in tilesInColumn) {
      final tileHeight = tile.type == TileType.hold ? (tile.holdHeight ?? tileSize) : tileSize;
      final tileBottom = tile.y + tileHeight;
      
      if (tile.y < tileSize * 3) {
        final newTileTop = -newTileHeight;
        final newTileBottom = newTileTop + newTileHeight;
        
        final distanceFromTop = (tileBottom - newTileTop).abs();
        final distanceFromBottom = (tile.y - newTileBottom).abs();
        final minDistance = min(distanceFromTop, distanceFromBottom);
        
        if (minDistance < minDistanceBetweenTiles) {
          return false;
        }
      }
    }
    
    return true;
  }

  Direction _randomDirection(int col) {
    List<Direction> directions = [Direction.up, Direction.down, Direction.left, Direction.right];
    if (col == 0) {
      directions.remove(Direction.right);
    }
    if (col == cols - 1) {
      directions.remove(Direction.left);
    }
    return directions[Random().nextInt(directions.length)];
  }

  void _addFlashEffect(GameTile tile, Color color) {
    final flash = FlashEffect(
      id: _flashId++,
      x: tile.col * tileSize,
      y: tile.y,
      width: tileSize,
      height: tile.type == TileType.hold ? (tile.holdHeight ?? tileSize) : tileSize,
      opacity: 1.0,
      color: color,
    );
    
    setState(() {
      flashEffects.add(flash);
    });
  }

  void _updateScore(int points) {
    setState(() {
      score += points;
    });
  }

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      isPaused = true;
    });
    
    _gameLoopTimer?.cancel();
    _tileGenerationTimer?.cancel();
    
    Future.delayed(const Duration(milliseconds: 300), () {
      _showGameOverDialog();
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('Your score: $score'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    _panStart = details.localPosition;
    final col = (details.localPosition.dx / tileSize).floor();
    final y = details.localPosition.dy;
    
    // Check for hold tiles
    for (final tile in tiles) {
      if (tile.type == TileType.hold &&
          tile.col == col &&
          !tile.holding &&
          tile.y <= y &&
          tile.y + (tile.holdHeight ?? tileSize * 0.85) >= y) {
        
        setState(() {
          _holdingTiles.add(tile.id);
          final index = tiles.indexOf(tile);
          tiles[index] = tile.copyWith(
            holding: true,
            holdStartY: tile.y,
            holdProgress: 0.0,
          );
        });
        break;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_panStart == null) return;
    
    final dx = details.localPosition.dx - _panStart!.dx;
    final dy = details.localPosition.dy - _panStart!.dy;
    
    Direction? direction;
    if (dx.abs() > dy.abs()) {
      if (dx > 20) direction = Direction.right;
      else if (dx < -20) direction = Direction.left;
    } else {
      if (dy > 20) direction = Direction.down;
      else if (dy < -20) direction = Direction.up;
    }
    
    if (direction == null) return;
    
    final endCol = (details.localPosition.dx / tileSize).floor();
    final touchY = details.localPosition.dy;
    
    // Find target tile
    final candidates = tiles.where((tile) =>
      tile.type == TileType.swipe &&
      tile.col == endCol &&
      !tile.holding).toList();
    
    if (candidates.isEmpty) return;
    
    GameTile? target;
    double minDistance = double.infinity;
    
    for (final tile in candidates) {
      final center = tile.y + tileSize / 2;
      final distance = (center - touchY).abs();
      if (distance < minDistance) {
        minDistance = distance;
        target = tile;
      }
    }
    
    if (target == null) return;
    
    // Check if direction is correct
    if (target.direction != direction) {
      _handleGameOver();
      return;
    }
    
    // Correct swipe
    _addFlashEffect(target, const Color(0xFF00ff88));
    _updateScore(1);
    
    setState(() {
      tiles.removeWhere((tile) => tile.id == target!.id);
    });
    
    _panStart = null;
  }

  void _onPanEnd(DragEndDetails details) {
    // Release all hold tiles
    setState(() {
      for (int i = 0; i < tiles.length; i++) {
        if (tiles[i].type == TileType.hold && tiles[i].holding) {
          tiles[i] = tiles[i].copyWith(holding: false);
        }
      }
      _holdingTiles.clear();
    });
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _tileGenerationTimer?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (gameWidth == 0) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // Game area
            Container(
              width: gameWidth,
              height: gameHeight,
              color: const Color(0xFF0f0f0f),
              child: Stack(
                children: [
                  // Render tiles
                  ...tiles.map((tile) => _buildTile(tile)).toList(),
                  
                  // Render flash effects
                  ...flashEffects.map((flash) => _buildFlashEffect(flash)).toList(),
                ],
              ),
            ),
            
            // Score display
            if (!isPaused && !gameOver)
              Positioned(
                top: 50,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // Game over/pause overlay
            if (isPaused || gameOver)
              Container(
                color: Colors.black.withOpacity(0.85),
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
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _togglePause,
                            icon: Icon(
                              isPaused ? Icons.play_arrow : Icons.pause,
                              color: Colors.white,
                              size: 30,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              padding: const EdgeInsets.all(15),
                            ),
                          ),
                          const SizedBox(width: 20),
                          if (gameOver)
                            IconButton(
                              onPressed: _resetGame,
                              icon: const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 30,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.all(15),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(GameTile tile) {
    if (tile.type == TileType.swipe) {
      return Positioned(
        left: tile.col * tileSize,
        top: tile.y,
        child: Container(
          width: tileSize,
          height: tileSize,
          decoration: BoxDecoration(
            color: const Color(0xFFb9d9fa),
            border: Border.all(color: const Color(0xFF2972ff), width: 2),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: _buildArrow(tile.direction!),
          ),
        ),
      );
    } else {
      // Hold tile
      final progress = tile.holdProgress;
      final progressColor = progress >= 0.9 
        ? const Color(0xFF26de81) 
        : progress >= 0.5 
          ? const Color(0xFFf7b731) 
          : const Color(0xFFfc5c65);
      
      return Positioned(
        left: tile.col * tileSize,
        top: tile.y,
        child: Container(
          width: tileSize,
          height: tile.holdHeight,
          decoration: BoxDecoration(
            color: tile.holding ? const Color(0xFFa55eea) : const Color(0xFFf7b731),
            border: Border.all(color: const Color(0xFFa55eea), width: 2),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tile.holding ? 'HOLD!' : 'HOLD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tile.holding) ...[
                const SizedBox(height: 4),
                Container(
                  width: tileSize - 16,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  Widget _buildArrow(Direction direction) {
    IconData icon;
    switch (direction) {
      case Direction.up:
        icon = Icons.keyboard_arrow_up;
        break;
      case Direction.down:
        icon = Icons.keyboard_arrow_down;
        break;
      case Direction.left:
        icon = Icons.keyboard_arrow_left;
        break;
      case Direction.right:
        icon = Icons.keyboard_arrow_right;
        break;
    }
    
    return Icon(
      icon,
      color: const Color(0xFF2972ff),
      size: tileSize * 0.6,
    );
  }

  Widget _buildFlashEffect(FlashEffect flash) {
    return Positioned(
      left: flash.x,
      top: flash.y,
      child: Container(
        width: flash.width,
        height: flash.height,
        decoration: BoxDecoration(
          color: flash.color.withOpacity(flash.opacity),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(flash.opacity * 0.8),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: flash.color.withOpacity(flash.opacity),
              blurRadius: 20,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );
  }
}
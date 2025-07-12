import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a wall segment
class Wall {
  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final int side;
  final bool hasCoin;
  bool coinCollected;
  final double coinX;
  final double coinY;

  Wall({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.side,
    required this.hasCoin,
    this.coinCollected = false,
    required this.coinX,
    required this.coinY,
  });
}

// Model for the player
class Player {
  double x;
  double y;
  double vx;
  double vy;
  bool jumping;
  bool canAirJump;
  bool touchingLeftSide;
  String? lastWallId;

  Player({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.jumping = false,
    this.canAirJump = false,
    this.touchingLeftSide = true,
    this.lastWallId,
  });
}

// Game settings
class GameSettings {
  double swipeVxFactor;
  double swipeVyFactor;
  double gravity;
  double jumpVx;
  double jumpVy;
  double airJumpVx;
  double airJumpVy;

  GameSettings({
    this.swipeVxFactor = 1.0,
    this.swipeVyFactor = 0.9,
    this.gravity = 0.7,
    this.jumpVx = 6.5,
    this.jumpVy = -12.0,
    this.airJumpVx = 5.5,
    this.airJumpVy = -10.0,
  });

  static GameSettings get defaults => GameSettings();
}

class WallKickersGame extends StatefulWidget {
  const WallKickersGame({super.key});

  @override
  State<WallKickersGame> createState() => _WallKickersGameState();
}

class _WallKickersGameState extends State<WallKickersGame> with TickerProviderStateMixin {
  // Game constants
  static const double playerSize = 24;
  static const double wallWidth = 40;
  static const double minWallLength = 60;
  static const double maxWallLength = 200;
  static const double coinSize = 16;
  static const double coinChance = 0.4;
  static const double minSwipeDistance = 30;

  // Game state
  List<Wall> walls = [];
  late Player player;
  double cameraOffsetY = 0;
  int score = 0;
  int coins = 0;
  bool isPaused = false;
  bool gameOver = false;
  bool showSettings = false;
  late GameSettings settings;

  // Animation and input
  late AnimationController _animationController;
  Timer? _gameLoopTimer;
  
  // Touch handling
  Offset? _panStart;
  String inputType = '';
  double swipeDistance = 0;
  int gestureDuration = 0;

  @override
  void initState() {
    super.initState();
    settings = GameSettings.defaults;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  bool _isGameDataInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isGameDataInitialized) {
      _initializeGameData();
      _isGameDataInitialized = true;
      resetGame(); // Call resetGame after initial data is set
    }
  }

  void _initializeGameData() {
    walls = _generateWallSegments(MediaQuery.of(context).size.height - 120, 20);
    player = _getInitialPlayerPosition();
  }

  void resetGame() {
    setState(() {
      cameraOffsetY = 0;
      score = 0;
      coins = 0;
      isPaused = false;
      gameOver = false;
      showSettings = false;
    });
    _initializeGameData(); // Re-initialize game data on reset
    _startGameLoop();
  }

  List<Wall> _generateWallSegments(double startY, int count) {
    final segments = <Wall>[];
    double y = startY;
    bool leftSide = true;

    const double thinWallWidth = 25;
    final double centerX = MediaQuery.of(context).size.width / 2 - thinWallWidth / 2;
    final double horizOffset = MediaQuery.of(context).size.width * 0.3;

    for (int i = 0; i < count; i++) {
      final wallLength = minWallLength + Random().nextDouble() * (maxWallLength - minWallLength);
      
      // Calculate gap based on current settings
      final maxJumpHeight = (settings.jumpVy.abs() * settings.jumpVy.abs()) / (2 * settings.gravity);
      final minGap = maxJumpHeight * 0.4;
      final maxGap = maxJumpHeight * 0.8;
      final gap = minGap + Random().nextDouble() * (maxGap - minGap);

      final minX = leftSide ? centerX - horizOffset : centerX;
      final maxX = leftSide ? centerX : centerX + horizOffset;
      final wallX = minX + Random().nextDouble() * (maxX - minX);

      segments.add(Wall(
        id: 'wall_${startY.toInt()}_$i',
        x: wallX,
        y: y,
        width: wallWidth,
        height: wallLength,
        side: leftSide ? -1 : 1,
        hasCoin: Random().nextDouble() < coinChance,
        coinX: MediaQuery.of(context).size.width / 2 - coinSize / 2,
        coinY: y + wallLength / 2 - coinSize / 2,
      ));

      y -= (wallLength + gap);
      leftSide = !leftSide;
    }

    return segments;
  }

  Player _getInitialPlayerPosition() {
    if (walls.isEmpty) {
      return Player(x: 100, y: 100);
    }
    
    final wall = walls.first;
    const offset = 2.0;
    
    return Player(
      x: wall.x + wall.width + offset,
      y: wall.y + wall.height / 2 - playerSize / 2,
      touchingLeftSide: true,
    );
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isPaused && !gameOver) {
        _updateGame();
      }
    });
  }

  void _updateGame() {
    if (!player.jumping) return;

    setState(() {
      // Update player position
      player.x += player.vx;
      player.y += player.vy;
      player.vy += settings.gravity;

      // Check wall collision
      final collision = _checkWallCollision();
      if (collision != null) {
        if (collision['wallId'] != player.lastWallId) {
          score++;
        }

        player.x = collision['newX'];
        player.vx = 0;
        player.vy = 0;
        player.jumping = false;
        player.canAirJump = true;
        player.touchingLeftSide = collision['touchingLeftSide'];
        player.lastWallId = collision['wallId'];
      }

      // Check game over condition
      if (player.y > MediaQuery.of(context).size.height + 100) {
        gameOver = true;
        isPaused = true;
      }

      // Update camera
      final playerScreenY = player.y + cameraOffsetY;
      final targetScreenY = MediaQuery.of(context).size.height * 0.7;
      if (playerScreenY < targetScreenY) {
        cameraOffsetY = targetScreenY - player.y;
      }

      // Generate new walls if needed
      _generateNewWalls();

      // Check coin collection
      _checkCoinCollection();
    });
  }

  Map<String, dynamic>? _checkWallCollision() {
    final playerRight = player.x + playerSize;
    final playerBottom = player.y + playerSize;

    for (final wall in walls) {
      final wallRight = wall.x + wall.width;
      final wallBottom = wall.y + wall.height;

      if (player.x < wallRight &&
          playerRight > wall.x &&
          player.y < wallBottom &&
          playerBottom > wall.y) {
        
        if (player.vx < 0 && player.x < wallRight && playerRight > wallRight) {
          return {
            'newX': wallRight,
            'touchingLeftSide': true,
            'wallId': wall.id,
          };
        }
        
        if (player.vx > 0 && playerRight > wall.x && player.x < wall.x) {
          return {
            'newX': wall.x - playerSize,
            'touchingLeftSide': false,
            'wallId': wall.id,
          };
        }
      }
    }

    return null;
  }

  void _generateNewWalls() {
    final highestWallY = walls.map((wall) => wall.y).reduce(min);
    final bottomScreen = -cameraOffsetY + MediaQuery.of(context).size.height;
    
    // Remove walls that are too far below
    walls.removeWhere((wall) => wall.y > bottomScreen + 200);
    
    // Add new walls if needed
    if (highestWallY > -cameraOffsetY - 400) {
      final newWalls = _generateWallSegments(highestWallY - 300, 10);
      walls.addAll(newWalls);
    }
  }

  void _checkCoinCollection() {
    for (final wall in walls) {
      if (wall.hasCoin && !wall.coinCollected) {
        final coinCenterX = wall.coinX + coinSize / 2;
        final coinCenterY = wall.coinY + coinSize / 2;
        final playerCenterX = player.x + playerSize / 2;
        final playerCenterY = player.y + playerSize / 2;
        
        final distance = sqrt(
          pow(coinCenterX - playerCenterX, 2) + 
          pow(coinCenterY - playerCenterY, 2)
        );
        
        if (distance < (coinSize + playerSize) / 2) {
          wall.coinCollected = true;
          coins++;
        }
      }
    }
  }

  void _handleTap() {
    if (gameOver || isPaused) return;

    if (!player.jumping) {
      // Wall jump
      final dir = player.touchingLeftSide ? 1 : -1;
      setState(() {
        player.vx = dir * settings.jumpVx;
        player.vy = settings.jumpVy;
        player.jumping = true;
        player.canAirJump = true;
      });
    } else if (player.canAirJump) {
      // Air jump
      final dir = player.vx > 0 ? -1 : 1;
      setState(() {
        player.vx = dir * settings.airJumpVx;
        player.vy = settings.airJumpVy;
        player.canAirJump = false;
      });
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (gameOver || isPaused) return;
    _panStart = details.localPosition;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (gameOver || isPaused || _panStart == null) return;

    final dx = details.localPosition.dx - _panStart!.dx;
    final dy = details.localPosition.dy - _panStart!.dy;
    final distance = sqrt(dx * dx + dy * dy);

    setState(() {
      swipeDistance = distance;
      inputType = distance < minSwipeDistance ? 'TAP' : 'SWIPE';
    });

    if (distance < minSwipeDistance) {
      _handleTap();
      return;
    }

    // Handle swipe
    if (distance > 0) {
      final nx = dx / distance;
      final ny = dy / distance;
      
      const swipeMultiplier = 15.0;
      final vx = nx * swipeMultiplier * settings.swipeVxFactor;
      final vy = ny * swipeMultiplier * settings.swipeVyFactor;

      if (!player.jumping) {
        setState(() {
          player.vx = vx;
          player.vy = vy;
          player.jumping = true;
          player.canAirJump = true;
        });
      } else if (player.canAirJump) {
        setState(() {
          player.vx = vx;
          player.vy = vy;
          player.canAirJump = false;
        });
      }
    }

    _panStart = null;
  }

  Widget _buildSettingsPanel() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.6), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => showSettings = false),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildSettingRows(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => settings = GameSettings.defaults),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                  ),
                  child: const Text('Reset'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: resetGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.8),
                  ),
                  child: const Text('Apply & Restart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSettingRows() {
    final settingsMap = {
      'SWIPE_VX_FACTOR': settings.swipeVxFactor,
      'SWIPE_VY_FACTOR': settings.swipeVyFactor,
      'GRAVITY': settings.gravity,
      'JUMP_VX': settings.jumpVx,
      'JUMP_VY': settings.jumpVy,
      'AIR_JUMP_VX': settings.airJumpVx,
      'AIR_JUMP_VY': settings.airJumpVy,
    };

    return settingsMap.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: entry.value.toString(),
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Colors.white30),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final numValue = double.tryParse(value);
                  if (numValue != null) {
                    setState(() {
                      switch (entry.key) {
                        case 'SWIPE_VX_FACTOR':
                          settings.swipeVxFactor = numValue;
                          break;
                        case 'SWIPE_VY_FACTOR':
                          settings.swipeVyFactor = numValue;
                          break;
                        case 'GRAVITY':
                          settings.gravity = numValue;
                          break;
                        case 'JUMP_VX':
                          settings.jumpVx = numValue;
                          break;
                        case 'JUMP_VY':
                          settings.jumpVy = numValue;
                          break;
                        case 'AIR_JUMP_VX':
                          settings.airJumpVx = numValue;
                          break;
                        case 'AIR_JUMP_VY':
                          settings.airJumpVy = numValue;
                          break;
                      }
                    });
                  }
                },
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onPanStart: _handlePanStart,
        onPanEnd: _handlePanEnd,
        onTap: _handleTap,
        child: Stack(
          children: [
            // Game Area
            Container(
              width: screenSize.width,
              height: screenSize.height,
              color: const Color(0xFF87CEEB), // Sky blue
              child: Stack(
                children: [
                  // Walls
                  ...walls.map((wall) => Positioned(
                    left: wall.x,
                    top: wall.y + cameraOffsetY,
                    child: Container(
                      width: wall.width,
                      height: wall.height,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B4513), // Brown
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF654321), width: 2),
                      ),
                    ),
                  )),
                  
                  // Coins
                  ...walls.where((wall) => wall.hasCoin && !wall.coinCollected).map((wall) => Positioned(
                    left: wall.coinX,
                    top: wall.coinY + cameraOffsetY,
                    child: Container(
                      width: coinSize,
                      height: coinSize,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '◉',
                          style: TextStyle(
                            color: Color(0xFFB8860B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )),
                  
                  // Player
                  Positioned(
                    left: player.x,
                    top: player.y + cameraOffsetY,
                    child: Container(
                      width: playerSize,
                      height: playerSize,
                      decoration: BoxDecoration(
                        color: player.canAirJump ? const Color(0xFFff6b6b) : const Color(0xFFe74c3c),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  
                  // Air jump indicator
                  if (player.jumping && player.canAirJump)
                    Positioned(
                      left: player.x + playerSize / 2 - 3,
                      top: player.y + cameraOffsetY - 10,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Header
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Score', style: TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$score', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        const Text('Coins', style: TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setState(() => showSettings = !showSettings),
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.settings, color: Colors.white),
                          ),
                        ),
                        IconButton(
                          onPressed: gameOver ? null : () => setState(() => isPaused = !isPaused),
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPaused ? Icons.play_arrow : Icons.pause,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Settings Panel
            if (showSettings)
              Positioned(
                top: 90,
                right: 16,
                child: _buildSettingsPanel(),
              ),
            
            // Debug Info
            if (inputType.isNotEmpty)
              Positioned(
                top: 100,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$inputType | Dist: ${swipeDistance.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            
            // Game Over / Pause Overlay
            if (gameOver || isPaused)
              Container(
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
                        ElevatedButton(
                          onPressed: resetGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3498db),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text(
                            'Play Again',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            
            // Instructions
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap to jump between walls! Tap again in air to change direction!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.4,
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
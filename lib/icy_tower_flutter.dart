import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a platform in the game
class Platform {
  final int id;
  final double x;
  final double y;
  final double width;
  final bool moving;
  final int direction;
  final Color color;

  Platform({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.moving,
    required this.direction,
    required this.color,
  });

  Platform copyWith({
    int? id,
    double? x,
    double? y,
    double? width,
    bool? moving,
    int? direction,
    Color? color,
  }) {
    return Platform(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      moving: moving ?? this.moving,
      direction: direction ?? this.direction,
      color: color ?? this.color,
    );
  }
}

// Model for a particle effect
class Particle {
  final int id;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double life;

  Particle({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.life,
  });

  Particle copyWith({
    int? id,
    double? x,
    double? y,
    double? vx,
    double? vy,
    Color? color,
    double? life,
  }) {
    return Particle(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      color: color ?? this.color,
      life: life ?? this.life,
    );
  }
}

// Ball state
class Ball {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double lastY;

  Ball({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.lastY,
  });

  Ball copyWith({
    double? x,
    double? y,
    double? vx,
    double? vy,
    double? lastY,
  }) {
    return Ball(
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      lastY: lastY ?? this.lastY,
    );
  }
}

class IcyTowerGameScreen extends StatefulWidget {
  const IcyTowerGameScreen({super.key});

  @override
  State<IcyTowerGameScreen> createState() => _IcyTowerGameScreenState();
}

class _IcyTowerGameScreenState extends State<IcyTowerGameScreen> {
  // Game constants
  static const double ballSize = 20;
  static const double platformWidth = 90;
  static const double platformHeight = 12;
  static const double gravity = 0.5;
  static const double jumpForce = -12;
  static const double horizontalSpeed = 5;
  static const double platformSpacing = 80;
  static const double wallBounceDamping = 0.8;
  static const int maxParticles = 20;
  static const double particleDecay = 0.08;

  final List<Color> platformColors = [
    const Color(0xFFff6b6b),
    const Color(0xFF4ecdc4),
    const Color(0xFF45b7d1),
    const Color(0xFFf7b731),
    const Color(0xFFa55eea),
    const Color(0xFF26de81),
  ];

  // Game state
  List<Platform> platforms = [];
  List<Particle> particles = [];
  Ball ball = Ball(x: 0, y: 0, vx: 0, vy: 0, lastY: 0);
  double cameraY = 0;
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  int lastPlatformId = 0;
  int frameCount = 0;
  int _pendingHorizontalInput = 0; // -1 for left, 1 for right, 0 for none

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
        _initializeGame();
      }
    });
  }

  void _initializeGame() {
    if (_screenSize == null) return;

    final gameWidth = _screenSize!.width;
    final gameHeight = _screenSize!.height;

    // Generate initial platforms
    final initialPlatforms = _generateInitialPlatforms(gameWidth, gameHeight);
    final startX = initialPlatforms[0].x + (initialPlatforms[0].width - ballSize) / 2;
    final startY = initialPlatforms[0].y - ballSize;

    setState(() {
      platforms = initialPlatforms;
      ball = Ball(x: startX, y: startY, vx: 0, vy: 0, lastY: startY);
      particles = [];
      cameraY = 0;
      score = 0;
      gameOver = false;
      isPaused = false;
      lastPlatformId = initialPlatforms.length - 1;
      frameCount = 0;
      _pendingHorizontalInput = 0;
    });

    _startGameLoop();
  }

  List<Platform> _generateInitialPlatforms(double gameWidth, double gameHeight) {
    final List<Platform> platformList = [];
    final random = Random();

    // Ground platform
    platformList.add(Platform(
      id: 0,
      x: 0,
      y: gameHeight - 100,
      width: gameWidth,
      moving: false,
      direction: 0,
      color: const Color(0xFF333333),
    ));

    // Generate initial platforms
    for (int i = 1; i < 10; i++) {
      platformList.add(Platform(
        id: i,
        x: random.nextDouble() * (gameWidth - platformWidth),
        y: gameHeight - 100 - i * platformSpacing,
        width: platformWidth,
        moving: random.nextDouble() < 0.3,
        direction: random.nextBool() ? 1 : -1,
        color: platformColors[i % platformColors.length],
      ));
    }

    return platformList;
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }

  void _gameLoop(Timer timer) {
    if (isPaused || gameOver || _screenSize == null) return;

    frameCount++;
    final gameWidth = _screenSize!.width;
    final gameHeight = _screenSize!.height;

    // Update platforms
    if (frameCount % 2 == 0) {
      _updatePlatforms(gameWidth);
      _addPlatformsIfNeeded(gameWidth);
    }

    // Update ball physics
    _updateBall(gameWidth, gameHeight);

    // Update particles
    if (frameCount % 3 == 0) {
      _updateParticles();
    }

    // Update camera
    if (frameCount % 2 == 0) {
      _updateCamera(gameHeight);
    }

    // Check game over
    _checkGameOver(gameHeight);

    // Update score
    _updateScore();

    setState(() {});
  }

  void _updatePlatforms(double gameWidth) {
    platforms = platforms.map((platform) {
      if (!platform.moving) return platform;

      double newX = platform.x + platform.direction * 1.2;
      int newDirection = platform.direction;

      if (newX <= 0) {
        newX = 0;
        newDirection = 1;
      } else if (newX >= gameWidth - platform.width) {
        newX = gameWidth - platform.width;
        newDirection = -1;
      }

      return platform.copyWith(x: newX, direction: newDirection);
    }).toList();
  }

  void _addPlatformsIfNeeded(double gameWidth) {
    final minY = platforms.map((p) => p.y).reduce(min);

    if (ball.y < minY + _screenSize!.height * 1.2) {
      final random = Random();
      final List<Platform> newPlatforms = [];

      for (int i = 0; i < 3; i++) {
        final newId = lastPlatformId + i + 1;
        newPlatforms.add(Platform(
          id: newId,
          x: random.nextDouble() * (gameWidth - platformWidth),
          y: minY - platformSpacing * (i + 1),
          width: platformWidth,
          moving: random.nextDouble() < 0.3,
          direction: random.nextBool() ? 1 : -1,
          color: platformColors[newId % platformColors.length],
        ));
      }

      lastPlatformId += 3;

      // Remove platforms that are too far down
      platforms = platforms
          .where((p) => p.y > ball.y - _screenSize!.height * 1.5)
          .toList();
      platforms.addAll(newPlatforms);
    }
  }

  void _updateBall(double gameWidth, double gameHeight) {
    // Ball physics
    double newVY = ball.vy + gravity;
    double newVX = ball.vx * 0.995; // Slight friction
    double newX = ball.x + newVX;
    double newY = ball.y + newVY;
    final lastY = ball.y;

    // Wall collision
    if (newX <= 0) {
      newX = 0;
      newVX = newVX.abs() * wallBounceDamping;
    } else if (newX >= gameWidth - ballSize) {
      newX = gameWidth - ballSize;
      newVX = -newVX.abs() * wallBounceDamping;
    }

    // Platform collision
    final collision = _checkPlatformCollision(newX, newY, newVY, lastY);
    if (collision != null) {
      newY = collision.y - ballSize;
      newVY = jumpForce;

      // Apply pending input on jump
      if (_pendingHorizontalInput != 0) {
        newVX = _pendingHorizontalInput * horizontalSpeed;
        _pendingHorizontalInput = 0; // Reset after use
      } else {
        newVX = 0; // Jump straight up if no input
      }

      if (collision.moving) {
        newVX += collision.direction * 0.3;
      }
      // Create particles
      if (frameCount % 3 == 0) {
        _createParticles(newX, newY, collision.color, 1);
      }
    }

    ball = Ball(x: newX, y: newY, vx: newVX, vy: newVY, lastY: lastY);
  }

  Platform? _checkPlatformCollision(double ballX, double ballY, double ballVY, double lastY) {
    if (ballVY <= 0) return null;

    final ballRight = ballX + ballSize;
    final ballLeft = ballX;
    final ballBottom = ballY + ballSize;

    for (final platform in platforms) {
      final platRight = platform.x + platform.width;
      final platLeft = platform.x;
      final platTop = platform.y;
      final platBottom = platform.y + platformHeight;

      // Quick bounds check
      if (ballRight < platLeft || ballLeft > platRight) continue;
      if (ballBottom < platTop || ballY > platBottom) continue;

      // Check if ball crossed platform in this frame
      final wasAbove = lastY + ballSize <= platTop;
      final isBelow = ballBottom >= platTop;

      if (wasAbove && isBelow) {
        return platform;
      }
    }
    return null;
  }

  void _createParticles(double x, double y, Color color, int count) {
    if (particles.length >= maxParticles) return;

    final random = Random();
    final limit = min(count, maxParticles - particles.length);

    for (int i = 0; i < limit; i++) {
      particles.add(Particle(
        id: random.nextInt(999999),
        x: x + random.nextDouble() * 15 - 7,
        y: y + random.nextDouble() * 15 - 7,
        vx: random.nextDouble() * 3 - 1.5,
        vy: random.nextDouble() * -2 - 1,
        color: color,
        life: 1,
      ));
    }
  }

  void _updateParticles() {
    particles = particles
        .map((p) => p.copyWith(
              x: p.x + p.vx,
              y: p.y + p.vy,
              vy: p.vy + 0.2,
              life: p.life - particleDecay,
            ))
        .where((p) => p.life > 0)
        .toList();
  }

  void _updateCamera(double gameHeight) {
    final double targetCameraY =
        max(gameHeight * 0.4 - ball.y, 0).toDouble();
    if ((targetCameraY - cameraY).abs() > 1) {
      cameraY = targetCameraY;
    }
  }

  void _checkGameOver(double gameHeight) {
    final ballScreenY = ball.y + cameraY;
    if (ballScreenY > gameHeight + 100) {
      gameOver = true;
      isPaused = true;
      _gameLoopTimer?.cancel();
    }
  }

  void _updateScore() {
    final newScore = max(0, ((_screenSize!.height - ball.y) / 15).floor());
    if (newScore > score) {
      score = newScore;
    }
  }

  void _handleTap(TapDownDetails details) {
    if (gameOver || isPaused) return;

    if (_screenSize != null) {
      final isLeft = details.localPosition.dx < _screenSize!.width / 2;

      // Invert controls: tap right to jump left and tap left to jump right
      _pendingHorizontalInput = isLeft ? 1 : -1;

      // Immediately apply jump with directional velocity
      ball = ball.copyWith(
        vx: _pendingHorizontalInput * horizontalSpeed,
        vy: jumpForce,
      );
    }
  }

  void _resetGame() {
    _gameLoopTimer?.cancel();
    _initializeGame();
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

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_screenSize == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final gameWidth = _screenSize!.width;
    final gameHeight = _screenSize!.height;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: GestureDetector(
        onTapDown: _handleTap,
        child: Stack(
          children: [
            // Game Area
            SizedBox(
              width: gameWidth,
              height: gameHeight,
              child: Stack(
                children: [
                  // World container with camera translation
                  Transform.translate(
                    offset: Offset(0, cameraY),
                    child: SizedBox(
                      width: gameWidth,
                      height: 4000,
                      child: Stack(
                        children: [
                          // Platforms
                          ...platforms.map((platform) {
                            final screenY = platform.y + cameraY;
                            if (screenY < -100 || screenY > gameHeight + 100) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: platform.x,
                              top: platform.y,
                              child: Container(
                                width: platform.width,
                                height: platformHeight,
                                decoration: BoxDecoration(
                                  color: platform.color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            );
                          }).toList(),

                          // Ball
                          Positioned(
                            left: ball.x,
                            top: ball.y,
                            child: Container(
                              width: ballSize,
                              height: ballSize,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ecdc4),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),

                          // Particles
                          ...particles.map((particle) {
                            final screenY = particle.y + cameraY;
                            if (screenY < -50 || screenY > gameHeight + 50) {
                              return const SizedBox.shrink();
                            }
                            return Positioned(
                              left: particle.x,
                              top: particle.y,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: particle.color.withOpacity(particle.life),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header HUD
            if (!gameOver)
              Positioned(
                top: 40,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Score',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Color(0xFF26de81),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _togglePause,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Game Over Overlay
            if (gameOver)
              Container(
                color: Colors.black.withOpacity(0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Game Over',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Color(0xFF26de81),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _resetGame,
                        icon: const Icon(Icons.restart_alt, color: Colors.white),
                        label: const Text(
                          'Restart',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF26de81),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Instructions (show at start)
            if (!gameOver && !isPaused && score == 0)
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
                    'Tap the left side to jump left or the right side to jump right.\nAvoid falling down and climb as high as possible.',
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
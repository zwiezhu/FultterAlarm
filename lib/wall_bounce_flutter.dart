import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

const double DEFAULT_GAME_WIDTH = 400;
const double DEFAULT_GAME_HEIGHT = 600;
const double WALL_WIDTH = 40;
const double PLAYER_SIZE = 26;
const double GRAVITY = 0.6;
const double JUMP_VX = 12;
const double JUMP_VY = -15;
const double AIR_JUMP_VX = 10;
const double AIR_JUMP_VY = -12;
const double WALL_BOUNCE_DAMPING = 0.7;
const double OBSTACLE_SIZE = 24;
const double DIAMOND_SIZE = 16;
const double WORLD_FLOOR = 5000;
const double CHUNK_HEIGHT = 1000;
const double PLAYER_SCREEN_RATIO = 0.8;

class GameObstacle {
  final double id;
  final double x;
  final double y;

  GameObstacle({required this.id, required this.x, required this.y});
}

class GameDiamond {
  final double id;
  final double x;
  final double y;
  final bool isDanger;

  GameDiamond({required this.id, required this.x, required this.y, required this.isDanger});
}

class Player {
  double x;
  double y;
  double vx;
  double vy;
  bool jumping;
  bool canAirJump;
  bool onLeft;

  Player({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.jumping = false,
    this.canAirJump = false,
    this.onLeft = true,
  });

  Player copyWith({
    double? x,
    double? y,
    double? vx,
    double? vy,
    bool? jumping,
    bool? canAirJump,
    bool? onLeft,
  }) {
    return Player(
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      jumping: jumping ?? this.jumping,
      canAirJump: canAirJump ?? this.canAirJump,
      onLeft: onLeft ?? this.onLeft,
    );
  }
}

class Camera {
  double y;
  Camera({required this.y});
}

class WallBounceGame extends StatefulWidget {
  final Function(int)? onScoreChange;
  final bool gameCompleted;
  final bool casualMode;

  const WallBounceGame({
    Key? key,
    this.onScoreChange,
    this.gameCompleted = false,
    this.casualMode = false,
  }) : super(key: key);

  @override
  State<WallBounceGame> createState() => _WallBounceGameState();
}

class _WallBounceGameState extends State<WallBounceGame> with TickerProviderStateMixin {
  late Player player;
  late Camera camera;
  List<GameObstacle> obstacles = [];
  List<GameDiamond> diamonds = [];
  int score = 0;
  bool gameStarted = false;
  bool gameOver = false;
  bool isPaused = false;
  double worldTop = 0;

  Size? _screenSize;
  double get gameWidth => _screenSize?.width ?? DEFAULT_GAME_WIDTH;
  double get gameHeight => _screenSize?.height ?? DEFAULT_GAME_HEIGHT;

  Timer? gameTimer;
  final math.Random random = math.Random();

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
    player = Player(
      x: WALL_WIDTH,
      y: WORLD_FLOOR - gameHeight * (1 - PLAYER_SCREEN_RATIO),
    );
    camera = Camera(y: WORLD_FLOOR - gameHeight);
    obstacles.clear();
    diamonds.clear();
    score = 0;
    gameStarted = false;
    gameOver = false;
    isPaused = false;
    worldTop = 0;
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  void _generateWorldChunk(double fromY, double toY) {
    for (double y = fromY; y > toY; y -= 120) {
      if (random.nextDouble() < 0.4) {
        obstacles.add(GameObstacle(
          id: random.nextDouble(),
          x: random.nextBool()
            ? WALL_WIDTH + 5
            : gameWidth - WALL_WIDTH - OBSTACLE_SIZE - 5,
          y: y + random.nextDouble() * 80 - 40,
        ));
      }
      
      if (random.nextDouble() < 0.9) {
        bool isDanger = random.nextDouble() < 0.2;
        double minX = WALL_WIDTH + 20;
        double maxX = gameWidth - WALL_WIDTH - DIAMOND_SIZE - 20;
        diamonds.add(GameDiamond(
          id: random.nextDouble(),
          x: minX + random.nextDouble() * (maxX - minX),
          y: y + random.nextDouble() * 80 - 40,
          isDanger: isDanger,
        ));
      }
      
      if (y % 240 == 0 && random.nextDouble() < 0.7) {
        bool isDanger = random.nextDouble() < 0.15;
        double centerX = gameWidth / 2 - DIAMOND_SIZE / 2;
        diamonds.add(GameDiamond(
          id: random.nextDouble(),
          x: centerX + random.nextDouble() * 60 - 30,
          y: y + random.nextDouble() * 60 - 30,
          isDanger: isDanger,
        ));
      }
    }
  }

  void _handleJump() {
    if (!gameStarted) {
      setState(() {
        gameStarted = true;
        _generateWorldChunk(WORLD_FLOOR - 200, -CHUNK_HEIGHT);
        worldTop = -CHUNK_HEIGHT;
      });
      _startGameLoop();
      return;
    }
    
    if (gameOver) {
      _resetGame();
      return;
    }
    
    if (isPaused) return;

    setState(() {
      if (!player.jumping) {
        double dir = player.onLeft ? 1 : -1;
        player = player.copyWith(
          vx: dir * JUMP_VX,
          vy: JUMP_VY,
          jumping: true,
          canAirJump: true,
        );
      } else if (player.canAirJump) {
        double dir = player.vx > 0 ? -1 : 1;
        player = player.copyWith(
          vx: dir * AIR_JUMP_VX,
          vy: AIR_JUMP_VY,
          canAirJump: false,
        );
      }
    });
  }

  bool _checkCollision(double px, double py, double size, double ox, double oy, double osize) {
    return px < ox + osize && px + size > ox && py < oy + osize && py + size > oy;
  }

  void _resetGame() {
    gameTimer?.cancel();
    setState(() {
      _initializeGame();
    });
  }

  void _startGameLoop() {
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!gameStarted || gameOver || isPaused || (widget.gameCompleted && !widget.casualMode)) {
        return;
      }

      setState(() {
        // Update player
        if (player.jumping) {
          double newX = player.x + player.vx;
          double newY = player.y + player.vy;
          double newVx = player.vx;
          double newVy = player.vy + GRAVITY;
          bool newOnLeft = player.onLeft;
          bool newJumping = player.jumping;
          bool newCanAirJump = player.canAirJump;

          if (newX <= WALL_WIDTH) {
            newX = WALL_WIDTH;
            if (newVx < 0) {
              newVx = 0;
              newVy = newVy * WALL_BOUNCE_DAMPING;
              newOnLeft = true;
              newJumping = false;
              newCanAirJump = true;
            }
          }
          
          if (newX >= gameWidth - WALL_WIDTH - PLAYER_SIZE) {
            newX = gameWidth - WALL_WIDTH - PLAYER_SIZE;
            if (newVx > 0) {
              newVx = 0;
              newVy = newVy * WALL_BOUNCE_DAMPING;
              newOnLeft = false;
              newJumping = false;
              newCanAirJump = true;
            }
          }
          
          if (newY > WORLD_FLOOR) {
            gameOver = true;
          }

          player = player.copyWith(
            x: newX,
            y: newY,
            vx: newVx,
            vy: newVy,
            onLeft: newOnLeft,
            jumping: newJumping,
            canAirJump: newCanAirJump,
          );
        }

        // Generate new world chunks
        if (player.y < worldTop + CHUNK_HEIGHT) {
          _generateWorldChunk(worldTop - 200, worldTop - CHUNK_HEIGHT);
          worldTop = worldTop - CHUNK_HEIGHT;
        }

        // Update camera
        double screenPos = camera.y + gameHeight * PLAYER_SCREEN_RATIO;
        if (player.y < screenPos) {
          double targetY = player.y - gameHeight * PLAYER_SCREEN_RATIO;
          double clampedY = math.min(WORLD_FLOOR - gameHeight, targetY);
          double smoothFactor = 0.1;
          camera.y = camera.y + (clampedY - camera.y) * smoothFactor;
        }

        // Check collisions with obstacles
        for (GameObstacle obs in obstacles) {
          if (_checkCollision(player.x, player.y, PLAYER_SIZE, obs.x, obs.y, OBSTACLE_SIZE)) {
            gameOver = true;
            break;
          }
        }

        // Check collisions with diamonds
        diamonds.removeWhere((d) {
          if (_checkCollision(player.x, player.y, PLAYER_SIZE, d.x, d.y, DIAMOND_SIZE)) {
            if (d.isDanger) {
              gameOver = true;
            } else {
              score += 10;
              widget.onScoreChange?.call(score);
            }
            return true;
          }
          return false;
        });
      });
    });
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  List<GameObstacle> _getVisibleObstacles() {
    return obstacles.where((obs) =>
        obs.y >= camera.y - OBSTACLE_SIZE && obs.y <= camera.y + gameHeight + OBSTACLE_SIZE).toList();
  }

  List<GameDiamond> _getVisibleDiamonds() {
    return diamonds.where((d) =>
        d.y >= camera.y - DIAMOND_SIZE && d.y <= camera.y + gameHeight + DIAMOND_SIZE).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F2937),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: GestureDetector(
            onTap: _handleJump,
            child: Container(
              width: gameWidth,
              height: gameHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                border: Border.all(color: const Color(0xFF374151), width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    // Game area
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GamePainter(
                          player: player,
                          camera: camera,
                          obstacles: _getVisibleObstacles(),
                          diamonds: _getVisibleDiamonds(),
                          worldTop: worldTop,
                          gameWidth: gameWidth,
                        ),
                      ),
                    ),
                    
                    // Header
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Score',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                Text(
                                  score.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: _togglePause,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF374151),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  isPaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Overlay
                    if (gameOver || isPaused || (widget.gameCompleted && !widget.casualMode))
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.75),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  gameOver
                                      ? (player.y < 100 ? 'Congratulations!' : 'Game Over')
                                      : widget.gameCompleted
                                          ? 'Game Complete!'
                                          : 'Paused',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (gameOver) ...[
                                  const SizedBox(height: 8),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 16, color: Color(0xFFD1D5DB)),
                                      children: [
                                        const TextSpan(text: 'Final Score: '),
                                        TextSpan(
                                          text: score.toString(),
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.casualMode) ...[
                                    const SizedBox(height: 16),
                                    GestureDetector(
                                      onTap: _resetGame,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.refresh, color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Play Again',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    
                    // No start instructions overlay
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final Player player;
  final Camera camera;
  final List<GameObstacle> obstacles;
  final List<GameDiamond> diamonds;
  final double worldTop;
  final double gameWidth;

  GamePainter({
    required this.player,
    required this.camera,
    required this.obstacles,
    required this.diamonds,
    required this.worldTop,
    required this.gameWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Draw walls
    paint.color = const Color(0xFF374151);
    canvas.drawRect(
      Rect.fromLTWH(0, worldTop - camera.y, WALL_WIDTH, WORLD_FLOOR - worldTop),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        gameWidth - WALL_WIDTH,
        worldTop - camera.y,
        WALL_WIDTH,
        WORLD_FLOOR - worldTop,
      ),
      paint,
    );

    // Draw obstacles
    paint.color = const Color(0xFFEF4444);
    for (GameObstacle obs in obstacles) {
      canvas.save();
      canvas.translate(
        obs.x + OBSTACLE_SIZE / 2,
        obs.y - camera.y + OBSTACLE_SIZE / 2,
      );
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: OBSTACLE_SIZE,
          height: OBSTACLE_SIZE,
        ),
        paint,
      );
      canvas.restore();
    }

    // Draw diamonds
    for (GameDiamond diamond in diamonds) {
      paint.color = diamond.isDanger ? const Color(0xFFEF4444) : const Color(0xFF10B981);
      canvas.save();
      canvas.translate(
        diamond.x + DIAMOND_SIZE / 2,
        diamond.y - camera.y + DIAMOND_SIZE / 2,
      );
      canvas.rotate(math.pi / 4);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: DIAMOND_SIZE,
          height: DIAMOND_SIZE,
        ),
        paint,
      );
      
      // Draw border
      paint.color = diamond.isDanger ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: DIAMOND_SIZE,
          height: DIAMOND_SIZE,
        ),
        paint,
      );
      paint.style = PaintingStyle.fill;
      canvas.restore();
    }

    // Draw player
    paint.color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          player.x,
          player.y - camera.y,
          PLAYER_SIZE,
          PLAYER_SIZE,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
    
    // Draw player border
    paint.color = const Color(0xFF34D399);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          player.x,
          player.y - camera.y,
          PLAYER_SIZE,
          PLAYER_SIZE,
        ),
        const Radius.circular(6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Example usage

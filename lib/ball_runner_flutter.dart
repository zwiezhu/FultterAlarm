import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for tunnel obstacles
class Tunnel {
  final int id;
  final double gapX;
  final double gapWidth;
  double y;
  bool passed;

  Tunnel({
    required this.id,
    required this.gapX,
    required this.gapWidth,
    required this.y,
    this.passed = false,
  });
}

class BallRunnerGame extends StatefulWidget {
  final Function(int) onScoreChange;
  final bool gameCompleted;
  final bool casualMode;

  const BallRunnerGame({
    Key? key,
    required this.onScoreChange,
    this.gameCompleted = false,
    this.casualMode = false,
  }) : super(key: key);

  @override
  State<BallRunnerGame> createState() => _BallRunnerGameState();
}

class _BallRunnerGameState extends State<BallRunnerGame> {
  // Game constants
  static const double ballSize = 28;
  static const double obstacleHeight = 26;
  static const double ballSpeed = 7;
  static const double obstacleSpeedStart = 2.8;
  late double obstacleSpeedMax;
  static const int obstacleIntervalStart = 2400;
  static const int obstacleIntervalMin = 550;
  static const double gapMin = ballSize * 1.4;
  static const double gapMax = ballSize * 2.3;
  static const double safetyMargin = 0.9;

  // Calculated at runtime based on screen size.
  late double crossTimeMs; // Time for the ball to cross the screen.

  // Game state
  double ballX = 0;
  double ballY = 0;
  int score = 0;
  List<Tunnel> tunnels = [];
  bool isPaused = false;
  bool gameOver = false;
  double obstacleSpeed = obstacleSpeedStart;
  int obstacleInterval = obstacleIntervalStart;
  double gapMultiplier = 2.0;
  int gameKey = 0;

  // Movement state
  int moveDirection = 0; // -1 left, 1 right, 0 none
  
  // Timers
  Timer? _gameLoopTimer;
  Timer? _obstacleTimer;

  double gameWidth = 0;
  double gameHeight = 0;

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
    gameHeight = mediaQuery.size.height;

    setState(() {
      ballX = (gameWidth - ballSize) / 2;
      ballY = gameHeight - ballSize - 12;
    });

    // Calculate how long it takes for the ball to move across the screen.
    final crossFrames = (gameWidth - ballSize) / ballSpeed;
    crossTimeMs = crossFrames * 16;

    // Determine the maximum safe obstacle speed based on this time.
    final verticalDistance = ballY + obstacleHeight;
    obstacleSpeedMax = verticalDistance / crossFrames;

    _resetGame();
  }

  void _resetGame() {
    setState(() {
      ballX = (gameWidth - ballSize) / 2;
      score = 0;
      tunnels = [];
      isPaused = false;
      gameOver = false;
      obstacleSpeed = min(obstacleSpeedStart, obstacleSpeedMax);
      obstacleInterval = obstacleIntervalStart;
      gapMultiplier = 2.0;
      gameKey++;
    });
    
    widget.onScoreChange(0);
    _startGame();
  }

  void _startGame() {
    if (gameOver || isPaused || (widget.gameCompleted && !widget.casualMode)) return;
    
    // Create first tunnel
    tunnels.add(_createTunnel(0));
    
    // Start obstacle generation timer
    _obstacleTimer?.cancel();
    _obstacleTimer = Timer.periodic(Duration(milliseconds: obstacleInterval), (timer) {
      if (!gameOver && !isPaused && !(widget.gameCompleted && !widget.casualMode)) {
        setState(() {
          final lastTunnel = tunnels.isNotEmpty ? tunnels.last : null;
          tunnels.add(_createTunnel(tunnels.length, lastTunnel));
        });
      }
    });
    
    // Start main game loop
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), _gameLoop);
  }

  Tunnel _createTunnel(int id, [Tunnel? previousTunnel]) {
    final baseGap = gapMin + Random().nextDouble() * (gapMax - gapMin);
    final gapWidth = baseGap * gapMultiplier;
    
    double minX = 0;
    double maxX = gameWidth - gapWidth;
    
    if (previousTunnel != null) {
      final verticalDistance = ballY + obstacleHeight;
      final crossFrames = verticalDistance / obstacleSpeed;
      final intervalFrames = obstacleInterval / 16;
      final available = max(0.0, crossFrames - intervalFrames);
      final maxShift = ballSpeed * available * safetyMargin;
      
      minX = max(0.0, previousTunnel.gapX - maxShift);
      maxX = min(gameWidth - gapWidth, previousTunnel.gapX + maxShift);
    }
    
    final gapX = minX + Random().nextDouble() * (maxX - minX);
    
    return Tunnel(
      id: id,
      gapX: gapX,
      gapWidth: gapWidth,
      y: -obstacleHeight,
    );
  }

  void _gameLoop(Timer timer) {
    if (gameOver || isPaused || (widget.gameCompleted && !widget.casualMode)) {
      return;
    }
    
    setState(() {
      // Move ball
      if (moveDirection != 0) {
        ballX += moveDirection * ballSpeed;
        ballX = ballX.clamp(0, gameWidth - ballSize);
      }
      
      // Move tunnels
      for (var tunnel in tunnels) {
        tunnel.y += obstacleSpeed;
      }
      
      // Remove tunnels that are off screen
      tunnels.removeWhere((tunnel) => tunnel.y > gameHeight);
      
      // Check collisions and scoring
      _checkCollisions();
    });
  }

  void _checkCollisions() {
    final ballCenter = ballX + ballSize / 2;
    
    for (var tunnel in tunnels) {
      // Check collision
      if (ballY + ballSize > tunnel.y &&
          ballY < tunnel.y + obstacleHeight &&
          (ballCenter < tunnel.gapX || ballCenter > tunnel.gapX + tunnel.gapWidth)) {
        _handleGameOver();
        return;
      }
      
      // Check scoring
      if (!tunnel.passed && tunnel.y + obstacleHeight > ballY + ballSize) {
        tunnel.passed = true;
        setState(() {
          score++;
          gapMultiplier = max(1.0, gapMultiplier - 0.1);
        });
        widget.onScoreChange(score);
        
        // Increase difficulty every 7 points
        if (score % 7 == 0) {
          setState(() {
            obstacleSpeed = min(obstacleSpeed + 0.28, obstacleSpeedMax);
            obstacleInterval = max(obstacleInterval - 70, obstacleIntervalMin);
          });
          
          // Restart timers with new interval
          _obstacleTimer?.cancel();
          _obstacleTimer = Timer.periodic(Duration(milliseconds: obstacleInterval), (timer) {
            if (!gameOver && !isPaused && !(widget.gameCompleted && !widget.casualMode)) {
              setState(() {
                final lastTunnel = tunnels.isNotEmpty ? tunnels.last : null;
                tunnels.add(_createTunnel(tunnels.length, lastTunnel));
              });
            }
          });
        }
      }
    }
  }

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      isPaused = true;
    });
    
    _gameLoopTimer?.cancel();
    _obstacleTimer?.cancel();
    
    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) {
        _showGameOverDialog();
      }
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d2d2d),
        title: const Text('Game Over', style: TextStyle(color: Colors.white)),
        content: Text('Score: $score', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('Restart', style: TextStyle(color: Color(0xFF26de81))),
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
      
      if (isPaused) {
        _gameLoopTimer?.cancel();
        _obstacleTimer?.cancel();
      } else {
        _startGame();
      }
    }
  }

  void _onPanStart(DragStartDetails details) {
    final touchX = details.globalPosition.dx;
    moveDirection = touchX < gameWidth / 2 ? -1 : 1;
  }

  void _onPanEnd(DragEndDetails details) {
    moveDirection = 0;
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _obstacleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    gameWidth = mediaQuery.size.width;
    gameHeight = mediaQuery.size.height;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // Game Area
            Container(
              width: gameWidth,
              height: gameHeight,
              color: const Color(0xFF0f0f0f),
              child: Stack(
                children: [
                  // Tunnels
                  ...tunnels.map((tunnel) => _buildTunnel(tunnel)),
                  
                  // Player Ball
                  Positioned(
                    left: ballX,
                    top: ballY,
                    child: Container(
                      width: ballSize,
                      height: ballSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2972ff), width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '⬤',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF45b7d1),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Header
            Positioned(
              top: 50,
              left: 20,
              right: 20,
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
                      children: [
                        const Text(
                          'Score',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                    Column(
                      children: [
                        Text(
                          'Speed: ${obstacleSpeed.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _togglePause,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
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
            
            // Instructions
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Tap left/right side of screen to dodge obstacles!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            
            // Overlay
            if (isPaused || gameOver || (widget.gameCompleted && !widget.casualMode))
              Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        gameOver ? 'Game Over!' : 
                        widget.gameCompleted ? 'Game Complete!' : 'Paused',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (gameOver && widget.casualMode) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _resetGame,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'Play Again',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF26de81),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTunnel(Tunnel tunnel) {
    return Stack(
      children: [
        // Left wall
        if (tunnel.gapX > 0)
          Positioned(
            left: 0,
            top: tunnel.y,
            child: Container(
              width: tunnel.gapX,
              height: obstacleHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF2972ff),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF45b7d1), width: 2),
              ),
            ),
          ),
        
        // Right wall
        if (tunnel.gapX + tunnel.gapWidth < gameWidth)
          Positioned(
            left: tunnel.gapX + tunnel.gapWidth,
            top: tunnel.y,
            child: Container(
              width: gameWidth - (tunnel.gapX + tunnel.gapWidth),
              height: obstacleHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF2972ff),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF45b7d1), width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
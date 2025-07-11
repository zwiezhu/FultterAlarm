import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model dla sekcji jaskini
class CaveSection {
  final double top;
  final double bottom;

  CaveSection({required this.top, required this.bottom});
}

// Model dla diamentu
class Diamond {
  final int id;
  final double x;
  final double y;

  Diamond({required this.id, required this.x, required this.y});
}

class CaveLanderGameScreen extends StatefulWidget {
  final Function(int)? onScoreChange;
  final bool gameCompleted;
  final bool casualMode;

  const CaveLanderGameScreen({
    super.key,
    this.onScoreChange,
    this.gameCompleted = false,
    this.casualMode = false,
  });

  @override
  State<CaveLanderGameScreen> createState() => _CaveLanderGameScreenState();
}

class _CaveLanderGameScreenState extends State<CaveLanderGameScreen> {
  // Stałe gry
  static const double shipWidth = 34;
  static const double shipHeight = 24;
  static const double shipRadius = 21.6; // sqrt(34^2 + 24^2) / 2
  static const double hitboxScale = 0.8;
  static const double hitboxRadius = shipRadius * hitboxScale;

  // Parametry fizyki
  static const double speedMin = 0.2;
  static const double speedMax = 2.5;
  static const double speedAccelDist = 1000;
  static const double gravity = 0.28;
  static const double engineForce = 0.65;
  static const double counterForceMult = 1.5;
  static const double rotationSpeed = 0.1;

  // Parametry jaskini
  static const double caveSection = 32;
  static const double caveWidthMin = shipHeight * 3.5;
  static const double caveWidthMax = shipHeight * 3.9;
  static const double caveWidthStart = shipHeight * 3.15;
  static const double caveShrinkRate = 0.997;
  static const int platformSections = 8;

  // Stan gry
  bool started = false;
  double shipX = caveSection * 2;
  double shipY = 0;
  double shipAngle = 0;
  double shipVx = 0;
  double shipVy = 0;
  double shipVangle = 0;
  bool canMove = false;
  double minPlatformHeight = 0;
  
  List<CaveSection> caveSections = [];
  List<Diamond> diamonds = [];
  double caveOffset = 0;
  int distanceScore = 0;
  int diamondScore = 0;
  bool isPaused = false;
  bool gameOver = false;
  
  late double gameWidth;
  late double gameHeight;
  late double groundLevel;
  late double ceilingLevel;
  late double screenCenterX;
  late double shipStartX;
  late double shipStartY;
  late double initialCaveOffset;
  
  bool leftEngine = false;
  bool rightEngine = false;
  Timer? gameLoopTimer;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.of(context);
    gameWidth = mediaQuery.size.width;
    gameHeight = mediaQuery.size.height - mediaQuery.padding.top;
    groundLevel = gameHeight - 60;
    ceilingLevel = min(500, gameHeight * 0.3);
    screenCenterX = gameWidth / 2 - shipWidth / 2;
    shipStartX = caveSection * 2;
    shipStartY = groundLevel - shipHeight - 40;
    initialCaveOffset = screenCenterX - shipStartX;
    minPlatformHeight = shipStartY;
    
    if (caveSections.isEmpty) {
      _initializeGame();
    }
  }

  void _initializeGame() {
    final seed = random.nextDouble();
    caveSections = _generateRandomCaveSections(64, 0, gameHeight / 2, caveWidthStart, seed);
    diamonds = _generateDiamonds(caveSections);
    
    setState(() {
      shipX = shipStartX;
      shipY = shipStartY;
      shipAngle = 0;
      shipVx = 0;
      shipVy = 0;
      shipVangle = 0;
      canMove = false;
      minPlatformHeight = shipStartY;
      caveOffset = initialCaveOffset;
      distanceScore = 0;
      diamondScore = 0;
      isPaused = false;
      gameOver = false;
    });
  }

  List<CaveSection> _generateRandomCaveSections(
    int count,
    int startIdx,
    double initialMid,
    double initialWidth,
    double seed,
  ) {
    final List<CaveSection> sections = [];
    double prevMid = initialMid;
    double prevWidth = initialWidth;
    
    final waveFreq = 8 + random.nextDouble() * 16;
    final waveAmp = 20 + random.nextDouble() * 40;
    final noiseStrength = 5 + random.nextDouble() * 15;
    final verticalTrend = (random.nextDouble() - 0.5) * 0.3;
    
    for (int i = 0; i < count; i++) {
      final idx = startIdx + i;
      
      // Płaska platforma startowa
      if (idx < platformSections) {
        sections.add(CaveSection(
          top: ceilingLevel,
          bottom: groundLevel,
        ));
        if (idx == platformSections - 1) {
          final platformHeight = groundLevel - ceilingLevel;
          prevMid = ceilingLevel + platformHeight / 2;
          prevWidth = platformHeight;
        }
        continue;
      }
      
      // Przejście z platformy do jaskini
      if (idx == platformSections) {
        final platformHeight = groundLevel - ceilingLevel;
        final transitionMid = ceilingLevel + platformHeight / 2;
        final transitionWidth = max(platformHeight, caveWidthStart);
        sections.add(CaveSection(
          top: max(0, transitionMid - transitionWidth / 2),
          bottom: min(gameHeight, transitionMid + transitionWidth / 2),
        ));
        prevMid = transitionMid;
        prevWidth = transitionWidth;
        continue;
      }
      
      // Właściwa jaskinia
      final progress = min(1.0, (idx - platformSections - 1) / 500);
      final widthTarget = caveWidthMin + (caveWidthMax - caveWidthMin) * (1 - progress);
      final widthNow = prevWidth * caveShrinkRate + widthTarget * (1 - caveShrinkRate);
      
      final waveOffset = sin((idx + seed * 100) / waveFreq) * waveAmp;
      final noiseOffset = (sin((idx + seed * 50) * 0.1) + sin((idx + seed * 30) * 0.3)) * noiseStrength;
      final trendOffset = (idx - platformSections - 1) * verticalTrend;
      
      double mid = prevMid + waveOffset * 0.15 + noiseOffset + trendOffset + (random.nextDouble() - 0.5) * 8;
      mid = max(caveWidthMax, min(gameHeight - caveWidthMax, mid));
      final widthFinal = max(widthNow, widthTarget);

      sections.add(CaveSection(
        top: max(0, mid - widthFinal / 2),
        bottom: min(gameHeight, mid + widthFinal / 2),
      ));

      prevMid = mid;
      prevWidth = widthFinal;
    }
    return sections;
  }

  List<Diamond> _generateDiamonds(List<CaveSection> sections) {
    final List<Diamond> diamonds = [];
    for (int i = 0; i < sections.length; i++) {
      if (i < platformSections) continue;
      if (random.nextDouble() < 0.1) {
        final section = sections[i];
        diamonds.add(Diamond(
          id: i,
          x: i * caveSection + caveSection / 2,
          y: (section.top + section.bottom) / 2,
        ));
      }
    }
    return diamonds;
  }

  void _startGame() {
    if (started) return;
    setState(() {
      started = true;
    });
    _startGameLoop();
  }

  void _startGameLoop() {
    gameLoopTimer?.cancel();
    gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (gameOver || isPaused || !started) return;
      _updateGame();
    });
  }

  void _updateGame() {
    final caveIdx = (shipX / caveSection).floor();
    final angleRad = (shipAngle * pi) / 180;
    final baseForce = rightEngine && !leftEngine ? engineForce * counterForceMult : engineForce;
    final thrustForce = (leftEngine || rightEngine) ? baseForce : 0;

    // Zawsze aplikuj grawitację po wystartowaniu
    shipVy += gravity;

    // Ciąg silnika
    if (thrustForce > 0) {
      final horizontalThrust = thrustForce * sin(angleRad);
      final verticalThrust = thrustForce * cos(angleRad);
      
      if (canMove) {
        shipVx += horizontalThrust;
      }
      shipVy -= verticalThrust;
    }

    // Ograniczenia prędkości
    const maxV = 4.0;
    shipVx = max(-maxV, min(maxV, shipVx));
    shipVy = max(-maxV, min(maxV, shipVy));

    // Aktualizacja dystansu
    final newDist = max(0, ((shipX - shipStartX) / 10).floor());
    distanceScore = newDist;

    // Oblicz prędkość do przodu
    final speedProgress = min(1.0, newDist / speedAccelDist);
    final forwardSpeed = canMove ? speedMin + (speedMax - speedMin) * speedProgress : 0;

    // Rotacja
    if (leftEngine && !rightEngine) shipVangle += rotationSpeed;
    if (rightEngine && !leftEngine) shipVangle -= rotationSpeed;

    // Ruch
    shipAngle += shipVangle;
    double newY = shipY + shipVy;
    double newX = canMove ? shipX + shipVx + forwardSpeed : shipX;

    // Blokada platformy startowej
    final onStartingPlatform = caveIdx < platformSections;
    if (onStartingPlatform && !canMove) {
      if (newY < minPlatformHeight - 5) {
        canMove = true;
      } else {
        if (newY > minPlatformHeight) {
          newY = minPlatformHeight;
          shipVy = 0;
        }
        newX = shipStartX;
        shipVx = 0;
      }
    }

    shipY = newY;
    shipX = newX;

    // Tłumienie
    shipVangle *= 0.984;
    shipVy *= 0.98;
    if (canMove) {
      shipVx *= 0.98;
    } else {
      shipVx = 0;
    }

    // Normalizacja kąta
    if (shipAngle > 180) shipAngle -= 360;
    if (shipAngle < -180) shipAngle += 360;

    // Aktualizacja kamery
    if (canMove) {
      caveOffset = screenCenterX - shipX;
    }

    // Zbieranie diamentów
    final shipCenterX = shipX + shipWidth / 2;
    final shipCenterY = shipY + shipHeight / 2;
    final List<Diamond> newDiamonds = [];
    int collected = 0;

    for (final diamond in diamonds) {
      final dist = sqrt(pow(shipCenterX - diamond.x, 2) + pow(shipCenterY - diamond.y, 2));
      if (dist < hitboxRadius + 8) {
        collected++;
      } else {
        newDiamonds.add(diamond);
      }
    }

    if (collected > 0) {
      diamondScore += collected * 10;
    }
    diamonds = newDiamonds;

    // Sprawdzenie kolizji
    if (started && (canMove || shipX > shipStartX + 20)) {
      final shipCY = shipY + shipHeight / 2;
      final safeHitboxRadius = hitboxRadius * 0.7;

      if (caveIdx < platformSections) {
        if (shipCY - safeHitboxRadius < ceilingLevel ||
            shipCY + safeHitboxRadius > groundLevel) {
          _handleGameOver();
          return;
        }
      } else if (caveIdx < caveSections.length) {
        final section = caveSections[caveIdx];
        if (shipCY - safeHitboxRadius < section.top ||
            shipCY + safeHitboxRadius > section.bottom) {
          _handleGameOver();
          return;
        }
      }
    }

    // Dodaj więcej sekcji jeśli potrzeba
    if (caveSections.length - caveIdx < 32) {
      _addMoreSections();
    }

    // Wywołaj callback ze zmianą wyniku
    if (widget.onScoreChange != null) {
      widget.onScoreChange!(distanceScore + diamondScore);
    }

    setState(() {});
  }

  void _addMoreSections() {
    final last = caveSections.last;
    final lastMid = (last.top + last.bottom) / 2;
    final lastWidth = last.bottom - last.top;
    final moreSections = _generateRandomCaveSections(32, caveSections.length, lastMid, lastWidth, random.nextDouble());
    
    final newDiamonds = _generateDiamonds(moreSections);
    final adjustedDiamonds = newDiamonds.map((d) => Diamond(
      id: d.id + caveSections.length,
      x: d.x,
      y: d.y,
    )).toList();
    
    caveSections.addAll(moreSections);
    diamonds.addAll(adjustedDiamonds);
  }

  void _handleGameOver() {
    setState(() {
      gameOver = true;
      isPaused = true;
    });
    gameLoopTimer?.cancel();
  }

  void _resetGame() {
    gameLoopTimer?.cancel();
    _initializeGame();
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
      if (isPaused) {
        gameLoopTimer?.cancel();
      } else {
        _startGameLoop();
      }
    }
  }

  void _handleTouch() {
    if (!started) {
      _startGame();
      return;
    }
    
    if (gameOver) {
      _resetGame();
      return;
    }
  }

  @override
  void dispose() {
    gameLoopTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speedProgress = min(1.0, distanceScore / speedAccelDist);
    final forwardSpeed = speedMin + (speedMax - speedMin) * speedProgress;
    
    final visibleStart = max(0, (-caveOffset / caveSection).floor() - 2);
    final visibleCount = (gameWidth / caveSection).ceil() + 4;
    final visibleSections = caveSections.skip(visibleStart).take(visibleCount).toList();
    final visibleDiamonds = diamonds.where((d) => 
      d.x + caveOffset > -32 && d.x + caveOffset < gameWidth + 32
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a2e),
      body: Stack(
        children: [
          // Header
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const Text('Score', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        '${distanceScore + diamondScore}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFa55eea)),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Speed: ${forwardSpeed.toStringAsFixed(1)} m/s', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (!canMove)
                        const Text('Movement Locked', style: TextStyle(fontSize: 10, color: Color(0xFFf7b731))),
                    ],
                  ),
                  IconButton(
                    onPressed: gameOver ? null : _togglePause,
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Game Area
          Positioned.fill(
            child: GestureDetector(
              onTap: _handleTouch,
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Cave sections
                    ...visibleSections.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final section = entry.value;
                      final i = visibleStart + idx;
                      
                      return Stack(
                        children: [
                          // Ceiling
                          Positioned(
                            left: i * caveSection + caveOffset,
                            top: 0,
                            child: Container(
                              width: caveSection,
                              height: section.top,
                              color: const Color(0xFF2972ff),
                            ),
                          ),
                          // Floor
                          Positioned(
                            left: i * caveSection + caveOffset,
                            top: section.bottom,
                            child: Container(
                              width: caveSection,
                              height: gameHeight - section.bottom,
                              color: const Color(0xFF2972ff),
                            ),
                          ),
                        ],
                      );
                    }).toList(),

                    // Diamonds
                    ...visibleDiamonds.map((diamond) {
                      return Positioned(
                        left: diamond.x + caveOffset - 8,
                        top: diamond.y - 8,
                        child: Transform.rotate(
                          angle: pi / 4,
                          child: Container(
                            width: 16,
                            height: 16,
                            color: Colors.cyan,
                          ),
                        ),
                      );
                    }).toList(),

                    // Ship
                    Positioned(
                      left: shipX + caveOffset,
                      top: shipY,
                      child: Transform.rotate(
                        angle: shipAngle * pi / 180,
                        child: SizedBox(
                          width: shipWidth,
                          height: shipHeight,
                          child: Stack(
                            children: [
                              // Ship body
                              Positioned(
                                left: shipWidth * 0.15,
                                top: shipHeight * 0.19,
                                child: Container(
                                  width: shipWidth * 0.7,
                                  height: shipHeight * 0.62,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: const Color(0xFFa55eea), width: 2),
                                  ),
                                ),
                              ),
                              // Left leg
                              Positioned(
                                left: -3,
                                bottom: 0,
                                child: Container(
                                  width: shipWidth * 0.38,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFa55eea),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                              // Right leg
                              Positioned(
                                right: -3,
                                bottom: 0,
                                child: Container(
                                  width: shipWidth * 0.38,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFa55eea),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Engine fire
                    if (leftEngine || rightEngine)
                      Positioned(
                        left: shipX + caveOffset + shipWidth * 0.25,
                        top: shipY + shipHeight * 0.55,
                        child: Container(
                          width: shipWidth * 0.25,
                          height: shipHeight * 0.26,
                          decoration: BoxDecoration(
                            color: const Color(0xFFf7b731).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Control buttons
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTapDown: (_) => setState(() => leftEngine = true),
                  onTapUp: (_) => setState(() => leftEngine = false),
                  onTapCancel: () => setState(() => leftEngine = false),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFa55eea), width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'L',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTapDown: (_) => setState(() => rightEngine = true),
                  onTapUp: (_) => setState(() => rightEngine = false),
                  onTapCancel: () => setState(() => rightEngine = false),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFFa55eea), width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'R',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overlays
          if (!started || gameOver || isPaused)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      gameOver ? 'GAME OVER' : !started ? 'CAVE LANDER' : 'PAUSED',
                      style: const TextStyle(
                        fontSize: 48,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (gameOver)
                      Text(
                        'Distance: ${distanceScore + diamondScore}m',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Color(0xFFa55eea),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      !started
                          ? 'Tap to start\nTap left/right to control thrusters\nNavigate through the cave!\n\nMovement locked until you lift off from platform'
                          : gameOver
                              ? 'Tap anywhere to play again'
                              : 'Tap to resume',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),
                    if (gameOver && widget.casualMode)
                      const SizedBox(height: 20),
                    if (gameOver && widget.casualMode)
                      ElevatedButton.icon(
                        onPressed: _resetGame,
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text('Play Again', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFa55eea),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a single card in the memory game
class Card {
  final int id;
  final String symbol;
  final Color color;
  bool isFlipped;
  bool isMatched;

  Card({
    required this.id,
    required this.symbol,
    required this.color,
    this.isFlipped = false,
    this.isMatched = false,
  });
}

class MemoryMatchGameScreen extends StatefulWidget {
  final Function(int)? onScoreChange;
  final bool gameCompleted;
  final bool casualMode;
  final VoidCallback? onUserInteraction;
  final int? remainingTime;
  final int? inactivityTime;
  final int durationMinutes;

  const MemoryMatchGameScreen({
    super.key,
    this.onScoreChange,
    this.gameCompleted = false,
    this.casualMode = false,
    this.onUserInteraction,
    this.remainingTime,
    this.inactivityTime,
    this.durationMinutes = 1,
  });

  @override
  State<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends State<MemoryMatchGameScreen> {
  // Game constants
  static const int gridSize = 4;
  static const int totalPairs = (gridSize * gridSize) ~/ 2;
  static const List<String> symbols = ['🌟', '🎯', '🎮', '🚀', '💎', '🔥', '⚡', '🎨'];
  static const List<Color> colors = [
    Color(0xFFff6b6b),
    Color(0xFF4ecdc4),
    Color(0xFF45b7d1),
    Color(0xFFf7b731),
    Color(0xFFa55eea),
    Color(0xFF26de81),
    Color(0xFFfd79a8),
    Color(0xFFfdcb6e),
  ];

  // Game state
  List<Card> cards = [];
  List<int> flippedCards = [];
  int score = 0;
  int moves = 0;
  int matches = 0;
  bool isPaused = false;
  bool gameOver = false;
  bool showPattern = true;
  int patternCountdown = 3;

  Timer? _patternTimer;
  Timer? _matchTimer;
  Timer? _countdownTimer;
  Timer? _gameOverTimer;
  Timer? _durationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => resetGame());
    _startDurationTimer();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer(Duration(minutes: widget.durationMinutes), () {
      setState(() {
        gameOver = true;
      });
    });
  }

  @override
  void dispose() {
    _patternTimer?.cancel();
    _matchTimer?.cancel();
    _countdownTimer?.cancel();
    _gameOverTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  List<Card> generateCards() {
    final pairs = symbols.take(totalPairs).toList().asMap().entries.map((entry) {
      return {
        'symbol': entry.value,
        'color': colors[entry.key],
      };
    }).toList();

    final List<Card> cardPairs = [];
    for (int i = 0; i < pairs.length; i++) {
      cardPairs.add(Card(
        id: i * 2,
        symbol: pairs[i]['symbol'] as String,
        color: pairs[i]['color'] as Color,
      ));
      cardPairs.add(Card(
        id: i * 2 + 1,
        symbol: pairs[i]['symbol'] as String,
        color: pairs[i]['color'] as Color,
      ));
    }

    // Shuffle cards
    cardPairs.shuffle();
    return cardPairs;
  }

  void handleCardPress(int cardId) {
    if (showPattern ||
        isPaused ||
        gameOver ||
        (widget.gameCompleted && !widget.casualMode) ||
        flippedCards.length >= 2) {
      return;
    }

    final card = cards.firstWhere((c) => c.id == cardId);
    if (card.isFlipped || card.isMatched) return;

    // Notify parent about user interaction
    widget.onUserInteraction?.call();

    setState(() {
      flippedCards.add(cardId);
      card.isFlipped = true;
    });

    if (flippedCards.length == 2) {
      setState(() {
        moves++;
      });

      final firstCard = cards.firstWhere((c) => c.id == flippedCards[0]);
      final secondCard = cards.firstWhere((c) => c.id == flippedCards[1]);

      if (firstCard.symbol == secondCard.symbol) {
        // Match found!
        _matchTimer = Timer(const Duration(milliseconds: 800), () {
          setState(() {
            firstCard.isMatched = true;
            secondCard.isMatched = true;
            matches++;
            
            final points = max(100 - moves * 5, 10);
            score += points;
            widget.onScoreChange?.call(score);

            // Check if game is complete
            if (matches == totalPairs) {
              gameOver = true;
              _gameOverTimer =
                  Timer(const Duration(seconds: 5), () => resetGame());
            }

            flippedCards.clear();
          });
        });
      } else {
        // No match
        _matchTimer = Timer(const Duration(milliseconds: 800), () {
          setState(() {
            firstCard.isFlipped = false;
            secondCard.isFlipped = false;
            flippedCards.clear();
          });
        });
      }
    }
  }

  void resetGame() {
    _patternTimer?.cancel();
    _matchTimer?.cancel();
    _countdownTimer?.cancel();
    _gameOverTimer?.cancel();
    _durationTimer?.cancel();

    setState(() {
      cards = generateCards();
      flippedCards.clear();
      score = 0;
      moves = 0;
      matches = 0;
      gameOver = false;
      isPaused = false;
      showPattern = true;
      patternCountdown = 3;
    });

    widget.onScoreChange?.call(0);

    // Show pattern for a few seconds with countdown
    setState(() {
      for (var card in cards) {
        card.isFlipped = true;
      }
    });

    // Start countdown
    int countdown = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown--;
      setState(() {
        patternCountdown = countdown;
      });

      if (countdown <= 0) {
        timer.cancel();
        setState(() {
          for (var card in cards) {
            card.isFlipped = false;
          }
          showPattern = false;
        });
      }
    });
  }

  void togglePause() {
    if (!gameOver && !showPattern) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  double getAccuracy() {
    if (moves == 0) return 100.0;
    return (matches / moves * 100).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final gameWidth = min(screenWidth - 40, 350.0);
    final cardSize = (gameWidth - 60) / gridSize;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Score
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
                          color: Color(0xFFf7b731),
                        ),
                      ),
                    ],
                  ),
                  
                  // Stats
                  Column(
                    children: [
                      if (widget.remainingTime != null)
                        Text(
                          'Time: ${widget.remainingTime}s',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      if (widget.inactivityTime != null)
                        Text(
                          'Inactive: ${widget.inactivityTime}s',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.inactivityTime! <= 5 ? Colors.red : Colors.grey,
                          ),
                        ),
                    ],
                  ),

                  // Pause button
                  GestureDetector(
                    onTap: togglePause,
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

              const SizedBox(height: 16),

              // Game Area
              Expanded(
                child: Container(
                  width: gameWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f0f0f),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Stack(
                    children: [
                      // Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return GestureDetector(
                            onTap: () => handleCardPress(card.id),
                            child: Container(
                              decoration: BoxDecoration(
                                color: card.isFlipped || card.isMatched
                                    ? card.color
                                    : const Color(0xFF333333),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: card.isMatched
                                      ? const Color(0xFF00d4aa)
                                      : const Color(0x1AFFFFFF),
                                  width: card.isMatched ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: card.isFlipped || card.isMatched
                                    ? Text(
                                        card.symbol,
                                        style: const TextStyle(fontSize: 20),
                                      )
                                    : const Text(
                                        '?',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF666666),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Pattern overlay
                      if (showPattern)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Column(
                              children: [
                                const Text(
                                  'Memorize the pattern!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFf7b731),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Starting in $patternCountdown...',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF999999),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Game overlays
                      if (isPaused ||
                          (gameOver && matches == totalPairs) ||
                          (widget.gameCompleted && !widget.casualMode))
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  gameOver && matches == totalPairs
                                      ? 'Perfect Memory!'
                                      : widget.gameCompleted
                                          ? 'Game Complete!'
                                          : 'Paused',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (gameOver && matches == totalPairs) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Final Score: $score',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFf7b731),
                                    ),
                                  ),
                                  Text(
                                    'Moves: $moves',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                  Text(
                                    'Accuracy: ${getAccuracy().toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF00d4aa),
                                    ),
                                  ),
                                ],
                                if (gameOver && widget.casualMode) ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: resetGame,
                                    icon: const Icon(Icons.refresh, color: Colors.white),
                                    label: const Text(
                                      'Play Again',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFf7b731),
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
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  showPattern
                      ? 'Study the pattern carefully!'
                      : 'Find matching pairs by flipping cards. Fewer moves = higher score!',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
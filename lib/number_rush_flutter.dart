import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for a math problem
class MathProblem {
  final int id;
  final String question;
  final int answer;
  final List<int> options;
  final int timeLeft;
  final int maxTime;

  MathProblem({
    required this.id,
    required this.question,
    required this.answer,
    required this.options,
    required this.timeLeft,
    required this.maxTime,
  });
}

class NumberRushGameScreen extends StatefulWidget {
  final Function(int)? onScoreChange;
  final bool gameCompleted;
  final bool casualMode;
  final VoidCallback? onUserInteraction;
  final int? remainingTime;
  final int? inactivityTime;

  const NumberRushGameScreen({
    super.key,
    this.onScoreChange,
    this.gameCompleted = false,
    this.casualMode = false,
    this.onUserInteraction,
    this.remainingTime,
    this.inactivityTime,
  });

  @override
  State<NumberRushGameScreen> createState() => _NumberRushGameScreenState();
}

class _NumberRushGameScreenState extends State<NumberRushGameScreen> {
  // Game state
  MathProblem? currentProblem;
  int score = 0;
  int streak = 0;
  bool isPaused = false;
  bool gameOver = false;
  int timeLeft = 10;
  int difficulty = 1;
  int? selectedAnswer;
  bool showResult = false;

  Timer? _gameTimer;
  final Random _random = Random();

  // Game colors
  final List<Color> optionColors = [
    const Color(0xFF4ecdc4),
    const Color(0xFF45b7d1),
    const Color(0xFFf7b731),
    const Color(0xFFa55eea),
  ];

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _generateNewProblem();
      }
    });
  }

  MathProblem _generateProblem() {
    final operations = ['+', '-', '*'];
    final operation = operations[_random.nextInt(operations.length)];
    
    int num1, num2, answer;
    String question;
    
    // Adjust difficulty based on current level
    final maxNum = (10 + difficulty * 5).clamp(10, 50);
    
    switch (operation) {
      case '+':
        num1 = _random.nextInt(maxNum) + 1;
        num2 = _random.nextInt(maxNum) + 1;
        answer = num1 + num2;
        question = '$num1 + $num2';
        break;
      case '-':
        num1 = _random.nextInt(maxNum) + 10;
        num2 = _random.nextInt(num1 - 1) + 1;
        answer = num1 - num2;
        question = '$num1 - $num2';
        break;
      case '*':
        final maxMul = (difficulty + 5).clamp(5, 12);
        num1 = _random.nextInt(maxMul) + 1;
        num2 = _random.nextInt(maxMul) + 1;
        answer = num1 * num2;
        question = '$num1 × $num2';
        break;
      default:
        num1 = 1;
        num2 = 1;
        answer = 2;
        question = '1 + 1';
    }

    // Generate wrong options
    final options = <int>[answer];
    while (options.length < 4) {
      final wrongAnswer = answer + _random.nextInt(20) - 10;
      if (wrongAnswer > 0 && !options.contains(wrongAnswer)) {
        options.add(wrongAnswer);
      }
    }

    // Shuffle options
    options.shuffle(_random);

    final maxTime = (15 - difficulty).clamp(5, 15);
    return MathProblem(
      id: DateTime.now().millisecondsSinceEpoch,
      question: question,
      answer: answer,
      options: options,
      timeLeft: maxTime,
      maxTime: maxTime,
    );
  }

  void _generateNewProblem() {
    if (gameOver || (widget.gameCompleted && !widget.casualMode)) return;

    setState(() {
      currentProblem = _generateProblem();
      timeLeft = currentProblem!.timeLeft;
      selectedAnswer = null;
      showResult = false;
    });

    _startTimer();
  }

  void _startTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isPaused || gameOver || currentProblem == null) return;

      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          // Time's up - wrong answer
          streak = 0;
          _generateNewProblem();
        }
      });
    });
  }

  void _handleAnswer(int selectedAnswer) {
    if (currentProblem == null || gameOver || (widget.gameCompleted && !widget.casualMode)) return;

    // Notify parent about user interaction
    widget.onUserInteraction?.call();

    final isCorrect = selectedAnswer == currentProblem!.answer;
    
    setState(() {
      this.selectedAnswer = selectedAnswer;
      showResult = true;
    });

    if (isCorrect) {
      final points = ((10 + streak * 2) * (timeLeft / 10)).round();
      setState(() {
        score += points;
        streak++;
        
        // Increase difficulty every 5 correct answers
        if (streak % 5 == 0) {
          difficulty++;
        }
      });
      
      widget.onScoreChange?.call(score);
    } else {
      setState(() {
        streak = 0;
      });
    }

    _gameTimer?.cancel();
    
    // Show result for a moment then generate next problem
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !gameOver) {
        _generateNewProblem();
      }
    });
  }

  void _resetGame() {
    setState(() {
      score = 0;
      streak = 0;
      difficulty = 1;
      gameOver = false;
      isPaused = false;
      selectedAnswer = null;
      showResult = false;
    });
    
    widget.onScoreChange?.call(0);
    _generateNewProblem();
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  Color _getTimeColor() {
    if (timeLeft <= 3) return const Color(0xFFff6b6b);
    if (timeLeft <= 6) return const Color(0xFFf7b731);
    return const Color(0xFF4ecdc4);
  }

  double _getTimePercentage() {
    if (currentProblem == null) return 1.0;
    return (timeLeft / currentProblem!.maxTime).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final gameWidth = mediaQuery.size.width - 40;
    final gameHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16.0),
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
                        score.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF45b7d1),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        'Streak: $streak',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'Level: $difficulty',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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
              child: Container(
                width: gameWidth,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1a1a),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: currentProblem != null && !isPaused && !gameOver && !(widget.gameCompleted && !widget.casualMode)
                    ? _buildGameContent()
                    : _buildOverlay(),
              ),
            ),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Solve math problems as fast as you can! Build streaks for bonus points.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer
          Column(
            children: [
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _getTimePercentage(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getTimeColor(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${timeLeft}s',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getTimeColor(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Problem
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d2d),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${currentProblem!.question} = ?',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 40),

          // Options
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: currentProblem!.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = selectedAnswer == option;
              final isCorrect = option == currentProblem!.answer;
              
              Color buttonColor = const Color(0xFF333333);
              if (showResult && isSelected) {
                buttonColor = isCorrect ? const Color(0xFF26de81) : const Color(0xFFff6b6b);
              } else if (showResult && isCorrect) {
                buttonColor = const Color(0xFF26de81);
              }

              return GestureDetector(
                onTap: showResult ? null : () => _handleAnswer(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  constraints: const BoxConstraints(minWidth: 70),
                  child: Text(
                    option.toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.75),
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
            Text(
              'Final Score: $score',
              style: const TextStyle(
                fontSize: 18,
                color: Color(0xFF45b7d1),
              ),
            ),
            const SizedBox(height: 32),
            if (gameOver && widget.casualMode)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _resetGame,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Play Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF45b7d1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Exit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF333333),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            if (!gameOver)
              ElevatedButton(
                onPressed: _togglePause,
                child: Text(isPaused ? 'Resume' : 'Pause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF45b7d1),
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
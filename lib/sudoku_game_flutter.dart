import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

// Model for wrong number animation
class WrongMark {
  final int id;
  final int row;
  final int col;
  final int value;
  final AnimationController controller;
  late final Animation<double> opacity;

  WrongMark({
    required this.id,
    required this.row,
    required this.col,
    required this.value,
    required this.controller,
  }) {
    opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOut),
    );
  }
}

// Model for coordinate pair
class Coord {
  final int row;
  final int col;

  Coord(this.row, this.col);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coord && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class SudokuGame extends StatefulWidget {
  final Function(int) onScoreChange;
  final bool gameCompleted;
  final bool casualMode;
  final VoidCallback? onUserInteraction;
  final int? remainingTime;
  final int? inactivityTime;

  const SudokuGame({
    super.key,
    required this.onScoreChange,
    required this.gameCompleted,
    this.casualMode = false,
    this.onUserInteraction,
    this.remainingTime,
    this.inactivityTime,
  });

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> with TickerProviderStateMixin {
  // Game constants
  static const int boardSize = 9;
  static const double cellSize = 35.0;
  static const double gameWidth = boardSize * cellSize;
  static const double gameHeight = boardSize * cellSize;

  // Game state
  List<List<int>> board = [];
  List<List<int>> solution = [];
  List<List<bool>> original = [];
  Coord? selected;
  int score = 0;
  bool isPaused = false;
  bool gameOver = false;
  List<WrongMark> wrongMarks = [];

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  List<T> _shuffle<T>(List<T> list) {
    final shuffled = List<T>.from(list);
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    return shuffled;
  }

  List<List<int>> _copyBoard(List<List<int>> board) {
    return board.map((row) => List<int>.from(row)).toList();
  }

  Map<String, List<List<int>>> _generateSudoku({int emptyCells = 40}) {
    final board = List.generate(9, (_) => List.filled(9, 0));

    bool _isValid(int row, int col, int num) {
      // Check row and column
      for (int i = 0; i < 9; i++) {
        if (board[row][i] == num || board[i][col] == num) return false;
      }

      // Check 3x3 box
      final boxRow = (row ~/ 3) * 3;
      final boxCol = (col ~/ 3) * 3;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          if (board[boxRow + i][boxCol + j] == num) return false;
        }
      }
      return true;
    }

    bool _fill(int pos) {
      if (pos == 81) return true;
      
      final row = pos ~/ 9;
      final col = pos % 9;
      final nums = _shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9]);
      
      for (final num in nums) {
        if (_isValid(row, col, num)) {
          board[row][col] = num;
          if (_fill(pos + 1)) return true;
          board[row][col] = 0;
        }
      }
      return false;
    }

    _fill(0);
    final solutionBoard = _copyBoard(board);
    final puzzle = _copyBoard(board);
    
    int removed = 0;
    while (removed < emptyCells) {
      final i = _random.nextInt(9);
      final j = _random.nextInt(9);
      if (puzzle[i][j] != 0) {
        puzzle[i][j] = 0;
        removed++;
      }
    }

    return {
      'puzzle': puzzle,
      'solution': solutionBoard,
    };
  }

  void _resetGame() {
    // Clear existing wrong marks
    for (final mark in wrongMarks) {
      mark.controller.dispose();
    }
    wrongMarks.clear();

    final generated = _generateSudoku();
    setState(() {
      board = generated['puzzle']!;
      solution = generated['solution']!;
      original = board.map((row) => row.map((cell) => cell != 0).toList()).toList();
      selected = null;
      score = 0;
      isPaused = false;
      gameOver = false;
    });
    widget.onScoreChange(0);
  }

  void _checkWin() {
    if (board.isEmpty || solution.isEmpty) return;
    
    bool isComplete = true;
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board[i][j] != solution[i][j]) {
          isComplete = false;
          break;
        }
      }
      if (!isComplete) break;
    }

    if (isComplete) {
      setState(() {
        isPaused = true;
        gameOver = true;
        score = 1;
      });
      widget.onScoreChange(1);
      
      if (!widget.gameCompleted) {
        _showWinDialog();
      }
    }
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: const Text('You have solved the sudoku!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _handleCellPress(int row, int col) {
    if (isPaused || gameOver || original[row][col]) return;
    
    // Notify parent about user interaction
    widget.onUserInteraction?.call();
    
    setState(() {
      selected = Coord(row, col);
    });
  }

  void _handleNumberPress(int num) {
    if (selected == null || isPaused || gameOver) return;
    if (original[selected!.row][selected!.col]) return;

    // Notify parent about user interaction
    widget.onUserInteraction?.call();

    if (solution[selected!.row][selected!.col] == num) {
      setState(() {
        board[selected!.row][selected!.col] = num;
      });
      _checkWin();
    } else {
      // Show wrong number animation
      final controller = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      
      final wrongMark = WrongMark(
        id: DateTime.now().millisecondsSinceEpoch,
        row: selected!.row,
        col: selected!.col,
        value: num,
        controller: controller,
      );

      setState(() {
        wrongMarks.add(wrongMark);
      });

      controller.forward().then((_) {
        setState(() {
          wrongMarks.removeWhere((mark) => mark.id == wrongMark.id);
        });
        controller.dispose();
      });
    }
  }

  void _handleErase() {
    if (selected == null || isPaused || gameOver) return;
    if (original[selected!.row][selected!.col]) return;
    
    setState(() {
      board[selected!.row][selected!.col] = 0;
    });
  }

  void _togglePause() {
    if (!gameOver) {
      setState(() {
        isPaused = !isPaused;
      });
    }
  }

  int get _filledCells {
    int count = 0;
    for (final row in board) {
      for (final cell in row) {
        if (cell != 0) count++;
      }
    }
    return count;
  }

  @override
  void dispose() {
    for (final mark in wrongMarks) {
      mark.controller.dispose();
    }
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
                        color: Color(0xFFa55eea),
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Filled: $_filledCells/81',
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
                  onPressed: gameOver ? null : _togglePause,
                ),
              ],
            ),
          ),

          // Game Area
          Expanded(
            child: Container(
              width: gameWidth,
              height: gameHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF0f0f0f),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  // Board
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF26de81), width: 2),
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFF222222),
                    ),
                    child: Column(
                      children: List.generate(9, (row) {
                        return Row(
                          children: List.generate(9, (col) {
                            final cell = board[row][col];
                            final isSelected = selected?.row == row && selected?.col == col;
                            final isOriginal = original[row][col];
                            final wrongMark = wrongMarks.where((mark) => mark.row == row && mark.col == col).firstOrNull;
                            
                            return GestureDetector(
                              onTap: () => _handleCellPress(row, col),
                              child: Container(
                                width: cellSize,
                                height: cellSize,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? const Color(0x4445b7d1)
                                      : isOriginal 
                                          ? const Color(0xFF333333)
                                          : const Color(0xFF1e1e1e),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: (row % 3 == 2 && row != 8) 
                                          ? const Color(0xFF26de81)
                                          : const Color(0xFF444444),
                                      width: (row % 3 == 2 && row != 8) ? 3 : 1,
                                    ),
                                    right: BorderSide(
                                      color: (col % 3 == 2 && col != 8) 
                                          ? const Color(0xFF26de81)
                                          : const Color(0xFF444444),
                                      width: (col % 3 == 2 && col != 8) ? 3 : 1,
                                    ),
                                    top: const BorderSide(color: Color(0xFF444444), width: 1),
                                    left: const BorderSide(color: Color(0xFF444444), width: 1),
                                  ),
                                ),
                                child: Center(
                                  child: wrongMark != null
                                      ? AnimatedBuilder(
                                          animation: wrongMark.opacity,
                                          builder: (context, child) {
                                            return Opacity(
                                              opacity: wrongMark.opacity.value,
                                              child: Text(
                                                wrongMark.value.toString(),
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  color: Color(0xFFff4d4d),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : Text(
                                          cell == 0 ? '' : cell.toString(),
                                          style: TextStyle(
                                            fontSize: 20,
                                            color: isOriginal 
                                                ? const Color(0xFF4ecdc4)
                                                : Colors.white,
                                            fontWeight: isOriginal 
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                ),
                              ),
                            );
                          }),
                        );
                      }),
                    ),
                  ),

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
                            Text(
                              'Filled: $_filledCells/81',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Color(0xFFa55eea),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (gameOver && widget.casualMode)
                              ElevatedButton.icon(
                                onPressed: _resetGame,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFa55eea),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('New Sudoku'),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Number pad
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Numbers 1-9
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(9, (index) {
                    final num = index + 1;
                    return _buildNumberButton(num.toString(), () => _handleNumberPress(num));
                  }),
                ),
                const SizedBox(height: 12),
                // Erase button
                _buildNumberButton('⌫', _handleErase),
              ],
            ),
          ),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16.0),
            child: const Text(
              'Fill all cells so every row, column and box contains 1-9 exactly once!',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberButton(String text, VoidCallback onPressed) {
    final isDisabled = isPaused || gameOver || (widget.gameCompleted && !widget.casualMode);
    
    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDisabled ? const Color(0xFF333333) : const Color(0xFF4ecdc4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDisabled ? const Color(0xFF666666) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

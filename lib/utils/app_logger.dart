import 'package:flutter/foundation.dart';

/// Lightweight in-app logger with a listenable buffer for UI overlays.
class AppLogger {
  AppLogger._internal();
  static final AppLogger instance = AppLogger._internal();

  // Keep a rolling buffer of the most recent lines.
  final ValueNotifier<List<String>> _buffer = ValueNotifier<List<String>>(<String>[]);

  /// Listenable log buffer for widgets (e.g., ValueListenableBuilder).
  ValueListenable<List<String>> get listenable => _buffer;

  /// Append a line to the log buffer (with a short timestamp).
  void log(String message) {
    final now = DateTime.now();
    final ts = _two(now.hour) + ':' + _two(now.minute) + ':' + _two(now.second);
    final lines = List<String>.from(_buffer.value);
    lines.add('[$ts] $message');
    // Cap buffer size to avoid unbounded growth
    const maxLines = 300;
    if (lines.length > maxLines) {
      lines.removeRange(0, lines.length - maxLines);
    }
    _buffer.value = lines;
  }

  /// Clear the log buffer.
  void clear() {
    _buffer.value = <String>[];
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}


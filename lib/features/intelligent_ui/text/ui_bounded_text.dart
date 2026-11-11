import 'dart:convert';

/// Whole semantic fields are selected under a UTF-8 budget. Oversized fields
/// are skipped, never sliced into misleading values or invalid JSON.
final class UiBoundedText {
  UiBoundedText(this.budget, {required this.omission}) {
    if (budget < utf8.encode(omission).length) {
      throw const FormatException('Insufficient projection budget');
    }
  }
  final int budget;
  final String omission;
  final _lines = <String>[];
  int _bytes = 0;
  bool _omitted = false;
  bool get omitted => _omitted;
  bool add(String line) {
    if (line.isEmpty) return true;
    if (line.length > budget - _bytes) {
      _omitted = true;
      return false;
    }
    final size = utf8.encode(line).length + (_lines.isEmpty ? 0 : 1);
    // Reserve the omission marker from the start, including its separator.
    if (_bytes + size + utf8.encode(omission).length + 1 > budget) {
      _omitted = true;
      return false;
    }
    _lines.add(line);
    _bytes += size;
    return true;
  }

  void noteOmission() => _omitted = true;
  String finish() => [..._lines, if (_omitted) omission].join('\n');
}

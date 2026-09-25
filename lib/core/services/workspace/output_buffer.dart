import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../utils/utf16_safe_cut.dart';

/// Accumulates a stream while retaining at most [maxBytes] (head + tail).
class BoundedStreamBuffer {
  BoundedStreamBuffer({this.maxBytes = 128 * 1024}) : _half = maxBytes ~/ 2;

  final int maxBytes;
  final int _half;
  final BytesBuilder _head = BytesBuilder(copy: true);
  Uint8List? _tail;
  int _tailNext = 0;
  bool _truncated = false;
  int _totalBytes = 0;
  String? _cachedText;
  String? _headText;

  int get totalBytes => _totalBytes;

  bool get truncated => _truncated;

  void add(List<int> bytes) {
    if (bytes.isEmpty) return;
    _totalBytes += bytes.length;
    _cachedText = null;
    if (!_truncated) {
      if (_head.length + bytes.length <= maxBytes) {
        _head.add(bytes);
        return;
      }
      final previous = _head.takeBytes();
      final headLength = previous.length < _half ? previous.length : _half;
      _head.add(Uint8List.sublistView(previous, 0, headLength));
      if (headLength < _half) {
        _head.add(bytes.sublist(0, _half - headLength));
      }
      _tail = Uint8List(_half);
      _truncated = true;
      _appendTail(previous);
      _appendTail(bytes);
      return;
    }
    _appendTail(bytes);
  }

  void _appendTail(List<int> bytes) {
    if (_half == 0 || bytes.isEmpty) return;
    final tail = _tail!;
    if (bytes.length >= _half) {
      tail.setRange(0, _half, bytes, bytes.length - _half);
      _tailNext = 0;
      return;
    }
    final first = bytes.length < _half - _tailNext
        ? bytes.length
        : _half - _tailNext;
    tail.setRange(_tailNext, _tailNext + first, bytes);
    if (first < bytes.length) {
      tail.setRange(0, bytes.length - first, bytes, first);
    }
    _tailNext = (_tailNext + bytes.length) % _half;
  }

  Uint8List _tailBytes() {
    final tail = _tail!;
    if (_tailNext == 0) return tail;
    return Uint8List(_half)
      ..setRange(0, _half - _tailNext, tail, _tailNext)
      ..setRange(_half - _tailNext, _half, tail);
  }

  /// Retained bytes (head, or head + tail when truncated). At most [maxBytes].
  Uint8List get bytes {
    if (!_truncated) return Uint8List.fromList(_head.toBytes());
    final head = _head.toBytes();
    final out = Uint8List(head.length + _half);
    out.setAll(0, head);
    out.setAll(head.length, _tailBytes());
    return out;
  }

  /// UTF-8 decode of [bytes] that never starts/ends mid-sequence.
  String get text => _cachedText ??= _decodeText();

  String _decodeText() {
    if (!_truncated) {
      return _decodeUtf8(
        _head.toBytes(),
        dropLeading: false,
        dropTrailing: false,
      );
    }
    final head = _headText ??= _decodeUtf8(
      _head.toBytes(),
      dropLeading: false,
      dropTrailing: true,
    );
    final tail = _decodeUtf8(
      _tailBytes(),
      dropLeading: true,
      dropTrailing: false,
    );
    return '$head$tail';
  }
}

/// Cuts [s] to at most [maxChars] UTF-16 code units without splitting a
/// surrogate pair. [keepTail] keeps the end instead of the start.
String utf16SafeCut(String s, int maxChars, {bool keepTail = false}) {
  if (maxChars <= 0) return '';
  if (s.length <= maxChars) return s;
  if (keepTail) {
    return s.substring(utf16SafeTailStart(s, s.length - maxChars));
  }
  return truncateHeadUtf16Safe(s, maxChars);
}

class CapturedOutput {
  const CapturedOutput({
    required this.stdout,
    required this.stderr,
    required this.stdoutTruncated,
    required this.stderrTruncated,
  });

  final String stdout;
  final String stderr;
  final bool stdoutTruncated;
  final bool stderrTruncated;
}

class ToolOutputOffload {
  const ToolOutputOffload({required this.modelText, this.offloadHostPath});

  /// JSON object for the model, plus a hint line when output was offloaded.
  final String modelText;
  final String? offloadHostPath;
}

class ToolOutputOffloader {
  /// When stdout+stderr exceed [inlineLimit] UTF-8 bytes, write the full
  /// output to `outputs/<toolCallId>.txt` and give the model a head+tail
  /// preview plus a `read_file`/`grep` hint.
  static Future<ToolOutputOffload> maybeOffload({
    required String toolCallId,
    required String stdout,
    required String stderr,
    required Directory outputsDir,
    int inlineLimit = 32 * 1024,
    int previewChars = 4 * 1024,
  }) async {
    final totalBytes = utf8.encode(stdout).length + utf8.encode(stderr).length;
    if (totalBytes <= inlineLimit) {
      return ToolOutputOffload(
        modelText: jsonEncode(<String, Object?>{
          'stdout': stdout,
          'stderr': stderr,
        }),
      );
    }

    await outputsDir.create(recursive: true);
    final file = File(p.join(outputsDir.path, '$toolCallId.txt'));
    final full = StringBuffer()
      ..writeln('=== stdout ===')
      ..write(stdout);
    if (stdout.isNotEmpty && !stdout.endsWith('\n')) {
      full.writeln();
    }
    full
      ..writeln('=== stderr ===')
      ..write(stderr);
    await file.writeAsString(full.toString());

    final modelPath = 'outputs/$toolCallId.txt';
    final json = jsonEncode(<String, Object?>{
      'stdout': _preview(stdout, previewChars),
      'stderr': _preview(stderr, previewChars),
      'truncated': true,
      'output_file': modelPath,
    });
    return ToolOutputOffload(
      modelText:
          '$json\nFull output written to $modelPath; use read_file or grep '
          'to inspect it.',
      offloadHostPath: file.path,
    );
  }

  static String _preview(String value, int maxChars) {
    if (value.length <= maxChars) return value;
    return truncateHeadTailUtf16Safe(
      value,
      maxChars,
      marker: '\n...[truncated]...\n',
    );
  }
}

String _decodeUtf8(
  List<int> raw, {
  required bool dropLeading,
  required bool dropTrailing,
}) {
  var start = 0;
  var end = raw.length;
  if (dropLeading) {
    while (start < end && (raw[start] & 0xC0) == 0x80) {
      start++;
    }
  }
  if (dropTrailing) {
    end = _utf8CompleteEnd(raw, start, end);
  }
  if (start >= end) return '';
  return utf8.decode(raw.sublist(start, end), allowMalformed: true);
}

int _utf8CompleteEnd(List<int> bytes, int start, int end) {
  if (end <= start) return end;
  var i = end - 1;
  if (bytes[i] < 0x80) return end;
  var continuations = 0;
  while (i >= start && (bytes[i] & 0xC0) == 0x80) {
    continuations++;
    i--;
  }
  if (i < start) return start;
  final expected = _utf8ExpectedContinuations(bytes[i]);
  if (expected < 0 || continuations != expected) return i;
  return end;
}

int _utf8ExpectedContinuations(int lead) {
  if (lead < 0x80) return 0;
  if (lead >= 0xC2 && lead <= 0xDF) return 1;
  if (lead >= 0xE0 && lead <= 0xEF) return 2;
  if (lead >= 0xF0 && lead <= 0xF4) return 3;
  return -1;
}

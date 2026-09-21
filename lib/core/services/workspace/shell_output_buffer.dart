import 'dart:convert';

import 'output_buffer.dart';

enum _EscapeState { none, escape, intermediate, csi, string, stringEscape }

/// Bounded plain-text output for shell tools, not an interactive terminal.
/// CR starts a replacement progress frame; the previous frame remains visible
/// until printable text arrives. UTF-8 and escape parsing survive chunk splits.
class ShellOutputBuffer {
  ShellOutputBuffer({this.maxBytes = 128 * 1024, this.onLine})
    : _completed = BoundedStreamBuffer(maxBytes: maxBytes),
      _line = BoundedStreamBuffer(maxBytes: maxBytes);

  final int maxBytes;
  final void Function(String line)? onLine;
  final BoundedStreamBuffer _completed;
  BoundedStreamBuffer _line;
  late final ByteConversionSink _decoder = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(_TextSink(_consume));
  _EscapeState _escape = _EscapeState.none;
  bool _replaceLine = false;
  bool _completedLineTruncated = false;
  bool _closed = false;
  bool _emittedText = false;

  String get currentLine => _line.text;

  bool get truncated =>
      _completedLineTruncated ||
      _completed.totalBytes + _line.totalBytes > maxBytes;

  String get text {
    if (_line.totalBytes == 0) return _completed.text;
    if (_completed.totalBytes == 0) return currentLine;
    // Each window is decoded before joining so a truncated UTF-8 boundary
    // cannot become a replacement character at the head/tail seam.
    final combined = BoundedStreamBuffer(maxBytes: maxBytes)
      ..add(utf8.encode(_completed.text))
      ..add(utf8.encode(currentLine));
    return combined.text;
  }

  /// Whether this chunk emitted printable text. Completed lines are delivered
  /// through [onLine]; control sequences and incomplete UTF-8 emit no text.
  bool add(List<int> bytes) {
    if (_closed) throw StateError('Shell output is already closed');
    _emittedText = false;
    _decoder.add(bytes);
    return _emittedText;
  }

  /// Whether finalizing UTF-8 emitted printable text.
  bool close() {
    if (_closed) return false;
    _emittedText = false;
    _decoder.close();
    _closed = true;
    return _emittedText;
  }

  /// The same rules for persisted shell previews, without shortening the input.
  static String normalize(String text) {
    final bytes = utf8.encode(text);
    final output = ShellOutputBuffer(maxBytes: bytes.length + 4)
      ..add(bytes)
      ..close();
    return output.text;
  }

  void _consume(String text) {
    var index = 0;
    while (index < text.length) {
      final code = text.codeUnitAt(index);
      if (_escape == _EscapeState.none && _isText(code)) {
        final start = index++;
        while (index < text.length && _isText(text.codeUnitAt(index))) {
          index++;
        }
        if (_replaceLine) {
          _line = BoundedStreamBuffer(maxBytes: maxBytes);
          _replaceLine = false;
        }
        _line.add(utf8.encode(text.substring(start, index)));
        _emittedText = true;
        continue;
      }
      index++;
      if (_escape == _EscapeState.string ||
          _escape == _EscapeState.stringEscape) {
        if (code == 0x07 ||
            code == 0x9c ||
            (_escape == _EscapeState.stringEscape && code == 0x5c)) {
          _escape = _EscapeState.none;
        } else {
          _escape = code == 0x1b
              ? _EscapeState.stringEscape
              : _EscapeState.string;
        }
        continue;
      }
      switch (code) {
        case 0x1b:
          _escape = _EscapeState.escape;
        case 0x9b:
          _escape = _EscapeState.csi;
        case 0x90 || 0x98 || 0x9d || 0x9e || 0x9f:
          _escape = _EscapeState.string;
        case 0x0d:
          _replaceLine = true;
          _escape = _EscapeState.none;
        case 0x0a:
          final line = currentLine;
          _completedLineTruncated |= _line.truncated;
          _completed.add(utf8.encode('$line\n'));
          onLine?.call(line);
          _line = BoundedStreamBuffer(maxBytes: maxBytes);
          _replaceLine = false;
          _escape = _EscapeState.none;
        default:
          switch (_escape) {
            case _EscapeState.escape:
              _escape = switch (code) {
                0x5b => _EscapeState.csi,
                0x5d || 0x50 || 0x58 || 0x5e || 0x5f => _EscapeState.string,
                >= 0x20 && <= 0x2f => _EscapeState.intermediate,
                _ => _EscapeState.none,
              };
            case _EscapeState.csi:
              if (code >= 0x40 && code <= 0x7e) {
                _escape = _EscapeState.none;
              }
            case _EscapeState.intermediate:
              if (code >= 0x30 && code <= 0x7e) {
                _escape = _EscapeState.none;
              }
            case _EscapeState.none ||
                _EscapeState.string ||
                _EscapeState.stringEscape:
              break;
          }
      }
    }
  }

  static bool _isText(int code) =>
      code == 0x09 || (code >= 0x20 && (code < 0x7f || code > 0x9f));
}

class _TextSink implements Sink<String> {
  _TextSink(this.onText);

  final void Function(String text) onText;

  @override
  void add(String data) => onText(data);

  @override
  void close() {}
}

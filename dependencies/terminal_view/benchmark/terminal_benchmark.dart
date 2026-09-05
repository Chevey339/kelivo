// Throughput benchmarks for the terminal core. Run with:
//
//   dart run benchmark/terminal_benchmark.dart
//
// The core has no Flutter dependency, so this runs on the plain Dart VM.
// Painting is not covered here; it needs a Flutter binding.

import 'dart:math';

import 'package:terminal_view/core.dart';

const _viewWidth = 80;
const _viewHeight = 24;
const _maxLines = 10000;

void main() {
  final results = <_Result>[
    _run('plain ascii', _plainAscii()),
    _run('sgr colors', _sgrColors()),
    _run('cursor moves', _cursorMoves()),
    _run('alt screen repaint', _altScreenFrames()),
    _run('wide chars', _wideChars()),
    _run('scrollback churn', _scrollbackChurn(), maxLines: 200),
    _runGetText(),
  ];

  final nameWidth = results.map((r) => r.name.length).reduce(max);
  print('');
  print('${'benchmark'.padRight(nameWidth)}   median      throughput');
  print('-' * (nameWidth + 26));
  for (final result in results) {
    print(
      '${result.name.padRight(nameWidth)}   '
      '${result.medianMs.toStringAsFixed(2).padLeft(7)} ms  '
      '${result.throughput.padLeft(12)}',
    );
  }
  print('');
}

/// Feeds [payload] to a fresh terminal and reports how long a full pass takes.
_Result _run(String name, String payload, {int maxLines = _maxLines}) {
  final samples = _measure(() {
    final terminal = Terminal(maxLines: maxLines);
    terminal.resize(_viewWidth, _viewHeight);
    terminal.write(payload);
  });

  final median = _median(samples);
  final mbPerSecond = payload.length / 1024 / 1024 / (median / 1000);
  return _Result(name, median, '${mbPerSecond.toStringAsFixed(1)} MB/s');
}

/// Copying a full scrollback, which is what a select-all plus copy costs.
_Result _runGetText() {
  final terminal = Terminal(maxLines: _maxLines);
  terminal.resize(_viewWidth, _viewHeight);
  terminal.write(_plainAscii());

  var length = 0;
  final samples = _measure(() => length = terminal.buffer.getText().length);

  final median = _median(samples);
  final mbPerSecond = length / 1024 / 1024 / (median / 1000);
  return _Result(
      'buffer getText', median, '${mbPerSecond.toStringAsFixed(1)} MB/s');
}

List<double> _measure(void Function() body, {int warmup = 3, int runs = 10}) {
  for (var i = 0; i < warmup; i++) {
    body();
  }

  final samples = <double>[];
  for (var i = 0; i < runs; i++) {
    final stopwatch = Stopwatch()..start();
    body();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 1000);
  }
  return samples;
}

double _median(List<double> samples) {
  final sorted = [...samples]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// 4 MiB of `ls -l`-shaped output.
String _plainAscii() {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < 4 * 1024 * 1024) {
    buffer.write(
      '-rw-r--r--  1 user  staff   ${(i * 7919) % 100000} '
      'Jan ${i % 28 + 1} 12:00 file_${i}_name.txt\r\n',
    );
    i++;
  }
  return buffer.toString();
}

/// The same output with a color change every few cells, as a build log or a
/// syntax-highlighting pager produces.
String _sgrColors() {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < 4 * 1024 * 1024) {
    buffer.write(
      '\x1b[32m✓\x1b[0m \x1b[1;34mmodule_$i\x1b[0m '
      '\x1b[38;5;${i % 256}mcompiled\x1b[0m in \x1b[33m${i % 900}ms\x1b[0m\r\n',
    );
    i++;
  }
  return buffer.toString();
}

/// Absolute cursor positioning plus erases, the shape a TUI redraw takes.
String _cursorMoves() {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < 2 * 1024 * 1024) {
    final row = i % _viewHeight + 1;
    buffer.write('\x1b[$row;1H\x1b[2Krow $row of frame $i');
    i++;
  }
  return buffer.toString();
}

/// Full-screen frames on the alternate buffer, as htop or vim would draw.
String _altScreenFrames() {
  final buffer = StringBuffer('\x1b[?1049h');
  var frame = 0;
  while (buffer.length < 2 * 1024 * 1024) {
    buffer.write('\x1b[H');
    for (var row = 0; row < _viewHeight; row++) {
      buffer.write('\x1b[K');
      for (var column = 0; column < _viewWidth ~/ 8; column++) {
        buffer.write('\x1b[4${(row + column + frame) % 8}m   \x1b[0m');
      }
      buffer.write('\r\n');
    }
    frame++;
  }
  buffer.write('\x1b[?1049l');
  return buffer.toString();
}

/// CJK and emoji, which take two cells and cannot share a batched glyph run.
String _wideChars() {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < 1024 * 1024) {
    buffer.write('日本語テキスト $i 🚀🔥✨ mixed with ascii\r\n');
    i++;
  }
  return buffer.toString();
}

/// A short scrollback, so almost every line written evicts an older one.
String _scrollbackChurn() {
  final buffer = StringBuffer();
  var i = 0;
  while (buffer.length < 2 * 1024 * 1024) {
    buffer.write('line $i: the quick brown fox jumps over the lazy dog\r\n');
    i++;
  }
  return buffer.toString();
}

class _Result {
  _Result(this.name, this.medianMs, this.throughput);

  final String name;
  final double medianMs;
  final String throughput;
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/shell_output_buffer.dart';

void main() {
  const cases = <String, String>{
    '': '',
    '10%\r50%\r100%': '100%',
    'AAAA\rBB': 'BB',
    'done\r\r': 'done',
    '\rhello\r\nnext\r\n': 'hello\nnext\n',
    '  null\nnullnull\n\n\n\tindented  \n':
        '  null\nnullnull\n\n\n\tindented  \n',
    '10%\r\x1b[32m100%\x1b[0m\r\x1b[0m': '100%',
    '\x1b[?25l\x1b[2K\r完成 😀\x1b[?25h': '完成 😀',
    '\x1b]0;window title\x07hello\x1b]8;;https://example.com\x1b\\link'
            '\x1b]8;;\x1b\\':
        'hellolink',
    '\x1bPignored\x1b\\\x1b(0text\x1b(B\x1b7\x1b8': 'text',
    '\x9b31mred\x9b0m\x9dtitle\x9c': 'red',
    'a\x00\x07\x7fb\x1b[31': 'ab',
  };

  for (final entry in cases.entries) {
    test('normalizes ${jsonEncode(entry.key)} across every byte split', () {
      final bytes = utf8.encode(entry.key);
      expect(ShellOutputBuffer.normalize(entry.key), entry.value);
      expect(ShellOutputBuffer.normalize(entry.value), entry.value);
      for (var split = 0; split <= bytes.length; split++) {
        final buffer = ShellOutputBuffer()
          ..add(bytes.sublist(0, split))
          ..add(bytes.sublist(split))
          ..close();
        expect(buffer.text, entry.value, reason: 'split at byte $split');
      }
      final bytewise = ShellOutputBuffer();
      for (final byte in bytes) {
        bytewise.add([byte]);
      }
      bytewise.close();
      expect(bytewise.text, entry.value);
    });
  }

  test('keeps the previous progress frame until replacement text arrives', () {
    final lines = <String>[];
    final buffer = ShellOutputBuffer(onLine: lines.add);
    buffer.add(utf8.encode('starting\n10%\r'));
    expect(lines, ['starting']);
    expect(buffer.text, 'starting\n10%');
    buffer.add(utf8.encode('\x1b[32'));
    expect(buffer.text, 'starting\n10%');
    buffer.add(utf8.encode('m100%\r'));
    expect(buffer.text, 'starting\n100%');
    buffer.add(utf8.encode('\n'));
    buffer.close();
    expect(buffer.text, 'starting\n100%\n');
    expect(lines, ['starting', '100%']);
  });

  test('does not display incomplete UTF-8 as replacement characters', () {
    final buffer = ShellOutputBuffer();
    final bytes = utf8.encode('😀');
    expect(buffer.add(bytes.sublist(0, 2)), isFalse);
    expect(buffer.text, isEmpty);
    expect(buffer.add(bytes.sublist(2)), isTrue);
    expect(buffer.text, '😀');
    expect(buffer.add([0xe4]), isFalse);
    expect(buffer.text, '😀');
    expect(buffer.close(), isTrue);
    expect(buffer.text, '😀\uFFFD');
    expect(buffer.close(), isFalse);
    expect(buffer.text, '😀\uFFFD');
  });

  test(
    'reports visible text even when a new progress frame looks identical',
    () {
      final buffer = ShellOutputBuffer();
      expect(buffer.add(utf8.encode('10%')), isTrue);
      expect(buffer.add([]), isFalse);
      expect(buffer.add(utf8.encode('\r\x1b[')), isFalse);
      expect(buffer.add(utf8.encode('32m')), isFalse);
      expect(buffer.add(utf8.encode('10%\x1b[0m')), isTrue);
      expect(buffer.text, '10%');
      expect(buffer.close(), isFalse);
    },
  );

  test('discarded progress does not consume the output budget', () {
    final buffer = ShellOutputBuffer(maxBytes: 64);
    buffer.add(utf8.encode('header\n${'A' * 256}'));
    expect(buffer.truncated, isTrue);
    expect(utf8.encode(buffer.text).length, lessThanOrEqualTo(64));
    buffer.add(utf8.encode('\rfinal\n'));
    expect(buffer.text, 'header\nfinal\n');
    expect(buffer.truncated, isFalse);
    for (var i = 0; i < 10000; i++) {
      buffer.add(utf8.encode('\rprogress $i'));
    }
    buffer.close();
    expect(buffer.text, 'header\nfinal\nprogress 9999');
    expect(buffer.truncated, isFalse);
  });

  test('completed output and unterminated lines remain bounded UTF-8', () {
    final buffer = ShellOutputBuffer(maxBytes: 65);
    buffer.add(utf8.encode('head\n${'中文😀' * 100}\n'));
    expect(buffer.truncated, isTrue);
    buffer.add(utf8.encode('${'内容😀' * 100}tail'));
    buffer.close();
    final text = buffer.text;
    expect(utf8.encode(text).length, lessThanOrEqualTo(65));
    expect(text, startsWith('head\n'));
    expect(text, endsWith('tail'));
    expect(text, isNot(contains('\uFFFD')));
    expect(() => jsonEncode(text), returnsNormally);
  });
}

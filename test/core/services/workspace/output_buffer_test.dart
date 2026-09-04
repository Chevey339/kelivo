import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/workspace/output_buffer.dart';

void main() {
  group('BoundedStreamBuffer', () {
    test('keeps head and tail when the stream exceeds maxBytes', () {
      final buffer = BoundedStreamBuffer(maxBytes: 128);
      buffer.add(utf8.encode('H' * 80));
      buffer.add(utf8.encode('T' * 80));
      expect(buffer.truncated, isTrue);
      expect(buffer.totalBytes, 160);
      expect(buffer.bytes.length, 128);
      final text = buffer.text;
      expect(text.startsWith('H'), isTrue);
      expect(text.endsWith('T'), isTrue);
      expect(text.contains('H'), isTrue);
      expect(text.contains('T'), isTrue);
      expect(text.length, lessThanOrEqualTo(128));
    });

    test('never splits a UTF-8 / UTF-16 emoji at a cut', () {
      final emoji = utf8.encode('😀');
      expect(emoji.length, 4);
      final buffer = BoundedStreamBuffer(maxBytes: 8);
      // 6 ASCII + 4-byte emoji + 6 ASCII = 16 bytes → head 4 + tail 4.
      buffer.add(utf8.encode('AAAAAA'));
      buffer.add(emoji);
      buffer.add(utf8.encode('BBBBBB'));
      expect(buffer.truncated, isTrue);
      final text = buffer.text;
      expect(() => jsonEncode(text), returnsNormally);
      expect(text.contains(String.fromCharCode(0xD800)), isFalse);
      // Lone surrogates would throw on jsonEncode; also reject U+FFFD clusters
      // from a torn emoji at the head/tail seam.
      expect(text.contains('😀') || !text.contains('\uFFFD'), isTrue);
    });
  });

  group('utf16SafeCut', () {
    test('does not split a surrogate pair at the head or tail', () {
      const value = 'a😀b'; // units: a, high, low, b
      expect(utf16SafeCut(value, 2), 'a');
      expect(utf16SafeCut(value, 2, keepTail: true), 'b');
      expect(() => jsonEncode(utf16SafeCut(value, 2)), returnsNormally);
      expect(
        () => jsonEncode(utf16SafeCut(value, 2, keepTail: true)),
        returnsNormally,
      );
    });
  });

  group('ToolOutputOffloader', () {
    test('returns inline JSON under the 32 KB threshold', () async {
      final dir = await Directory.systemTemp.createTemp('kelivo_offload_');
      addTearDown(() => dir.delete(recursive: true));
      final result = await ToolOutputOffloader.maybeOffload(
        toolCallId: 't1',
        stdout: 'hello',
        stderr: '',
        outputsDir: dir,
      );
      expect(result.offloadHostPath, isNull);
      expect(jsonDecode(result.modelText), {'stdout': 'hello', 'stderr': ''});
    });

    test(
      'offloads over-threshold output with a 4 KB preview and hint',
      () async {
        final dir = await Directory.systemTemp.createTemp('kelivo_offload_');
        addTearDown(() => dir.delete(recursive: true));
        final stdout = 'S' * 40 * 1024;
        final stderr = 'E' * 1024;
        final result = await ToolOutputOffloader.maybeOffload(
          toolCallId: 'big1',
          stdout: stdout,
          stderr: stderr,
          outputsDir: dir,
          previewChars: 4 * 1024,
        );
        expect(result.offloadHostPath, isNotNull);
        expect(File(result.offloadHostPath!).existsSync(), isTrue);
        final stored = File(result.offloadHostPath!).readAsStringSync();
        expect(stored, contains(stdout));
        expect(stored, contains(stderr));

        final split = result.modelText.split('\n');
        final jsonLine = split.first;
        final body = jsonDecode(jsonLine) as Map<String, dynamic>;
        expect(body['truncated'], isTrue);
        expect(body['output_file'], 'outputs/big1.txt');
        expect((body['stdout'] as String).length, lessThanOrEqualTo(4 * 1024));
        expect((body['stdout'] as String).startsWith('S'), isTrue);
        expect((body['stdout'] as String).endsWith('S'), isTrue);
        expect(result.modelText, contains('read_file'));
        expect(result.modelText, contains('grep'));
        expect(result.modelText, contains('outputs/big1.txt'));
      },
    );
  });

  test('CapturedOutput holds both streams', () {
    const captured = CapturedOutput(
      stdout: 'out',
      stderr: 'err',
      stdoutTruncated: true,
      stderrTruncated: false,
    );
    expect(captured.stdout, 'out');
    expect(captured.stderrTruncated, isFalse);
  });
}

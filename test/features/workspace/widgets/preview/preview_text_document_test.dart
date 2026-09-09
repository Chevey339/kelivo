import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/features/workspace/widgets/preview/preview_text_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  var nextFile = 0;

  setUp(() => directory = Directory.systemTemp.createTempSync('preview_text_'));
  tearDown(() => directory.deleteSync(recursive: true));

  Future<PreviewTextDocument> openBytes(List<int> bytes) async {
    final file = File('${directory.path}/${nextFile++}.txt');
    await file.writeAsBytes(bytes);
    return loadPreviewTextDocument(file);
  }

  Future<void> verifyPages(List<int> bytes) async {
    final document = await openBytes(bytes);
    expect(document.usesPlainText, isTrue);
    expect(document.source, isNull);
    final reader = PreviewTextReader(document);
    try {
      final chunks = <String>[];
      for (var i = 0; i < document.chunkCount; i++) {
        chunks.add(await reader.readChunk(i));
      }
      expect(chunks.join(), utf8.decode(bytes, allowMalformed: true));
      for (final chunk in chunks) {
        expect(
          chunk.length,
          lessThanOrEqualTo(PreviewTextDocument.chunkBytes + 3),
        );
        expect(utf8.decode(utf8.encode('x$chunk')).substring(1), chunk);
      }
      for (var i = 1; i < chunks.length; i++) {
        expect(
          chunks[i - 1].endsWith('\r') && chunks[i].startsWith('\n'),
          isFalse,
        );
      }
    } finally {
      await reader.close();
    }
  }

  test(
    'small files retain rich rendering and normalized source lines',
    () async {
      for (final source in ['', '中文😀', 'one\r\ntwo\rthree\n']) {
        final document = await openBytes(utf8.encode(source));
        expect(document.usesPlainText, isFalse);
        expect(document.source, source);
        expect(document.lines, source.split(RegExp(r'\r\n|\r|\n')));
        expect(await document.readSource(), source);
      }
    },
  );

  test('size, line count and a long line select paged text', () async {
    for (final source in [
      '${'神' * 100}\n' * 500,
      '\n' * PreviewTextDocument.richMaxLines,
      'x' * (PreviewTextDocument.chunkBytes + 1),
    ]) {
      await verifyPages(utf8.encode(source));
    }
  });

  test('random-access boundaries preserve UTF-8, BOMs and CRLF', () async {
    for (final suffix in ['é', '神', '😀', '\r\n', '\ufeff']) {
      for (var prefixLength = 2045; prefixLength <= 2049; prefixLength++) {
        await verifyPages(
          utf8.encode('${'x' * prefixLength}$suffix${'y' * 2200}\nEND\r\n'),
        );
      }
    }
    await verifyPages(
      utf8.encode('\ufeff${'first\r\n中文😀\rthird\n\n' * 10000}'),
    );
  });

  test(
    'malformed and incomplete UTF-8 stays consistent across pages',
    () async {
      for (final tail in [
        [0xe2, 0x82],
        [0xf0, 0x90, 0x80],
        [0xe0, 0x80, 0x80, 65],
        [0xf4, 0x90, 0x80, 0x80],
        [0xff, 0x80, 0x80],
      ]) {
        for (var prefixLength = 4093; prefixLength <= 4097; prefixLength++) {
          await verifyPages([...List.filled(prefixLength, 65), ...tail]);
        }
      }
    },
  );

  test('a 1 GiB file opens without materializing source or an index', () async {
    final file = File('${directory.path}/huge.log');
    final writer = await file.open(mode: FileMode.write);
    const length = 1024 * 1024 * 1024;
    await writer.writeString('BEGIN');
    await writer.setPosition(length - 3);
    await writer.writeString('END');
    await writer.close();
    final document = await loadPreviewTextDocument(file);
    expect(document.byteLength, length);
    expect(document.source, isNull);
    expect(document.lines, isEmpty);
    expect(document.firstChunk!.length, lessThanOrEqualTo(2051));
    final reader = PreviewTextReader(document);
    try {
      expect(
        (await reader.readChunk(document.chunkCount - 1)).endsWith('END'),
        isTrue,
      );
      expect(reader.bytesRead, lessThanOrEqualTo(2056));
      expect(
        reader.cachedBytes,
        lessThanOrEqualTo(PreviewTextReader.maxCacheBytes),
      );
    } finally {
      await reader.close();
    }
  });

  test(
    'concurrent seeks are correct and scrolling keeps a bounded cache',
    () async {
      final block = Uint8List(PreviewTextDocument.chunkBytes)
        ..fillRange(0, PreviewTextDocument.chunkBytes, 65);
      final file = File('${directory.path}/pages.txt');
      final writer = await file.open(mode: FileMode.write);
      for (var i = 0; i < 160; i++) {
        block.setRange(0, 5, ascii.encode(i.toString().padLeft(5, '0')));
        await writer.writeFrom(block);
      }
      await writer.close();
      final reader = PreviewTextReader(await loadPreviewTextDocument(file));
      try {
        final indexes = [100, 4, 159, 1, 80];
        final pages = await Future.wait(indexes.map(reader.readChunk));
        for (var i = 0; i < indexes.length; i++) {
          expect(
            pages[i].startsWith(indexes[i].toString().padLeft(5, '0')),
            isTrue,
          );
        }
        for (var i = 0; i < 160; i++) {
          await reader.readChunk(i);
          expect(
            reader.cachedBytes,
            lessThanOrEqualTo(PreviewTextReader.maxCacheBytes),
          );
        }
        final before = reader.bytesRead;
        await reader.readChunk(159);
        expect(reader.bytesRead, before);
        expect(reader.cachedChunk(0), isNull);
      } finally {
        await reader.close();
      }
      expect(reader.cachedBytes, 0);
      await expectLater(reader.readChunk(0), throwsStateError);
      await reader.close();
    },
  );

  test('cancelled queued requests do no disk I/O', () async {
    final reader = PreviewTextReader(await openBytes(utf8.encode('x' * 20000)));
    var cancelled = false;
    final request = reader.readChunk(2, isCancelled: () => cancelled);
    cancelled = true;
    expect(await request, isEmpty);
    expect(reader.bytesRead, 0);
    await reader.close();
  });

  test('a failed page does not poison later reads', () async {
    final document = await openBytes(utf8.encode('x' * 20000));
    final file = File(document.path);
    await file.delete();
    final reader = PreviewTextReader(document);
    try {
      await expectLater(
        reader.readChunk(1),
        throwsA(isA<FileSystemException>()),
      );
      await file.writeAsString('x' * 20000);
      expect(await reader.readChunk(1), 'x' * 2048);
    } finally {
      await reader.close();
    }
  });
}

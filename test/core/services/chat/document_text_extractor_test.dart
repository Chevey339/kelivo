import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/services/chat/document_text_extractor.dart';
import 'package:Kelivo/core/services/chat/text_file_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('kelivo_extract_'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  DocumentText decode(List<int> bytes, {bool cut = false}) => decodeTextFile(
    Uint8List.fromList(bytes),
    name: 'notes.txt',
    byteLimit: cut,
  );
  Matcher failure(AttachmentProblem reason) =>
      isA<AttachmentReadError>().having((e) => e.problem, 'reason', reason);

  test('fixed byte samples select UTF, GB2312/GB18030 and CP950', () {
    for (final (bytes, expected) in <(List<int>, String)>[
      ([], ''), ([32, 10, 9], ' \n\t'),
      (utf8.encode('中文'), '中文'),
      ([0xef, 0xbb, 0xbf, ...utf8.encode('中文')], '中文'),
      ([0xff, 0xfe, 0x2d, 0x4e, 0x87, 0x65], '中文'),
      ([0xfe, 0xff, 0x4e, 0x2d, 0x65, 0x87, 0xff], '中文'),
      ([0xff, 0xfe, 0x41, 0, 0x2d, 0x4e, 0x87, 0x65], 'A中文'),
      ([0xd6, 0xd0, 0xce, 0xc4], '中文'),
      (
        [0xd6, 0xd0, 0x95, 0x32, 0x82, 0x36],
        '中𠀀',
      ), // U+20000 uses four GB18030 bytes.
      ([0xa4, 0xb5, 0xa4, 0xd1, 0xb4, 0xb8, 0xa4, 0xd1], '今天晴天'),
      ([0xb4, 0xfa, 0xb8, 0xd5], '測試'),
      (
        [
          0xb5,
          0x7b,
          0xa6,
          0xa1,
          0xb3,
          0x5d,
          0xad,
          0x70,
          0xa,
          0xb3,
          0x73,
          0xbd,
          0x75,
          0xa5,
          0xa2,
          0xb1,
          0xd1,
          0xa,
          0xbb,
          0x4f,
          0xc6,
          0x57,
          0xb7,
          0x73,
          0xbb,
          0x44,
          0xa,
          0xb4,
          0xfa,
          0xb8,
          0xd5,
        ],
        '程式設計\n連線失敗\n臺灣新聞\n測試',
      ),
      ([0xa4, 0xa4, 0xa4, 0xe5], '中文'),
      (
        [
          0xb3,
          0x6f,
          0xac,
          0x4f,
          0xa4,
          0x40,
          0xa5,
          0xf7,
          0xc1,
          0x63,
          0xc5,
          0xe9,
          0xa4,
          0xa4,
          0xa4,
          0xe5,
          0xaa,
          0xba,
          0xa4,
          0xe5,
          0xb3,
          0xb9,
          0xa1,
          0x43,
        ],
        '這是一份繁體中文的文章。',
      ),
      (
        [
          0xd5,
          0xe2,
          0xca,
          0xc7,
          0xd2,
          0xbb,
          0xb7,
          0xdd,
          0xbc,
          0xf2,
          0xcc,
          0xe5,
          0xd6,
          0xd0,
          0xce,
          0xc4,
          0xb5,
          0xc4,
          0xce,
          0xc4,
          0xd5,
          0xc2,
          0xa1,
          0xa3,
        ],
        '这是一份简体中文的文章。',
      ),
    ]) {
      final result = decode(bytes);
      expect(result.text, expected, reason: bytes.toString());
      expect(result.count, expected.runes.length);
      expect(result.truncated, isFalse);
    }
  });

  test(
    'binary signatures, zero ratio, unsupported BOMs and corrupt encodings are distinct',
    () {
      for (final bytes in [
        [0x50, 0x4b, 3, 4, 0, 1],
        [0, 65, 0, 66, 0, 67, 68, 69, 70, 71],
      ]) {
        expect(
          () => decode(bytes),
          throwsA(failure(AttachmentProblem.notText)),
        );
      }
      expect(decode([65, 0, 66, 67]).text, 'A\x00BC');
      for (final bytes in [
        [0xff, 0xfe, 0, 0, 0x41],
        [0, 0, 0xfe, 0xff],
        [0xef, 0xbb, 0xbf, 0xd6, 0xd0],
        [0xff, 0xff, 0xff],
      ]) {
        expect(
          () => decode(bytes),
          throwsA(failure(AttachmentProblem.encoding)),
        );
      }
    },
  );

  test('only a byte-limited prefix can discard an incomplete character', () {
    for (final (bytes, expected) in <(List<int>, String)>[
      ([...utf8.encode('中文'), 0xf0, 0x9f, 0x98], '中文'),
      ([0xff, 0xfe, 0x2d, 0x4e, 0x3d, 0xd8], '中'),
      ([0xd6, 0xd0, 0xce, 0xc4, 0x95, 0x32, 0x82], '中文'),
      ([0xa4, 0xa4, 0xa4, 0xe5, 0xa4], '中文'),
    ]) {
      final result = decode(bytes, cut: true);
      expect(result.text, expected);
      expect(result.truncated, isTrue);
      expect(result.count, expected.runes.length);
    }
    expect(
      () => decode([0xef, 0xbb, 0xbf, 0xf0, 0x9f]),
      throwsA(failure(AttachmentProblem.encoding)),
    );
  });

  test('prompt cap counts Unicode scalar values, including the final pair', () {
    final exact = 'a' * 99999 + '😀';
    expect(decode(utf8.encode(exact)).truncated, isFalse);
    final result = decode(utf8.encode('$exact尾'));
    expect(result.text, exact);
    expect(result.count, 100000);
    expect(result.truncated, isTrue);
  });

  test(
    'CJK text survives an incomplete UTF8 sequence at the probe boundary',
    () async {
      final expected = '文件内容' * 2000;
      final file = File('${directory.path}/notes.txt')
        ..writeAsStringSync(expected);
      final result = await DocumentTextExtractor.extractResolved(
        path: file.path,
        mime: 'text/plain',
      );
      expect(result.text, expected);
    },
  );

  test(
    'oversize PDF and DOCX are rejected before their contents are read',
    () async {
      for (final mime in [
        'application/pdf',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ]) {
        final file = File('${directory.path}/large');
        file.openSync(mode: FileMode.write)
          ..truncateSync(256 * 1024 * 1024)
          ..closeSync();
        await expectLater(
          DocumentTextExtractor.extractResolved(path: file.path, mime: mime),
          throwsA(failure(AttachmentProblem.tooLarge)),
        );
      }
    },
  );

  test('large text reads only its byte prefix, for UTF-8 and GBK', () async {
    for (final (prefix, suffix, expected) in [
      (utf8.encode('中文'), [0xf0, 0x9f, 0x98], '中文'),
      ([0xd6, 0xd0, 0xce, 0xc4], [0x95, 0x32, 0x82], '中文'),
    ]) {
      final file = File('${directory.path}/large.txt');
      final bulk = Uint8List(kMaxDocumentExtractBytes)
        ..fillRange(0, kMaxDocumentExtractBytes, 0x61);
      bulk.setRange(0, prefix.length, prefix);
      bulk.setRange(bulk.length - suffix.length, bulk.length, suffix);
      file.openSync(mode: FileMode.write)
        ..writeFromSync(bulk)
        ..writeByteSync(0xff)
        ..closeSync();
      final result = await DocumentTextExtractor.extractResolved(
        path: file.path,
        mime: 'text/plain',
      );
      expect(result.text, expected + 'a' * 99998);
      expect(result.count, 100000);
      expect(result.truncated, isTrue);
    }
  });

  test(
    'generic Word .doc keeps its structured route and hard size cap',
    () async {
      final file = File('${directory.path}/word')
        ..writeAsBytesSync([0xd0, 0xcf, 0x11, 0xe0]);
      final doc = DocumentAttachment(
        path: file.path,
        fileName: 'notes.DOC',
        mime: 'application/octet-stream',
      );
      final cache = DocumentExtractionCache();
      expect(
        (await cache.read(doc)).text,
        contains('DOC format (.doc) not supported'),
      );
      file.openSync(mode: FileMode.write)
        ..truncateSync(kMaxDocumentExtractBytes + 1)
        ..closeSync();
      await expectLater(
        cache.read(doc),
        throwsA(failure(AttachmentProblem.tooLarge)),
      );
    },
  );

  test(
    'a verified published copy reuses the original result, but an edited source or destination never does',
    () async {
      final file = File('${directory.path}/draft.txt')..writeAsStringSync('中文');
      DocumentAttachment doc(File f) => DocumentAttachment(
        path: f.path,
        fileName: '稿.txt',
        mime: 'text/plain',
      );
      final cache = DocumentExtractionCache();
      final original = await cache.read(doc(file));
      final before = file.statSync();
      final copy = file.copySync('${directory.path}/published.txt');
      await cache.reusePublishedCopy(doc(file), file, before, copy);
      expect(await cache.read(doc(copy)), same(original));
      copy.writeAsStringSync('新');
      expect((await cache.read(doc(copy))).text, '新');
      file.writeAsStringSync('changed during publication');
      final second = file.copySync('${directory.path}/published2.txt');
      await cache.reusePublishedCopy(doc(file), file, before, second);
      expect(
        (await cache.read(doc(second))).text,
        'changed during publication',
      );
    },
  );

  test(
    'cache rechecks a restored file and preserves truncation with the text',
    () async {
      final file = File('${directory.path}/稿.log')
        ..writeAsStringSync('文' * 100001);
      final doc = DocumentAttachment(
        path: file.path,
        fileName: '稿.log',
        mime: 'application/octet-stream',
      );
      final cache = DocumentExtractionCache();
      expect((await cache.read(doc)).count, 100000);
      expect((await cache.read(doc)).truncated, isTrue);
      file.writeAsBytesSync([0xd6, 0xd0, 0xce, 0xc4]);
      expect((await cache.read(doc)).text, '中文');
      file.deleteSync();
      await expectLater(
        cache.read(doc),
        throwsA(failure(AttachmentProblem.missing)),
      );
    },
  );
}

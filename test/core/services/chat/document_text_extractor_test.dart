import 'dart:io';
import 'package:Kelivo/core/services/chat/document_text_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  setUp(
    () => directory = Directory.systemTemp.createTempSync('kelivo_extract_'),
  );
  tearDown(() => directory.deleteSync(recursive: true));

  test(
    'binary files stay attachments instead of being decoded as prompt text',
    () async {
      final file = File('${directory.path}/app.apk')
        ..writeAsBytesSync([0x50, 0x4b, 3, 4, 0, 1]);
      await expectLater(
        DocumentTextExtractor.extractResolved(
          path: file.path,
          mime: 'application/vnd.android.package-archive',
        ),
        throwsA(isA<AttachmentRequiresWorkspace>()),
      );
    },
  );

  test('large files are not read into memory for prompt extraction', () async {
    final file = File('${directory.path}/large.pdf');
    final handle = file.openSync(mode: FileMode.write)
      ..truncateSync(256 * 1024 * 1024);
    handle.closeSync();
    await expectLater(
      DocumentTextExtractor.extractResolved(
        path: file.path,
        mime: 'application/pdf',
      ),
      throwsA(isA<AttachmentRequiresWorkspace>()),
    );
    expect(file.lengthSync(), 256 * 1024 * 1024);
  });

  test(
    'CJK text survives an incomplete UTF8 sequence at the probe boundary',
    () async {
      final expected = '文件内容' * 2000;
      final file = File('${directory.path}/notes.txt')
        ..writeAsStringSync(expected);
      expect(
        await DocumentTextExtractor.extractResolved(
          path: file.path,
          mime: 'text/plain',
        ),
        expected,
      );
    },
  );
}

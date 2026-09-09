import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/services/incoming_share_service.dart';
import 'package:Kelivo/core/services/chat/document_text_extractor.dart';
import 'package:Kelivo/utils/upload_dedupe.dart';
import 'package:archive/archive_io.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late IncomingShareService service;
  const channel = MethodChannel('test.incoming_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    root = Directory.systemTemp.createTempSync('kelivo_incoming_');
    service = IncomingShareService(channel);
  });

  tearDown(() {
    service.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  test('reading a pending inbox never acknowledges it', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'getPendingShares') {
        return [
          {'id': '1', 'text': 'hello', 'files': [], 'failedFiles': 2},
        ];
      }
      expect(call.arguments, ['1']);
      return null;
    });
    final first = await service.pending();
    final second = await service.pending();
    expect(first.single.text, 'hello');
    expect(second.single.failedFiles, 2);
    expect(calls, ['getPendingShares', 'getPendingShares']);
    await service.acknowledge(first);
    expect(calls.last, 'acknowledgeShares');
  });

  test(
    'cancelling preparation rolls back copies without deleting sources',
    () async {
      final source = File(p.join(root.path, 'large.zip'))
        ..writeAsBytesSync(List.filled(256 * 1024, 1));
      final upload = Directory(p.join(root.path, 'upload'))..createSync();
      final progress = <ShareImportProgress>[];
      service.progress.addListener(() {
        final current = service.progress.value;
        if (current != null) {
          progress.add(current);
          service.cancelImport();
        }
      });
      await expectLater(
        service.prepare([
          IncomingShare(
            id: 'cancel',
            text: '',
            files: [
              DocumentAttachment(
                path: source.path,
                fileName: 'large.zip',
                mime: 'application/zip',
              ),
            ],
          ),
        ], uploadDirectory: upload),
        throwsA(isA<ShareImportCancelled>()),
      );
      expect(progress.first.total, 256 * 1024);
      expect(upload.listSync(), isEmpty);
      expect(source.existsSync(), isTrue);
      expect(service.progress.value, isNull);
    },
  );

  test('arbitrary binary attachment reports completed byte progress', () async {
    final source = File(p.join(root.path, 'app.apk'))
      ..writeAsBytesSync([0x50, 0x4b, 0, 1]);
    final values = <ShareImportProgress>[];
    service.progress.addListener(() {
      if (service.progress.value != null) values.add(service.progress.value!);
    });
    final input = await service.prepare([
      IncomingShare(
        id: 'apk',
        text: '',
        files: [
          DocumentAttachment(
            path: source.path,
            fileName: 'app.apk',
            mime: 'application/vnd.android.package-archive',
          ),
        ],
      ),
    ], uploadDirectory: Directory(p.join(root.path, 'upload')));
    expect(input.documents.single.fileName, 'app.apk');
    expect(File(input.documents.single.path).readAsBytesSync(), [
      0x50,
      0x4b,
      0,
      1,
    ]);
    expect(values.last.bytes, 4);
    expect(values.last.fraction, 1);
    expect(service.progress.value, isNull);
  });

  test(
    'cancelled batches keep a completed copy already reused by another import',
    () async {
      final first = File(p.join(root.path, 'one'))
        ..writeAsStringSync('keep me');
      final second = File(p.join(root.path, 'two'))
        ..writeAsBytesSync([1, 2, 3]);
      final resumeSecond = Completer<void>();
      final upload = Directory(p.join(root.path, 'upload'))..createSync();
      final reachedSecond = Completer<void>();
      service.progress.addListener(() {
        if (service.progress.value?.index == 2 && !reachedSecond.isCompleted) {
          reachedSecond.complete();
        }
      });
      // Hold the second source open so the first copy can be reused before a
      // failure rolls the entire batch back.
      final preparing = IOOverrides.runWithIOOverrides(
        () => service.prepare([
          IncomingShare(
            id: 'batch',
            text: '',
            files: [
              DocumentAttachment(
                path: first.path,
                fileName: 'one.txt',
                mime: 'text/plain',
              ),
              DocumentAttachment(
                path: second.path,
                fileName: 'two.zip',
                mime: 'application/zip',
              ),
            ],
          ),
        ], uploadDirectory: upload),
        _PausedSourceOverride(second, resumeSecond.future),
      );
      final failure = expectLater(
        preparing,
        throwsA(isA<ShareImportCancelled>()),
      );
      await reachedSecond.future;
      final reused = await UploadDedupe.findIdentical(
        upload,
        first.readAsBytesSync(),
        'one.txt',
      );
      expect(reused, isNotNull);
      await service.cancelImport();
      resumeSecond.complete();
      await failure;
      expect(File(reused!).readAsStringSync(), 'keep me');
    },
  );

  test(
    'discarding a prepared batch preserves copies adopted by another draft',
    () async {
      final source = File(p.join(root.path, 'one'))
        ..writeAsStringSync('keep me');
      final upload = Directory(p.join(root.path, 'upload'))..createSync();
      final input = await service.prepare([
        IncomingShare(
          id: 'discard',
          text: '',
          files: [
            DocumentAttachment(
              path: source.path,
              fileName: 'one.txt',
              mime: 'text/plain',
            ),
          ],
        ),
      ], uploadDirectory: upload);
      final reused = await UploadDedupe.findIdentical(
        upload,
        source.readAsBytesSync(),
        'one.txt',
      );
      await service.discardPrepared(input);
      expect(File(reused!).readAsStringSync(), 'keep me');
    },
  );

  test(
    'generic MIME PDFs and DOCX reach the real text extractors after sharing',
    () async {
      final pdf = PdfDocument();
      pdf.pages.add().graphics.drawString(
        'Shared PDF text',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(0, 0, 200, 40),
      );
      final pdfFile = File(p.join(root.path, 'pdf-source'))
        ..writeAsBytesSync(await pdf.save());
      pdf.dispose();
      final xml = utf8.encode(
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Shared DOCX text</w:t></w:r></w:p></w:body></w:document>',
      );
      final docx = File(p.join(root.path, 'docx-source'))
        ..writeAsBytesSync(
          ZipEncoder().encode(
            Archive()
              ..addFile(ArchiveFile('word/document.xml', xml.length, xml)),
          ),
        );
      final input = await service.prepare([
        IncomingShare(
          id: 'docs',
          text: '',
          files: [
            DocumentAttachment(
              path: pdfFile.path,
              fileName: 'REPORT.PDF',
              mime: 'application/octet-stream',
            ),
            DocumentAttachment(
              path: docx.path,
              fileName: '报告.docx',
              mime: '*/*',
            ),
          ],
        ),
      ], uploadDirectory: Directory(p.join(root.path, 'upload')));
      expect(input.documents[0].mime, 'application/pdf');
      expect(
        input.documents[1].mime,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(
        await DocumentTextExtractor.extractResolved(
          path: input.documents[0].path,
          mime: input.documents[0].mime,
        ),
        contains('Shared PDF text'),
      );
      expect(
        await DocumentTextExtractor.extractResolved(
          path: input.documents[1].path,
          mime: input.documents[1].mime,
        ),
        contains('Shared DOCX text'),
      );
    },
  );

  test(
    'keeps Chinese names, separates duplicate names and combines pending text',
    () async {
      final source = File(p.join(root.path, 'source'))
        ..writeAsStringSync('document');
      final image = File(p.join(root.path, 'photo'))
        ..writeAsBytesSync([1, 2, 3]);
      final upload = Directory(p.join(root.path, 'upload'))..createSync();
      final existing = File(p.join(upload.path, '文件.txt'))
        ..writeAsStringSync('keep');
      final input = await service.prepare([
        IncomingShare(
          id: '1',
          text: 'first',
          files: [
            DocumentAttachment(
              path: source.path,
              fileName: '../文件.txt',
              mime: 'text/plain',
            ),
            DocumentAttachment(
              path: image.path,
              fileName: '图片.PNG',
              mime: 'image/png',
            ),
          ],
        ),
        const IncomingShare(id: '2', text: 'https://example.com', files: []),
      ], uploadDirectory: upload);
      expect(input.text, 'first\n\nhttps://example.com');
      expect(input.documents.single.fileName, '文件(1).txt');
      expect(input.documents.single.mime, 'text/plain');
      expect(p.basename(input.imagePaths.single), '图片.PNG');
      expect(existing.readAsStringSync(), 'keep');
      source.deleteSync();
      image.deleteSync();
      expect(File(input.documents.single.path).readAsStringSync(), 'document');
      expect(File(input.imagePaths.single).readAsBytesSync(), [1, 2, 3]);
      await service.discardPrepared(input);
      expect(upload.listSync().single.path, existing.path);
    },
  );

  test(
    'a failed batch rolls back only files it created and retains the inbox',
    () async {
      final source = File(p.join(root.path, 'source'))
        ..writeAsStringSync('copied');
      final upload = Directory(p.join(root.path, 'upload'))..createSync();
      final existing = File(p.join(upload.path, 'existing.pdf'))
        ..writeAsStringSync('keep');
      await expectLater(
        service.prepare([
          IncomingShare(
            id: '1',
            text: '',
            files: [
              DocumentAttachment(
                path: source.path,
                fileName: 'existing.pdf',
                mime: 'application/pdf',
              ),
              DocumentAttachment(
                path: p.join(root.path, 'missing'),
                fileName: 'missing.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ], uploadDirectory: upload),
        throwsA(isA<FileSystemException>()),
      );
      expect(upload.listSync().single.path, existing.path);
      expect(existing.readAsStringSync(), 'keep');
      expect(source.existsSync(), isTrue);
    },
  );

  test(
    'media and document MIME types are preserved for the existing attachment pipeline',
    () async {
      final source = File(p.join(root.path, 'source'))
        ..writeAsStringSync('data');
      final input = await service.prepare([
        IncomingShare(
          id: '1',
          text: '',
          files: [
            for (final (name, mime) in [
              ('camera.heic', 'image/heic'),
              ('video.mp4', 'video/mp4'),
              ('voice.mp3', 'audio/mpeg'),
              ('voice.pcm', 'audio/pcm;rate=24000'),
              ('report.pdf', 'application/pdf'),
            ])
              DocumentAttachment(path: source.path, fileName: name, mime: mime),
          ],
        ),
      ], uploadDirectory: Directory(p.join(root.path, 'upload')));
      expect(p.basename(input.imagePaths.single), 'camera.heic');
      expect(input.documents.map((file) => file.mime), [
        'video/mp4',
        'audio/mpeg',
        'audio/pcm;rate=24000',
        'application/pdf',
      ]);
    },
  );
}

final class _PausedSourceOverride extends IOOverrides {
  _PausedSourceOverride(this.source, this.ready);
  final File source;
  final Future<void> ready;
  @override
  File createFile(String path) =>
      path == source.path ? _PausedFile(source, ready) : super.createFile(path);
}

class _PausedFile extends Fake implements File {
  _PausedFile(this.source, this.ready);
  final File source;
  final Future<void> ready;
  @override
  Future<int> length() => source.length();
  @override
  Stream<List<int>> openRead([int? start, int? end]) async* {
    await ready;
    yield source.readAsBytesSync();
  }
}

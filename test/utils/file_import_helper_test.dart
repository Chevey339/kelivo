import 'dart:io';
import 'dart:typed_data';

import 'package:Kelivo/utils/file_import_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late Directory uploadDir;
  late Directory pickerCache;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('file_import_helper');
    uploadDir = Directory(p.join(tempRoot.path, 'upload'));
    pickerCache = await Directory(
      p.join(tempRoot.path, 'cache'),
    ).create(recursive: true);
  });

  tearDown(() async {
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  Future<File> pickerCopy(
    String name,
    String content,
    DateTime modified,
  ) async {
    final file = File(
      p.join(
        pickerCache.path,
        '${DateTime.now().microsecondsSinceEpoch}',
        name,
      ),
    );
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
    await file.setLastModified(modified);
    return file;
  }

  test('reuses the stored file when the same file is picked again', () async {
    // The document pickers hand us a fresh cache copy each time, so the
    // modification time differs even though the physical file did not change.
    final first = await pickerCopy('notes.txt', 'hello', DateTime(2020, 1, 1));
    final saved = await FileImportHelper.copyXFile(
      XFile(first.path),
      uploadDir,
    );
    expect(saved, isNotNull);

    final second = await pickerCopy('notes.txt', 'hello', DateTime(2024, 6, 6));
    final reused = await FileImportHelper.copyXFile(
      XFile(second.path),
      uploadDir,
    );

    expect(reused, saved);
    expect(uploadDir.listSync().whereType<File>(), hasLength(1));
  });

  test('file import streams without calling readAsBytes', () async {
    final source = await pickerCopy(
      'app.apk',
      'streamed bytes',
      DateTime(2026),
    );
    final saved = await FileImportHelper.copyXFile(
      _StreamOnlyFile(source.path),
      uploadDir,
    );
    expect(saved, isNotNull);
    expect(await File(saved!).readAsString(), 'streamed bytes');
  });

  test(
    'keeps both files when a same-named file has different content',
    () async {
      final first = await pickerCopy(
        'notes.txt',
        'hello',
        DateTime(2020, 1, 1),
      );
      final saved = await FileImportHelper.copyXFile(
        XFile(first.path),
        uploadDir,
      );

      final second = await pickerCopy(
        'notes.txt',
        'goodbye',
        DateTime(2020, 1, 1),
      );
      final copied = await FileImportHelper.copyXFile(
        XFile(second.path),
        uploadDir,
      );

      expect(copied, isNot(saved));
      expect(p.basename(copied!), 'notes(1).txt');
      expect(await File(copied).readAsString(), 'goodbye');
      expect(uploadDir.listSync().whereType<File>(), hasLength(2));
    },
  );

  test('keeps identical content stored under a different name apart', () async {
    // The display name and MIME type are derived from the stored path, so a
    // different name must never resolve to an existing file.
    final first = await pickerCopy('notes.txt', 'hello', DateTime(2020, 1, 1));
    final saved = await FileImportHelper.copyXFile(
      XFile(first.path),
      uploadDir,
    );

    final renamed = await pickerCopy(
      'config.json',
      'hello',
      DateTime(2020, 1, 1),
    );
    final copied = await FileImportHelper.copyXFile(
      XFile(renamed.path),
      uploadDir,
    );

    expect(copied, isNot(saved));
    expect(p.basename(copied!), 'config.json');
    expect(uploadDir.listSync().whereType<File>(), hasLength(2));
  });

  test('does not reuse a numbered file the user named themselves', () async {
    final numbered = await pickerCopy(
      'notes(1).txt',
      'hello',
      DateTime(2020, 1, 1),
    );
    final saved = await FileImportHelper.copyXFile(
      XFile(numbered.path),
      uploadDir,
    );
    expect(p.basename(saved!), 'notes(1).txt');

    final plain = await pickerCopy('notes.txt', 'hello', DateTime(2020, 1, 1));
    final copied = await FileImportHelper.copyXFile(
      XFile(plain.path),
      uploadDir,
    );

    expect(copied, isNot(saved));
    expect(p.basename(copied!), 'notes.txt');
  });

  test('reuses a versioned copy of the same name', () async {
    final first = await pickerCopy('notes.txt', 'hello', DateTime(2020, 1, 1));
    await FileImportHelper.copyXFile(XFile(first.path), uploadDir);

    // "notes(1).txt" is written because the content differs...
    final second = await pickerCopy(
      'notes.txt',
      'goodbye',
      DateTime(2020, 1, 1),
    );
    final versioned = await FileImportHelper.copyXFile(
      XFile(second.path),
      uploadDir,
    );
    expect(p.basename(versioned!), 'notes(1).txt');

    // ...and picking that same content again resolves back to it.
    final third = await pickerCopy(
      'notes.txt',
      'goodbye',
      DateTime(2024, 6, 6),
    );
    final reused = await FileImportHelper.copyXFile(
      XFile(third.path),
      uploadDir,
    );

    expect(reused, versioned);
    expect(uploadDir.listSync().whereType<File>(), hasLength(2));
  });
}

class _StreamOnlyFile extends XFile {
  _StreamOnlyFile(super.path);
  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Must stream file imports');
}

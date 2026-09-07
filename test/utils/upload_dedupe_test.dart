import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:Kelivo/utils/upload_dedupe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('upload_dedupe');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Uint8List bytesOf(String content) => Uint8List.fromList(content.codeUnits);

  Future<File> store(String name, Uint8List bytes) async {
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  test('a freshly created file is not shared', () async {
    final file = await UploadDedupe.reserveUniqueFile(dir, 'notes.txt');

    expect(UploadDedupe.isShared(file.path), isFalse);
  });

  test('a pending deletion cannot be handed to a new dedupe reader', () async {
    final bytes = bytesOf('file contents');
    final file = await store('notes.txt', bytes);
    final deletionStarted = Completer<void>();
    final finishDeletion = Completer<void>();
    final deletion = IOOverrides.runWithIOOverrides(
      () => UploadDedupe.deleteIfUnshared(file.path),
      _DeleteOverride(file, deletionStarted, finishDeletion.future),
    );
    await deletionStarted.future;
    expect(await UploadDedupe.findIdentical(dir, bytes, 'notes.txt'), isNull);
    finishDeletion.complete();
    await deletion;
    expect(await file.exists(), isFalse);
  });

  test('a file is marked shared before its bytes are read', () async {
    // Same name and size but different content: the file is opened and hashed,
    // does not match, and still must count as shared — a reader may be holding
    // an open descriptor on it right now.
    final other = await store('notes.txt', bytesOf('hello'));

    expect(
      await UploadDedupe.findIdentical(dir, bytesOf('world'), 'notes.txt'),
      isNull,
    );
    expect(UploadDedupe.isShared(other.path), isTrue);
  });

  test('a reused file stays marked shared', () async {
    final file = await store('notes.txt', bytesOf('hello'));

    expect(
      await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'notes.txt'),
      file.path,
    );
    expect(UploadDedupe.isShared(file.path), isTrue);
  });

  test('recreating a deleted name clears the stale mark', () async {
    final file = await store('notes.txt', bytesOf('hello'));
    await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'notes.txt');
    expect(UploadDedupe.isShared(file.path), isTrue);
    await file.delete();

    final recreated = await UploadDedupe.reserveUniqueFile(dir, 'notes.txt');

    expect(recreated.path, file.path);
    expect(UploadDedupe.isShared(recreated.path), isFalse);
  });

  test('does not match a different name, extension, or content', () async {
    await store('notes.txt', bytesOf('hello'));

    expect(
      await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'config.json'),
      isNull,
    );
    expect(
      await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'notes.md'),
      isNull,
    );
    expect(
      await UploadDedupe.findIdentical(dir, bytesOf('other'), 'notes.txt'),
      isNull,
    );
  });

  test(
    'matches a numbered file only next to its unnumbered original',
    () async {
      // A "notes(1).txt" the user named themselves is a file of its own, not a
      // version of a "notes.txt" we never wrote.
      await store('notes(1).txt', bytesOf('hello'));
      expect(
        await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'notes.txt'),
        isNull,
      );

      // Once "notes.txt" exists, the numbered file is part of its family.
      await store('notes.txt', bytesOf('goodbye'));
      expect(
        await UploadDedupe.findIdentical(dir, bytesOf('hello'), 'notes.txt'),
        p.join(dir.path, 'notes(1).txt'),
      );
    },
  );

  test('hashes nothing when the directory holds no candidate', () async {
    // A 4 MB file crosses the background-hashing threshold; with no same-named
    // candidate stored, the lookup must not hash it at all.
    final big = Uint8List(4 * 1024 * 1024);
    await store('other.bin', big);

    expect(await UploadDedupe.findIdentical(dir, big, 'clip.mp4'), isNull);
  });
}

final class _DeleteOverride extends IOOverrides {
  _DeleteOverride(this.file, this.started, this.ready);
  final File file;
  final Completer<void> started;
  final Future<void> ready;
  @override
  File createFile(String path) => path == file.path
      ? _DeletingFile(file, started, ready)
      : super.createFile(path);
}

class _DeletingFile extends Fake implements File {
  _DeletingFile(this.file, this.started, this.ready);
  final File file;
  final Completer<void> started;
  final Future<void> ready;
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    started.complete();
    await ready;
    return file.delete(recursive: recursive);
  }
}

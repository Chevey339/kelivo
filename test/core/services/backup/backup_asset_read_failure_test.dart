import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/data_sync.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('backup_asset_read_failure_');
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'a mid-read failure removes the partial ZIP entry and preserves siblings',
    () {
      final first = File('${root.path}/first.txt')..writeAsStringSync('first');
      final bad = File('${root.path}/unreadable.bin');
      final random = Random(42);
      bad.writeAsBytesSync(
        List.generate(2 * 1024 * 1024, (_) => random.nextInt(256)),
      );
      final last = File('${root.path}/last.txt')..writeAsStringSync('last');
      final destination = File('${root.path}/backup.zip');
      final wrapped = _FailingFile(bad, readFailure: true);
      final files = {
        for (final file in [first, bad, last, destination]) file.path: file,
        bad.path: wrapped,
      };
      final skipped = IOOverrides.runZoned(
        () => DataSync.debugPackAssetFiles(
          destination: destination,
          source: root,
          files: [first, bad, last],
        ),
        createFile: (path) => files[path]!,
      );
      expect(skipped, [bad.path]);
      expect(wrapped.opened!.bytesRead, greaterThan(0));
      expect(wrapped.opened!.closed, isTrue);
      expect(destination.lengthSync(), lessThan(4096));
      final archive = ZipDecoder().decodeBytes(
        destination.readAsBytesSync(),
        verify: true,
      );
      try {
        expect(archive.files.map((entry) => entry.name), [
          'upload/first.txt',
          'upload/last.txt',
        ]);
        expect(
          archive.findFile('upload/first.txt')!.readBytes(),
          'first'.codeUnits,
        );
        expect(
          archive.findFile('upload/last.txt')!.readBytes(),
          'last'.codeUnits,
        );
      } finally {
        archive.clearSync();
      }
    },
  );

  test('a ZIP destination write failure is fatal and closes the output', () {
    final source = File('${root.path}/source.txt')..writeAsStringSync('source');
    final destination = File('${root.path}/backup.zip');
    final wrapped = _FailingFile(destination, readFailure: false);
    final files = {source.path: source, destination.path: wrapped};
    expect(
      () => IOOverrides.runZoned(
        () => DataSync.debugPackAssetFiles(
          destination: destination,
          source: root,
          files: [source],
        ),
        createFile: (path) => files[path]!,
      ),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.osError?.errorCode,
          'disk full',
          28,
        ),
      ),
    );
    expect(wrapped.opened!.closed, isTrue);
  });
}

class _FailingFile implements File {
  _FailingFile(this.file, {required this.readFailure});
  final File file;
  final bool readFailure;
  _FailingHandle? opened;
  @override
  String get path => file.path;
  @override
  FileStat statSync() => file.statSync();
  @override
  int lengthSync() => file.lengthSync();
  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) => opened =
      _FailingHandle(file.openSync(mode: mode), readFailure: readFailure);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingHandle implements RandomAccessFile {
  _FailingHandle(this.file, {required this.readFailure});
  final RandomAccessFile file;
  final bool readFailure;
  int bytesRead = 0;
  bool closed = false;
  @override
  int lengthSync() => file.lengthSync();
  @override
  int positionSync() => file.positionSync();
  @override
  void setPositionSync(int position) => file.setPositionSync(position);
  @override
  int readIntoSync(List<int> buffer, [int start = 0, int? end]) {
    if (readFailure && bytesRead > 0) {
      throw FileSystemException(
        'Source read failed',
        file.path,
        const OSError('I/O error', 5),
      );
    }
    final count = file.readIntoSync(buffer, start, end);
    bytesRead += count;
    return count;
  }

  @override
  void writeFromSync(List<int> buffer, [int start = 0, int? end]) {
    if (!readFailure) {
      throw FileSystemException(
        'Destination write failed',
        file.path,
        const OSError('No space left', 28),
      );
    }
    file.writeFromSync(buffer, start, end);
  }

  @override
  void closeSync() {
    closed = true;
    file.closeSync();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

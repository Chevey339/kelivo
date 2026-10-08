import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/backup/streaming_zip_entry.dart';

final class _CountingOutput extends OutputMemoryStream {
  _CountingOutput(this.onWrite);
  final void Function(List<int>) onWrite;
  @override
  void writeBytes(List<int> bytes, {int? length}) =>
      onWrite(length == null ? bytes : bytes.sublist(0, length));
  @override
  void flush() {}
}

void main() {
  for (final compress in [false, true]) {
    test('preserves all bytes with compression=$compress', () {
      final data = Uint8List.fromList(List.generate(65537, (i) => i % 251));
      final bytes = ZipEncoder().encode(
        Archive()..addFile(
          ArchiveFile('data', data.length, data)
            ..compression = compress
                ? CompressionType.deflate
                : CompressionType.none,
        ),
      );
      final archive = ZipDecoder().decodeBytes(bytes);
      final output = OutputMemoryStream();
      writeZipEntryStreaming(archive.single, output);
      expect(sha256.convert(output.getBytes()), sha256.convert(data));
      archive.clearSync();
    });
  }

  test('writes before compressed input ends and can stop decoding early', () {
    final data = Uint8List(16 * 1024 * 1024);
    final bytes = ZipEncoder().encode(
      Archive()..addFile(ArchiveFile('database/kelivo.db', data.length, data)),
    );
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    final input = decoder.directory.fileHeaders.single.file!.getStream(
      decompress: false,
    );
    var written = 0;
    var sawOutputBeforeEnd = false;
    final output = _CountingOutput((chunk) {
      sawOutputBeforeEnd |= !input.isEOS;
      written += chunk.length;
    });
    expect(
      () => writeZipEntryStreaming(
        archive.single,
        output,
        checkCancelled: () {
          if (written >= 256 * 1024) throw StateError('cancelled');
        },
      ),
      throwsStateError,
    );
    expect(sawOutputBeforeEnd, isTrue);
    expect(written, lessThan(data.length));
    expect(input.position, 0, reason: 'a failed read restores the ZIP cursor');
    final retry = OutputMemoryStream();
    writeZipEntryStreaming(archive.single, retry);
    expect(sha256.convert(retry.getBytes()), sha256.convert(data));
    archive.clearSync();
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hashes the bytes actually read, optionally copying those same bytes into
/// a new staging file. Run on a backup worker for large payloads.
({int bytes, String sha256}) digestBackupFile(
  File source, {
  File? copyTo,
  Uint8List? buffer,
  void Function()? checkCancelled,
  void Function(int)? onBytes,
}) {
  checkCancelled?.call();
  final input = source.openSync();
  RandomAccessFile? output;
  try {
    if (copyTo != null) {
      copyTo.createSync(exclusive: true);
      output = copyTo.openSync(mode: FileMode.writeOnly);
    }
    final block = buffer ?? Uint8List(input.lengthSync().clamp(1, 1024 * 1024));
    final digest = _FileDigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var bytes = 0;
    while (true) {
      checkCancelled?.call();
      final count = input.readIntoSync(block);
      if (count == 0) break;
      hash.add(Uint8List.sublistView(block, 0, count));
      output?.writeFromSync(block, 0, count);
      bytes += count;
      onBytes?.call(count);
    }
    hash.close();
    return (bytes: bytes, sha256: digest.value.toString());
  } finally {
    try {
      output?.closeSync();
    } finally {
      input.closeSync();
    }
  }
}

final class _FileDigestSink implements Sink<Digest> {
  late final Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

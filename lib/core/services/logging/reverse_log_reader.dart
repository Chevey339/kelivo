import 'dart:io';
import 'dart:typed_data';

/// Logs are append-only. Remember their original extent and prefix so a
/// rotated/replaced active file cannot be mixed into an existing reading session.
class LogFileSnapshot {
  const LogFileSnapshot(this.length, this.prefix);
  final int length;
  final Uint8List prefix;
}

/// A backward line reader whose cursor is a byte boundary, not retained text.
/// Long lines are assembled once, including UTF-8 split across read chunks.
class ReverseLogReader {
  ReverseLogReader._(this._file, this.position, this.chunkSize, this.snapshot);

  final RandomAccessFile _file;
  final int chunkSize;
  final LogFileSnapshot snapshot;
  int position;
  Uint8List _buffer = Uint8List(0);
  int _index = 0;

  static Future<ReverseLogReader> open(
    File file, {
    int? end,
    int chunkSize = 128 * 1024,
    LogFileSnapshot? snapshot,
  }) async {
    if (chunkSize <= 0) throw ArgumentError.value(chunkSize, 'chunkSize');
    final handle = await file.open();
    try {
      final length = await handle.length();
      final prefixLength =
          snapshot?.prefix.length ?? (length < 256 ? length : 256);
      final prefix = await handle.read(prefixLength);
      if ((end != null && (end < 0 || end > length)) ||
          (snapshot != null &&
              (length < snapshot.length ||
                  !_sameBytes(prefix, snapshot.prefix)))) {
        throw FileSystemException('Log changed; refresh to reload', file.path);
      }
      final captured = snapshot ?? LogFileSnapshot(length, prefix);
      return ReverseLogReader._(
        handle,
        end ?? captured.length,
        chunkSize,
        captured,
      );
    } catch (_) {
      await handle.close();
      rethrow;
    }
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Uses this already-validated handle, even if the path is rotated meanwhile.
  Stream<List<int>> readRange(int start, int end) async* {
    if (start < 0 || end < start || end > snapshot.length) {
      throw RangeError('Invalid log range');
    }
    await _file.setPosition(start);
    var remaining = end - start;
    while (remaining > 0) {
      final count = remaining < chunkSize ? remaining : chunkSize;
      final bytes = await _file.read(count);
      if (bytes.length != count) {
        throw const FileSystemException('Log changed; refresh to reload');
      }
      remaining -= bytes.length;
      yield bytes;
    }
  }

  Future<({Uint8List bytes, int start, int end})?> readLine() async {
    if (position == 0) return null;
    final end = position;
    final parts = <Uint8List>[];
    while (position > 0) {
      if (_index == 0) {
        final count = position < chunkSize ? position : chunkSize;
        await _file.setPosition(position - count);
        _buffer = await _file.read(count);
        if (_buffer.length != count) {
          throw const FileSystemException('Log changed; refresh to reload');
        }
        _index = count;
      }
      final segmentEnd = _index;
      while (_index > 0 && _buffer[_index - 1] != 10) {
        _index--;
        position--;
      }
      parts.add(Uint8List.sublistView(_buffer, _index, segmentEnd));
      if (_index > 0) {
        _index--;
        position--;
        break;
      }
    }
    final bytes = BytesBuilder(copy: false);
    for (final part in parts.reversed) {
      bytes.add(part);
    }
    return (bytes: bytes.takeBytes(), start: position, end: end);
  }

  Future<void> close() => _file.close();
}

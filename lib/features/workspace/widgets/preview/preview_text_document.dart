import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:Kelivo/shared/cache/byte_lru_cache.dart';

Future<PreviewTextDocument> loadPreviewTextDocument(File file) =>
    compute(_openPreviewTextDocument, file.path);

PreviewTextDocument _openPreviewTextDocument(String path) {
  final file = File(path).openSync();
  try {
    final length = file.lengthSync();
    if (length <= PreviewTextDocument.richMaxBytes) {
      final bytes = file.readSync(length);
      if (bytes.length != length) {
        throw FileSystemException('File changed', path);
      }
      final source = utf8.decode(bytes, allowMalformed: true);
      final lines = source.split(RegExp(r'\r\n|\r|\n'));
      if (lines.length <= PreviewTextDocument.richMaxLines &&
          lines.every(
            (line) => line.length <= PreviewTextDocument.chunkBytes,
          )) {
        return PreviewTextDocument._(path, length, source, lines, null);
      }
    }
    file.setPositionSync(0);
    final first = file.readSync(
      math.min(length, PreviewTextDocument.chunkBytes + 4),
    );
    return PreviewTextDocument._(
      path,
      length,
      null,
      const [],
      _decodeChunk(first, readStart: 0, index: 0, fileLength: length),
    );
  } finally {
    file.closeSync();
  }
}

/// Small files own their source. Large files own only metadata and the first
/// page: neither opening the preview nor jumping to EOF scans the whole file.
class PreviewTextDocument {
  PreviewTextDocument._(
    this.path,
    this.byteLength,
    this.source,
    this.lines,
    this.firstChunk,
  );

  static const richMaxBytes = 128 * 1024;
  static const richMaxLines = 2000;
  static const chunkBytes = 2048;

  final String path;
  final int byteLength;
  final String? source;
  final List<String> lines;
  final String? firstChunk;

  bool get usesPlainText => source == null;
  int get chunkCount => (byteLength + chunkBytes - 1) ~/ chunkBytes;

  /// Only an explicit full-file copy materializes a large file as a string.
  /// Clipboard.setData requires the entire string; browsing never calls this.
  Future<String> readSource() async =>
      source ?? await compute(_readSource, path);
}

String _readSource(String path) =>
    utf8.decode(File(path).readAsBytesSync(), allowMalformed: true);

/// One reader per mounted view. Serializing seek/read keeps concurrent visible
/// rows from racing on the file position. Disposed rows skip queued disk reads.
class PreviewTextReader {
  PreviewTextReader(this.document) {
    final first = document.firstChunk;
    if (first != null) _cache.put(0, first);
  }

  static const maxCacheBytes = 128 * 1024;
  final PreviewTextDocument document;
  final _cache = ByteLruCache<int, String>(
    maxBytes: maxCacheBytes,
    sizeOf: (_, text) => text.length * 2 + 64,
  );
  RandomAccessFile? _file;
  Future<void> _tail = Future<void>.value();
  Future<void>? _closing;
  bool _closed = false;

  @visibleForTesting
  int bytesRead = 0;
  @visibleForTesting
  int get cachedBytes => _cache.bytes;

  String? cachedChunk(int index) => _cache.get(index);

  Future<String> readChunk(int index, {bool Function()? isCancelled}) {
    RangeError.checkValidIndex(index, this, 'index', document.chunkCount);
    if (_closed) return Future.error(StateError('Preview reader is closed'));
    final cached = cachedChunk(index);
    if (cached != null) return SynchronousFuture(cached);
    final result = _tail.then((_) async {
      if (_closed || (isCancelled?.call() ?? false)) return '';
      final cached = cachedChunk(index);
      if (cached != null) return cached;
      final file = _file ??= await File(document.path).open();
      final start = math.max(0, index * PreviewTextDocument.chunkBytes - 4);
      final end = math.min(
        document.byteLength,
        (index + 1) * PreviewTextDocument.chunkBytes + 4,
      );
      await file.setPosition(start);
      final bytes = await file.read(end - start);
      bytesRead += bytes.length;
      if (bytes.length != end - start) {
        throw FileSystemException(
          'File changed while previewing',
          document.path,
        );
      }
      final text = _decodeChunk(
        bytes,
        readStart: start,
        index: index,
        fileLength: document.byteLength,
      );
      if (!_closed) _cache.put(index, text);
      return text;
    });
    // An unreadable page must not poison the queue or leak an unhandled future.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> close() {
    _closed = true;
    _cache.clear();
    return _closing ??= _tail.then((_) async {
      await _file?.close();
      _file = null;
    });
  }
}

String _decodeChunk(
  Uint8List bytes, {
  required int readStart,
  required int index,
  required int fileLength,
}) {
  final nominalStart = index * PreviewTextDocument.chunkBytes;
  final nominalEnd = math.min(
    fileLength,
    nominalStart + PreviewTextDocument.chunkBytes,
  );
  final start = _textBoundary(bytes, nominalStart - readStart);
  final end = _textBoundary(bytes, nominalEnd - readStart);
  final chunk = Uint8List.sublistView(bytes, start, end);
  final text = utf8.decode(chunk, allowMalformed: true);
  // Utf8Decoder strips a leading BOM. Only the BOM at file offset zero is a
  // signature; a U+FEFF at any later page boundary is actual file content.
  if (readStart + start > 0 &&
      chunk.length >= 3 &&
      chunk[0] == 0xef &&
      chunk[1] == 0xbb &&
      chunk[2] == 0xbf) {
    return '\ufeff$text';
  }
  return text;
}

/// Adjacent pages independently choose the same boundary, at most three bytes
/// before their nominal offset. Keep UTF-8 sequences (including incomplete
/// valid prefixes) and CRLF intact without scanning or indexing earlier pages.
int _textBoundary(Uint8List bytes, int offset) {
  if (offset == 0 || offset == bytes.length) return offset;
  var start = offset;
  while (start > 0 && offset - start < 3 && bytes[start] & 0xc0 == 0x80) {
    start--;
  }
  if (start < offset) {
    final lead = bytes[start];
    final length = lead >= 0xc2 && lead <= 0xdf
        ? 2
        : lead >= 0xe0 && lead <= 0xef
        ? 3
        : lead >= 0xf0 && lead <= 0xf4
        ? 4
        : 0;
    var validPrefix = length > offset - start;
    for (var i = start + 1; validPrefix && i <= offset; i++) {
      final byte = bytes[i];
      validPrefix = byte & 0xc0 == 0x80;
      if (i == start + 1) {
        if (lead == 0xe0 && byte < 0xa0 ||
            lead == 0xed && byte >= 0xa0 ||
            lead == 0xf0 && byte < 0x90 ||
            lead == 0xf4 && byte >= 0x90) {
          validPrefix = false;
        }
      }
    }
    if (validPrefix) offset = start;
  }
  if (offset > 0 && bytes[offset] == 10 && bytes[offset - 1] == 13) offset--;
  return offset;
}

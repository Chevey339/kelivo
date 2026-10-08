import 'dart:io';

import 'package:archive/archive_io.dart';

/// Writes a ZIP member without retaining its decompressed contents.
///
/// archive's native ZLibDecoder.decodeStream collects every decoded chunk in
/// ChunkedConversionSink.withCallback before forwarding any of them. Feed the
/// native converter directly into the destination instead. Keep archive's ZIP
/// parser (including ZIP64) and its codecs for non-deflate members.
void writeZipEntryStreaming(
  ArchiveFile entry,
  OutputStream output, {
  void Function()? checkCancelled,
}) {
  final content = entry.rawContent;
  if (content is! ZipFile ||
      content.compressionMethod != CompressionType.deflate) {
    checkCancelled?.call();
    entry.writeContent(output);
    return;
  }
  inflateZipDeflateStreaming(
    content.getStream(decompress: false),
    output,
    checkCancelled: checkCancelled,
  );
}

/// Shared with Chatbox's bounded entry verifier and raw-deflate validator.
void inflateZipDeflateStreaming(
  InputStream input,
  OutputStream output, {
  void Function()? checkCancelled,
}) {
  final position = input.position;
  final destination = _ZipOutputSink(output, checkCancelled);
  final converter = ZLibCodec(
    raw: true,
  ).decoder.startChunkedConversion(destination);
  var closed = false;
  try {
    // Bound each compressed input too: highly compressible data can expand by
    // over 1000x before the converter returns control to the cancellation loop.
    const chunkSize = 1024;
    while (!input.isEOS) {
      checkCancelled?.call();
      final size = input.length < chunkSize ? input.length : chunkSize;
      converter.add(input.readBytes(size).toUint8List());
    }
    closed = true;
    converter.close();
  } finally {
    if (!closed) {
      // Release the native inflater even when the destination rejects output
      // or cancellation interrupts a chunk. Preserve the original exception.
      destination.discard = true;
      try {
        converter.close();
      } catch (_) {}
    }
    input.setPosition(position);
  }
}

final class _ZipOutputSink implements Sink<List<int>> {
  _ZipOutputSink(this.output, this.checkCancelled);

  final OutputStream output;
  final void Function()? checkCancelled;
  bool discard = false;

  @override
  void add(List<int> data) {
    if (discard) return;
    checkCancelled?.call();
    output.writeBytes(data);
  }

  @override
  void close() {
    if (!discard) output.flush();
  }
}

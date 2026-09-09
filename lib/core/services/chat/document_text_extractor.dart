import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/unicode_sanitizer.dart';

/// Data passed to the background isolate for document extraction.
class _ExtractorParams {
  final String path;
  final String mime;
  _ExtractorParams(this.path, this.mime);
}

class AttachmentRequiresWorkspace implements Exception {
  const AttachmentRequiresWorkspace(this.name);
  final String name;
  @override
  String toString() => 'Attachment requires workspace file tools: $name';
}

class DocumentTextExtractor {
  /// Extracts text from a document file at [path] with [mime] type.
  ///
  /// Resolves via [SandboxPathResolver.resolveForIo] once, then delegates to
  /// [extractResolved]. Prefer [extractResolved] when the caller already
  /// resolved the path (avoid a second pass).
  static Future<String> extract({
    required String path,
    required String mime,
  }) async {
    final resolved = SandboxPathResolver.resolveForIo(path);
    if (resolved == null) return '[[File not found: $path]]';
    return extractResolved(path: resolved, mime: mime);
  }

  /// Extract using an already-resolved absolute filesystem path.
  /// Does **not** call [SandboxPathResolver.fix] / [resolveForIo].
  static Future<String> extractResolved({
    required String path,
    required String mime,
  }) {
    // Offload the heavy work to a separate isolate using compute.
    return compute(_extractTask, _ExtractorParams(path, mime));
  }

  /// The heavy extraction logic that runs in a background isolate.
  static String _extractTask(_ExtractorParams params) {
    final path = params.path;
    final mime = params.mime;

    try {
      final source = File(path);
      if (!source.existsSync()) return '[[File not found: $path]]';
      // Receiving a file is independent of inlining it in a model request.
      // Larger files remain available to workspace tools without a full read.
      if (source.lengthSync() > 16 * 1024 * 1024) {
        throw AttachmentRequiresWorkspace(p.basename(path));
      }
      if (mime == 'application/pdf') {
        try {
          final file = File(path);
          if (!file.existsSync()) return '[[File not found: $path]]';

          final bytes = file.readAsBytesSync();
          // Heavy synchronous PDF parsing happens here, in the sub-thread.
          final document = PdfDocument(inputBytes: bytes);
          final extractor = PdfTextExtractor(document);
          final extracted = extractor.extractText();
          final text = UnicodeSanitizer.sanitize(extracted);

          document.dispose();

          if (text.trim().isNotEmpty) return text;
          return '[PDF] Unable to extract text from file.';
        } catch (e) {
          return '[[Failed to read PDF: $e]]';
        }
      }

      if (mime == 'application/msword') {
        return '[[DOC format (.doc) not supported for text extraction]]';
      }

      if (mime ==
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
        return _extractDocxSync(path);
      }

      // Unknown types may be archives or executables. Probe a small prefix
      // before deciding whether a text read is useful.
      final probe = source.openSync();
      try {
        final prefix = probe.readSync(8192);
        if (prefix.contains(0)) {
          throw AttachmentRequiresWorkspace(p.basename(path));
        }
        final decoder = utf8.decoder.startChunkedConversion(
          StringConversionSink.fromStringSink(StringBuffer()),
        );
        try {
          decoder.add(prefix);
          if (source.lengthSync() <= prefix.length) decoder.close();
        } on FormatException {
          throw AttachmentRequiresWorkspace(p.basename(path));
        }
      } finally {
        probe.closeSync();
      }
      // Read only bounded, text-like files.
      final file = File(path);
      if (!file.existsSync()) return '[[File not found: $path]]';
      final bytes = file.readAsBytesSync();
      return UnicodeSanitizer.sanitize(
        utf8.decode(bytes, allowMalformed: true),
      );
    } on AttachmentRequiresWorkspace {
      rethrow;
    } catch (e) {
      return '[[Failed to read file: $e]]';
    }
  }

  /// Synchronous DOCX extraction for isolate use.
  static String _extractDocxSync(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return '[DOCX] file not found';

      final input = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(input);
      final docXml = archive.findFile('word/document.xml');
      if (docXml == null) return '[DOCX] document.xml not found';

      final xml = XmlDocument.parse(utf8.decode(docXml.content as List<int>));
      final buffer = StringBuffer();
      for (final p in xml.findAllElements('w:p')) {
        final texts = p.findAllElements('w:t');
        if (texts.isEmpty) {
          buffer.writeln();
          continue;
        }
        for (final t in texts) {
          buffer.write(t.innerText);
        }
        buffer.writeln();
      }
      return UnicodeSanitizer.sanitize(buffer.toString());
    } catch (e) {
      return '[[Failed to parse DOCX: $e]]';
    }
  }
}

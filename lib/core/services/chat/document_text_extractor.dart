import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/chat_input_data.dart';
import '../../utils/multimodal_input_utils.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/unicode_sanitizer.dart';
import 'text_file_decoder.dart';

export 'text_file_decoder.dart'
    show AttachmentProblem, AttachmentReadError, DocumentText;

typedef _Input = ({String path, String name, String mime});

class DocumentTextExtractor {
  static Future<DocumentText> extractResolved({
    required String path,
    required String mime,
    String? name,
  }) => compute(_extractTask, (
    path: path,
    mime: mime,
    name: name ?? p.basename(path),
  ));

  static DocumentText _extractTask(_Input input) {
    const docx =
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    final mime = input.mime.split(';').first.trim().toLowerCase();
    final structured =
        mime == 'application/pdf' ||
        mime == docx ||
        mime == 'application/msword';
    try {
      final file = File(input.path).openSync();
      late Uint8List bytes;
      late int size;
      try {
        size = file.lengthSync();
        if (structured && size > kMaxDocumentExtractBytes) {
          throw AttachmentReadError(AttachmentProblem.tooLarge, input.name);
        }
        if (mime == 'application/msword') {
          const text =
              '[[DOC format (.doc) not supported for text extraction]]';
          return DocumentText(text, count: text.length);
        }
        bytes = file.readSync(math.min(size, kMaxDocumentExtractBytes));
      } finally {
        file.closeSync();
      }
      if (!structured) {
        return decodeTextFile(
          bytes,
          name: input.name,
          byteLimit: size > kMaxDocumentExtractBytes,
        );
      }
      final String text;
      if (mime == 'application/pdf') {
        try {
          final document = PdfDocument(inputBytes: bytes);
          try {
            final extracted = UnicodeSanitizer.sanitize(
              PdfTextExtractor(document).extractText(),
            );
            text = extracted.trim().isNotEmpty
                ? extracted
                : '[PDF] Unable to extract text from file.';
          } finally {
            document.dispose();
          }
        } catch (e) {
          return DocumentText('[[Failed to read PDF: $e]]');
        }
      } else {
        text = _extractDocxSync(bytes);
      }
      return DocumentText(text, count: text.runes.length);
    } on FileSystemException {
      throw AttachmentReadError(AttachmentProblem.missing, input.name);
    }
  }

  /// Synchronous DOCX extraction for isolate use.
  static String _extractDocxSync(Uint8List input) {
    try {
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

typedef _Version = ({String path, String mime, DateTime modified, int size});

/// Shared by the composer, its send guard and prompt builder. Stat even on a
/// cache hit: a restored draft or a replaced/deleted file must be rechecked.
/// Cache the complete result (including truncation), never a localized notice.
class DocumentExtractionCache {
  final _entries = <_Version, Future<DocumentText>>{};

  _Version _version(File file, String mime, FileStat stat) =>
      (path: file.path, mime: mime, modified: stat.modified, size: stat.size);

  void _remember(_Version key, Future<DocumentText> result) {
    _entries[key] = result;
    if (_entries.length > 32) _entries.remove(_entries.keys.first);
  }

  /// Publication copies a private draft to a new path. Transfer the verified
  /// result only when its actual source is unchanged across the copy.
  Future<void> reusePublishedCopy(
    DocumentAttachment doc,
    File source,
    FileStat beforeCopy,
    File destination,
  ) async {
    final mime = resolveDocumentAttachmentMime(doc);
    final sourceVersion = _version(source, mime, beforeCopy);
    final cached = _entries[sourceVersion];
    if (cached == null) return;
    try {
      await cached;
      final after = await source.stat();
      final published = await destination.stat();
      if (after.type == FileSystemEntityType.file &&
          _version(source, mime, after) == sourceVersion &&
          published.type == FileSystemEntityType.file &&
          published.size == beforeCopy.size) {
        _remember(_version(destination, mime, published), cached);
      }
    } on AttachmentReadError {
      // Never copy failures: the published file gets its own preflight.
    } on FileSystemException {
      // If the copy or source disappeared, the normal send guard handles it.
    }
  }

  Future<DocumentText> read(DocumentAttachment file) async {
    final path = SandboxPathResolver.resolveForIo(file.path);
    if (path == null) {
      throw AttachmentReadError(AttachmentProblem.missing, file.fileName);
    }
    final mime = resolveDocumentAttachmentMime(file);
    final source = File(path);
    final FileStat stat;
    try {
      stat = await source.stat();
    } on FileSystemException {
      throw AttachmentReadError(AttachmentProblem.missing, file.fileName);
    }
    if (stat.type != FileSystemEntityType.file) {
      throw AttachmentReadError(AttachmentProblem.missing, file.fileName);
    }
    final key = _version(source, mime, stat);
    final result =
        _entries.remove(key) ??
        DocumentTextExtractor.extractResolved(path: path, mime: mime);
    _remember(key, result);
    try {
      return await result;
    } on AttachmentReadError catch (e) {
      if (identical(_entries[key], result)) _entries.remove(key);
      throw AttachmentReadError(e.problem, file.fileName);
    }
  }
}

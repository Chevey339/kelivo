import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/unicode_sanitizer.dart';

/// Data passed to the background isolate for document extraction.
class _ExtractorParams {
  final String path;
  final String mime;
  _ExtractorParams(this.path, this.mime);
}

class DocumentTextExtractor {
  /// Extracts text from a document file at [path] with [mime] type.
  /// This operation is performed in a background isolate to avoid blocking the UI.
  static Future<String> extract({required String path, required String mime}) async {
    // Fix path before passing to isolate (isolate has no access to main UI context)
    final fixedPath = SandboxPathResolver.fix(path);
    
    // Offload the heavy work to a separate isolate using compute.
    // This unblocks the main UI thread.
    return compute(_extractTask, _ExtractorParams(fixedPath, mime));
  }

  /// The heavy extraction logic that runs in a background isolate.
  static String _extractTask(_ExtractorParams params) {
    final path = params.path;
    final mime = params.mime;
    
    try {
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
      
      if (mime == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
        return _extractDocxSync(path);
      }
      
      // Fallback: read as plain text
      final file = File(path);
      if (!file.existsSync()) return '[[File not found: $path]]';
      final bytes = file.readAsBytesSync();
      return UnicodeSanitizer.sanitize(utf8.decode(bytes, allowMalformed: true));
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

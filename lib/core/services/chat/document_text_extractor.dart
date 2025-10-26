import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:flutter/services.dart';
import 'package:read_pdf_text/read_pdf_text.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/platform_utils.dart';

class DocumentTextExtractor {
  static Future<String> extract({required String path, required String mime}) async {
    try {
      // Remap old iOS sandbox path if needed
      final fixedPath = SandboxPathResolver.fix(path);
      if (mime == 'application/pdf') {
        // Check if platform supports PDF reading
        if (PlatformUtils.isWindows) {
          return '[[PDF text extraction is not yet supported on Windows]]';
        }
        
        try {
          final text = await PlatformUtils.callPlatformMethod(
            () => ReadPdfText.getPDFtext(fixedPath),
            fallback: '',
          );
          if (text != null && text.trim().isNotEmpty) return text;
        } on PlatformException catch (e) {
          return '[[Failed to read PDF: ${e.message ?? e.code}]]';
        } on MissingPluginException catch (_) {
          return '[[PDF text extraction plugin not available]]';
        } catch (e) {
          return '[[Failed to read PDF: $e]]';
        }
        return '[PDF] Unable to extract text from file.';
      }
      if (mime == 'application/msword') {
        return '[[DOC format (.doc) not supported for text extraction]]';
      }
      if (mime == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
        return await _extractDocx(path);
      }
      // Fallback: read as text
      final file = File(fixedPath);
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      return '[[Failed to read file: $e]]';
    }
  }

  static Future<String> _extractDocx(String path) async {
    try {
      final input = File(SandboxPathResolver.fix(path)).readAsBytesSync();
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
      return buffer.toString();
    } catch (e) {
      return '[[Failed to parse DOCX: $e]]';
    }
  }
}

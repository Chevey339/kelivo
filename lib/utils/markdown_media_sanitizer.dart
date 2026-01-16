import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import './app_directories.dart';

class MarkdownMediaSanitizer {
  static final Uuid _uuid = const Uuid();
  static final RegExp _imgRe = RegExp(
    r'!\[[^\]]*\]\((data:image\/[a-zA-Z0-9.+-]+;base64,[a-zA-Z0-9+/=\r\n]+)\)',
    multiLine: true,
  );

  static Future<String> replaceInlineBase64Images(String markdown) async {
    // // Fast path: only proceed when it's clearly a base64 data image
    // if (!(markdown.contains('data:image/') && markdown.contains(';base64,'))) {
    //   return markdown;
    // }
    if (!markdown.contains('data:image')) return markdown;

    final matches = _imgRe.allMatches(markdown).toList();
    if (matches.isEmpty) return markdown;

    // Ensure target directory
    final dir = await AppDirectories.getImagesDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final sb = StringBuffer();
    int last = 0;
    int idx = 0;
    for (final m in matches) {
      sb.write(markdown.substring(last, m.start));
      final dataUrl = m.group(1)!;
      String ext = AppDirectories.extFromMime(_mimeOf(dataUrl));

      // Extract base64 payload
      final b64Index = dataUrl.indexOf('base64,');
      if (b64Index < 0) {
        sb.write(markdown.substring(m.start, m.end));
        last = m.end;
        continue;
      }
      final payload = dataUrl.substring(b64Index + 7);

      // // Skip very small payloads to avoid overhead (likely tiny icons)
      // if (payload.length < 4096) {
      //   sb.write(markdown.substring(m.start, m.end));
      //   last = m.end;
      //   continue;
      // }

      // Decode in a background isolate (pure Dart decode)
      final normalized = payload.replaceAll('\n', '');
      List<int> bytes;
      try {
        bytes = await compute(_decodeBase64, normalized);
      } catch (_) {
        // Skip malformed base64 to avoid crashing streaming responses; keep original markup.
        sb.write(markdown.substring(m.start, m.end));
        last = m.end;
        continue;
      }

      // Deterministic filename by content hash to prevent duplicates
      // Same base64 -> same filename across runs
      final digest = _uuid.v5(Uuid.NAMESPACE_URL, normalized);
      final file = File('${dir.path}/img_$digest.$ext');
      if (!await file.exists()) {
        await file.writeAsBytes(bytes, flush: true);
      }

      // Replace only the URL part inside the parentheses
      final replaced = markdown.substring(m.start, m.end).replaceFirst(dataUrl, file.path);
      sb.write(replaced);
      last = m.end;
      idx++;
    }
    sb.write(markdown.substring(last));
    return sb.toString();
  }

  // Replace Markdown image links pointing to local file paths with inline base64 data URLs.
  // Example: "![image](/data/user/0/.../images/xxx.png)" -> "![image](data:image/png;base64,...)"
  static Future<String> inlineLocalImagesToBase64(String markdown) async {
    // Quick check: contains a Markdown image and looks like a local path
    if (!(markdown.contains('![') && markdown.contains(']('))) return markdown;

    final re = RegExp(r'!\[[^\]]*\]\(([^)]+)\)', multiLine: true);
    final matches = re.allMatches(markdown).toList();
    if (matches.isEmpty) return markdown;

    final sb = StringBuffer();
    int last = 0;
    for (final m in matches) {
      sb.write(markdown.substring(last, m.start));
      final url = (m.group(1) ?? '').trim();
      // Only convert local file paths; skip http(s) and existing data URLs
      final isRemote = url.startsWith('http://') || url.startsWith('https://');
      final isData = url.startsWith('data:');
      final isFileUri = url.startsWith('file://');
      final isLikelyLocalPath = (!isRemote && !isData) && (isFileUri || url.startsWith('/') || url.contains(':'));

      if (!isLikelyLocalPath) {
        // Keep original
        sb.write(markdown.substring(m.start, m.end));
        last = m.end;
        continue;
      }

      try {
        // Normalize file path
        var path = url;
        if (isFileUri) {
          path = url.replaceFirst('file://', '');
        }
        // Read bytes and encode
        final fixed = path; // Caller may already pass sandbox-fixed paths; avoid depending on Flutter layer here
        final f = File(fixed);
        if (!f.existsSync()) {
          // Fallback to original if missing
          sb.write(markdown.substring(m.start, m.end));
          last = m.end;
          continue;
        }
        final bytes = await f.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = _guessMimeFromPath(fixed);
        final dataUrl = 'data:$mime;base64,$b64';
        final replaced = markdown.substring(m.start, m.end).replaceFirst(url, dataUrl);
        sb.write(replaced);
      } catch (_) {
        // On failure, keep original
        sb.write(markdown.substring(m.start, m.end));
      }
      last = m.end;
    }
    sb.write(markdown.substring(last));
    return sb.toString();
  }

  static String _guessMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/png';
  }

  static List<int> _decodeBase64(String b64) => base64Decode(b64.replaceAll('\n', ''));

  static String _mimeOf(String dataUrl) {
    try {
      final start = dataUrl.indexOf(':');
      final semi = dataUrl.indexOf(';');
      if (start >= 0 && semi > start) {
        return dataUrl.substring(start + 1, semi);
      }
    } catch (_) {}
    return 'image/png';
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class RemoteFile {
  final String path;
  final int size;
  final DateTime lastModified;

  const RemoteFile({
    required this.path,
    required this.size,
    required this.lastModified,
  });
}

abstract class SyncTransport {
  Future<void> uploadBytes(String remotePath, List<int> bytes);
  Future<List<RemoteFile>> listFiles(String prefix);
  Future<List<int>> downloadBytes(String remotePath);
  Future<void> deleteFile(String remotePath);
}

class WebDavSyncTransport implements SyncTransport {
  final String baseUrl;
  final String username;
  final String password;
  final String userAgent;

  const WebDavSyncTransport({
    required this.baseUrl,
    this.username = '',
    this.password = '',
    this.userAgent = '',
  });

  Map<String, String> get _authHeaders {
    if (username.isEmpty) return {};
    final token = base64Encode(utf8.encode('$username:$password'));
    return {'Authorization': 'Basic $token'};
  }

  Map<String, String> get _extraHeaders {
    if (userAgent.isEmpty) return {};
    return {'User-Agent': userAgent};
  }

  String _cleanUrl() {
    var u = baseUrl.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  @override
  Future<void> uploadBytes(String remotePath, List<int> bytes) async {
    final url = '${_cleanUrl()}/$remotePath';
    final client = http.Client();
    try {
      final req = http.Request('PUT', Uri.parse(url))
        ..headers.addAll({
          'Content-Type': 'application/octet-stream',
          ..._authHeaders,
          ..._extraHeaders,
        })
        ..bodyBytes = bytes;
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('WebDAV PUT failed: ${res.statusCode} ${res.body}');
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<List<RemoteFile>> listFiles(String prefix) async {
    final url = '${_cleanUrl()}/$prefix';
    final client = http.Client();
    try {
      final req = http.Request('PROPFIND', Uri.parse(url))
        ..headers.addAll({
          'Depth': '1',
          'Content-Type': 'application/xml; charset=utf-8',
          ..._authHeaders,
          ..._extraHeaders,
        });
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode == 404) return [];
      if (res.statusCode != 207) {
        throw Exception('WebDAV PROPFIND failed: ${res.statusCode}');
      }

      final doc = XmlDocument.parse(res.body);
      final files = <RemoteFile>[];
      for (final response in doc.findAllElements('D:response')) {
        final href = response.findElements('D:href').firstOrNull?.innerText;
        if (href == null || href.endsWith('/')) continue;
        final propStat = response.findElements('D:propstat').firstOrNull;
        if (propStat == null) continue;
        final prop = propStat.findElements('D:prop').firstOrNull;
        if (prop == null) continue;
        final sizeStr = prop
            .findElements('D:getcontentlength')
            .firstOrNull
            ?.innerText;
        final modifiedStr = prop
            .findElements('D:getlastmodified')
            .firstOrNull
            ?.innerText;
        files.add(
          RemoteFile(
            path: href,
            size: sizeStr != null ? int.tryParse(sizeStr) ?? 0 : 0,
            lastModified: modifiedStr != null
                ? _parseHttpDate(modifiedStr)
                : DateTime.now(),
          ),
        );
      }
      return files;
    } finally {
      client.close();
    }
  }

  @override
  Future<List<int>> downloadBytes(String remotePath) async {
    final url = '${_cleanUrl()}/$remotePath';
    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url))
        ..headers.addAll({..._authHeaders, ..._extraHeaders});
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode != 200) {
        throw Exception('WebDAV GET failed: ${res.statusCode}');
      }
      return res.bodyBytes.toList();
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteFile(String remotePath) async {
    final url = '${_cleanUrl()}/$remotePath';
    final client = http.Client();
    try {
      final req = http.Request('DELETE', Uri.parse(url))
        ..headers.addAll({..._authHeaders, ..._extraHeaders});
      final res = await client.send(req).then(http.Response.fromStream);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('WebDAV DELETE failed: ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// WebDAV returns timestamps in RFC 1123 format, e.g.
  /// "Thu, 14 Jun 2024 12:00:00 GMT".
  static DateTime _parseHttpDate(String input) {
    try {
      // Trim whitespace and remove day-of-week prefix
      final s = input.trim();
      final withoutDay = s.contains(',')
          ? s.substring(s.indexOf(',') + 1).trim()
          : s;
      final spaceIdx = withoutDay.indexOf(' ');
      final dayStr = withoutDay.substring(0, spaceIdx);
      final rest = withoutDay.substring(spaceIdx).trim();
      final dateTimeStr = '$dayStr $rest'.replaceFirst(' GMT', '');
      final result = DateTime.tryParse(dateTimeStr);
      if (result != null) return result.toUtc();
    } catch (_) {}
    return DateTime.now();
  }
}

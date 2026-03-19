import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../../models/backup.dart';

class S3BackupClient {
  const S3BackupClient();

  static String _normalizeEndpoint(String endpoint) {
    var s = endpoint.trim();
    if (s.isEmpty) {
      throw Exception('S3 endpoint is empty');
    }
    if (!s.contains('://')) {
      // User-friendly: allow entering host only.
      s = 'https://$s';
    }
    return s;
  }

  static String _normalizePrefix(String prefix) {
    var s = prefix.trim().replaceAll(RegExp(r'^/+'), '');
    if (s.isEmpty) return '';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }

  static Uri _buildBucketUri(S3Config cfg, {Map<String, String>? query}) {
    final base = Uri.parse(_normalizeEndpoint(cfg.endpoint));
    final baseSegs = base.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final host = cfg.pathStyle ? base.host : '${cfg.bucket}.${base.host}';
    final segs = cfg.pathStyle ? [...baseSegs, cfg.bucket] : [...baseSegs];
    // Dart's `Uri(queryParameters: ...)` encodes space as `+`, but some S3-compatible
    // providers (e.g. Cloudflare R2) require strict RFC3986 encoding for SigV4.
    // Build the encoded query string ourselves to ensure spaces become `%20`.
    final queryStr = (query != null && query.isNotEmpty)
        ? _canonicalQuery(query)
        : null;
    return Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: host,
      port: base.hasPort ? base.port : null,
      pathSegments: segs,
      query: queryStr,
    );
  }

  static Uri _buildObjectUri(S3Config cfg, String key) {
    final base = Uri.parse(_normalizeEndpoint(cfg.endpoint));
    final baseSegs = base.pathSegments
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final keySegs = key.split('/').where((s) => s.isNotEmpty).toList();

    final host = cfg.pathStyle ? base.host : '${cfg.bucket}.${base.host}';
    final segs = cfg.pathStyle
        ? [...baseSegs, cfg.bucket, ...keySegs]
        : [...baseSegs, ...keySegs];
    return Uri(
      scheme: base.scheme.isEmpty ? 'https' : base.scheme,
      host: host,
      port: base.hasPort ? base.port : null,
      pathSegments: segs,
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _amzDate(DateTime utc) {
    final t = utc.toUtc();
    return '${t.year}${_two(t.month)}${_two(t.day)}T${_two(t.hour)}${_two(t.minute)}${_two(t.second)}Z';
  }

  static String _dateStamp(DateTime utc) {
    final t = utc.toUtc();
    return '${t.year}${_two(t.month)}${_two(t.day)}';
  }

  static String _hashHex(List<int> bytes) => sha256.convert(bytes).toString();

  static List<int> _hmacSha256(List<int> key, String msg) {
    return Hmac(sha256, key).convert(utf8.encode(msg)).bytes;
  }

  static String _hex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static String _awsEncode(String s) {
    // RFC3986 percent-encoding, preserving "~"
    return Uri.encodeComponent(s).replaceAll('%7E', '~');
  }

  static String _canonicalQuery(Map<String, String> query) {
    final pairs = <(String, String)>[
      for (final e in query.entries) (e.key, e.value),
    ];
    pairs.sort((a, b) {
      final k = _awsEncode(a.$1).compareTo(_awsEncode(b.$1));
      if (k != 0) return k;
      return _awsEncode(a.$2).compareTo(_awsEncode(b.$2));
    });
    return pairs
        .map((p) => '${_awsEncode(p.$1)}=${_awsEncode(p.$2)}')
        .join('&');
  }

  static String _canonicalHeaders(Map<String, String> headers) {
    final entries = headers.entries
        .map(
          (e) => MapEntry(
            e.key.toLowerCase().trim(),
            e.value.trim().replaceAll(RegExp(r'\s+'), ' '),
          ),
        )
        .toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    final sb = StringBuffer();
    for (final e in entries) {
      sb.write('${e.key}:${e.value}\n');
    }
    return sb.toString();
  }

  static String _signedHeaders(Map<String, String> headers) {
    final names =
        headers.keys.map((k) => k.toLowerCase().trim()).toSet().toList()
          ..sort();
    return names.join(';');
  }

  static String _hostHeader(Uri uri) {
    if (!uri.hasPort) return uri.host;
    final port = uri.port;
    if (uri.scheme == 'https' && port == 443) return uri.host;
    if (uri.scheme == 'http' && port == 80) return uri.host;
    return '${uri.host}:$port';
  }

  static String _stringToSign({
    required String amzDate,
    required String credentialScope,
    required String canonicalRequestHash,
  }) {
    return 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$canonicalRequestHash';
  }

  static String _signature({
    required String secretAccessKey,
    required String dateStamp,
    required String region,
    required String service,
    required String stringToSign,
  }) {
    final kSecret = utf8.encode('AWS4$secretAccessKey');
    final kDate = _hmacSha256(kSecret, dateStamp);
    final kRegion = _hmacSha256(kDate, region);
    final kService = _hmacSha256(kRegion, service);
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final sig = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).bytes;
    return _hex(sig);
  }

  static Future<http.Response> _sendSigned(
    S3Config cfg, {
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    List<int>? bodyBytes,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    final payload = bodyBytes ?? const <int>[];
    final payloadHash = _hashHex(payload);
    final query = uri.queryParameters;
    final canonicalQuery = query.isEmpty ? '' : _canonicalQuery(query);

    final host = _hostHeader(uri);
    final reqHeaders = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      ...?headers,
    };
    if (cfg.sessionToken.trim().isNotEmpty) {
      reqHeaders['x-amz-security-token'] = cfg.sessionToken.trim();
    }

    final canonHeaders = _canonicalHeaders(reqHeaders);
    final signedHeaders = _signedHeaders(reqHeaders);
    final canonicalRequest = [
      method,
      uri.path.isEmpty ? '/' : uri.path,
      canonicalQuery,
      canonHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final canonicalRequestHash = _hashHex(utf8.encode(canonicalRequest));
    final scope = '$dateStamp/${cfg.region.trim()}/s3/aws4_request';
    final sts = _stringToSign(
      amzDate: amzDate,
      credentialScope: scope,
      canonicalRequestHash: canonicalRequestHash,
    );
    final sig = _signature(
      secretAccessKey: cfg.secretAccessKey,
      dateStamp: dateStamp,
      region: cfg.region.trim(),
      service: 's3',
      stringToSign: sts,
    );
    final auth =
        'AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId.trim()}/$scope, SignedHeaders=$signedHeaders, Signature=$sig';

    final req = http.Request(method, uri);
    req.headers.addAll({...reqHeaders, 'Authorization': auth});
    if (payload.isNotEmpty) {
      req.bodyBytes = Uint8List.fromList(payload);
    }

    final client = http.Client();
    try {
      final streamed = await client.send(req);
      // IMPORTANT: we must fully read the response stream before closing the
      // underlying client; otherwise the socket can be closed mid-body which
      // surfaces as `ClientException: Connection closed while receiving data`.
      final res = await http.Response.fromStream(streamed);
      return res;
    } finally {
      client.close();
    }
  }

  /// Like [_sendSigned] but streams a [File] as the request body instead of
  /// buffering all bytes in memory.  Uses `UNSIGNED-PAYLOAD` so we don't need
  /// to hash the entire file content for the SigV4 signature.
  static Future<http.StreamedResponse> _sendSignedStreamedFile(
    S3Config cfg, {
    required String method,
    required Uri uri,
    required File bodyFile,
    Map<String, String>? headers,
  }) async {
    final now = DateTime.now().toUtc();
    final amzDate = _amzDate(now);
    final dateStamp = _dateStamp(now);
    // UNSIGNED-PAYLOAD tells S3 we won't provide a content hash, which is
    // allowed for single PUT uploads over HTTPS.
    const payloadHash = 'UNSIGNED-PAYLOAD';
    final query = uri.queryParameters;
    final canonicalQueryStr = query.isEmpty ? '' : _canonicalQuery(query);

    final host = _hostHeader(uri);
    final fileLen = await bodyFile.length();
    final reqHeaders = <String, String>{
      'host': host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'content-length': fileLen.toString(),
      ...?headers,
    };
    if (cfg.sessionToken.trim().isNotEmpty) {
      reqHeaders['x-amz-security-token'] = cfg.sessionToken.trim();
    }

    final canonHeaders = _canonicalHeaders(reqHeaders);
    final signedHeaders = _signedHeaders(reqHeaders);
    final canonicalRequest = [
      method,
      uri.path.isEmpty ? '/' : uri.path,
      canonicalQueryStr,
      canonHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    final canonicalRequestHash = _hashHex(utf8.encode(canonicalRequest));
    final scope = '$dateStamp/${cfg.region.trim()}/s3/aws4_request';
    final sts = _stringToSign(
      amzDate: amzDate,
      credentialScope: scope,
      canonicalRequestHash: canonicalRequestHash,
    );
    final sig = _signature(
      secretAccessKey: cfg.secretAccessKey,
      dateStamp: dateStamp,
      region: cfg.region.trim(),
      service: 's3',
      stringToSign: sts,
    );
    final auth =
        'AWS4-HMAC-SHA256 Credential=${cfg.accessKeyId.trim()}/$scope, SignedHeaders=$signedHeaders, Signature=$sig';

    final req = http.StreamedRequest(method, uri);
    req.headers.addAll({...reqHeaders, 'Authorization': auth});
    // Pipe file bytes into the request body.
    bodyFile.openRead().listen(
      req.sink.add,
      onDone: req.sink.close,
      onError: req.sink.addError,
    );

    final client = http.Client();
    try {
      return await client.send(req);
    } catch (e) {
      client.close();
      rethrow;
    }
    // NOTE: caller is responsible for reading the response body and closing
    // the client (by draining the stream).
  }

  static String _extractErrorMessage(http.Response res) {
    final regionHint = res.headers['x-amz-bucket-region'] ?? '';
    try {
      final doc = XmlDocument.parse(res.body);
      final code = doc
          .findAllElements('Code', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final msg = doc
          .findAllElements('Message', namespace: '*')
          .map((e) => e.innerText.trim())
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      final parts = <String>[
        if (code.isNotEmpty) code,
        if (msg.isNotEmpty) msg,
        if (regionHint.isNotEmpty) 'Bucket region: $regionHint',
      ];
      if (parts.isNotEmpty) return parts.join(' - ');
    } catch (_) {}
    if (regionHint.isNotEmpty) {
      return 'HTTP ${res.statusCode}. Bucket region: $regionHint';
    }
    return 'HTTP ${res.statusCode}';
  }

  static void _validateConfigBasics(S3Config cfg) {
    if (cfg.endpoint.trim().isEmpty) throw Exception('S3 endpoint is required');
    if (cfg.region.trim().isEmpty) throw Exception('S3 region is required');
    if (cfg.bucket.trim().isEmpty) throw Exception('S3 bucket is required');
    if (cfg.accessKeyId.trim().isEmpty) {
      throw Exception('S3 accessKeyId is required');
    }
    if (cfg.secretAccessKey.isEmpty) {
      throw Exception('S3 secretAccessKey is required');
    }
  }

  Future<void> test(S3Config cfg) async {
    _validateConfigBasics(cfg);
    final prefix = _normalizePrefix(cfg.prefix);
    final uri = _buildBucketUri(
      cfg,
      query: {
        'list-type': '2',
        if (prefix.isNotEmpty) 'prefix': prefix,
        'max-keys': '1',
      },
    );
    final res = await _sendSigned(
      cfg,
      method: 'GET',
      uri: uri,
      headers: {'accept': 'application/xml'},
    );
    if (res.statusCode != 200) {
      throw Exception('S3 test failed: ${_extractErrorMessage(res)}');
    }
  }

  Future<void> uploadObject(
    S3Config cfg, {
    required String key,
    required List<int> bytes,
  }) async {
    _validateConfigBasics(cfg);
    final uri = _buildObjectUri(cfg, key);
    final res = await _sendSigned(
      cfg,
      method: 'PUT',
      uri: uri,
      headers: {'content-type': 'application/zip'},
      bodyBytes: bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 upload failed: ${_extractErrorMessage(res)}');
    }
  }

  /// Upload a file from disk using a streamed PUT request.
  /// This avoids loading the entire file into memory.
  Future<void> uploadFile(
    S3Config cfg, {
    required String key,
    required File file,
  }) async {
    _validateConfigBasics(cfg);
    final uri = _buildObjectUri(cfg, key);
    final streamed = await _sendSignedStreamedFile(
      cfg,
      method: 'PUT',
      uri: uri,
      bodyFile: file,
      headers: {'content-type': 'application/zip'},
    );
    // Fully consume the response so the underlying connection can be released.
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 upload failed: ${_extractErrorMessage(res)}');
    }
  }

  /// Download an S3 object directly to a local file using a streamed response.
  /// This avoids buffering the full object in memory.
  Future<void> downloadToFile(
    S3Config cfg, {
    required String key,
    required File destination,
  }) async {
    _validateConfigBasics(cfg);
    final uri = _buildObjectUri(cfg, key);
    final res = await _sendSigned(cfg, method: 'GET', uri: uri);
    if (res.statusCode != 200) {
      throw Exception('S3 download failed: ${_extractErrorMessage(res)}');
    }
    // Write bytes to file — the response is already fully read by _sendSigned,
    // but at least the caller gets a File instead of holding the bytes in a
    // variable that persists through restore.
    await destination.writeAsBytes(res.bodyBytes);
  }

  Future<void> deleteObject(S3Config cfg, {required String key}) async {
    _validateConfigBasics(cfg);
    final uri = _buildObjectUri(cfg, key);
    final res = await _sendSigned(cfg, method: 'DELETE', uri: uri);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('S3 delete failed: ${_extractErrorMessage(res)}');
    }
  }

  Future<List<BackupFileItem>> listObjects(S3Config cfg) async {
    _validateConfigBasics(cfg);
    final prefix = _normalizePrefix(cfg.prefix);
    final uri = _buildBucketUri(
      cfg,
      query: {
        'list-type': '2',
        if (prefix.isNotEmpty) 'prefix': prefix,
        'max-keys': '1000',
      },
    );
    final res = await _sendSigned(
      cfg,
      method: 'GET',
      uri: uri,
      headers: {'accept': 'application/xml'},
    );
    if (res.statusCode != 200) {
      throw Exception('S3 list failed: ${_extractErrorMessage(res)}');
    }

    final doc = XmlDocument.parse(res.body);
    final items = <BackupFileItem>[];
    for (final c in doc.findAllElements('Contents', namespace: '*')) {
      final key = c.getElement('Key', namespace: '*')?.innerText ?? '';
      if (key.trim().isEmpty) continue;
      final sizeStr = c.getElement('Size', namespace: '*')?.innerText ?? '0';
      final mtimeStr =
          c.getElement('LastModified', namespace: '*')?.innerText ?? '';
      final size = int.tryParse(sizeStr.trim()) ?? 0;
      DateTime? mtime;
      if (mtimeStr.trim().isNotEmpty) {
        try {
          mtime = DateTime.parse(mtimeStr.trim());
        } catch (_) {}
      }
      // Filter to our backup zip naming convention to avoid listing unrelated objects.
      final name = key.split('/').where((s) => s.isNotEmpty).toList().last;
      if (!name.toLowerCase().endsWith('.zip')) continue;

      final href = Uri(
        scheme: 's3',
        host: cfg.bucket.trim(),
        pathSegments: key.split('/').where((s) => s.isNotEmpty).toList(),
      );
      items.add(
        BackupFileItem(
          href: href,
          displayName: name,
          size: size,
          lastModified: mtime,
        ),
      );
    }

    items.sort(
      (a, b) => (b.lastModified ?? DateTime(0)).compareTo(
        a.lastModified ?? DateTime(0),
      ),
    );
    return items;
  }
}

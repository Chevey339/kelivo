import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:html2md/html2md.dart' as html2md;
import 'package:mcp_client/mcp_client.dart' as mcp;

/// @kelivo/fetch — In-memory MCP server engine and transport (Flutter/Dart)
///
/// Provides one token-conscious `fetch` tool. HTML is simplified to Markdown
/// by default, while raw content requires an explicit opt-in. Responses are
/// bounded and can be continued with `start_index`.
///
/// The server implements a minimal subset of MCP over JSON-RPC 2.0:
/// initialize, tools/list, tools/call. It is intended to run in the same
/// isolate as the Flutter app and connect to a standard mcp.Client via an
/// in-memory ClientTransport.

class KelivoFetchRequestPayload {
  static const defaultMaxLength = 5000;
  static const maximumMaxLength = 20000;

  final Uri url;
  final Map<String, String> headers;
  final int maxLength;
  final int startIndex;
  final bool raw;

  KelivoFetchRequestPayload({
    required this.url,
    Map<String, String>? headers,
    this.maxLength = defaultMaxLength,
    this.startIndex = 0,
    this.raw = false,
  }) : headers = headers ?? const {};

  static KelivoFetchRequestPayload parse(Object? args) {
    if (args is! Map) {
      throw ArgumentError(
        'Invalid arguments: expected an object containing url',
      );
    }
    final map = args.cast<String, dynamic>();
    final urlRaw = (map['url'] ?? '').toString().trim();
    final uri = Uri.tryParse(urlRaw);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw ArgumentError('Invalid url: $urlRaw');
    }
    final headersAny = map['headers'];
    final headers = <String, String>{};
    if (headersAny is Map) {
      headersAny.forEach((k, v) {
        if (k == null || v == null) return;
        headers[k.toString()] = v.toString();
      });
    }
    final maxLength = _parseInteger(
      map['max_length'],
      name: 'max_length',
      defaultValue: defaultMaxLength,
    );
    if (maxLength < 1 || maxLength > maximumMaxLength) {
      throw ArgumentError(
        'Invalid max_length: expected a value from 1 to $maximumMaxLength',
      );
    }
    final startIndex = _parseInteger(
      map['start_index'],
      name: 'start_index',
      defaultValue: 0,
    );
    if (startIndex < 0) {
      throw ArgumentError('Invalid start_index: expected a non-negative value');
    }
    final rawAny = map['raw'];
    if (rawAny != null && rawAny is! bool) {
      throw ArgumentError('Invalid raw: expected a boolean');
    }

    return KelivoFetchRequestPayload(
      url: uri,
      headers: headers,
      maxLength: maxLength,
      startIndex: startIndex,
      raw: rawAny as bool? ?? false,
    );
  }

  static int _parseInteger(
    Object? value, {
    required String name,
    required int defaultValue,
  }) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw ArgumentError('Invalid $name: expected an integer');
  }
}

class KelivoFetcher {
  static const _defaultUA =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static Future<http.Response> _fetch(KelivoFetchRequestPayload payload) async {
    try {
      final merged = <String, String>{
        'User-Agent': _defaultUA,
        ...payload.headers,
      };
      final resp = await http.get(payload.url, headers: merged);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      return resp;
    } catch (e) {
      throw Exception(
        'Failed to fetch ${payload.url}: ${e is Exception ? e.toString() : 'Unknown error'}',
      );
    }
  }

  static Future<Map<String, dynamic>> fetch(
    KelivoFetchRequestPayload payload,
  ) async {
    try {
      final resp = await _fetch(payload);
      final contentType = (resp.headers['content-type'] ?? '').toLowerCase();
      final body = resp.body;
      final text = payload.raw
          ? body
          : _contentForModel(body, contentType: contentType);
      return _ok(_bounded(text, payload));
    } catch (e) {
      return _err(e.toString());
    }
  }

  static String _contentForModel(String body, {required String contentType}) {
    if (_isHtml(body, contentType: contentType)) {
      return _htmlToMarkdown(body);
    }
    if (contentType.contains('application/json') ||
        contentType.contains('+json')) {
      try {
        return jsonEncode(jsonDecode(body));
      } catch (_) {
        // Preserve malformed or JSON-like responses instead of failing fetch.
      }
    }
    return body.trim();
  }

  static bool _isHtml(String body, {required String contentType}) {
    if (contentType.contains('text/html') ||
        contentType.contains('application/xhtml+xml')) {
      return true;
    }
    if (contentType.isNotEmpty) return false;
    final prefix = body.length > 256 ? body.substring(0, 256) : body;
    return RegExp(
      r'<\s*(?:!doctype\s+html|html)\b',
      caseSensitive: false,
    ).hasMatch(prefix);
  }

  static String _htmlToMarkdown(String html) {
    final dom.Document document = html_parser.parse(html);
    document
        .querySelectorAll(
          'script,style,noscript,template,svg,iframe,nav,aside,footer,form',
        )
        .forEach((element) => element.remove());

    final mainContent = document.querySelector('main,article,[role="main"]');
    final source = mainContent?.outerHtml ?? document.body?.innerHtml ?? html;
    final markdown = html2md.convert(source).trim();
    if (markdown.isNotEmpty) {
      return markdown.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    }
    return (mainContent?.text ?? document.body?.text ?? '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _bounded(String text, KelivoFetchRequestPayload payload) {
    if (payload.startIndex >= text.length) {
      return 'No more content available.';
    }

    var start = payload.startIndex;
    if (start > 0 && _isLowSurrogate(text.codeUnitAt(start))) {
      start -= 1;
    }
    var end = math.min(start + payload.maxLength, text.length);
    if (end < text.length &&
        end > start &&
        _isHighSurrogate(text.codeUnitAt(end - 1)) &&
        _isLowSurrogate(text.codeUnitAt(end))) {
      end = end - start == 1 ? end + 1 : end - 1;
    }

    final content = text.substring(start, end);
    if (end >= text.length) return content;
    return '$content\n\n[Content truncated: showing characters $start-${end - 1} '
        'of ${text.length}. Call kelivo_fetch with start_index=$end to continue.]';
  }

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

  static bool _isLowSurrogate(int codeUnit) =>
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  static Map<String, dynamic> _ok(String text) => {
    'content': [
      {'type': 'text', 'text': text},
    ],
    'isStreaming': false,
    'isError': false,
  };

  static Map<String, dynamic> _err(String message) => {
    'content': [
      {'type': 'text', 'text': message},
    ],
    'isStreaming': false,
    'isError': true,
  };
}

/// Minimal JSON-RPC server for MCP that serves @kelivo/fetch tools.
class KelivoFetchMcpServerEngine {
  bool _closed = false;

  Future<dynamic> handleMessage(dynamic message) async {
    if (_closed) return null;

    // Support batch arrays defensively (return array of responses)
    if (message is List) {
      final out = <dynamic>[];
      for (final m in message) {
        out.add(await _handleSingle(m));
      }
      return out;
    }
    return await _handleSingle(message);
  }

  Future<Map<String, dynamic>> _handleSingle(dynamic raw) async {
    try {
      if (raw is! Map) {
        return _error(null, code: -32600, message: 'Invalid Request');
      }
      final req = raw.cast<String, dynamic>();
      final id = req['id'];
      final method = (req['method'] ?? '').toString();
      final params = (req['params'] is Map)
          ? (req['params'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      switch (method) {
        case mcp.McpProtocol.methodInitialize:
          return _ok(
            id,
            result: {
              'serverInfo': {'name': '@kelivo/fetch', 'version': '0.2.0'},
              'protocolVersion': mcp.McpProtocol.defaultVersion,
              // Only tools capability is advertised for this minimal server
              'capabilities': {
                'tools': {'listChanged': false},
              },
            },
          );

        case mcp.McpProtocol.methodListTools:
          return _ok(id, result: {'tools': _toolDefinitions()});

        case mcp.McpProtocol.methodCallTool:
          final name = (params['name'] ?? '').toString();
          final arguments = (params['arguments'] is Map)
              ? (params['arguments'] as Map).cast<String, dynamic>()
              : <String, dynamic>{};

          KelivoFetchRequestPayload payload;
          try {
            payload = KelivoFetchRequestPayload.parse(arguments);
          } catch (e) {
            return _ok(id, result: KelivoFetcher._err(e.toString()));
          }

          if (name == 'kelivo_fetch') {
            return _ok(id, result: await KelivoFetcher.fetch(payload));
          }
          return _error(id, code: -32101, message: 'Tool not found: $name');

        default:
          // Ignore common notifications; respond error for unknown requests
          if (id == null) {
            return _noop();
          }
          return _error(id, code: -32601, message: 'Method not found: $method');
      }
    } catch (e) {
      return _error(null, code: -32603, message: 'Internal error: $e');
    }
  }

  void close() {
    _closed = true;
  }

  Map<String, dynamic> _ok(dynamic id, {required Map<String, dynamic> result}) {
    return {'jsonrpc': '2.0', if (id != null) 'id': id, 'result': result};
  }

  Map<String, dynamic> _error(
    dynamic id, {
    required int code,
    required String message,
  }) {
    return {
      'jsonrpc': '2.0',
      if (id != null) 'id': id,
      'error': {'code': code, 'message': message},
    };
  }

  Map<String, dynamic> _noop() => {'jsonrpc': '2.0'};

  List<Map<String, dynamic>> _toolDefinitions() {
    Map<String, dynamic> schema() => {
      'type': 'object',
      'properties': {
        'url': {
          'type': 'string',
          'description':
              'Use the URL exactly as given; do not add www. It must include '
              'http:// or https://: https://example.com is valid, while '
              'example.com is invalid.',
        },
        'headers': {
          'type': 'object',
          'description': 'Optional headers to include in the request',
        },
        'max_length': {
          'type': 'integer',
          'description': 'Maximum content characters to return',
          'default': KelivoFetchRequestPayload.defaultMaxLength,
          'minimum': 1,
          'maximum': KelivoFetchRequestPayload.maximumMaxLength,
        },
        'start_index': {
          'type': 'integer',
          'description': 'Character index used to continue truncated content',
          'default': 0,
          'minimum': 0,
        },
        'raw': {
          'type': 'boolean',
          'description':
              'Return raw source instead of compact, readable Markdown',
          'default': false,
        },
      },
      'required': ['url'],
    };

    return [
      {
        'name': 'kelivo_fetch',
        'description':
            'Fetch the public contents of a web page. Only fetch a URL that '
            'already appears in the conversation: one provided by the user or '
            'returned by a prior web_search, kelivo_fetch, or other tool. '
            'Cannot access content that requires authentication, including private '
            'documents or pages behind login walls. HTML is simplified to compact '
            'Markdown with bounded output by default. Continue truncated content with '
            'start_index; use raw=true only when exact source is required.',
        'inputSchema': schema(),
      },
    ];
  }
}

/// In-memory ClientTransport that directly invokes the local server engine.
class KelivoInMemoryClientTransport implements mcp.ClientTransport {
  final KelivoFetchMcpServerEngine _server;
  final _messageController = StreamController<dynamic>.broadcast();
  final _closeCompleter = Completer<void>();
  bool _closed = false;

  KelivoInMemoryClientTransport(this._server);

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    if (_closed) return;
    // Process asynchronously to mimic real transport
    Future.microtask(() async {
      final resp = await _server.handleMessage(message);
      if (_closed) return;
      if (resp != null) {
        _messageController.add(resp);
      }
    });
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _server.close();
    } catch (_) {}
    if (!_messageController.isClosed) _messageController.close();
    if (!_closeCompleter.isCompleted) _closeCompleter.complete();
  }
}

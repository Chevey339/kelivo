import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:html2md/html2md.dart' as html2md;
import 'package:mcp_client/mcp_client.dart' as mcp;

/// @kelivo/fetch — In-memory MCP server engine and transport (Flutter/Dart)
///
/// Provides four tools:
/// - fetch_html     → returns raw HTML text
/// - fetch_markdown → HTML converted to Markdown
/// - fetch_txt      → plain text (script/style removed, whitespace collapsed)
/// - fetch_json     → JSON stringified
///
/// The server implements a minimal subset of MCP over JSON-RPC 2.0:
/// initialize, tools/list, tools/call. It is intended to run in the same
/// isolate as the Flutter app and connect to a standard mcp.Client via an
/// in-memory ClientTransport.

class KelivoFetchRequestPayload {
  final Uri url;
  final Map<String, String> headers;

  KelivoFetchRequestPayload({required this.url, Map<String, String>? headers})
    : headers = headers ?? const {};

  static KelivoFetchRequestPayload parse(Object? args) {
    if (args is! Map) {
      throw ArgumentError(
        'Invalid arguments: expected object with url[, headers]',
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
    return KelivoFetchRequestPayload(url: uri, headers: headers);
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

  static Future<Map<String, dynamic>> html(
    KelivoFetchRequestPayload payload,
  ) async {
    try {
      final resp = await _fetch(payload);
      final text = resp.body;
      return _ok(text);
    } catch (e) {
      return _err(e.toString());
    }
  }

  static Future<Map<String, dynamic>> json(
    KelivoFetchRequestPayload payload,
  ) async {
    try {
      final resp = await _fetch(payload);
      final raw = resp.body;
      final dynamic data = jsonDecode(raw);
      return _ok(const JsonEncoder.withIndent('  ').convert(data));
    } catch (e) {
      return _err(e.toString());
    }
  }

  static Future<Map<String, dynamic>> txt(
    KelivoFetchRequestPayload payload,
  ) async {
    try {
      final resp = await _fetch(payload);
      final html = resp.body;
      final dom.Document document = html_parser.parse(html);
      document.querySelectorAll('script,style').forEach((el) => el.remove());
      final text = document.body?.text ?? '';
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      return _ok(normalized);
    } catch (e) {
      return _err(e.toString());
    }
  }

  static Future<Map<String, dynamic>> markdown(
    KelivoFetchRequestPayload payload,
  ) async {
    try {
      final resp = await _fetch(payload);
      final html = resp.body;
      final md = html2md.convert(html);
      return _ok(md);
    } catch (e) {
      return _err(e.toString());
    }
  }

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
              'serverInfo': {'name': '@kelivo/fetch', 'version': '0.1.0'},
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

          if (name == 'fetch_html') {
            return _ok(id, result: await KelivoFetcher.html(payload));
          }
          if (name == 'fetch_markdown') {
            return _ok(id, result: await KelivoFetcher.markdown(payload));
          }
          if (name == 'fetch_txt') {
            return _ok(id, result: await KelivoFetcher.txt(payload));
          }
          if (name == 'fetch_json') {
            return _ok(id, result: await KelivoFetcher.json(payload));
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
        'url': {'type': 'string', 'description': 'URL of the website to fetch'},
        'headers': {
          'type': 'object',
          'description': 'Optional headers to include in the request',
        },
      },
      'required': ['url'],
    };

    return [
      {
        'name': 'fetch_html',
        'description':
            'Fetch a web page from the given URL and return the full raw HTML source code as a string. Use this tool when you need to inspect the raw HTML structure of a page, parse specific HTML elements, extract data from non-standard HTML structures, or when other fetch formats (markdown, plain text) produce unsatisfactory results. The "url" parameter must be a valid HTTP or HTTPS URL. Optional "headers" parameter allows sending custom HTTP headers. The tool sends a standard browser User-Agent header. This tool returns the complete raw HTML, including script and style tags, which may contain large amounts of irrelevant markup. For most content extraction tasks, prefer fetch_markdown (cleaner output) or fetch_txt (plain text only). Do NOT use this tool for internal/private URLs or URLs requiring authentication. The response is capped at the full HTTP response body — extremely large pages may impact performance. Returns an error if the HTTP request fails (non-2xx status, network error, or invalid URL).',
        'inputSchema': schema(),
      },
      {
        'name': 'fetch_markdown',
        'description':
            'Fetch a web page from the given URL and convert the HTML content into clean Markdown format. Use this tool as the preferred option for most web content retrieval tasks, because Markdown preserves document structure (headings, lists, links, code blocks, emphasis) while removing unnecessary HTML markup. Ideal for reading articles, documentation, blog posts, tutorials, and most standard web content. The "url" parameter must be a valid HTTP or HTTPS URL. Optional "headers" parameter allows sending custom HTTP headers. The tool sends a standard browser User-Agent header. Do NOT use this tool for pages that are primarily data tables, JSON endpoints, or non-HTML content — use fetch_json or fetch_txt instead. Do NOT use this tool for pages behind login walls or requiring authentication. The Markdown conversion is heuristic and may lose some formatting for complex layouts. Returns an error if the HTTP request fails.',
        'inputSchema': schema(),
      },
      {
        'name': 'fetch_txt',
        'description':
            'Fetch a web page from the given URL and return the content as plain text — HTML tags, scripts, and styles are stripped, and whitespace is normalized. Use this tool when you only need the readable textual content of a page without any formatting, markup, or structure. Best suited for: extracting the body text of simple pages, reading text-heavy but poorly-structured pages, obtaining clean input for text analysis or summarization, or when the Markdown conversion from fetch_markdown produces noise. The "url" parameter must be a valid HTTP or HTTPS URL. Optional "headers" parameter allows sending custom HTTP headers. The tool sends a standard browser User-Agent header. Do NOT use this tool when you need to preserve document structure (use fetch_markdown instead) or when you need raw HTML (use fetch_html). Returns an error if the HTTP request fails.',
        'inputSchema': schema(),
      },
      {
        'name': 'fetch_json',
        'description':
            'Fetch a JSON document from the given URL and return the parsed, pretty-printed (indented with 2 spaces) JSON content as a string. Use this tool when: accessing a REST API endpoint, reading a JSON configuration file, fetching structured data from a public JSON feed, or examining the response of a JSON-based web service. The "url" parameter must be a valid HTTP or HTTPS URL pointing to a JSON resource. Optional "headers" parameter allows sending custom HTTP headers (e.g. Authorization, Accept). The tool sends a standard browser User-Agent header. The response is validated as valid JSON before returning; if the response body is not valid JSON, the tool returns an error with details. Do NOT use this tool for HTML pages, plain text, or non-JSON content — use the appropriate fetch tool (fetch_html, fetch_markdown, or fetch_txt) instead. Returns an error if the HTTP request fails or the response is not valid JSON.',
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mcp_client/mcp_client.dart' as mcp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/icloud_sync_service.dart';

/// Transport type supported on mobile: SSE and Streamable HTTP.
enum McpTransportType { sse, http }

/// Connection status for an MCP server.
enum McpStatus { idle, connecting, connected, error }

class McpParamSpec {
  final String name;
  final bool required;
  final String? type;
  final dynamic defaultValue;

  McpParamSpec({
    required this.name,
    required this.required,
    this.type,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'required': required,
    'type': type,
    'default': defaultValue,
  };

  factory McpParamSpec.fromJson(Map<String, dynamic> json) => McpParamSpec(
    name: json['name'] as String? ?? '',
    required: json['required'] as bool? ?? false,
    type: json['type'] as String?,
    defaultValue: json['default'],
  );
}

class McpToolConfig {
  final bool enabled;
  final String name;
  final String? description;
  final List<McpParamSpec> params;
  // Raw JSON schema for parameters, if provided by the server
  final Map<String, dynamic>? schema;

  McpToolConfig({
    required this.enabled,
    required this.name,
    this.description,
    this.params = const [],
    this.schema,
  });

  McpToolConfig copyWith({bool? enabled, String? name, String? description, List<McpParamSpec>? params, Map<String, dynamic>? schema}) =>
      McpToolConfig(
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        description: description ?? this.description,
        params: params ?? this.params,
        schema: schema ?? this.schema,
      );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'name': name,
    'description': description,
    'params': params.map((e) => e.toJson()).toList(),
    if (schema != null) 'schema': schema,
  };

  factory McpToolConfig.fromJson(Map<String, dynamic> json) => McpToolConfig(
    enabled: json['enabled'] as bool? ?? true,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    params: (json['params'] as List?)
        ?.map((e) => McpParamSpec.fromJson((e as Map).cast<String, dynamic>()))
        .toList() ??
        const [],
    schema: (json['schema'] is Map)
        ? (json['schema'] as Map).cast<String, dynamic>()
        : null,
  );
}

class McpServerConfig {
  final String id; // stable id
  final bool enabled;
  final String name;
  final McpTransportType transport;
  final String url; // SSE endpoint or HTTP base URL
  final List<McpToolConfig> tools;
  final Map<String, String> headers; // custom HTTP headers

  McpServerConfig({
    required this.id,
    required this.enabled,
    required this.name,
    required this.transport,
    required this.url,
    this.tools = const [],
    this.headers = const {},
  });

  McpServerConfig copyWith({
    String? id,
    bool? enabled,
    String? name,
    McpTransportType? transport,
    String? url,
    List<McpToolConfig>? tools,
    Map<String, String>? headers,
  }) =>
      McpServerConfig(
        id: id ?? this.id,
        enabled: enabled ?? this.enabled,
        name: name ?? this.name,
        transport: transport ?? this.transport,
        url: url ?? this.url,
        tools: tools ?? this.tools,
        headers: headers ?? this.headers,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'name': name,
    'transport': transport.name,
    'url': url,
    'tools': tools.map((e) => e.toJson()).toList(),
    'headers': headers,
  };

  factory McpServerConfig.fromJson(Map<String, dynamic> json) => McpServerConfig(
    id: json['id'] as String? ?? const Uuid().v4(),
    enabled: json['enabled'] as bool? ?? true,
    name: json['name'] as String? ?? '',
    transport: (json['transport'] as String?) == 'http' ? McpTransportType.http : McpTransportType.sse,
    url: json['url'] as String? ?? '',
    tools: (json['tools'] as List?)
        ?.map((e) => McpToolConfig.fromJson((e as Map).cast<String, dynamic>()))
        .toList() ??
        const [],
    headers: ((json['headers'] as Map?)?.map((k, v) => MapEntry(k.toString(), v.toString()))) ?? const {},
  );
}

class McpProvider extends ChangeNotifier {
  static const String _prefsKey = 'mcp_servers_v1';

  final Map<String, mcp.Client> _clients = {};
  final Map<String, McpStatus> _status = {}; // id -> status
  final Map<String, String> _errors = {}; // id -> last error
  List<McpServerConfig> _servers = [];
  // Reconnect bookkeeping to avoid duplicate concurrent retries
  final Set<String> _reconnecting = <String>{};
  // Heartbeat timers for live-connection health checks
  final Map<String, Timer> _heartbeats = <String, Timer>{};

  bool _loading = false;
  bool _pendingReload = false;

  McpProvider() {
    _load();
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.addListener(_handleICloudUpdate);
    }
  }

  List<McpServerConfig> get servers => List.unmodifiable(_servers);
  McpStatus statusFor(String id) => _status[id] ?? McpStatus.idle;
  String? errorFor(String id) => _errors[id];
  bool get hasAnyEnabled => _servers.any((s) => s.enabled);
  bool isConnected(String id) => _clients.containsKey(id) && statusFor(id) == McpStatus.connected;
  List<McpServerConfig> get connectedServers =>
      _servers.where((s) => statusFor(s.id) == McpStatus.connected).toList(growable: false);

  Future<void> _load() async {
    if (_loading) {
      _pendingReload = true;
      return;
    }
    _loading = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => McpServerConfig.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _servers = list;
      } catch (_) {}
    }
    // initialize statuses
    for (final s in _servers) {
      _status[s.id] = McpStatus.idle;
      _errors.remove(s.id);
    }
    notifyListeners();

    // Auto-connect enabled servers
    for (final s in _servers.where((e) => e.enabled)) {
      // fire and forget
      unawaited(connect(s.id));
    }
    _loading = false;
    if (_pendingReload) {
      _pendingReload = false;
      unawaited(_load());
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_servers.map((e) => e.toJson()).toList()));
  }

  McpServerConfig? getById(String id) {
    for (final s in _servers) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<String> addServer({
    required bool enabled,
    required String name,
    required McpTransportType transport,
    required String url,
    Map<String, String> headers = const {},
  }) async {
    final id = const Uuid().v4();
    final cfg = McpServerConfig(
      id: id,
      enabled: enabled,
      name: name.trim().isEmpty ? 'MCP' : name.trim(),
      transport: transport,
      url: url.trim(),
      headers: headers,
    );
    _servers = [..._servers, cfg];
    _status[id] = McpStatus.idle;
    await _persist();
    notifyListeners();
    if (enabled) {
      unawaited(connect(id));
    }
    return id;
  }

  Future<void> updateServer(McpServerConfig updated) async {
    final idx = _servers.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return;
    _servers = List<McpServerConfig>.of(_servers)..[idx] = updated;
    await _persist();
    notifyListeners();
    if (!updated.enabled) {
      await disconnect(updated.id);
    } else {
      // Always reconnect after saving to apply changes (url/transport/name)
      await disconnect(updated.id);
      unawaited(connect(updated.id));
    }
  }

  Future<void> removeServer(String id) async {
    await disconnect(id);
    _servers = _servers.where((e) => e.id != id).toList(growable: false);
    _status.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> setToolEnabled(String serverId, String toolName, bool enabled) async {
    final idx = _servers.indexWhere((e) => e.id == serverId);
    if (idx < 0) return;
    final server = _servers[idx];
    final tools = server.tools.map((t) => t.name == toolName ? t.copyWith(enabled: enabled) : t).toList();
    _servers[idx] = server.copyWith(tools: tools);
    await _persist();
    notifyListeners();
  }

  Future<void> connect(String id) async {
    final server = _servers.firstWhere((e) => e.id == id, orElse: () => throw StateError('Server not found'));
    // If already connected, try a ping by listing tools quickly; else return
    if (_clients.containsKey(id)) {
      // Already connected; update status just in case
      _status[id] = McpStatus.connected;
      _errors.remove(id);
      notifyListeners();
      return;
    }
    _status[id] = McpStatus.connecting;
    _errors.remove(id);
    notifyListeners();

    try {
      // Log connect intent and parameters
      // debugPrint('[MCP/Connect] id=$id name=${server.name} transport=${server.transport.name}');
      // debugPrint('[MCP/Connect] url=${server.url}');
      // if (server.headers.isNotEmpty) {
      //   debugPrint('[MCP/Headers] ${server.headers.length} headers:');
      //   server.headers.forEach((k, v) {
      //     final masked = _maskIfSensitive(k, v);
      //     debugPrint('  - $k: $masked');
      //   });
      // } else {
      //   debugPrint('[MCP/Headers] (none)');
      // }

      final clientConfig = mcp.McpClient.simpleConfig(
        name: 'Kelivo MCP',
        version: '1.0.0',
        // Turn on library-internal verbose logs
        enableDebugLogging: false,
      );

      final mergedHeaders = <String, String>{...server.headers};
      final transportConfig = server.transport == McpTransportType.sse
          ? mcp.TransportConfig.sse(
        serverUrl: server.url,
        headers: mergedHeaders.isEmpty ? null : mergedHeaders,
      )
          : mcp.TransportConfig.streamableHttp(
        baseUrl: server.url,
        headers: mergedHeaders.isEmpty ? null : mergedHeaders,
      );

      // debugPrint('[MCP/Connect] creating client (enableDebugLogging=true) ...');
      final clientResult = await mcp.McpClient.createAndConnect(
        config: clientConfig,
        transportConfig: transportConfig,
      );

      final client = clientResult.fold((c) => c, (err) => throw err);
      _clients[id] = client;
      _status[id] = McpStatus.connected;
      _errors.remove(id);
      // debugPrint('[MCP/Connected] id=$id (${server.name})');
      notifyListeners();

      // Try to refresh tools once connected
      // debugPrint('[MCP/Tools] refreshing tools for id=$id ...');
      await refreshTools(id);
      // debugPrint('[MCP/Tools] refresh done for id=$id');

      // Start/refresh heartbeat for this connection
      _startHeartbeat(id);
    } catch (e, st) {
      // debugPrint('[MCP/Error] connect failed for id=$id (${server.name})');
      // _logMcpException('connect', serverId: id, error: e, stack: st);
      _status[id] = McpStatus.error;
      _errors[id] = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect(String id) async {
    final client = _clients.remove(id);
    try {
      // debugPrint('[MCP/Disconnect] id=$id ...');
      client?.disconnect();
      // debugPrint('[MCP/Disconnect] id=$id done');
    } catch (e, st) {
      // debugPrint('[MCP/Error] disconnect failed for id=$id');
      // _logMcpException('disconnect', serverId: id, error: e, stack: st);
    }
    _status[id] = McpStatus.idle;
    _errors.remove(id);
    _stopHeartbeat(id);
    notifyListeners();
  }

  Future<void> reconnect(String id) async {
    await disconnect(id);
    await connect(id);
  }

  Future<void> _reconnectWithBackoff(String id, {int maxAttempts = 3}) async {
    if (_reconnecting.contains(id)) return;
    _reconnecting.add(id);
    try {
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        await reconnect(id);
        if (isConnected(id)) return;
        // progressive backoff: 600ms, 1200ms, 2400ms
        final delayMs = 600 * (1 << (attempt - 1));
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    } finally {
      _reconnecting.remove(id);
    }
  }

  void _startHeartbeat(String id, {Duration interval = const Duration(seconds: 12)}) {
    _stopHeartbeat(id);
    _heartbeats[id] = Timer.periodic(interval, (t) async {
      // Heartbeat only when we think we're connected
      if (!isConnected(id)) return;
      final client = _clients[id];
      if (client == null) return;
      try {
        // A lightweight call to verify liveness
        // listTools is relatively cheap and available
        final fut = client.listTools();
        // Add a soft timeout to avoid piling up
        await fut.timeout(const Duration(seconds: 6));
      } catch (e, st) {
        // debugPrint('[MCP/Heartbeat] liveness check failed id=$id');
        // _logMcpException('heartbeat', serverId: id, error: e, stack: st);
        // Consider connection lost; mark error and try auto-reconnect
        _status[id] = McpStatus.error;
        _errors[id] = e.toString();
        notifyListeners();
        await _reconnectWithBackoff(id, maxAttempts: 3);
        // If reconnected, restart heartbeat (connect() also starts it)
        if (!isConnected(id)) {
          // keep error state; next heartbeat tick will be a no-op
        }
      }
    });
  }

  void _stopHeartbeat(String id) {
    _heartbeats.remove(id)?.cancel();
  }

  McpToolConfig? _toolConfig(String serverId, String toolName) {
    final idx = _servers.indexWhere((e) => e.id == serverId);
    if (idx < 0) return null;
    final s = _servers[idx];
    for (final t in s.tools) {
      if (t.name == toolName) return t;
    }
    return null;
  }

  Map<String, dynamic> _normalizeArgsForTool(String serverId, String toolName, Map<String, dynamic> args) {
    try {
      final cfg = _toolConfig(serverId, toolName);
      final schema = cfg?.schema;
      if (schema == null || schema.isEmpty) return args;
      final cloned = jsonDecode(jsonEncode(args)) as Map<String, dynamic>;
      var normalized = _normalizeBySchema(cloned, schema, propertyName: null);
      if (normalized is! Map<String, dynamic>) return args;
      normalized = _normalizeSpecialCases(toolName, normalized);
      return normalized;
    } catch (_) {
      return args;
    }
  }

  Map<String, dynamic> _normalizeSpecialCases(String toolName, Map<String, dynamic> args) {
    try {
      if (toolName == 'firecrawl_search') {
        // sources: ["web"] -> [{"type":"web"}]
        final rawSources = args['sources'];
        if (rawSources is List && rawSources.isNotEmpty && rawSources.every((e) => e is String)) {
          args['sources'] = rawSources.map((e) => {'type': e}).toList();
        }
        // Provide pragmatic defaults for commonly required fields if absent
        args.putIfAbsent('tbs', () => '0');
        args.putIfAbsent('filter', () => '0');
        args.putIfAbsent('location', () => 'us');
        // If tbs/filter are present but empty, coerce to '0'
        if ((args['tbs'] is String) && (args['tbs'] as String).isEmpty) args['tbs'] = '0';
        if ((args['filter'] is String) && (args['filter'] as String).isEmpty) args['filter'] = '0';
        if ((args['location'] is String) && (args['location'] as String).toLowerCase() == 'global') args['location'] = 'us';
        final so = (args['scrapeOptions'] is Map)
            ? (args['scrapeOptions'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        so.putIfAbsent('waitFor', () => 0);
        // formats normalization: server expects union of simple literals ["markdown"|"html"|"rawHtml"] OR an object only when type=="json"
        final fm = so['formats'];
        if (fm is List) {
          final norm = <dynamic>[];
          for (final f in fm) {
            if (f is Map) {
              final t = (f['type'] ?? '').toString();
              if (t == 'markdown' || t == 'html' || t == 'rawHtml') {
                norm.add(t);
              } else if (t == 'json') {
                norm.add(f); // keep object form for json
              } else if (t.isNotEmpty) {
                norm.add(t);
              }
            } else if (f is String) {
              if (f == 'json') {
                norm.add({'type': 'json'});
              } else {
                norm.add(f);
              }
            } else {
              norm.add(f);
            }
          }
          so['formats'] = norm;
        }
        args['scrapeOptions'] = so;
      }
    } catch (_) {}
    return args;
  }

  dynamic _normalizeBySchema(dynamic value, Map<String, dynamic> schema, {String? propertyName}) {
    try {
      // Handle anyOf/oneOf by choosing first matching branch; if value is null, attempt defaults
      final List<Map<String, dynamic>> unions = _schemaUnions(schema);
      if (unions.isNotEmpty) {
        // Heuristic only for certain fields (e.g., sources) — DO NOT apply globally.
        if (value is String && propertyName == 'sources') {
          final objBranch = unions.firstWhere(
              (m) => _schemaTypes(m).contains('object') && ((m['properties'] as Map?)?.containsKey('type') ?? false),
              orElse: () => const {});
          if (objBranch.isNotEmpty) {
            return _normalizeBySchema({'type': value}, objBranch, propertyName: propertyName);
          }
        }
        for (final branch in unions) {
          try {
            return _normalizeBySchema(value, branch, propertyName: propertyName);
          } catch (_) {
            // try next branch
          }
        }
        // fallthrough to first branch
        return _normalizeBySchema(value, unions.first, propertyName: propertyName);
      }

      final declaredTypes = _schemaTypes(schema);
      if (declaredTypes.contains('object')) {
        final props = (schema['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final req = (schema['required'] as List?)?.map((e) => e.toString()).toSet() ?? const <String>{};
        final out = <String, dynamic>{};
        final input = (value is Map) ? (value as Map).cast<String, dynamic>() : const <String, dynamic>{};
        // copy passthrough unknowns
        input.forEach((k, v) {
          if (!props.containsKey(k)) out[k] = v;
        });
        for (final entry in props.entries) {
          final key = entry.key;
          final propSchema = (entry.value is Map) ? (entry.value as Map).cast<String, dynamic>() : const <String, dynamic>{};
          dynamic v = input.containsKey(key) ? input[key] : null;
          if (v == null) {
            if (propSchema.containsKey('default')) {
              v = propSchema['default'];
            } else {
              final enumVals = _schemaEnum(propSchema);
              if (enumVals.isNotEmpty) {
                v = enumVals.first;
              } else if (key == 'waitFor' && _schemaTypes(propSchema).any((t) => t == 'number' || t == 'integer')) {
                v = 0; // pragmatic default often acceptable for waitFor
              }
            }
          }
          if (v != null) {
            out[key] = _normalizeBySchema(v, propSchema, propertyName: key);
          } else if (!req.contains(key)) {
            // omit optional nulls
          } else {
            // keep as null for required to let server validate if still missing
          }
        }
        return out;
      }

      if (declaredTypes.contains('array')) {
        final items = (schema['items'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final list = (value is List) ? value : [value];
        final out = [];
        for (final item in list) {
          dynamic iv = item;
          // Heuristic only for sources array, not for other arrays like formats
          final itemTypes = _schemaTypes(items);
          if (propertyName == 'sources' && item is String && itemTypes.contains('object')) {
            final itemProps = (items['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
            if (itemProps.containsKey('type')) {
              iv = {'type': item};
            }
          }
          out.add(_normalizeBySchema(iv, items, propertyName: propertyName));
        }
        return out;
      }

      if (declaredTypes.contains('boolean')) {
        if (value is bool) return value;
        if (value is String) {
          final s = value.toLowerCase();
          if (s == 'true' || s == '1' || s == 'yes') return true;
          if (s == 'false' || s == '0' || s == 'no') return false;
        }
        return value;
      }

      if (declaredTypes.contains('integer')) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final p = int.tryParse(value);
          if (p != null) return p;
        }
        return value;
      }

      if (declaredTypes.contains('number')) {
        if (value is num) return value;
        if (value is String) {
          final p = double.tryParse(value);
          if (p != null) return p;
        }
        return value;
      }

      if (declaredTypes.contains('string')) {
        if (value == null) return value;
        if (value is String) {
          final enums = _schemaEnum(schema);
          if (enums.isNotEmpty && !enums.contains(value)) {
            // keep original; server will validate
          }
          return value;
        }
        return value.toString();
      }

      // no declared type: return as-is
      return value;
    } catch (_) {
      return value;
    }
  }

  List<Map<String, dynamic>> _schemaUnions(Map<String, dynamic> schema) {
    final out = <Map<String, dynamic>>[];
    final anyOf = schema['anyOf'];
    final oneOf = schema['oneOf'];
    if (anyOf is List) {
      out.addAll(anyOf.whereType<Map>().map((e) => (e as Map).cast<String, dynamic>()));
    }
    if (oneOf is List) {
      out.addAll(oneOf.whereType<Map>().map((e) => (e as Map).cast<String, dynamic>()));
    }
    return out;
  }

  List<String> _schemaTypes(Map<String, dynamic> schema) {
    final t = schema['type'];
    if (t is String) return [t];
    if (t is List) return t.map((e) => e.toString()).toList();
    return const [];
  }

  List<dynamic> _schemaEnum(Map<String, dynamic> schema) {
    final e = schema['enum'];
    if (e is List) return e;
    return const [];
  }

  Future<void> refreshTools(String id) async {
    final client = _clients[id];
    if (client == null) return;
    try {
      // debugPrint('[MCP/Tools] listTools() ...');
      final tools = await client.listTools();
      // debugPrint('[MCP/Tools] listTools() returned ${tools.length} tools');
      // Preserve enabled state from existing config
      final idx = _servers.indexWhere((e) => e.id == id);
      if (idx < 0) return;
      final existing = _servers[idx].tools;
      final existingMap = {for (final t in existing) t.name: t};

      List<McpToolConfig> merged = [];
      for (final t in tools) {
        final prior = existingMap[t.name];
        // Extract params from inputSchema if present
        final params = <McpParamSpec>[];
        Map<String, dynamic>? schemaJson;
        try {
          final schema = t.inputSchema; // dynamic; depends on package
          if (schema != null) {
            // We attempt to read JSON schema-ish fields via toJson if provided
            final Map<String, dynamic> js = (schema is Map<String, dynamic>)
                ? schema
                : (schema is Object && schema.toString().isNotEmpty)
                    ? (schema as dynamic).toJson?.call() as Map<String, dynamic>? ?? {}
                    : {};
            schemaJson = js;
            final props = (js['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
            final req = (js['required'] as List?)?.map((e) => e.toString()).toSet() ?? const <String>{};
            props.forEach((key, val) {
              String? ty;
              dynamic defVal;
              try {
                final v = (val as Map).cast<String, dynamic>();
                final ttype = v['type'];
                if (ttype is String) {
                  ty = ttype;
                } else if (ttype is List) {
                  ty = ttype.map((e) => e.toString()).join('|');
                }
                defVal = v['default'];
              } catch (_) {}
              params.add(McpParamSpec(name: key, required: req.contains(key), type: ty, defaultValue: defVal));
            });
          }
        } catch (_) {}

        merged.add(McpToolConfig(
          enabled: prior?.enabled ?? true,
          name: t.name,
          description: t.description,
          params: params,
          schema: schemaJson,
        ));
      }

      _servers[idx] = _servers[idx].copyWith(tools: merged);
      await _persist();
      notifyListeners();
    } catch (e, st) {
      // debugPrint('[MCP/Tools] listTools() failed for id=$id');
      // _logMcpException('listTools', serverId: id, error: e, stack: st);
      // ignore tool refresh errors; status stays connected
    }
  }

  Future<void> ensureConnected(String id) async {
    // Do not attempt to connect if the server is disabled
    final cfg = getById(id);
    if (cfg == null || !cfg.enabled) return;
    if (isConnected(id)) return;
    // Try a few times with short backoff in case server blips
    await _reconnectWithBackoff(id, maxAttempts: 3);
  }

  Future<mcp.CallToolResult?> callTool(String serverId, String toolName, Map<String, dynamic> args) async {
    try {
      await ensureConnected(serverId);
      var client = _clients[serverId];
      if (client == null) return null;
      // Normalize arguments based on tool schema (best-effort)
      final normalized = _normalizeArgsForTool(serverId, toolName, args);
      // if (normalized != args) {
      //   debugPrint('[MCP/Call] serverId=$serverId tool=$toolName args(normalized)=${jsonEncode(normalized)}');
      // } else {
      //   debugPrint('[MCP/Call] serverId=$serverId tool=$toolName args=${jsonEncode(args)}');
      // }
      final start = DateTime.now();
      final result = await client.callTool(toolName, normalized);
      final durMs = DateTime.now().difference(start).inMilliseconds;
      // Detailed call timing/content logging disabled
      return result;
    } catch (e, st) {
      // debugPrint('[MCP/Call/Error] serverId=$serverId tool=$toolName');
      // _logMcpException('callTool', serverId: serverId, toolName: toolName, error: e, stack: st);

      // If this is a parameter validation error from the server, do NOT disconnect.
      try {
        if (e is mcp.McpError && (e.code == -32602)) {
          // Keep connection healthy status; surface error to caller via null
          _errors[serverId] = e.toString();
          // debugPrint('[MCP/Call] invalid arguments; skipping reconnect');
          return null;
        }
      } catch (_) {}

      _status[serverId] = McpStatus.error;
      _errors[serverId] = e.toString();
      notifyListeners();
      // Auto-reconnect a few times and try once more
      try {
        await _reconnectWithBackoff(serverId, maxAttempts: 3);
        if (!isConnected(serverId)) return null;
        final client = _clients[serverId];
        if (client == null) return null;
        // debugPrint('[MCP/Call] retry serverId=$serverId tool=$toolName');
        final start = DateTime.now();
        final normalized = _normalizeArgsForTool(serverId, toolName, args);
        final result = await client.callTool(toolName, normalized);
        final durMs = DateTime.now().difference(start).inMilliseconds;
        // Detailed retry logging disabled
        // Mark healthy again
        _status[serverId] = McpStatus.connected;
        _errors.remove(serverId);
        notifyListeners();
        return result;
      } catch (e2, st2) {
        // debugPrint('[MCP/Call/RetryError] serverId=$serverId tool=$toolName');
        // _logMcpException('callTool-retry', serverId: serverId, toolName: toolName, error: e2, stack: st2);
        // Keep error state; give up
        return null;
      }
    }
  }

  void _logMcpException(
    String phase, {
    required String serverId,
    String? toolName,
    required Object error,
    StackTrace? stack,
  }) {
    try {
      final type = error.runtimeType.toString();
      // debugPrint('[MCP/Error/$phase] id=$serverId${toolName != null ? ' tool='+toolName : ''} type=$type msg=$error');
      // Best-effort to extract structured fields from common error types
      final dyn = error as dynamic;
      try {
        final code = dyn.code;
        // if (code != null) debugPrint('[MCP/Error/$phase] code=$code');
      } catch (_) {}
      try {
        final status = dyn.status;
        // if (status != null) debugPrint('[MCP/Error/$phase] status=$status');
      } catch (_) {}
      try {
        final reason = dyn.reason;
        // if (reason != null) debugPrint('[MCP/Error/$phase] reason=$reason');
      } catch (_) {}
      try {
        final inner = dyn.cause ?? dyn.inner ?? dyn.original;
        // if (inner != null) debugPrint('[MCP/Error/$phase] cause=$inner');
      } catch (_) {}
      // if (stack != null) debugPrint(stack.toString());
    } catch (_) {
      // If anything fails during logging, still print fallback
      // debugPrint('[MCP/Error/$phase] id=$serverId${toolName != null ? ' tool='+toolName : ''} ${error.runtimeType}: $error');
      // if (stack != null) debugPrint(stack.toString());
    }
  }



  String _briefContent(dynamic c) {
    try {
      // Try known fields
      final dyn = c as dynamic;
      final txt = _safeString(() => dyn.text as String?);
      if (txt != null && txt.isNotEmpty) {
        return txt.length > 120 ? txt.substring(0, 120) + '…' : txt;
      }
      final url = _safeString(() => dyn.url as String?);
      if (url != null && url.isNotEmpty) return 'url=$url';
      final uri = _safeString(() => dyn.uri as String?);
      if (uri != null && uri.isNotEmpty) return 'uri=$uri';
      // Try toJson
      final toJson = (dyn.toJson as dynamic?)?.call();
      if (toJson is Map) {
        return jsonEncode(toJson);
      }
    } catch (_) {}
    final s = c.toString();
    return (s.length > 120) ? s.substring(0, 120) + '…' : s;
  }

  String? _safeString(String? Function() f) {
    try {
      final v = f();
      if (v == null) return null;
      final s = v.toString();
      return s;
    } catch (_) {
      return null;
    }
  }

  String _maskIfSensitive(String key, String value) {
    try {
      final lk = key.toLowerCase();
      final sensitive = lk.contains('authorization') || lk.contains('token') || lk.contains('api-key') || lk.endsWith('key') || lk == 'cookie';
      if (!sensitive) return value;
      final v = value.trim();
      if (v.isEmpty) return value;
      if (v.length <= 8) return '***';
      return v.substring(0, 4) + '…' + v.substring(v.length - 2);
    } catch (_) {
      return '***';
    }
  }

  List<McpToolConfig> getEnabledToolsForServers(Set<String> serverIds) {
    // Only expose tools for servers that are both selected AND currently connected
    final tools = <McpToolConfig>[];
    for (final s in _servers.where((s) => serverIds.contains(s.id))) {
      if (statusFor(s.id) != McpStatus.connected) continue;
      if (!s.enabled) continue;
      tools.addAll(s.tools.where((t) => t.enabled));
    }
    return tools;
  }

  void _handleICloudUpdate() {
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final t in _heartbeats.values) {
      t.cancel();
    }
    _heartbeats.clear();
    if (ICloudSyncService.instance.isSupported) {
      ICloudSyncService.instance.removeListener(_handleICloudUpdate);
    }
    super.dispose();
  }
}

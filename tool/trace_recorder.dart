import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/api/stream/sse_event.dart';
import 'package:Kelivo/core/services/api/stream/sse_framing.dart';
import 'package:Kelivo/core/services/api/stream/stream_trace.dart';

import 'src/traces_config.dart';

/// Record framed SSE events from a live provider.
///
/// Writes only `id` / `event` / `data` / `retryMillis`. Never writes headers
/// or API keys. Keys are read from the environment variable named in
/// `tool/traces.yaml`.
///
/// Usage:
///   dart run tool/trace_recorder.dart --list
///   dart run tool/trace_recorder.dart --case thinking-tools-search --dry-run
///   dart run tool/trace_recorder.dart --case thinking-tools-search --force
Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final root = _repoRoot();
  final config = loadTracesYaml(File('${root.path}/tool/traces.yaml'));

  if (options.list) {
    for (final trace in config.traces) {
      stdout.writeln(
        '${trace.provider}/${trace.name} -> ${trace.relativeOutput}',
      );
    }
    return;
  }

  final selected = options.caseName == null
      ? config.traces
      : [
          config.find(options.caseName!) ??
              (throw StateError('Unknown case: ${options.caseName}')),
        ];

  for (final raw in selected) {
    final trace = raw.copyWith(
      baseUrl: options.baseUrl,
      endpoint: options.endpoint,
      apiKeyEnv: options.apiKeyEnv,
      model: options.model,
      authHeader: options.authHeader,
      authScheme: options.authScheme,
    );
    await _record(root, trace, dryRun: options.dryRun, force: options.force);
  }
}

class _Options {
  const _Options({
    this.caseName,
    this.list = false,
    this.dryRun = false,
    this.force = false,
    this.baseUrl,
    this.endpoint,
    this.apiKeyEnv,
    this.model,
    this.authHeader,
    this.authScheme,
  });

  final String? caseName;
  final bool list;
  final bool dryRun;
  final bool force;
  final String? baseUrl;
  final String? endpoint;
  final String? apiKeyEnv;
  final String? model;
  final String? authHeader;
  final String? authScheme;
}

_Options _parseArgs(List<String> args) {
  String? caseName;
  var list = false;
  var dryRun = false;
  var force = false;
  String? baseUrl;
  String? endpoint;
  String? apiKeyEnv;
  String? model;
  String? authHeader;
  String? authScheme;
  for (var i = 0; i < args.length; i++) {
    String takeValue(String flag) {
      if (i + 1 >= args.length) {
        throw StateError('$flag requires a value');
      }
      return args[++i];
    }

    switch (args[i]) {
      case '--list':
        list = true;
      case '--dry-run':
        dryRun = true;
      case '--force':
        force = true;
      case '--case':
        caseName = takeValue('--case');
      case '--base-url':
        baseUrl = takeValue('--base-url');
      case '--endpoint':
        endpoint = takeValue('--endpoint');
      case '--api-key-env':
        apiKeyEnv = takeValue('--api-key-env');
      case '--model':
        model = takeValue('--model');
      case '--auth-header':
        authHeader = takeValue('--auth-header');
      case '--auth-scheme':
        authScheme = takeValue('--auth-scheme');
      default:
        throw StateError('Unknown argument: ${args[i]}');
    }
  }
  return _Options(
    caseName: caseName,
    list: list,
    dryRun: dryRun,
    force: force,
    baseUrl: baseUrl,
    endpoint: endpoint,
    apiKeyEnv: apiKeyEnv,
    model: model,
    authHeader: authHeader,
    authScheme: authScheme,
  );
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/tool/traces.yaml').existsSync() &&
        File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Run from the Kelivo repository (missing tool/traces.yaml).',
      );
    }
    dir = parent;
  }
}

Future<void> _record(
  Directory root,
  TraceCase trace, {
  required bool dryRun,
  required bool force,
}) async {
  final output = File('${root.path}/${trace.relativeOutput}');
  if (output.existsSync() && !force && !dryRun) {
    stdout.writeln('skip ${trace.name} (exists; pass --force to overwrite)');
    return;
  }

  final bodyFile = File('${root.path}/${trace.bodyFile}');
  if (!bodyFile.existsSync()) {
    throw StateError('Missing body file: ${trace.bodyFile}');
  }
  final body = jsonDecode(bodyFile.readAsStringSync());
  if (body is! Map) {
    throw StateError('Body file must be a JSON object: ${trace.bodyFile}');
  }
  final payload = Map<String, dynamic>.from(body);
  _forceStream(trace.provider, payload, model: trace.model);

  final uri = traceRequestUri(trace);
  final headers = _authHeaders(trace);
  if (dryRun) {
    stdout.writeln('POST $uri');
    stdout.writeln('headers: ${_redactedHeaders(headers)}');
    stdout.writeln('body: ${jsonEncode(payload)}');
    stdout.writeln('output: ${trace.relativeOutput}');
    return;
  }

  final key = Platform.environment[trace.apiKeyEnv];
  if (key == null || key.isEmpty) {
    throw StateError('Missing ${trace.apiKeyEnv} for ${trace.name}');
  }

  final client = HttpClient();
  client.connectionTimeout = Duration(milliseconds: trace.timeoutMs);
  try {
    final request = await client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close().timeout(
      Duration(milliseconds: trace.timeoutMs),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await utf8.decodeStream(response);
      throw HttpException('HTTP ${response.statusCode}: $errorBody', uri: uri);
    }
    final events = <SseEvent>[];
    await for (final event in parseSseEventStrings(
      response.transform(utf8.decoder),
    )) {
      events.add(event);
    }
    if (events.isEmpty) {
      throw StateError('No SSE events recorded for ${trace.name}');
    }
    output.parent.createSync(recursive: true);
    final tmp = File('${output.path}.tmp');
    tmp.writeAsStringSync(encodeSseEventsJsonl(events));
    tmp.renameSync(output.path);
    stdout.writeln('wrote ${trace.relativeOutput} (${events.length} events)');
  } finally {
    client.close(force: true);
  }
}

void _forceStream(
  String provider,
  Map<String, dynamic> body, {
  required String model,
}) {
  switch (provider) {
    case 'google':
      break;
    case 'openai-responses':
      body['stream'] = true;
      body['model'] = body['model'] ?? model;
    default:
      body['stream'] = true;
      body['model'] = body['model'] ?? model;
  }
}

Map<String, String> _authHeaders(TraceCase trace) {
  final key = Platform.environment[trace.apiKeyEnv] ?? '';
  if (trace.authHeader.isNotEmpty) {
    final value = trace.authScheme.isEmpty ? key : '${trace.authScheme} $key';
    return <String, String>{
      trace.authHeader: value,
      if (trace.provider == 'claude') 'anthropic-version': '2023-06-01',
    };
  }
  switch (trace.provider) {
    case 'claude':
      return <String, String>{
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      };
    case 'google':
      return <String, String>{'x-goog-api-key': key};
    default:
      return <String, String>{'Authorization': 'Bearer $key'};
  }
}

Map<String, String> _redactedHeaders(Map<String, String> headers) {
  return <String, String>{
    for (final entry in headers.entries)
      entry.key:
          entry.key.toLowerCase().contains('key') ||
              entry.key.toLowerCase() == 'authorization'
          ? '<redacted>'
          : entry.value,
  };
}

import 'dart:io';

/// One recordable provider case from [tool/traces.yaml].
class TraceCase {
  const TraceCase({
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.apiKeyEnv,
    required this.model,
    required this.bodyFile,
    this.endpoint = '',
    this.timeoutMs = 120000,
    this.outputRoot = 'test/fixtures/stream-traces',
    this.authHeader = '',
    this.authScheme = '',
  });

  final String name;
  final String provider;
  final String baseUrl;
  final String endpoint;
  final String apiKeyEnv;
  final String model;
  final String bodyFile;
  final int timeoutMs;
  final String outputRoot;
  final String authHeader;
  final String authScheme;

  TraceCase copyWith({
    String? baseUrl,
    String? endpoint,
    String? apiKeyEnv,
    String? model,
    String? authHeader,
    String? authScheme,
  }) {
    return TraceCase(
      name: name,
      provider: provider,
      baseUrl: baseUrl ?? this.baseUrl,
      endpoint: endpoint ?? this.endpoint,
      apiKeyEnv: apiKeyEnv ?? this.apiKeyEnv,
      model: model ?? this.model,
      bodyFile: bodyFile,
      timeoutMs: timeoutMs,
      outputRoot: outputRoot,
      authHeader: authHeader ?? this.authHeader,
      authScheme: authScheme ?? this.authScheme,
    );
  }

  String get relativeOutput => '$outputRoot/$provider/$name/events.jsonl';
}

/// Build the streaming request URL. Concatenate path segments so a base
/// that already ends in `/v1` is not stripped by [Uri.resolve].
Uri traceRequestUri(TraceCase trace) {
  if (trace.provider == 'google') {
    final base = trace.baseUrl.endsWith('/')
        ? trace.baseUrl.substring(0, trace.baseUrl.length - 1)
        : trace.baseUrl;
    return Uri.parse(
      '$base/models/${trace.model}:streamGenerateContent?alt=sse',
    );
  }
  final rawBase = trace.baseUrl.endsWith('/')
      ? trace.baseUrl.substring(0, trace.baseUrl.length - 1)
      : trace.baseUrl;
  final endpoint = trace.endpoint.startsWith('/')
      ? trace.endpoint
      : '/${trace.endpoint}';
  if (trace.endpoint.isEmpty) return Uri.parse(rawBase);
  return Uri.parse('$rawBase$endpoint');
}

class TracesConfig {
  const TracesConfig({required this.traces, this.outputRoot = ''});

  final List<TraceCase> traces;
  final String outputRoot;

  TraceCase? find(String name) {
    for (final trace in traces) {
      if (trace.name == name) return trace;
    }
    return null;
  }
}

/// Minimal YAML reader for the traces file schema (maps + list of maps).
TracesConfig parseTracesYaml(String source, {String outputRootFallback = ''}) {
  final defaults = <String, String>{};
  final traces = <TraceCase>[];
  var inDefaults = false;
  var inTraces = false;
  final current = <String, String>{};

  void flush() {
    if (current.isEmpty) return;
    traces.add(
      TraceCase(
        name: current['name'] ?? '',
        provider: current['provider'] ?? '',
        baseUrl: current['baseUrl'] ?? '',
        endpoint: current['endpoint'] ?? '',
        apiKeyEnv: current['apiKeyEnv'] ?? '',
        model: current['model'] ?? '',
        bodyFile: current['bodyFile'] ?? '',
        timeoutMs:
            int.tryParse(current['timeoutMs'] ?? '') ??
            int.tryParse(defaults['timeoutMs'] ?? '') ??
            120000,
        outputRoot:
            current['outputRoot'] ??
            defaults['outputRoot'] ??
            outputRootFallback,
        authHeader: current['authHeader'] ?? '',
        authScheme: current['authScheme'] ?? '',
      ),
    );
    current.clear();
  }

  for (var raw in source.split('\n')) {
    final comment = raw.indexOf('#');
    if (comment >= 0) raw = raw.substring(0, comment);
    if (raw.trim().isEmpty) continue;
    final indent = raw.length - raw.trimLeft().length;
    final line = raw.trim();

    if (indent == 0 && line == 'defaults:') {
      flush();
      inDefaults = true;
      inTraces = false;
      continue;
    }
    if (indent == 0 && line == 'traces:') {
      flush();
      inDefaults = false;
      inTraces = true;
      continue;
    }
    if (indent == 0) {
      inDefaults = false;
      inTraces = false;
      continue;
    }

    if (inDefaults && line.contains(':')) {
      final split = line.indexOf(':');
      defaults[line.substring(0, split).trim()] = _unquote(
        line.substring(split + 1).trim(),
      );
      continue;
    }

    if (inTraces && line.startsWith('- ')) {
      flush();
      final rest = line.substring(2).trim();
      if (rest.contains(':')) {
        final split = rest.indexOf(':');
        current[rest.substring(0, split).trim()] = _unquote(
          rest.substring(split + 1).trim(),
        );
      }
      continue;
    }

    if (inTraces && line.contains(':')) {
      final split = line.indexOf(':');
      current[line.substring(0, split).trim()] = _unquote(
        line.substring(split + 1).trim(),
      );
    }
  }
  flush();

  return TracesConfig(
    traces: traces.where((t) => t.name.isNotEmpty).toList(),
    outputRoot: defaults['outputRoot'] ?? outputRootFallback,
  );
}

TracesConfig loadTracesYaml(File file) {
  return parseTracesYaml(file.readAsStringSync());
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}

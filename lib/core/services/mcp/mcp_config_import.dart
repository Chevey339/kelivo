import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../providers/mcp_provider.dart';

/// Parses desktop-client JSON as new servers. Importing never replaces a saved
/// server (even when its display name matches), or imports cached tools/tokens.
List<McpServerConfig> parseMcpConfigImport(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected an object');
  }
  final Object? raw = decoded['mcpServers'] ?? decoded;
  if (raw is! Map || raw.isEmpty) {
    throw const FormatException('No MCP servers found');
  }
  final result = <McpServerConfig>[];
  for (final entry in raw.entries) {
    final name = entry.key.toString();
    final config = entry.value;
    if (config is! Map) throw FormatException('Invalid server: $name');
    final type = (config['type'] ?? '').toString().toLowerCase();
    if (![
      '',
      'stdio',
      'http',
      'streamablehttp',
      'streamable-http',
      'sse',
    ].contains(type)) {
      throw FormatException('Unsupported transport: $name');
    }
    final command = config['command'];
    final stdio = type == 'stdio' || (type.isEmpty && command != null);
    final args = config['args'] ?? <String>[];
    if (args is! List || args.any((arg) => arg is! String)) {
      throw FormatException('Arguments must be strings: $name');
    }
    final url = config['url'] ?? config['baseUrl'];
    if (stdio) {
      if (command is! String || command.trim().isEmpty) {
        throw FormatException('Missing command: $name');
      }
    } else {
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw FormatException('Invalid server URL: $name');
      }
    }
    final cwd = config['cwd'] ?? config['workingDirectory'];
    if (cwd != null && cwd is! String) {
      throw FormatException('Invalid working directory: $name');
    }
    result.add(
      McpServerConfig(
        id: const Uuid().v4(),
        name: name,
        enabled: config['disabled'] != true && config['isActive'] != false,
        transport: stdio
            ? McpTransportType.stdio
            : type == 'sse'
            ? McpTransportType.sse
            : McpTransportType.http,
        command: stdio ? command as String : null,
        args: List<String>.from(args),
        env: _strings(config['env'], name),
        url: stdio ? '' : url as String,
        headers: _strings(config['headers'], name),
        workingDirectory: cwd as String?,
      ),
    );
  }
  return result;
}

Map<String, String> _strings(Object? value, String name) {
  if (value == null) return {};
  if (value is! Map ||
      value.keys.any((key) => key is! String) ||
      value.values.any((v) => v is! String)) {
    throw FormatException('Expected string key/value pairs: $name');
  }
  return Map<String, String>.from(value);
}

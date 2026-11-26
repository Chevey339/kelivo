import 'dart:async';

import '../auth/claude_oauth_request.dart' show encodeClaudeOAuthToolName;

/// Client functions advertised in the latest HTTP round of this generation.
/// Provider-specific tool selection and custom bodies can replace the app's
/// original definitions before each send.
class RequestToolDeclarations {
  static RequestToolDeclarations? get current =>
      Zone.current[RequestToolDeclarations] as RequestToolDeclarations?;

  Set<String> _names = const {};
  bool _claudeOAuth = false;

  static Set<String> _functionNames(Object? tools) {
    final names = <String>{};
    if (tools is! List) return names;
    for (final tool in tools.whereType<Map>()) {
      switch (tool) {
        case {'type': 'function', 'function': {'name': final String name}}:
        case {'type': 'function', 'name': final String name}:
        case {'name': final String name, 'input_schema': Map()}:
          names.add(name);
        default:
          final declarations =
              tool['functionDeclarations'] ?? tool['function_declarations'];
          if (declarations is List) {
            for (final declaration in declarations) {
              if (declaration case {'name': final String name}) names.add(name);
            }
          }
      }
    }
    return names;
  }

  void record(Map<String, dynamic> body, {bool claudeOAuth = false}) {
    final names = _functionNames(body['tools']);
    // A request may retain schemas for prompt caching while restricting which
    // functions the model can actually choose.
    switch (body['tool_choice']) {
      case 'none' || {'type': 'none'}:
        names.clear();
      case {'type': 'function', 'function': {'name': final String forced}}:
      case {'type': 'function' || 'tool', 'name': final String forced}:
        names.retainAll([forced]);
      case {
        'type': 'allowed_tools',
        'allowed_tools': {'tools': final List allowed},
      }:
      case {'type': 'allowed_tools', 'tools': final List allowed}:
        names.retainAll(_functionNames(allowed));
      case {'type': final String type} when type != 'auto' && type != 'any':
        names.clear(); // A provider-hosted or custom tool was forced.
    }
    final config = body['toolConfig'] ?? body['tool_config'];
    if (config is Map) {
      final calling =
          config['functionCallingConfig'] ?? config['function_calling_config'];
      if (calling is Map) {
        if (calling['mode'] == 'NONE') names.clear();
        final allowed =
            calling['allowedFunctionNames'] ??
            calling['allowed_function_names'];
        if (allowed is List && allowed.isNotEmpty) names.retainAll(allowed);
      }
    }
    _names = names;
    _claudeOAuth = claudeOAuth;
  }

  String? advertisedName(String name) {
    if (!_names.contains(name)) return null;
    // The authenticated Claude transport prefixes names after body encoding.
    return _claudeOAuth ? encodeClaudeOAuthToolName(name) : name;
  }
}

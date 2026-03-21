bool shouldAttachGeminiFunctionCallingConfig(List<Map<String, dynamic>> tools) {
  for (final tool in tools) {
    if (!tool.containsKey('function_declarations')) continue;
    final decls = tool['function_declarations'];
    if (decls is List && decls.isNotEmpty) return true;
  }
  return false;
}

/// Whether [tools] contains both built-in tools and non-empty function_declarations.
bool hasBuiltInAndFunctionDeclarations(List<Map<String, dynamic>> tools) {
  bool hasBuiltIn = false;
  bool hasFuncDecls = false;
  for (final tool in tools) {
    if (tool.containsKey('google_search') ||
        tool.containsKey('code_execution') ||
        tool.containsKey('url_context')) {
      hasBuiltIn = true;
    }
    if (tool.containsKey('function_declarations')) {
      final decls = tool['function_declarations'];
      if (decls is List && decls.isNotEmpty) hasFuncDecls = true;
    }
  }
  return hasBuiltIn && hasFuncDecls;
}

/// Builds the `toolConfig` map for Gemini API requests.
///
/// Gemini 3 with combined built-in + custom tools:
///   - VALIDATED mode (AUTO not supported with server-side tool invocations)
///   - includeServerSideToolInvocations: true
///
/// All other cases with function_declarations:
///   - AUTO mode (existing behavior)
///
/// Returns null if no toolConfig is needed.
Map<String, dynamic>? buildGeminiToolConfig({
  required List<Map<String, dynamic>> tools,
  required bool isGemini3,
}) {
  final hasFuncDecls = shouldAttachGeminiFunctionCallingConfig(tools);
  if (!hasFuncDecls) return null;

  if (isGemini3 && hasBuiltInAndFunctionDeclarations(tools)) {
    return {
      'function_calling_config': {'mode': 'VALIDATED'},
      'includeServerSideToolInvocations': true,
    };
  }
  return {
    'function_calling_config': {'mode': 'AUTO'},
  };
}

final _geminiGeneration = RegExp(r'gemini-(\d+)', caseSensitive: false);

/// Gemini 3+ (AI Studio + Vertex) allows built-in tools to coexist with
/// `functionDeclarations`. Earlier generations mutually exclude them.
bool supportsMixedBuiltInAndFunctionTools(String upstreamModelId) {
  final generation = _geminiGeneration.firstMatch(upstreamModelId)?.group(1);
  return generation != null && int.parse(generation) >= 3;
}

bool shouldAttachGeminiFunctionCallingConfig(List<Map<String, dynamic>> tools) {
  for (final tool in tools) {
    if (!tool.containsKey('functionDeclarations')) continue;
    final decls = tool['functionDeclarations'];
    if (decls is List && decls.isNotEmpty) return true;
  }
  return false;
}

/// Whether [tools] contains both built-in tools and non-empty functionDeclarations.
bool hasBuiltInAndFunctionDeclarations(List<Map<String, dynamic>> tools) {
  bool hasBuiltIn = false;
  bool hasFuncDecls = false;
  for (final tool in tools) {
    if (tool.containsKey('googleSearch') ||
        tool.containsKey('codeExecution') ||
        tool.containsKey('urlContext')) {
      hasBuiltIn = true;
    }
    if (tool.containsKey('functionDeclarations')) {
      final decls = tool['functionDeclarations'];
      if (decls is List && decls.isNotEmpty) hasFuncDecls = true;
    }
  }
  return hasBuiltIn && hasFuncDecls;
}

/// Builds the `toolConfig` map for Gemini API requests.
///
/// Gemini 3+ on the Gemini API with combined built-in + custom tools:
///   - VALIDATED mode (AUTO not supported with server-side tool invocations)
///   - includeServerSideToolInvocations: true
///
/// All other cases with functionDeclarations:
///   - AUTO mode (existing behavior)
///
/// Returns null if no toolConfig is needed.
Map<String, dynamic>? buildGeminiToolConfig({
  required List<Map<String, dynamic>> tools,
  required bool allowServerSideToolInvocations,
}) {
  final hasFuncDecls = shouldAttachGeminiFunctionCallingConfig(tools);
  if (!hasFuncDecls) return null;

  if (allowServerSideToolInvocations &&
      hasBuiltInAndFunctionDeclarations(tools)) {
    return {
      'functionCallingConfig': {'mode': 'VALIDATED'},
      'includeServerSideToolInvocations': true,
    };
  }
  return {
    'functionCallingConfig': {'mode': 'AUTO'},
  };
}

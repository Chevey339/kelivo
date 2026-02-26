bool shouldAttachGeminiFunctionCallingConfig(List<Map<String, dynamic>> tools) {
  for (final tool in tools) {
    if (!tool.containsKey('function_declarations')) continue;
    final decls = tool['function_declarations'];
    if (decls is List && decls.isNotEmpty) return true;
  }
  return false;
}

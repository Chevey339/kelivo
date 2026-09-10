import '../../../providers/settings_provider.dart';
import '../builtin_tools.dart';

/// Mirrors the providers' native-tool selection using the same builders. In
/// particular, older Gemini native tools displace client function declarations.
class GenerationCapabilities {
  GenerationCapabilities({
    required this.clientTools,
    required this.nativeTools,
    this.allowsClientTools = true,
  });

  factory GenerationCapabilities.resolve({
    required ProviderConfig config,
    required String modelId,
    required List<Map<String, dynamic>> clientTools,
  }) {
    final kind = ProviderConfig.classify(
      config.id,
      explicitType: config.providerType,
    );
    final upstream = BuiltInToolNames.effectiveModelId(
      cfg: config,
      modelId: modelId,
    );
    final configured = BuiltInToolNames.parseFromOverride(
      config.modelOverrides[modelId],
    );
    final native = <String>[];
    var clients = clientTools;
    var allowsClientTools = true;
    switch (kind) {
      case ProviderKind.google:
        final selected = buildGeminiToolsArray(
          builtIns: configured,
          allowCoexistence: upstream.toLowerCase().contains('gemini-3'),
          geminiTools: const [
            {'function_declarations': <Object>[]},
          ],
        );
        if (!selected.any(
          (entry) => entry.containsKey('function_declarations'),
        )) {
          clients = [];
          allowsClientTools = false;
        }
        native.addAll(
          selected
              .expand((entry) => entry.keys)
              .where((name) => name != 'function_declarations'),
        );
      case ProviderKind.claude:
        if (BuiltInToolsHelper.isBuiltInSearchEnabled(
          cfg: config,
          modelId: modelId,
        )) {
          native.add('web_search');
        }
        native.addAll(
          BuiltInToolsHelper.claudeServerToolEntries(
            cfg: config,
            modelId: modelId,
            enabled: configured,
          ).map((entry) => entry['name'].toString()),
        );
      case ProviderKind.openai:
        final payload = config.useResponseApi == true
            ? BuiltInToolsHelper.buildResponsesTools(
                cfg: config,
                modelId: modelId,
                upstreamModelId: upstream,
              )
            : BuiltInToolsHelper.buildChatCompletionsTools(
                cfg: config,
                modelId: modelId,
                upstreamModelId: upstream,
              );
        native.addAll(payload.tools.map((entry) => entry['type'].toString()));
        if (native.isEmpty &&
            BuiltInToolsHelper.isBuiltInSearchEnabled(
              cfg: config,
              modelId: modelId,
            )) {
          native.add('web_search');
        }
    }
    if (kind == ProviderKind.claude) {
      final claimed = clients
          .map((tool) => (tool['function'] as Map?)?['name'])
          .toSet();
      native.removeWhere(claimed.contains);
    }
    return GenerationCapabilities(
      clientTools: List.unmodifiable(clients),
      nativeTools: List.unmodifiable(native),
      allowsClientTools: allowsClientTools,
    );
  }

  final List<Map<String, dynamic>> clientTools;
  final List<String> nativeTools;
  final bool allowsClientTools;
  Set<String> get toolNames => clientTools
      .map((tool) => ((tool['function'] as Map?)?['name'] ?? '').toString())
      .toSet();
}

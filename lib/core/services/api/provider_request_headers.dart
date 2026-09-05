import 'package:uuid/uuid.dart';

import '../../providers/settings_provider.dart';

const String _openRouterAppReferer = 'https://github.com/Chevey339/kelivo';
const String _openRouterAppTitle = 'Kelivo';
const String _openRouterAppCategories = 'general-chat';

/// Resolve once per generation, before retries and tool follow-up rounds.
Map<String, String>? providerSessionHeaders(
  ProviderConfig config, {
  String? conversationId,
  Map<String, String>? extraHeaders,
}) {
  final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase();
  if (host != 'opencode.ai') return extraHeaders;
  final id = conversationId?.trim() ?? '';
  return {
    'x-opencode-session': id.isEmpty ? const Uuid().v4() : id,
    ...?extraHeaders,
  };
}

bool isOpenRouterProvider(ProviderConfig config) {
  final host = Uri.tryParse(config.baseUrl)?.host.toLowerCase() ?? '';
  return host.contains('openrouter.ai');
}

Map<String, String> providerDefaultHeaders(ProviderConfig config) {
  if (!isOpenRouterProvider(config)) return const <String, String>{};
  return const <String, String>{
    'HTTP-Referer': _openRouterAppReferer,
    'X-OpenRouter-Title': _openRouterAppTitle,
    'X-OpenRouter-Categories': _openRouterAppCategories,
  };
}

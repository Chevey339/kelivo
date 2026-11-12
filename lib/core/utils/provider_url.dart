import '../providers/settings_provider.dart';
import '../services/api/builtin_tools.dart';

enum UrlError { empty, invalid }

enum NormalizeNote {
  trimmedWhitespace,
  addedScheme,
  movedPath,
  trimmedSlash,
  addedVersion,
}

class NormalizeResult {
  const NormalizeResult({
    required this.value,
    this.movedPath,
    this.notes = const [],
    this.error,
  });

  final String value;
  final String? movedPath;
  final List<NormalizeNote> notes;
  final UrlError? error;
}

String providerUrlVersion(ProviderKind kind) =>
    kind == ProviderKind.google ? '/v1beta' : '/v1';

/// Normalizes an edited base URL. Never run this as a migration of saved config.
NormalizeResult normalizeBaseUrl(
  String raw,
  ProviderKind kind, {
  bool allowAutoVersion = true,
}) {
  var value = raw.trim();
  final notes = <NormalizeNote>[];
  if (value.isEmpty) {
    return const NormalizeResult(value: '', error: UrlError.empty);
  }
  if (value != raw) notes.add(NormalizeNote.trimmedWhitespace);
  // A host:port is not a URI scheme. Explicit schemes must still be validated.
  final hasScheme =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value) &&
      !RegExp(r'^[^/:]+:\d+(?:[/?#]|$)').hasMatch(value);
  if (!hasScheme && !value.startsWith('//')) {
    value = 'https://$value';
    notes.add(NormalizeNote.addedScheme);
  } else if (value.startsWith('//')) {
    value = 'https:$value';
    notes.add(NormalizeNote.addedScheme);
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const ['http', 'https'].contains(uri.scheme) ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      RegExp(r'[\s\\]').hasMatch(value)) {
    return NormalizeResult(value: raw.trim(), error: UrlError.invalid);
  }
  // Keep query/fragment and user-entered path spelling intact.
  var path = uri.path;
  String? movedPath;
  for (final endpoint in ['/chat/completions', '/responses', '/messages']) {
    if (path.endsWith(endpoint)) {
      movedPath = endpoint;
      path = path.substring(0, path.length - endpoint.length);
      notes.add(NormalizeNote.movedPath);
      break;
    }
  }
  if (path.endsWith('/')) {
    path = path.replaceFirst(RegExp(r'/+$'), '');
    notes.add(NormalizeNote.trimmedSlash);
  }
  if (allowAutoVersion && path.isEmpty) {
    path = providerUrlVersion(kind);
    notes.add(NormalizeNote.addedVersion);
  }
  if (path != uri.path) value = uri.replace(path: path).toString();
  return NormalizeResult(
    value: value,
    movedPath: movedPath,
    notes: List.unmodifiable(notes),
  );
}

/// The provider endpoint, using the same concatenation rules as requests.
/// [stream] only affects Google's RPC name; transport query parameters are
/// added by the caller, as before.
String resolveRequestUrl(
  ProviderConfig c, {
  String? modelId,
  bool stream = true,
}) {
  final base = c.baseUrl.endsWith('/')
      ? c.baseUrl.substring(0, c.baseUrl.length - 1)
      : c.baseUrl;
  final kind = ProviderConfig.classify(c.id, explicitType: c.providerType);
  switch (kind) {
    case ProviderKind.openai:
      if (c.useResponseApi == true) {
        final uri = Uri.parse(base);
        if (BuiltInToolsHelper.isDashScopeProvider(c) &&
            uri.path.replaceAll(RegExp(r'/$'), '') !=
                '/api/v2/apps/protocols/compatible-mode/v1') {
          return '${uri.scheme}://${uri.authority}/api/v2/apps/protocols/compatible-mode/v1/responses';
        }
        return '$base/responses';
      }
      return '$base${c.chatPath ?? '/chat/completions'}';
    case ProviderKind.claude:
      return '$base/messages';
    case ProviderKind.google:
      final model = modelId ?? '{模型}';
      if (c.vertexAI == true && model.toLowerCase().startsWith('claude-')) {
        final location = (c.location ?? 'us-central1').trim();
        final project = (c.projectId ?? '').trim();
        final endpoint = stream ? 'streamRawPredict' : 'rawPredict';
        return '${providerVertexOrigin(c, location)}/v1/projects/$project/locations/$location/publishers/anthropic/models/$model:$endpoint';
      }
      final endpoint = stream ? 'streamGenerateContent' : 'generateContent';
      if (c.vertexAI == true &&
          c.location?.isNotEmpty == true &&
          c.projectId?.isNotEmpty == true) {
        final location = stream ? c.location!.trim() : c.location!;
        final project = stream ? c.projectId!.trim() : c.projectId!;
        return 'https://aiplatform.googleapis.com/v1/projects/$project/locations/$location/publishers/google/models/$model:$endpoint';
      }
      return '$base/models/$model:$endpoint';
  }
}

String providerVertexOrigin(ProviderConfig config, String loc) {
  final raw = config.baseUrl.trim();
  final host = (Uri.tryParse(raw)?.host ?? '').toLowerCase();
  // Switching a Gemini provider to Vertex keeps its Gemini API base URL.
  final official =
      host.isEmpty ||
      host == 'generativelanguage.googleapis.com' ||
      host == 'aiplatform.googleapis.com' ||
      host.endsWith('-aiplatform.googleapis.com') ||
      RegExp(r'^aiplatform\.[a-z]+\.rep\.googleapis\.com$').hasMatch(host);
  if (official) {
    final l = loc.toLowerCase();
    final regional = switch (l) {
      'global' => 'aiplatform.googleapis.com',
      'us' || 'eu' => 'aiplatform.$l.rep.googleapis.com',
      _ => '$l-aiplatform.googleapis.com',
    };
    return 'https://$regional';
  }
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../../models/native_compaction.dart';
import '../../models/provider_oauth.dart';
import '../../models/token_usage.dart';
import '../../providers/settings_provider.dart';
import 'request_token_estimate.dart';

String _basePath(String path) => path
    .replaceFirst(
      RegExp(r'/(responses(?:/compact)?|chat/completions|messages)/?$'),
      '',
    )
    .replaceFirst(RegExp(r'/+$'), '');

/// Resolve against the configured service, including custom paths and queries.
Uri nativeResponsesEndpoint(ProviderConfig config, {bool compact = false}) {
  final base = Uri.parse(config.baseUrl);
  return base.replace(
    path: '${_basePath(base.path)}/responses${compact ? '/compact' : ''}',
  );
}

/// A scope protects opaque state from accidental replay to another connection.
/// Model names and provider allowlists do not decide native support.
String nativeCompactionScope(ProviderConfig config) => sha256
    .convert(
      utf8.encode(
        jsonEncode([
          config.id,
          nativeResponsesEndpoint(config).toString(),
          config.oauthProvider?.name,
          config.oauthCredentials?.accountId ??
              config.oauthCredentials?.sessionId,
        ]),
      ),
    )
    .toString();

ProviderConfig nativeResponsesConfig(ProviderConfig config) => config.copyWith(
  providerType: ProviderKind.openai,
  useResponseApi: true,
  baseUrl: Uri.parse(
    config.baseUrl,
  ).replace(path: _basePath(Uri.parse(config.baseUrl).path)).toString(),
);

bool hasNativeCompaction(List<Map<String, dynamic>> messages) =>
    messages.any((message) => message[nativeCompactionMessageKey] is Map);

/// A custom input replaces the entire history. Never silently discard opaque
/// state when applying such an override, including during tool follow-ups.
void validateNativeCompactionOverrides(
  Map<String, dynamic> body,
  Map<String, dynamic> overrides,
) {
  if (overrides.containsKey('input') &&
      (body['input'] as List? ?? const []).whereType<Map>().any(
        (item) => item[nativeCompactionWireKey] == true,
      )) {
    throw StateError('native_compaction_input_overridden');
  }
}

void validateNativeCompactionScope(
  List<Map<String, dynamic>> messages,
  ProviderConfig config,
) {
  for (final message in messages) {
    if (message[nativeCompactionMessageKey] case final Map value) {
      final payload = NativeCompactionPayload.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (payload.scope != nativeCompactionScope(config) ||
          (payload.protocol == NativeCompactionProtocol.codex) !=
              (config.oauthProvider == OAuthProvider.chatgpt)) {
        throw StateError('native_compaction_scope_changed');
      }
    }
  }
}

/// Reuse real input usage only while the same opaque window and connection are
/// active. New plain history/tools are estimated as a delta, never from the
/// ciphertext length. A changed window needs a new provider measurement.
class NativeCompactionUsage {
  const NativeCompactionUsage._(
    this.scope,
    this.identity,
    this.counted,
    this.inputTokens,
  );
  final String scope;
  final String identity;
  final int counted;
  final int inputTokens;

  static String? _identity(Map<String, dynamic> body) {
    final input = body['input'];
    if (input is! List) return null;
    final items = input
        .whereType<Map>()
        .where((item) => item['type'] == 'compaction')
        .toList();
    if (items.isEmpty) return null;
    return sha256
        .convert(
          utf8.encode(
            jsonEncode([
              for (final item in items)
                {
                  'id': item['id'],
                  'encrypted_content': item['encrypted_content'],
                },
            ]),
          ),
        )
        .toString();
  }

  static NativeCompactionUsage? record(
    Map<String, dynamic> body,
    String scope,
    TokenUsage usage,
  ) {
    final identity = _identity(body);
    if (identity == null || usage.promptTokens <= 0) return null;
    return NativeCompactionUsage._(
      scope,
      identity,
      estimateRequestInput(body, ProviderKind.openai),
      usage.promptTokens,
    );
  }

  int? estimate(Map<String, dynamic> body, String scope) {
    if (this.scope != scope || identity != _identity(body)) return null;
    return (inputTokens +
            estimateRequestInput(body, ProviderKind.openai) -
            counted)
        .clamp(0, 1 << 31);
  }
}

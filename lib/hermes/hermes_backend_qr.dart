import 'dart:convert';

/// QR code payload parsed from the Hermes backend QR display.
///
/// Hermes can display a QR code containing connection info.
/// Format: `kelivo://hermes?url=...&token=...&profile=...`
/// or plain JSON: `{"v":1,"url":"ws://...","token":"...","profile":"..."}`
class HermesQrPayload {
  final String url;
  final String? token;
  final String? profile;

  const HermesQrPayload({required this.url, this.token, this.profile});
}

/// Parses QR code content into a [HermesQrPayload].
HermesQrPayload? parseHermesQr(String raw) {
  final trimmed = raw.trim();

  // Plain JSON format
  if (trimmed.startsWith('{')) {
    try {
      final m = jsonDecode(trimmed) as Map<String, dynamic>;
      return HermesQrPayload(
        url: m['url'] as String,
        token: m['token'] as String?,
        profile: m['profile'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // kelivo://hermes? URL scheme
  if (trimmed.startsWith('kelivo://hermes')) {
    try {
      final uri = Uri.parse(trimmed);
      final params = uri.queryParameters;
      return HermesQrPayload(
        url: params['url'] ?? '',
        token: params['token'],
        profile: params['profile'],
      );
    } catch (_) {
      return null;
    }
  }

  // ws:// or wss:// direct URL — minimal: just url, no auth
  if (trimmed.startsWith('ws://') || trimmed.startsWith('wss://')) {
    return HermesQrPayload(url: trimmed);
  }

  return null;
}

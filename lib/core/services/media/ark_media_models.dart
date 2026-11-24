bool isArkMediaHost(String host) =>
    host.startsWith('ark.') &&
    (host.endsWith('.volces.com') || host.endsWith('.bytepluses.com'));

final _arkFamily = RegExp(
  r'(?:(?:doubao|bytedance|dola|dreamina)[ -])?(?:seedream|seededit|seedance)[ -]+\d[\w.-]*(?:[ -]+(?:pro|lite|flash|fast|mini|i2v|t2v|i2i)\b)*',
  caseSensitive: false,
);

/// Ark endpoint IDs hide the model family. An explicitly named model can
/// supply its capabilities while the request still addresses the endpoint ID.
String arkMediaFamily(String upstream, String logicalId, String? displayName) {
  if (!upstream.toLowerCase().startsWith('ep-')) return upstream.toLowerCase();
  for (final label in [logicalId, if (displayName != null) displayName]) {
    final match = _arkFamily.firstMatch(label);
    if (match != null) {
      return match.group(0)!.toLowerCase().replaceAll(RegExp(r' +'), '-');
    }
  }
  return upstream.toLowerCase();
}

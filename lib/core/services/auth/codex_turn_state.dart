import '../../providers/settings_provider.dart';

/// Server routing state for one user generation, shared by retries and tool
/// continuations, but never by separate generations.
class CodexTurnState {
  static const headerName = 'x-codex-turn-state';

  (String, String?, String?)? _owner;
  String? _value;

  (String, String?, String?) _ownerOf(ProviderConfig config) => (
    config.id,
    config.oauthCredentials?.sessionId,
    config.oauthCredentials?.accountId,
  );

  void apply(Map<String, String> headers, ProviderConfig config) {
    final owner = _ownerOf(config);
    if (_owner != owner) {
      _owner = owner;
      _value = null;
    }
    // This token is supplied by the server, not by persistent custom headers.
    headers.remove(headerName);
    if (_value case final value?) headers[headerName] = value;
  }

  void capture(Map<String, String> headers, ProviderConfig config) {
    // A late response from an earlier owner cannot overwrite the current turn.
    if (_owner == _ownerOf(config)) _value ??= headers[headerName];
  }
}

/// Profile scope management.
///
/// Hermes supports multiple named profiles (e.g. "default", "work", "personal").
/// This module tracks which profile is active and provides helpers to scope
/// RPC calls to the current profile.

import 'hermes_config.dart';
import 'hermes_gateway.dart';

/// Tracks the active Hermes profile scope.
class HermesProfileScope {
  final HermesConfig _config;
  HermesGateway? _gateway;

  HermesProfileScope({required HermesConfig config}) : _config = config;

  /// Attach a gateway instance to scope RPC calls.
  void attach(HermesGateway gateway) {
    _gateway = gateway;
  }

  /// The currently active profile name, or null for default.
  String? get currentProfile => _config.activeBackend?.profile;

  /// Switch to a different profile on the active backend.
  Future<void> switchProfile(String? profile) async {
    final backend = _config.activeBackend;
    if (backend == null) return;

    await _gateway?.sendRpc('profile.switch', {'profile': profile});
  }

  /// List available profiles.
  Future<List<String>> listProfiles() async {
    final result = await _gateway?.sendRpc('profile.list');
    return (result?['profiles'] as List?)?.cast<String>() ?? [];
  }
}

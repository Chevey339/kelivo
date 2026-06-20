/// Stub implementation of [HermesBackendDiscovery] for desktop platforms.
///
/// mDNS discovery via bonsoir is not available on macOS/Linux desktop.
/// Users on desktop add backends manually via URL or QR code.
abstract class HermesBackendDiscovery {
  /// Creates a discovery instance. On desktop, all scan methods are no-ops.
  factory HermesBackendDiscovery() = _DesktopDiscoveryStub;

  /// No-op on desktop.
  Stream<List<DiscoveredHermesBackend>> get discovered => const Stream.empty();

  /// No-op on desktop.
  Future<void> startScan() async {}

  /// No-op on desktop.
  Future<void> stopScan() async {}

  /// No-op on desktop.
  void dispose() {}
}

/// A Hermes backend discovered on the local network via mDNS.
class DiscoveredHermesBackend {
  final String name;
  final String host;
  final int port;
  final String url; // ws://host:port

  DiscoveredHermesBackend({
    required this.name,
    required this.host,
    required this.port,
  }) : url = 'ws://$host:$port';

  @override
  String toString() => 'DiscoveredHermesBackend($name @ $url)';
}

class _DesktopDiscoveryStub implements HermesBackendDiscovery {
  @override
  Stream<List<DiscoveredHermesBackend>> get discovered => const Stream.empty();

  @override
  Future<void> startScan() async {}

  @override
  Future<void> stopScan() async {}

  @override
  void dispose() {}
}

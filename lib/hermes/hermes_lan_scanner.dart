import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Cancellation token for aborting scan operations.
class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// A Hermes backend discovered on the local network.
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredHermesBackend &&
          runtimeType == other.runtimeType &&
          host == other.host &&
          port == other.port;

  @override
  int get hashCode => host.hashCode ^ port.hashCode;
}

/// Configuration for Hermes LAN scanner.
class LanScannerConfig {
  /// Default Hermes server port.
  static const int defaultPort = 9119;

  /// Connection timeout for each probe.
  static const Duration connectionTimeout = Duration(milliseconds: 500);

  /// Scan timeout for entire scan operation.
  static const Duration scanTimeout = Duration(seconds: 30);

  const LanScannerConfig({
    this.ports = const [defaultPort],
    this.connectionTimeoutMs = 1000,
    this.maxConcurrent = 30,
    this.scanTimeoutMs = 30000,
  });

  /// Ports to scan.
  final List<int> ports;

  /// Connection timeout in milliseconds.
  final int connectionTimeoutMs;

  /// Maximum concurrent connections.
  final int maxConcurrent;

  /// Scan timeout in milliseconds.
  final int scanTimeoutMs;
}

/// Hermes backend discovery via LAN scanning.
///
/// Scans the local network for Hermes servers by probing common ports
/// and verifying with the /api/status endpoint.
class HermesBackendDiscovery {
  HermesBackendDiscovery._() : _config = const LanScannerConfig();

  final LanScannerConfig _config;
  final _controller = StreamController<List<DiscoveredHermesBackend>>.broadcast();
  final _results = <DiscoveredHermesBackend>[];
  final _foundHosts = <String>{};
  CancellationToken? _cancellationToken;
  bool _isScanning = false;

  HermesBackendDiscovery({LanScannerConfig? config})
      : _config = config ?? const LanScannerConfig();

  /// Stream of discovered backends, emits a list each time new backends are found.
  Stream<List<DiscoveredHermesBackend>> get discovered => _controller.stream;

  /// Whether a scan is currently in progress.
  bool get isScanning => _isScanning;

  /// Start scanning for Hermes backends on the local network.
  Future<void> startScan() async {
    if (_isScanning) {
      print('[LanScanner] Already scanning, ignoring request');
      return;
    }
    
    _isScanning = true;
    _cancellationToken = CancellationToken();
    _results.clear();
    _foundHosts.clear();

    print('[LanScanner] Starting scan with config: ports=$_config.ports, timeout=${_config.connectionTimeoutMs}ms, maxConcurrent=${_config.maxConcurrent}');

    try {
      // Get network interfaces
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      print('[LanScanner] Found ${interfaces.length} network interfaces');

      final targets = <String>[];
      for (final interface in interfaces) {
        print('[LanScanner] Interface: ${interface.name}, addresses: ${interface.addresses.map((a) => a.address).join(', ')}');
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            final subnetTargets = _expandSubnet(addr.address, 24);
            print('[LanScanner] Expanded ${addr.address} to ${subnetTargets.length} targets');
            targets.addAll(subnetTargets);
          }
        }
      }

      if (targets.isEmpty) {
        print('[LanScanner] No targets to scan, finishing');
        _controller.add([]);
        return;
      }

      // Deduplicate targets
      final uniqueTargets = targets.toSet().toList();
      print('[LanScanner] Total unique targets to scan: ${uniqueTargets.length}');

      // Scan with controlled concurrency
      await _scanTargets(uniqueTargets);
      
      print('[LanScanner] Scan complete, found ${_results.length} backends');
      _controller.add(List.from(_results));
    } catch (e, stack) {
      print('[LanScanner] Scan error: $e\n$stack');
    } finally {
      _isScanning = false;
      _cancellationToken = null;
    }
  }

  /// Stop the current scan.
  Future<void> stopScan() async {
    print('[LanScanner] Stopping scan');
    _cancellationToken?.cancel();
    _isScanning = false;
  }

  /// Dispose resources.
  void dispose() {
    _cancellationToken?.cancel();
    _controller.close();
  }

  /// Expand an IPv4 address with subnet mask into a list of target IPs.
  List<String> _expandSubnet(String ip, int maskBits) {
    final parts = ip.split('.').map(int.parse).toList();
    if (parts.length != 4) return [ip];

    // Clamp mask to reasonable range
    maskBits = maskBits.clamp(16, 30);
    
    final hostBits = 32 - maskBits;
    final baseAddr = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
    final hostMask = (1 << hostBits) - 1;
    final networkAddr = baseAddr & (~hostMask);

    final targets = <String>[];
    // Calculate number of hosts, cap at 254
    final numHosts = (1 << hostBits).clamp(1, 254);
    
    // For small subnets, scan all; for larger, sample
    if (numHosts <= 254) {
      for (var i = 1; i <= numHosts; i++) {
        final addr = networkAddr + i;
        targets.add('${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}');
      }
    } else {
      // For /16 or larger, just scan a subset to avoid timeout
      for (var i = 1; i <= 254; i++) {
        final addr = networkAddr + i;
        targets.add('${(addr >> 24) & 0xFF}.${(addr >> 16) & 0xFF}.${(addr >> 8) & 0xFF}.${addr & 0xFF}');
      }
    }

    return targets;
  }

  Future<void> _scanTargets(List<String> targets) async {
    final token = _cancellationToken;
    if (token == null) return;

    final timeoutMs = _config.scanTimeoutMs;
    final scanFuture = _doScan(targets, token);
    
    // Add overall timeout
    await scanFuture.timeout(
      Duration(milliseconds: timeoutMs),
      onTimeout: () {
        print('[LanScanner] Scan timed out after ${timeoutMs}ms');
        token.cancel();
      },
    );
  }

  Future<void> _doScan(List<String> targets, CancellationToken token) async {
    final semaphore = _Semaphore(_config.maxConcurrent);
    final futures = <Future<void>>[];

    for (final target in targets) {
      if (token.isCancelled) break;

      if (_foundHosts.contains(target)) continue;

      futures.add(
        semaphore.run(() async {
          if (token.isCancelled) return;
          await _probeTarget(target, token);
        }),
      );
    }

    await Future.wait(futures);
  }

  Future<void> _probeTarget(String host, CancellationToken token) async {
    if (token.isCancelled) return;

    for (final port in _config.ports) {
      if (token.isCancelled) return;

      try {
        // Try HTTP first (more efficient)
        final isHermes = await _verifyHermes(host, port, token);
        if (isHermes && !token.isCancelled) {
          print('[LanScanner] Found Hermes at $host:$port');
        }
      } catch (_) {
        // Port closed or timeout, continue
      }
    }
  }

  Future<bool> _verifyHermes(String host, int port, CancellationToken token) async {
    if (token.isCancelled) return false;

    try {
      final timeout = Duration(milliseconds: _config.connectionTimeoutMs);
      
      // Direct HTTP request
      final client = HttpClient();
      client.connectionTimeout = timeout;
      client.idleTimeout = const Duration(seconds: 1);

      try {
        final request = await client.getUrl(Uri.parse('http://$host:$port/api/status'));
        request.headers.set('User-Agent', 'Kelivo/1.0');
        
        final response = await request.close().timeout(timeout);
        
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;

          // Extract server name
          String name = 'Hermes@$host';
          if (data.containsKey('name')) {
            name = data['name']?.toString() ?? name;
          } else if (data.containsKey('hostname')) {
            name = data['hostname']?.toString() ?? name;
          } else if (data.containsKey('server')) {
            name = data['server']?.toString() ?? name;
          }

          // Double-check we haven't already added this
          if (!_foundHosts.contains(host)) {
            _foundHosts.add(host);
            final backend = DiscoveredHermesBackend(name: name, host: host, port: port);
            _results.add(backend);
            _controller.add(List.from(_results));
            return true;
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      // Not a Hermes server
    }
    return false;
  }
}

/// Simple semaphore for controlling concurrency.
class _Semaphore {
  _Semaphore(this.maxCount);

  final int maxCount;
  int _currentCount = 0;
  final _waitQueue = <Completer<void>>[];

  Future<T> run<T>(Future<T> Function() task) async {
    if (_currentCount < maxCount) {
      _currentCount++;
      try {
        return await task();
      } finally {
        _release();
      }
    } else {
      final completer = Completer<void>();
      _waitQueue.add(completer);
      await completer.future;
      _currentCount++;
      try {
        return await task();
      } finally {
        _release();
      }
    }
  }

  void _release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeAt(0);
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}

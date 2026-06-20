import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../hermes/hermes_auth.dart';
import '../../hermes/hermes_config.dart';
import '../../hermes/hermes_event_bus.dart';
import '../../hermes/hermes_gateway.dart';
import '../../hermes/hermes_rest_client.dart';

/// Top-level provider that owns the [HermesGateway] singleton.
///
/// Wraps [HermesGateway] as a Flutter [ChangeNotifier] so the UI can
/// react to connection state changes without importing Hermes internals.
class HermesGatewayProvider extends ChangeNotifier {
  late final HermesConfig _config;
  late final HermesEventBus _eventBus;
  late final HermesGateway _gateway;

  HermesConnectionState _state = HermesConnectionState.disconnected;
  HermesBackendBox? _currentBackend;
  String? _lastError;

  HermesGatewayProvider() {
    _config = HermesConfig();
    _eventBus = HermesEventBus();
    _gateway = HermesGateway(eventBus: _eventBus, config: _config);
  }

  HermesConnectionState get state => _state;
  HermesBackendBox? get currentBackend => _currentBackend;
  HermesEventBus get eventBus => _eventBus;
  HermesGateway get gateway => _gateway;
  HermesConfig get config => _config;
  String? get lastError => _lastError;

  /// Initialize Hive config and load persisted backends.
  Future<void> init() async {
    await _config.init();
    // Auto-connect to last active backend if any
    final active = _config.activeBackend;
    if (active != null) {
      await connectBackend(active.id);
    }
  }

  /// Connect to a backend by its id.
  Future<void> connectBackend(String id) async {
    final backend = _config.box.get(id);
    if (backend == null) {
      _lastError = 'Backend not found: $id';
      _state = HermesConnectionState.error;
      notifyListeners();
      return;
    }

    _currentBackend = backend;
    _lastError = null;
    _state = HermesConnectionState.connecting;
    notifyListeners();

    try {
      await _gateway.connect(backend);
      await _config.markConnected(backend.id);
      _currentBackend = backend;
      _state = HermesConnectionState.ready;
    } on HermesAuthException catch (e) {
      _lastError = e.message;
      _state = HermesConnectionState.error;
      await _config.markError(backend.id, e.message);
    } catch (e) {
      _lastError = e.toString();
      _state = HermesConnectionState.error;
      await _config.markError(backend.id, e.toString());
    }

    notifyListeners();
  }

  /// Disconnect from the current backend.
  Future<void> disconnect() async {
    await _gateway.disconnect();
    _state = HermesConnectionState.disconnected;
    _currentBackend = null;
    notifyListeners();
  }

  /// Add a new backend and optionally connect to it.
  Future<void> addBackend({
    required String name,
    required String url,
    String? token,
    String? profile,
    String authMode = 'auto',
    bool connectImmediately = false,
  }) async {
    final backend = HermesBackendBox(
      id: const Uuid().v4(),
      name: name,
      url: url,
      authMode: authMode,
      token: token,
      profile: profile,
      addedAt: DateTime.now(),
    );
    await _config.addBackend(backend);

    if (connectImmediately) {
      await connectBackend(backend.id);
    } else {
      notifyListeners();
    }
  }

  /// Remove a backend by id.
  Future<void> removeBackend(String id) async {
    if (_currentBackend?.id == id) {
      await disconnect();
    }
    await _config.removeBackend(id);
    notifyListeners();
  }

  /// Send a JSON-RPC call through the gateway.
  Future<dynamic> sendRpc(String method, [Map<String, dynamic>? params]) {
    return _gateway.sendRpc(method, params);
  }

  @override
  void dispose() {
    _gateway.dispose();
    super.dispose();
  }
}

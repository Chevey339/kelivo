import 'package:hive/hive.dart';

part 'hermes_config.g.dart';

/// Auth mode for a Hermes backend connection.
enum HermesAuthMode {
  /// Loopback / insecure mode: token passed as query param.
  loopback,

  /// Gated / OAuth mode: one-time ticket obtained from `/api/auth/ws-ticket`.
  gated,

  /// Auth mode will be auto-detected on first connect.
  auto,
}

/// Persisted Hermes backend configuration.
@HiveType(typeId: 100)
class HermesBackendBox extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String url; // ws:// or wss://

  @HiveField(3)
  String authMode; // 'loopback' | 'gated' | 'auto'

  @HiveField(4)
  String? token;

  @HiveField(5)
  String? profile;

  @HiveField(6)
  final DateTime addedAt;

  @HiveField(7)
  DateTime? lastConnectedAt;

  @HiveField(8)
  String? lastError;

  @HiveField(9)
  bool isActive;

  HermesBackendBox({
    required this.id,
    required this.name,
    required this.url,
    required this.authMode,
    this.token,
    this.profile,
    required this.addedAt,
    this.lastConnectedAt,
    this.lastError,
    this.isActive = false,
  });

  HermesAuthMode get authModeEnum {
    switch (authMode) {
      case 'gated':
        return HermesAuthMode.gated;
      case 'loopback':
        return HermesAuthMode.loopback;
      default:
        return HermesAuthMode.auto;
    }
  }

  HermesBackendBox copyWith({
    String? name,
    String? url,
    String? authMode,
    String? token,
    String? profile,
    DateTime? lastConnectedAt,
    String? lastError,
    bool? isActive,
  }) {
    return HermesBackendBox(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      authMode: authMode ?? this.authMode,
      token: token ?? this.token,
      profile: profile ?? this.profile,
      addedAt: addedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastError: lastError ?? this.lastError,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Manages the list of Hermes backends persisted in Hive.
class HermesConfig {
  static const String _boxName = 'hermes_backends';

  Box<HermesBackendBox>? _box;

  Box<HermesBackendBox> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
        'HermesConfig not initialized. Call HermesConfig.init() first.',
      );
    }
    return _box!;
  }

  /// Initialize Hive and open the backends box.
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(HermesBackendBoxAdapter());
    }
    _box = await Hive.openBox<HermesBackendBox>(_boxName);
  }

  /// All persisted backends.
  List<HermesBackendBox> get backends => box.values.toList();

  /// Currently active backend.
  HermesBackendBox? get activeBackend =>
      backends.where((b) => b.isActive).firstOrNull;

  /// Add a new backend.
  Future<void> addBackend(HermesBackendBox backend) async {
    await box.put(backend.id, backend);
  }

  /// Remove a backend by id.
  Future<void> removeBackend(String id) async {
    await box.delete(id);
  }

  /// Set a backend as the active one.
  Future<void> setActiveBackend(String id) async {
    for (final b in backends) {
      final changed = b.isActive != (b.id == id);
      if (changed) {
        b.isActive = (b.id == id);
        await b.save();
      }
    }
  }

  /// Update last connected timestamp and clear last error.
  Future<void> markConnected(String id) async {
    final b = box.get(id);
    if (b != null) {
      b.lastConnectedAt = DateTime.now();
      b.lastError = null;
      b.isActive = true;
      await b.save();
      await setActiveBackend(id);
    }
  }

  /// Record a connection error.
  Future<void> markError(String id, String error) async {
    final b = box.get(id);
    if (b != null) {
      b.lastError = error;
      await b.save();
    }
  }

  /// Close the Hive box.
  Future<void> close() async {
    await _box?.close();
  }
}

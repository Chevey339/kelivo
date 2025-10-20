import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provides a lightweight bridge between SharedPreferences and the native
/// iCloud key-value store on Apple platforms. The native layer is responsible
/// for mirroring UserDefaults changes into iCloud and vice versa. This Dart
/// service merely ensures initialization happens before the app runs and gives
/// interested classes a hook to refresh any in-memory caches when remote
/// updates arrive.
class ICloudSyncService {
  ICloudSyncService._();

  static final ICloudSyncService instance = ICloudSyncService._();

  static const _channelName = 'kelivo/icloud_kv';
  static const _eventsName = 'kelivo/icloud_kv_events';

  final MethodChannel _channel = const MethodChannel(_channelName);
  final EventChannel _events = const EventChannel(_eventsName);

  final List<VoidCallback> _listeners = <VoidCallback>[];

  StreamSubscription<dynamic>? _eventSub;
  bool _active = false;

  bool get isSupported {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  bool get isActive => _active;

  /// Initializes the native iCloud bridge (no-op on non-Apple platforms).
  Future<void> initialize() => enable();

  /// Enables iCloud sync bridging if supported.
  Future<void> enable() async {
    if (!isSupported) {
      _active = false;
      return;
    }
    if (_active) return;
    try {
      await _eventSub?.cancel();
      _eventSub = _events.receiveBroadcastStream().listen((dynamic _) async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload();
        } catch (_) {
          // ignore reload errors; listeners will attempt to recover
        }
        // Notify registered listeners so they can refresh their own caches.
        for (final listener in List<VoidCallback>.from(_listeners)) {
          try {
            listener();
          } catch (_) {
            // Listener errors should not break other listeners.
          }
        }
      });
      await _channel.invokeMethod<void>('initialize');
      _active = true;
    } on MissingPluginException {
      // iCloud bridge not available (e.g., running on simulator without plugin).
      await _eventSub?.cancel();
      _eventSub = null;
      _active = false;
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[ICloudSyncService] initialize failed: $err');
      }
      await _eventSub?.cancel();
      _eventSub = null;
      _active = false;
    }
  }

  /// Disables iCloud sync bridging and stops listening for remote updates.
  Future<void> disable() async {
    if (!isSupported) {
      _active = false;
      return;
    }
    if (!_active) return;
    try {
      await _channel.invokeMethod<void>('shutdown');
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[ICloudSyncService] shutdown failed: $err');
      }
    }
    await _eventSub?.cancel();
    _eventSub = null;
    _active = false;
  }

  /// Manually requests a local-to-iCloud sync (safe to call on any platform).
  Future<void> syncNow() async {
    if (!isSupported || !_active) return;
    try {
      await _channel.invokeMethod<void>('manualSync');
    } catch (err) {
      if (kDebugMode) {
        debugPrint('[ICloudSyncService] manualSync failed: $err');
      }
    }
  }

  void addListener(VoidCallback listener) {
    if (_listeners.contains(listener)) return;
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    _eventSub = null;
    _listeners.clear();
    _active = false;
  }
}

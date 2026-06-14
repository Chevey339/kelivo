import 'package:flutter/foundation.dart';

enum SyncStatus { disabled, enabling, idle, pushing, pulling, error }

class SyncProvider extends ChangeNotifier {
  SyncStatus _status = SyncStatus.disabled;
  int _pendingChangeCount = 0;
  DateTime? _lastSyncAt;
  String? _lastError;
  int _consecutiveFailures = 0;

  /// External callback set by the app initialization code.
  /// UI calls [triggerSync] which dispatches here.
  VoidCallback? onTriggerSync;
  VoidCallback? onResetError;

  SyncStatus get status => _status;
  int get pendingChangeCount => _pendingChangeCount;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  int get consecutiveFailures => _consecutiveFailures;
  bool get isReady => _status == SyncStatus.idle;

  void triggerSync() {
    onTriggerSync?.call();
  }

  void setStatus(SyncStatus status) {
    if (_status == status) return;
    _status = status;
    if (status != SyncStatus.error) {
      _lastError = null;
    }
    notifyListeners();
  }

  void setPendingChangeCount(int count) {
    if (_pendingChangeCount == count) return;
    _pendingChangeCount = count;
    notifyListeners();
  }

  void setLastSyncAt(DateTime? at) {
    _lastSyncAt = at;
    notifyListeners();
  }

  void recordError(String message) {
    _status = SyncStatus.error;
    _lastError = message;
    _consecutiveFailures++;
    notifyListeners();
  }

  void resetError() {
    onResetError?.call();
    if (_status == SyncStatus.error) {
      _status = SyncStatus.idle;
    }
    _lastError = null;
    _consecutiveFailures = 0;
    notifyListeners();
  }

  bool get shouldBackoff => _consecutiveFailures >= 3;

  bool get shouldStop => _consecutiveFailures >= 6;
}

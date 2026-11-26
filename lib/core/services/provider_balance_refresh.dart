import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/widgets.dart';

import '../providers/settings_provider.dart';
import 'provider_balance_service.dart';

typedef ProviderBalanceSnapshot = ({
  String? balance,
  DateTime? updatedAt,
  String? error,
});

/// Owns balance results and scheduling for all surfaces using these settings.
class ProviderBalanceRefresh {
  ProviderBalanceRefresh(
    this._settings, {
    @visibleForTesting
    Future<String> Function(ProviderConfig, {CancelToken? cancelToken})? fetch,
    @visibleForTesting
    Future<bool> Function(ProviderConfig) hasNetwork = _hasNetwork,
  }) : _fetch = fetch ?? ProviderBalanceService.fetchBalance,
       _networkAvailable = hasNetwork {
    _settings.addListener(_syncSettings);
    _lifecycle = AppLifecycleListener(
      onStateChange: (_) {
        for (final entry in _entries.values) {
          entry._schedule();
        }
      },
    );
  }

  final SettingsProvider _settings;
  final Future<String> Function(ProviderConfig, {CancelToken? cancelToken})
  _fetch;
  final Future<bool> Function(ProviderConfig) _networkAvailable;
  final _entries = <String, ProviderBalanceEntry>{};
  late final AppLifecycleListener _lifecycle;

  bool get _appVisible => switch (WidgetsBinding.instance.lifecycleState) {
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
    _ => true,
  };

  ProviderBalanceEntry forProvider(String key) => _entries.putIfAbsent(
    key,
    () => ProviderBalanceEntry._(this, _settings.getProviderConfig(key)),
  );

  void replyFinished(String key) {
    final entry = forProvider(key);
    entry._replyDue = clock.now().add(ProviderBalanceEntry._debounce);
    entry._schedule();
  }

  void _syncSettings() {
    for (final entry in _entries.entries) {
      entry.value._applySettings(_settings.getProviderConfig(entry.key));
    }
  }

  void dispose() {
    _settings.removeListener(_syncSettings);
    _lifecycle.dispose();
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
  }

  static Future<bool> _hasNetwork(ProviderConfig config) async {
    // Local endpoints can work even while the device is disconnected.
    try {
      final host = ProviderBalanceService.balanceUri(config).host;
      if (host == 'localhost' ||
          InternetAddress.tryParse(host)?.isLoopback == true) {
        return true;
      }
    } on FormatException {
      return true;
    } on ProviderBalanceException {
      return true;
    }
    final connectivity = await Connectivity().checkConnectivity();
    return !connectivity.contains(ConnectivityResult.none);
  }
}

class ProviderBalanceEntry extends ValueNotifier<ProviderBalanceSnapshot> {
  ProviderBalanceEntry._(this._owner, this._config) : super(_empty) {
    _interval = _owner._settings.balanceRefreshIntervalFor(_config);
    _onReply = _owner._settings.balanceRefreshOnReplyFor(_config);
    _initialDue = clock.now().add(_debounce);
  }

  static const ProviderBalanceSnapshot _empty = (
    balance: null,
    updatedAt: null,
    error: null,
  );
  static const _debounce = Duration(milliseconds: 500);
  static const _timeout = Duration(seconds: 20);
  static const _offlineDelay = Duration(seconds: 30);
  final ProviderBalanceRefresh _owner;
  ProviderConfig _config;
  late int _interval;
  late bool _onReply;
  int _visibleBadges = 0;
  bool _checkingNetwork = false;
  bool _disposed = false;
  Timer? _timer;
  DateTime? _initialDue;
  DateTime? _replyDue;
  DateTime? _lastAttempt;
  DateTime? _retryAt;
  DateTime? _offlineUntil;
  int _failures = 0;
  CancelToken? _cancelToken;
  Future<String>? _inFlight;

  VoidCallback attachVisibleBadge() {
    if (_visibleBadges == 0 &&
        _interval == 0 &&
        !_onReply &&
        value.balance == null &&
        value.error != null) {
      _initialDue = clock.now().add(_debounce);
    }
    _visibleBadges++;
    _schedule();
    return () {
      _visibleBadges--;
      _schedule();
    };
  }

  void _applySettings(ProviderConfig config) {
    final interval = _owner._settings.balanceRefreshIntervalFor(config);
    final onReply = _owner._settings.balanceRefreshOnReplyFor(config);
    if (identical(_config, config) &&
        _interval == interval &&
        _onReply == onReply) {
      return;
    }
    final reset =
        _config.balanceEnabled != config.balanceEnabled ||
        (!identical(_config, config) &&
            !ProviderBalanceService.sameRequest(_config, config));
    _config = config;
    _interval = interval;
    _onReply = onReply;
    if (!onReply) _replyDue = null;
    if (reset) {
      _cancelRequest();
      _initialDue = clock.now().add(_debounce);
      _replyDue = null;
      _lastAttempt = null;
      _retryAt = null;
      _offlineUntil = null;
      _failures = 0;
      value = _empty;
    }
    _schedule();
  }

  DateTime? get _nextRefresh {
    if (_disposed ||
        !_config.enabled ||
        _config.balanceEnabled != true ||
        _visibleBadges == 0 ||
        !_owner._appVisible ||
        _inFlight != null ||
        _checkingNetwork) {
      return null;
    }

    // A burst of replies can move the debounce but not the periodic deadline.
    // Starting a query consumes the pending reply refresh.
    var due = _replyDue;
    final lastAttempt = _lastAttempt;
    if (_interval > 0 && lastAttempt != null) {
      final periodic = lastAttempt.add(Duration(minutes: _interval));
      if (due == null || periodic.isBefore(due)) due = periodic;
    }
    due = _later(due, _initialDue);
    if (_interval > 0 || _onReply) {
      due = _later(due, _retryAt);
    }
    return due == null ? null : _later(due, _offlineUntil);
  }

  static DateTime? _later(DateTime? first, DateTime? second) =>
      first == null || (second != null && second.isAfter(first))
      ? second
      : first;

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    final due = _nextRefresh;
    if (due == null) return;
    _timer = Timer(due.difference(clock.now()), _refreshIfDue);
  }

  Future<void> _refreshIfDue() async {
    _timer = null;
    final config = _config;
    _checkingNetwork = true;
    var online = true;
    try {
      online = await _owner
          ._networkAvailable(config)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Some hosts do not provide a connectivity service (e.g. NetworkManager
      // on Linux). In that case let the HTTP request detect network errors.
    } finally {
      _checkingNetwork = false;
    }
    final now = clock.now();
    final due = _nextRefresh;
    if (identical(config, _config) && due != null && !due.isAfter(now)) {
      if (online) {
        try {
          await query();
        } catch (_) {
          // The shared snapshot contains the error and the last good result.
        }
        return;
      }
      _offlineUntil = now.add(_offlineDelay);
    }
    _schedule();
  }

  Future<String> query() {
    final current = _inFlight;
    if (current != null) return current;
    _timer?.cancel();
    _timer = null;
    _initialDue = null;
    _replyDue = null;
    _offlineUntil = null;
    final token = CancelToken();
    _cancelToken = token;
    return _inFlight = _runQuery(_config, token);
  }

  Future<String> _runQuery(ProviderConfig config, CancelToken token) async {
    try {
      final balance =
          await Future<String>.sync(
            () => _owner._fetch(config, cancelToken: token),
          ).timeout(
            _timeout,
            onTimeout: () {
              token.cancel();
              throw const ProviderBalanceException('Balance request timed out');
            },
          );
      if (!identical(_cancelToken, token)) {
        throw const ProviderBalanceException('Balance request was cancelled');
      }
      _failures = 0;
      _retryAt = null;
      value = (balance: balance, updatedAt: clock.now(), error: null);
      return balance;
    } catch (error) {
      if (identical(_cancelToken, token)) {
        final seconds = math.min(30 << math.min(_failures++, 4), 300);
        _retryAt = clock.now().add(Duration(seconds: seconds));
        value = (
          balance: value.balance,
          updatedAt: value.updatedAt,
          error: error.toString(),
        );
      }
      rethrow;
    } finally {
      if (identical(_cancelToken, token)) {
        _inFlight = null;
        _cancelToken = null;
        _lastAttempt = clock.now();
        _schedule();
      }
    }
  }

  void _cancelRequest() {
    final token = _cancelToken;
    _cancelToken = null;
    _inFlight = null;
    token?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _cancelRequest();
    super.dispose();
  }
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/business_settings_router.dart';

const defaultCodexClientVersion = '0.169.0';
typedef CodexVersionSnapshot = ({String version, int revision});
const bundledCodexVersion = (version: defaultCodexClientVersion, revision: 0);

class CodexClientVersion extends ChangeNotifier {
  CodexClientVersion({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? IOClient.new;

  static final _latestUri = Uri.parse(
    'https://registry.npmjs.org/@openai/codex/latest',
  );
  static const _refreshInterval = Duration(hours: 6);
  static const _retryInterval = Duration(minutes: 5);
  static final _stableVersion = RegExp(r'^\d{1,9}\.\d{1,9}\.\d{1,9}$');
  static final _floor = defaultCodexClientVersion
      .split('.')
      .map(int.parse)
      .toList();

  final http.Client Function() _clientFactory;
  CodexVersionSnapshot _snapshot = bundledCodexVersion;
  CodexVersionSnapshot get snapshot => _snapshot;
  DateTime? _nextCheck;
  Future<SharedPreferences?>? _cache;
  Future<void>? _checking;

  Future<String> current() async {
    await (_cache ??= _loadCache());
    return snapshot.version;
  }

  Future<void> refresh({bool force = false}) async {
    final preferences = await (_cache ??= _loadCache());
    if (_checking case final pending?) {
      await pending;
    } else if (force || _nextCheck?.isAfter(DateTime.now()) != true) {
      final request = _checkLatest(preferences);
      _checking = request;
      try {
        await request;
      } finally {
        _checking = null;
      }
    }
  }

  Future<SharedPreferences?> _loadCache() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      final raw = preferences.get(
        BusinessKeyRegistry.codexClientVersionCacheKey,
      );
      if (raw is! String) return preferences;
      final record = jsonDecode(raw);
      if (record is Map && _adopt(record['version'])) {
        final checkedAt = record['checkedAt'];
        if (checkedAt is int) {
          final timestamp = DateTime.fromMillisecondsSinceEpoch(checkedAt);
          if (!timestamp.isAfter(DateTime.now())) {
            _nextCheck = timestamp.add(_refreshInterval);
          }
        }
      }
    } catch (_) {}
    return preferences;
  }

  Future<void> _checkLatest(SharedPreferences? preferences) async {
    _nextCheck = DateTime.now().add(_retryInterval);
    try {
      final client = _clientFactory();
      try {
        final request = http.Request('GET', _latestUri)
          ..followRedirects = false
          ..headers['Accept'] = 'application/json';
        final response = await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) return;
        final data = jsonDecode(response.body);
        if (data is! Map || !_adopt(data['version'])) return;
      } finally {
        client.close();
      }
      final now = DateTime.now();
      _nextCheck = now.add(_refreshInterval);
      await preferences?.setString(
        BusinessKeyRegistry.codexClientVersionCacheKey,
        jsonEncode({
          'version': snapshot.version,
          'checkedAt': now.millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  bool _adopt(Object? candidate) {
    if (candidate is! String ||
        _stableVersion.matchAsPrefix(candidate)?.end != candidate.length) {
      return false;
    }
    final latest = candidate.split('.');
    var version = defaultCodexClientVersion;
    for (var index = 0; index < _floor.length; index++) {
      final delta = int.parse(latest[index]) - _floor[index];
      if (delta == 0) continue;
      if (delta > 0) version = candidate;
      break;
    }
    if (version != snapshot.version) {
      _snapshot = (version: version, revision: snapshot.revision + 1);
      notifyListeners();
    }
    return true;
  }
}

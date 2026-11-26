import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../database/business_preferences.dart';

/// A marker names an object within one destination. It contains no credentials
/// and is usable only for deleting that partial, never for resuming a transfer.
class BackupPartials {
  const BackupPartials(this.preferences);
  final BusinessPreferences? preferences;
  static const installationKey = 'backup_install_id_v1';
  static Future<String> installationId(BusinessPreferences prefs) =>
      prefs.runExclusiveMutation(() async {
        await prefs.load();
        if (prefs.getString(installationKey) case final String id) return id;
        final id = const Uuid().v4();
        await prefs.setString(installationKey, id);
        return id;
      });

  static const preferenceKey = 'backup_outstanding_partial_v1';
  static final _live = <String>{};
  static final _remoteName = RegExp(
    r'^kelivo_backup_[\w.-]+\.(?:zip|kbackup)\.partial$',
  );

  static bool isRemoteName(String name) => _remoteName.hasMatch(name);
  static String scope(List<String> location) =>
      sha256.convert(utf8.encode(jsonEncode(location))).toString();
  static bool oldEnough(DateTime? modified, DateTime now) =>
      modified != null &&
      modified.isBefore(now.subtract(const Duration(hours: 6)));

  List<String> marked(String scope) =>
      (preferences?.getStringList(preferenceKey) ?? const <String>[])
          .where((entry) => entry.startsWith('$scope/'))
          .map((entry) => entry.substring(scope.length + 1))
          .toList();

  Future<void> _mark(String id, bool add) async {
    final prefs = preferences;
    if (prefs == null) return;
    await prefs.runExclusiveMutation(() async {
      await prefs.load();
      final values = {...?prefs.getStringList(preferenceKey)};
      final changed = add ? values.add(id) : values.remove(id);
      if (!changed) return;
      if (values.isEmpty) {
        await prefs.remove(preferenceKey);
      } else {
        await prefs.setStringList(preferenceKey, values.toList());
      }
    });
  }

  Future<void> publish({
    required String scope,
    required String name,
    required Future<void> Function() write,
    required Future<void> Function() removePartial,
  }) async {
    final id = '$scope/$name';
    if (!_live.add(id)) throw StateError('Backup already running');
    try {
      await _mark(id, true);
      try {
        await write();
      } finally {
        try {
          await removePartial();
        } catch (_) {
          /* Reclaimed by a later sweep. */
        }
        await _mark(id, false);
      }
    } finally {
      _live.remove(id);
    }
  }

  Future<void> sweep({
    required String scope,
    required bool Function(String) owns,
    required Future<Map<String, DateTime?>> Function() list,
    required Future<void> Function(String) remove,
    DateTime? now,
  }) async {
    await preferences?.load();
    final markedNames = marked(scope).where(owns).toSet();
    Future<void> reclaim(String name, bool marked) async {
      final id = '$scope/$name';
      if (!_live.add(id)) return;
      try {
        await remove(name);
        if (marked) await _mark(id, false);
      } catch (_) {
        // A directory can be offline, or a server can deny listing/deletion.
      } finally {
        _live.remove(id);
      }
    }

    for (final name in markedNames) {
      await reclaim(name, true);
    }
    final ageAt = now ?? DateTime.now();
    final Map<String, DateTime?> items;
    try {
      items = await list();
    } catch (_) {
      return;
    }
    for (final item in items.entries) {
      if (owns(item.key) &&
          !markedNames.contains(item.key) &&
          oldEnough(item.value, ageAt)) {
        await reclaim(item.key, false);
      }
    }
  }
}

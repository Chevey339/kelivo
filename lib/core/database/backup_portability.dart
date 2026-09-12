import 'dart:convert';

import 'app_database.dart';
import 'business_data.dart';
import 'business_repository.dart';

/// Device state stays in SQLite at runtime, but must not travel in a backup.
final class BackupPortability {
  BackupPortability._();

  static const devicePreferenceKeys = {
    'desktop_scheduled_tasks_v1',
    'environment_state_v1',
    'environment_disk_usage_v1',
    'environment_rootfs_selection_v1',
    'environment_proot_options_v1',
    'environment_variables_v1',
  };

  static bool _isLinked(BusinessEntityValue row) =>
      (jsonDecode(row.payload) as Map)['kind'] == 'linked';

  static BusinessSnapshot portable(BusinessSnapshot source) {
    final workspaces = source.entities[BusinessEntityKind.workspace]!;
    final linkedIds = {for (final row in workspaces.where(_isLinked)) row.id};
    final entities = {...source.entities};
    entities[BusinessEntityKind.workspace] = [
      for (final row in workspaces)
        if (!_isLinked(row))
          row.copyWith(
            payload: jsonEncode(
              Map<String, dynamic>.from(jsonDecode(row.payload) as Map)
                ..remove('hostPath')
                ..remove('lastUsedAt'),
            ),
          ),
    ];
    entities[BusinessEntityKind.assistant] = [
      for (final row in source.entities[BusinessEntityKind.assistant]!)
        _withoutLinkedDefault(row, linkedIds),
    ];
    return BusinessSnapshot(
      entities: entities,
      preferences: {...source.preferences}
        ..removeWhere((key, _) => devicePreferenceKeys.contains(key)),
    );
  }

  static BusinessEntityValue _withoutLinkedDefault(
    BusinessEntityValue row,
    Set<String> linkedIds,
  ) {
    final payload = Map<String, dynamic>.from(jsonDecode(row.payload) as Map);
    if (!linkedIds.contains(payload['defaultWorkspaceId'])) return row;
    payload.remove('defaultWorkspaceId');
    return row.copyWith(payload: jsonEncode(payload));
  }

  /// Preserve the target's environment and linked folders during overwrite.
  static BusinessSnapshot preserveDeviceState(
    BusinessSnapshot incoming,
    BusinessSnapshot local,
  ) {
    final linked = local.entities[BusinessEntityKind.workspace]!
        .where(_isLinked)
        .toList();
    final linkedIds = {for (final row in linked) row.id};
    return BusinessSnapshot(
      entities: {
        ...incoming.entities,
        BusinessEntityKind.workspace: [
          ...linked,
          for (final row in incoming.entities[BusinessEntityKind.workspace]!)
            if (!linkedIds.contains(row.id)) row,
        ],
      },
      preferences: {
        ...incoming.preferences,
        for (final key in devicePreferenceKeys)
          if (local.preferences.containsKey(key)) key: local.preferences[key]!,
      },
    );
  }

  /// Only call on a temporary database, never the live database. This also
  /// handles old backups whose raw SQLite payload still has device-only rows.
  static Future<void> sanitizeDatabase(AppDatabase database) async {
    // Erase removed payloads from SQLite cells as well as its logical rows.
    await database.customStatement('PRAGMA secure_delete = ON;');
    await database.transaction(() async {
      await BusinessRepository(database).transformSnapshot(portable);
      await database.customStatement(
        "DELETE FROM extension_entity_rows WHERE kind = 'externalMounts';",
      );
      // Chat history remains readable, but imported chats cannot inherit a
      // directory grant or silently authorize shell execution on this device.
      await database.customStatement('''
        UPDATE conversation_rows SET extras_json = CASE
          WHEN json_extract(extras_json, '\$."workspace.id"') IS NOT NULL
            AND NOT EXISTS (
              SELECT 1 FROM extension_entity_rows
              WHERE kind = 'workspace'
                AND id = json_extract(extras_json, '\$."workspace.id"')
            )
          THEN json_remove(extras_json, '\$."workspace.id"',
            '\$."workspace.cwd"', '\$."workspace.tools_used"',
            '\$."workspace.allowAll"')
          ELSE json_remove(extras_json, '\$."workspace.allowAll"')
        END
        WHERE json_valid(extras_json)
          AND (json_type(extras_json, '\$."workspace.id"') IS NOT NULL
            OR json_type(extras_json, '\$."workspace.allowAll"') IS NOT NULL);
      ''');
    });
  }
}

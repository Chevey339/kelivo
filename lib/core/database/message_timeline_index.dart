import 'package:drift/drift.dart';

/// A rebuildable index over message identity, not another source of history.
/// Source rows and version_selections_json remain authoritative. Like the FTS
/// index, this can be dropped and reconstructed without changing a backup's
/// readable schema. Triggers cover repository writes and raw import/restore SQL.
final class MessageTimelineIndex {
  MessageTimelineIndex(this.database);

  final GeneratedDatabase database;
  Future<void>? _installation;

  static Future<void> install(GeneratedDatabase db) async {
    await db.transaction(() async {
      for (final sql in _schema) {
        await db.customStatement(sql);
      }
    });
  }

  /// External snapshots carry canonical rows, never a trusted ready index.
  static const discardStatements = <String>[
    'DROP TRIGGER IF EXISTS timeline_message_insert',
    'DROP TRIGGER IF EXISTS timeline_message_delete',
    'DROP TRIGGER IF EXISTS timeline_message_update',
    'DROP TRIGGER IF EXISTS timeline_message_order_update',
    'DROP TRIGGER IF EXISTS timeline_conversation_insert',
    'DROP TRIGGER IF EXISTS timeline_selection_update',
    'DROP TRIGGER IF EXISTS timeline_group_insert',
    'DROP TRIGGER IF EXISTS timeline_group_delete',
    'DROP TABLE IF EXISTS timeline_revision_rows',
    'DROP TABLE IF EXISTS timeline_group_rows',
    'DROP TABLE IF EXISTS timeline_selection_rows',
    'DROP TABLE IF EXISTS timeline_state',
  ];

  Future<void> ensureConversation(String id) async {
    final installation = _installation ??= install(database);
    try {
      await installation;
    } catch (_) {
      // A failed transaction leaves no installed index. Share an in-flight
      // attempt, but let a later read retry after a transient storage failure.
      if (identical(_installation, installation)) _installation = null;
      rethrow;
    }
    final state = await database
        .customSelect(
          'SELECT ready FROM timeline_state WHERE conversation_id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (state?.read<int>('ready') == 1) return;
    await database.transaction(() async {
      // Recheck inside the transaction: another reader may have built it.
      final ready = await database
          .customSelect(
            'SELECT ready FROM timeline_state WHERE conversation_id = ?',
            variables: [Variable<String>(id)],
          )
          .getSingleOrNull();
      if (ready?.read<int>('ready') == 1) return;
      await database.customStatement(
        '''
INSERT OR IGNORE INTO timeline_state(conversation_id, ready, group_count)
SELECT id, 0, 0 FROM conversation_rows WHERE id = ?
''',
        [id],
      );
      await database.customStatement(
        'DELETE FROM timeline_group_rows WHERE conversation_id = ?',
        [id],
      );
      await database.customStatement(
        'DELETE FROM timeline_revision_rows WHERE conversation_id = ?',
        [id],
      );
      // This one-time build reads headers only, entirely on SQLite's worker.
      // Other conversations are indexed only when they are actually opened.
      await database.customStatement(
        '''
INSERT INTO timeline_revision_rows(revision_id,conversation_id,group_id,message_order)
SELECT id,conversation_id,COALESCE(group_id,id),message_order
FROM message_rows WHERE conversation_id = ?
''',
        [id],
      );
      await database.customStatement(
        '''
INSERT INTO timeline_group_rows(conversation_id, group_id, anchor_order, version_count)
SELECT conversation_id, group_id, MIN(message_order), COUNT(*)
FROM timeline_revision_rows WHERE conversation_id = ?
GROUP BY group_id
''',
        [id],
      );
      await database.customStatement(
        'DELETE FROM timeline_selection_rows WHERE conversation_id = ?',
        [id],
      );
      await database.customStatement(
        '''
INSERT INTO timeline_selection_rows(conversation_id,group_id,version)
SELECT c.id,j.key,CAST(j.value AS INTEGER)
FROM conversation_rows c,json_each(c.version_selections_json) j WHERE c.id = ?
''',
        [id],
      );
      await database.customStatement(
        'UPDATE timeline_state SET ready = 1, message_count = (SELECT COALESCE(SUM(version_count),0) FROM timeline_group_rows g WHERE g.conversation_id = timeline_state.conversation_id) WHERE conversation_id = ?',
        [id],
      );
    });
  }

  /// The selected candidate if it still exists, otherwise the latest candidate.
  /// Both source branches use existing indexes, including a null-group anchor
  /// whose id is subsequently used as the group_id of another revision.
  static String selectedRevision(String groupAlias) =>
      '''
COALESCE(
  (SELECT id FROM (
    SELECT m.id,m.message_order FROM message_rows m
    WHERE m.conversation_id = $groupAlias.conversation_id
      AND m.group_id = $groupAlias.group_id AND m.version = s.version
    UNION ALL
    SELECT m.id,m.message_order FROM message_rows m
    WHERE m.conversation_id = $groupAlias.conversation_id
      AND m.id = $groupAlias.group_id AND m.group_id IS NULL AND m.version = s.version
  ) ORDER BY message_order DESC,id DESC LIMIT 1),
  (SELECT id FROM (
    SELECT * FROM (
      SELECT m.id,m.version,m.message_order FROM message_rows m
      WHERE m.conversation_id = $groupAlias.conversation_id AND m.group_id = $groupAlias.group_id
      ORDER BY m.version DESC,m.message_order DESC,m.id DESC LIMIT 1
    )
    UNION ALL
    SELECT m.id,m.version,m.message_order FROM message_rows m
    WHERE m.conversation_id = $groupAlias.conversation_id AND m.id = $groupAlias.group_id AND m.group_id IS NULL
  ) ORDER BY version DESC,message_order DESC,id DESC LIMIT 1)
)
''';

  static String _remove(String row) =>
      '''
DELETE FROM timeline_revision_rows WHERE revision_id = $row.id;
UPDATE timeline_state SET message_count = message_count - 1
WHERE conversation_id = $row.conversation_id AND ready = 1;
DELETE FROM timeline_group_rows
WHERE conversation_id = $row.conversation_id AND group_id = COALESCE($row.group_id,$row.id)
  AND version_count = 1;
UPDATE timeline_group_rows SET
  version_count = version_count - 1,
  anchor_order = CASE WHEN anchor_order = $row.message_order THEN (
    SELECT message_order FROM timeline_revision_rows
    WHERE conversation_id = $row.conversation_id AND group_id = COALESCE($row.group_id,$row.id)
    ORDER BY message_order LIMIT 1
  ) ELSE anchor_order END
WHERE conversation_id = $row.conversation_id AND group_id = COALESCE($row.group_id,$row.id);
''';

  static String _add(String row) =>
      '''
INSERT INTO timeline_revision_rows(revision_id,conversation_id,group_id,message_order)
SELECT $row.id,$row.conversation_id,COALESCE($row.group_id,$row.id),$row.message_order
WHERE EXISTS(SELECT 1 FROM timeline_state WHERE conversation_id = $row.conversation_id AND ready = 1);
UPDATE timeline_state SET message_count = message_count + 1
WHERE conversation_id = $row.conversation_id AND ready = 1;
INSERT INTO timeline_group_rows(conversation_id,group_id,anchor_order,version_count)
SELECT $row.conversation_id,COALESCE($row.group_id,$row.id),$row.message_order,1
WHERE EXISTS(SELECT 1 FROM timeline_state WHERE conversation_id = $row.conversation_id AND ready = 1)
ON CONFLICT(conversation_id,group_id) DO UPDATE SET
  anchor_order = MIN(anchor_order,excluded.anchor_order),version_count = version_count + 1;
''';

  static final _schema = <String>[
    '''CREATE TABLE IF NOT EXISTS timeline_state(
      conversation_id TEXT PRIMARY KEY REFERENCES conversation_rows(id) ON DELETE CASCADE,
      ready INTEGER NOT NULL, group_count INTEGER NOT NULL DEFAULT 0, message_count INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID''',
    '''CREATE TABLE IF NOT EXISTS timeline_group_rows(
      conversation_id TEXT NOT NULL REFERENCES conversation_rows(id) ON DELETE CASCADE,
      group_id TEXT NOT NULL,anchor_order INTEGER NOT NULL,version_count INTEGER NOT NULL,
      PRIMARY KEY(conversation_id,group_id)
    ) WITHOUT ROWID''',
    '''CREATE INDEX IF NOT EXISTS idx_timeline_group_order
      ON timeline_group_rows(conversation_id,anchor_order,group_id)''',
    // A per-conversation projection avoids installing a global source index
    // across every unopened history. Its group/order lookup also bounds anchor
    // updates when a bulk reorder moves many revisions of the same group.
    '''CREATE TABLE IF NOT EXISTS timeline_revision_rows(
      revision_id TEXT PRIMARY KEY REFERENCES message_rows(id) ON DELETE CASCADE,
      conversation_id TEXT NOT NULL,group_id TEXT NOT NULL,message_order INTEGER NOT NULL
    ) WITHOUT ROWID''',
    '''CREATE INDEX IF NOT EXISTS idx_timeline_revision_order
      ON timeline_revision_rows(conversation_id,group_id,message_order)''',
    '''CREATE TABLE IF NOT EXISTS timeline_selection_rows(
      conversation_id TEXT NOT NULL REFERENCES conversation_rows(id) ON DELETE CASCADE,
      group_id TEXT NOT NULL,version INTEGER NOT NULL,
      PRIMARY KEY(conversation_id,group_id)
    ) WITHOUT ROWID''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_group_insert
      AFTER INSERT ON timeline_group_rows BEGIN
      UPDATE timeline_state SET group_count = group_count + 1 WHERE conversation_id = NEW.conversation_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_group_delete
      AFTER DELETE ON timeline_group_rows BEGIN
      UPDATE timeline_state SET group_count = group_count - 1 WHERE conversation_id = OLD.conversation_id;
    END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_conversation_insert
      AFTER INSERT ON conversation_rows BEGIN
      INSERT INTO timeline_state(conversation_id,ready,group_count) VALUES(NEW.id,1,0);
      INSERT INTO timeline_selection_rows(conversation_id,group_id,version)
      SELECT NEW.id,key,CAST(value AS INTEGER) FROM json_each(NEW.version_selections_json);
    END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_selection_update
      AFTER UPDATE OF version_selections_json ON conversation_rows
      WHEN OLD.version_selections_json IS NOT NEW.version_selections_json
      AND EXISTS(SELECT 1 FROM timeline_state WHERE conversation_id = NEW.id AND ready = 1)
      BEGIN
      DELETE FROM timeline_selection_rows WHERE conversation_id = NEW.id;
      INSERT INTO timeline_selection_rows(conversation_id,group_id,version)
      SELECT NEW.id,key,CAST(value AS INTEGER) FROM json_each(NEW.version_selections_json);
    END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_message_insert
      AFTER INSERT ON message_rows BEGIN ${_add('NEW')} END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_message_delete
      AFTER DELETE ON message_rows BEGIN ${_remove('OLD')} END''',
    '''CREATE TRIGGER IF NOT EXISTS timeline_message_update
      AFTER UPDATE OF id,conversation_id,group_id ON message_rows
      WHEN OLD.id IS NOT NEW.id OR OLD.conversation_id IS NOT NEW.conversation_id
        OR OLD.group_id IS NOT NEW.group_id
      BEGIN ${_remove('OLD')} ${_add('NEW')} END''',
    // Reordering does not change membership or counts. Avoid tearing down and
    // reinserting every group while making room for a reply in old history.
    '''CREATE TRIGGER IF NOT EXISTS timeline_message_order_update
      AFTER UPDATE OF message_order ON message_rows
      WHEN OLD.message_order IS NOT NEW.message_order AND OLD.id IS NEW.id
        AND OLD.conversation_id IS NEW.conversation_id AND OLD.group_id IS NEW.group_id
      BEGIN
      UPDATE timeline_revision_rows SET message_order = NEW.message_order WHERE revision_id = NEW.id;
      UPDATE timeline_group_rows SET anchor_order = (
        SELECT message_order FROM timeline_revision_rows
        WHERE conversation_id = NEW.conversation_id AND group_id = COALESCE(NEW.group_id,NEW.id)
        ORDER BY message_order LIMIT 1
      ) WHERE conversation_id = NEW.conversation_id AND group_id = COALESCE(NEW.group_id,NEW.id)
        AND (anchor_order = OLD.message_order OR NEW.message_order < anchor_order);
    END''',
  ];
}

/// Shared SQLite contract for an explicitly chosen empty chat state.
abstract final class EmptyDatabasePermission {
  static const tokenKey = 'intentional_empty_chat_state_v1';

  static const hasDataQuery = '''
    SELECT (EXISTS(SELECT 1 FROM conversation_rows LIMIT 1)
         OR EXISTS(SELECT 1 FROM message_rows LIMIT 1)) AS present
  ''';

  /// Persistent triggers also cover bulk imports and direct SQLite writes.
  /// Deletions never grant permission: only an explicit application action may.
  static Iterable<String> get invalidationTriggers sync* {
    for (final table in ['conversation_rows', 'message_rows']) {
      for (final event in ['INSERT', 'UPDATE']) {
        yield '''
          CREATE TRIGGER IF NOT EXISTS invalidate_empty_${table}_${event.toLowerCase()}
          AFTER $event ON $table
          BEGIN
            DELETE FROM chat_storage_meta_rows WHERE key = '$tokenKey';
          END
        ''';
      }
    }
  }
}

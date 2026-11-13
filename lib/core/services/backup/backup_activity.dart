/// Tracks heavy backup, restore and import work in this process.
///
/// Exists because there is no single provider to ask. The mobile backup screen
/// builds its own [BackupProvider]/[S3BackupProvider] instances rather than
/// using the ones at the root of the tree, so anything sampling the root pair
/// sees `busy == false` for the whole of a mobile backup; and restoring from a
/// local file never sets that flag on any instance at all. Background work that
/// has to stay out of the way asks here instead, where every task that shows
/// the shared progress dialog is accounted for.
///
/// Counted rather than boolean: tasks can nest, and a task the user sent to the
/// background outlives the dialog that started it.
final class BackupActivity {
  BackupActivity._();

  static int _depth = 0;
  static Future<void>? _automaticTask;
  static void Function()? _cancelAutomatic;

  /// Whether any backup-class task is running right now.
  static bool get isActive => _depth > 0;

  static void begin() => _depth += 1;

  static void end() {
    if (_depth > 0) _depth -= 1;
  }

  /// A manual backup or restore takes priority over an unattended upload.
  /// Callers first [begin], then wait here before touching business data.
  static Future<void> cancelAutomaticAndWait() async {
    final task = _automaticTask;
    if (task == null) return;
    _cancelAutomatic?.call();
    await task;
  }

  static void registerAutomatic(Future<void> task, void Function() cancel) {
    if (_automaticTask != null) {
      throw StateError('automatic_backup_already_running');
    }
    _automaticTask = task;
    _cancelAutomatic = cancel;
  }

  static void clearAutomatic(Future<void> task) {
    if (!identical(_automaticTask, task)) return;
    _automaticTask = null;
    _cancelAutomatic = null;
  }

  /// Test-only: drops any depth a failed test left behind.
  static void debugReset() {
    _depth = 0;
    _automaticTask = null;
    _cancelAutomatic = null;
  }
}

/// Process-wide count shared by operations that access backup and restore data.
final class BackupActivity {
  BackupActivity._();

  static int _depth = 0;
  static bool externalActive = false;

  /// Whether any backup-class task is running right now.
  static bool get isActive => _depth > 0;

  static void begin() => _depth += 1;

  static void end() {
    if (_depth > 0) _depth -= 1;
  }

  /// Test-only: drops any depth a failed test left behind.
  static void debugReset() {
    _depth = 0;
    externalActive = false;
  }
}

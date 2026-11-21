/// Bounds shared by ZIP import and the on-disk bundles used during restore.
abstract final class BackupArchiveLimits {
  static const entries = 100000;
  static const entryBytes = 8 * 1024 * 1024 * 1024;
  static const totalBytes = 16 * 1024 * 1024 * 1024;
  static const manifestBytes = 16 * 1024 * 1024;
  static const settingsBytes = 1024 * 1024 * 1024;

  /// Counts uncompressed bytes, including the generated manifest.
  static int addFile(int total, String name, int size) {
    if (name == 'settings.json' && (size <= 0 || size > settingsBytes)) {
      throw const FormatException('settings_size');
    }
    if (name == 'manifest.json' && (size < 0 || size > manifestBytes)) {
      throw const FormatException('manifest_size');
    }
    if (size < 0 || size > entryBytes) {
      throw FormatException('zip_entry_size:$name');
    }
    final next = total + size;
    if (next > totalBytes) throw const FormatException('zip_total_size');
    return next;
  }
}

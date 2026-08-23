enum BackupPhase {
  preparing,
  snapshottingDatabase,
  packing,
  verifying,
  uploading,
  downloading,
  extracting,
  validating,
  readingSettings,
  stagingCandidate,
  committing,
  importingSessions,
  importingMessages,
  materializingFiles,
  listingRemote,
  finalizing,
}

enum BackupProgressUnit { none, bytes, items }

typedef BackupProgressSink = void Function(BackupProgress progress);

final class BackupProgress {
  const BackupProgress({
    required this.phase,
    required this.processed,
    this.total,
    this.unit = BackupProgressUnit.none,
    this.cancellable = true,
    this.detail,
  });

  final BackupPhase phase;
  final int processed;
  final int? total;
  final BackupProgressUnit unit;
  final bool cancellable;
  final String? detail;

  double? get fraction => (total != null && total! > 0)
      ? (processed / total!).clamp(0.0, 1.0)
      : null;
}

enum BackupPhase {
  preparing,
  snapshottingDatabase,
  scanning,
  packing,
  verifying,
  encrypting,
  decrypting,
  uploading,
  downloading,
  extracting,
  validating,
  checkingDatabase,
  readingSettings,
  stagingCandidate,
  committing,
  importingSessions,
  importingMessages,
  materializingFiles,
  listingRemote,
  choosingDestination,
  saving,
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
    this.skippedEntries = const [],
  });

  final BackupPhase phase;
  final int processed;
  final int? total;
  final BackupProgressUnit unit;
  final bool cancellable;
  final String? detail;

  /// Relative asset paths omitted because their source could not be read.
  /// A directory counts once, including its unlisted descendants.
  final List<String> skippedEntries;

  double? get fraction => (total != null && total! > 0)
      ? (processed / total!).clamp(0.0, 1.0)
      : null;
}

class BackupByteProgress {
  BackupByteProgress({
    this.onProgress,
    this.checkCancelled,
    required this.phase,
    required this.total,
  });

  final BackupProgressSink? onProgress;
  final void Function()? checkCancelled;
  final BackupPhase phase;
  int total;
  var processed = 0;

  void add(int bytes, {String? detail}) {
    processed += bytes;
    report(detail: detail);
  }

  void skipUnreadBytes(int bytes) {
    total -= bytes.clamp(0, (total - processed).clamp(0, total));
    report();
  }

  void report({String? detail}) {
    checkCancelled?.call();
    onProgress?.call(
      BackupProgress(
        phase: phase,
        processed: processed,
        total: total,
        unit: BackupProgressUnit.bytes,
        detail: detail,
        cancellable: true,
      ),
    );
  }
}

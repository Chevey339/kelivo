import 'package:intl/intl.dart';

import '../../core/services/backup/backup_task_progress.dart';
import '../../l10n/app_localizations.dart';
import 'format_bytes.dart';

String? backupProgressSubtitle(
  AppLocalizations l10n,
  BackupProgress progress, {
  Duration elapsed = Duration.zero,
}) {
  final total = progress.total;
  if (total == null) {
    if (progress.phase == BackupPhase.scanning) {
      return l10n.backupProgressDiscoveredFiles(progress.processed);
    }
    if (elapsed.inSeconds == 0) return null;
    return formatBackupElapsed(l10n, elapsed);
  }
  switch (progress.unit) {
    case BackupProgressUnit.bytes:
      return l10n.backupProgressBytes(
        formatBytes(progress.processed),
        formatBytes(total),
      );
    case BackupProgressUnit.items:
      final format = NumberFormat.decimalPattern();
      return l10n.backupProgressItems(
        format.format(progress.processed),
        format.format(total),
      );
    case BackupProgressUnit.none:
      return null;
  }
}

String formatBackupElapsed(AppLocalizations l10n, Duration elapsed) {
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return l10n.backupProgressElapsed('${elapsed.inMinutes}:$seconds');
}

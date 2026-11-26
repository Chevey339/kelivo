import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/providers/backup_reminder_provider.dart';
import '../../core/providers/external_backup_auto_provider.dart';
import '../../core/services/backup/backup_cancel_token.dart';
import '../../core/services/backup/backup_secure_password_store.dart';
import '../../core/services/backup/backup_staging.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/snackbar.dart';
import 'backup_restore_error_message.dart';
import 'local_snapshot_scheduler.dart';

class ExternalBackupAutoScheduler extends StatefulWidget {
  const ExternalBackupAutoScheduler({super.key, required this.child});
  final Widget child;
  @override
  State<ExternalBackupAutoScheduler> createState() =>
      _ExternalBackupAutoSchedulerState();
}

class _ExternalBackupAutoSchedulerState
    extends State<ExternalBackupAutoScheduler>
    with WidgetsBindingObserver {
  Timer? _delay;
  StreamSubscription<DateTime>? _ticks;
  bool _ready = false;
  bool _keychainReported = false;
  Future<void>? _startup;
  int _generation = 0;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticks = context.read<BackupReminderProvider>().ticks.listen((now) {
      if (_ready && _foreground) unawaited(_check(now));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _foreground) _schedule(LocalSnapshotScheduler.launchDelay);
    });
  }

  Future<void> _prepare() async {
    final auto = context.read<ExternalBackupAutoProvider>();
    await auto.settings.loaded;
    try {
      await BackupStaging.sweep();
    } on Exception {
      /* Next backup also sweeps. */
    }
    try {
      await auto.settings.retryBackupPasswordRemoval();
    } on BackupKeychainUnavailable {
      /* Keep the revocation for the next startup. */
    }
    if (mounted) unawaited(auto.cleanupDestinations());
  }

  void _schedule(Duration after) {
    final generation = ++_generation;
    _ready = false;
    _delay?.cancel();
    _delay = Timer(after, () async {
      await (_startup ??= _prepare());
      if (!mounted || generation != _generation || !_foreground) return;
      _ready = true;
      await _check(DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _delay?.cancel();
    _generation++;
    _ready = false;
    if (state == AppLifecycleState.resumed) {
      context.read<ExternalBackupAutoProvider>().allowNextCheck();
      _schedule(
        _startup == null
            ? LocalSnapshotScheduler.launchDelay
            : LocalSnapshotScheduler.resumeDelay,
      );
    }
  }

  Future<void> _check(DateTime now) async {
    final auto = context.read<ExternalBackupAutoProvider>();
    final l10n = AppLocalizations.of(context)!;
    String message;
    var type = NotificationType.success;
    try {
      if (!await auto.runIfDue(now, foreground: _foreground)) return;
      message = l10n.backupAutoSucceeded;
    } on BackupCancelledException {
      message = l10n.backupProgressCancelled;
      type = NotificationType.info;
    } catch (error) {
      if (error is BackupKeychainUnavailable) {
        if (_keychainReported) return;
        _keychainReported = true;
      }
      message = automaticBackupErrorMessage(l10n, error);
      type = NotificationType.error;
    }
    final root = rootNavigatorKey.currentState?.overlay?.context;
    if (root != null && root.mounted) {
      showAppSnackBar(root, message: message, type: type);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _delay?.cancel();
    _ticks?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

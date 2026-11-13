import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../core/providers/webdav_backup_schedule_provider.dart';
import '../../core/services/backup/webdav_background_backup.dart';

/// Runs due checks while visible and serves Android's existing app engine.
class WebDavBackupScheduler extends StatefulWidget {
  const WebDavBackupScheduler({super.key, required this.child});

  final Widget child;

  @override
  State<WebDavBackupScheduler> createState() => _WebDavBackupSchedulerState();
}

class _WebDavBackupSchedulerState extends State<WebDavBackupScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WebDavBackgroundBackup.attachForeground(
        () => context.read<WebDavBackupScheduleProvider>().runIfDue(),
        cancelAndWait: () =>
            context.read<WebDavBackupScheduleProvider>().cancelAndWait(),
      );
      _schedule(const Duration(seconds: 8));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WebDavBackgroundBackup.detachForeground();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _timer?.cancel();
    if (state != AppLifecycleState.resumed) return;
    unawaited(context.read<WebDavBackupScheduleProvider>().refresh());
    _schedule(const Duration(seconds: 3));
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _check);
  }

  Future<void> _check() async {
    if (!mounted) return;
    try {
      await context.read<WebDavBackupScheduleProvider>().runIfDue();
    } finally {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _schedule(const Duration(minutes: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

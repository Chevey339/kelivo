import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/local_snapshot_provider.dart';
import '../../core/services/backup/local_snapshot_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/snackbar.dart';

/// Decides when to ask for an automatic local copy, without a timer service,
/// a notification, or a background task.
///
/// Launch and resume are the only two moments it acts on, and both are delayed
/// past the frames the user is actually waiting for: the check itself is two
/// `stat` calls, and the copy only happens when one is genuinely due.
class LocalSnapshotScheduler extends StatefulWidget {
  const LocalSnapshotScheduler({super.key, required this.child});

  final Widget child;

  /// Long enough for the first screen to settle and its own I/O to finish.
  static const launchDelay = Duration(seconds: 8);

  /// Shorter on resume: the app is already warm.
  static const resumeDelay = Duration(seconds: 3);

  /// Floor between checks, so app switching does not re-run the gates
  /// repeatedly.
  static const minimumCheckGap = Duration(minutes: 1);

  @override
  State<LocalSnapshotScheduler> createState() => _LocalSnapshotSchedulerState();
}

class _LocalSnapshotSchedulerState extends State<LocalSnapshotScheduler>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedule(LocalSnapshotScheduler.launchDelay);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state != AppLifecycleState.resumed) {
      // Nothing is started on the way out: the copy takes longer than the
      // time the OS grants a backgrounded app, and being killed mid-write is
      // exactly what the staged-then-renamed publish exists to survive.
      _timer?.cancel();
      return;
    }
    _schedule(LocalSnapshotScheduler.resumeDelay);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _check);
  }

  Future<void> _check() async {
    if (!mounted) return;
    final now = DateTime.now();
    final last = _lastCheck;
    if (last != null &&
        now.difference(last) < LocalSnapshotScheduler.minimumCheckGap) {
      return;
    }
    _lastCheck = now;

    final provider = context.read<LocalSnapshotProvider>();
    final result = await provider.runIfDue();
    if (!mounted) return;
    if (result is! LocalSnapshotCreated) return;
    if (!provider.settings.announceResult) return;
    try {
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.localSnapshotTakeDone,
      );
    } catch (_) {
      // This runs from a timer, above the Navigator. A missing overlay must
      // not turn a successful copy into an unhandled error.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

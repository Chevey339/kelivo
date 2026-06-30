import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:reel_text/reel_text.dart';

import '../../core/services/native_file_save.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import '../../utils/platform_utils.dart';
import 'hive_to_sqlite_migration_service.dart';

class HiveToSqliteMigrationPage extends StatefulWidget {
  const HiveToSqliteMigrationPage({super.key, required this.service});

  final HiveToSqliteMigrationService service;

  @override
  State<HiveToSqliteMigrationPage> createState() =>
      _HiveToSqliteMigrationPageState();
}

class _HiveToSqliteMigrationPageState extends State<HiveToSqliteMigrationPage> {
  late HiveToSqliteMigrationStatus _status;
  StreamSubscription<HiveToSqliteMigrationStatus>? _sub;
  File? _backupFile;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.service.initialStatus();
    _sub = widget.service.statusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(widget.service.dispose());
    super.dispose();
  }

  Future<void> _pickBackupAndStart() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final backupFile = Platform.isAndroid || Platform.isIOS
          ? await _createAndSaveMobileBackup()
          : await _createDesktopBackup();
      if (backupFile == null) return;
      if (!mounted) return;
      setState(() => _backupFile = backupFile);
      await widget.service.migrate(backupFile: backupFile);
    } catch (error, stackTrace) {
      if (mounted && _status.stage != HiveToSqliteMigrationStage.failed) {
        setState(() {
          _status = HiveToSqliteMigrationStatus(
            stage: HiveToSqliteMigrationStage.failed,
            progress: _status.progress,
            title: 'failed',
            detail: 'backup',
            backupPath: _status.stage == HiveToSqliteMigrationStage.backupReady
                ? null
                : _status.backupPath,
            error: '$error',
            log: [..._status.log, '$error', stackTrace.toString()],
            backupItems: _status.backupItems,
          );
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<File?> _createDesktopBackup() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context)!.migrationChooseFolderButton,
    );
    if (path == null || path.trim().isEmpty) return null;
    return widget.service.backupTo(Directory(path));
  }

  Future<File?> _createAndSaveMobileBackup() async {
    final backupFile = await widget.service.backupToTemporaryFile();
    try {
      if (mounted) {
        setState(() {
          _status = _status.copyWith(
            stage: HiveToSqliteMigrationStage.backingUp,
            progress: 0,
            detail: 'saving_zip',
            backupPath: null,
          );
        });
      }
      final saved = await NativeFileSave.saveFileFromPath(
        sourcePath: backupFile.path,
        fileName: p.basename(backupFile.path),
      );
      if (saved) return backupFile;
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      if (mounted) {
        setState(() => _status = widget.service.initialStatus());
      }
      return null;
    } catch (_) {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _retry() async {
    final backupFile = _backupFile;
    if (backupFile == null || _busy) {
      await _pickBackupAndStart();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.service.migrate(backupFile: backupFile);
    } catch (_) {
      // Status stream already carries the failure details.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final desktop = MediaQuery.sizeOf(context).width >= 720;
    final overlay = Theme.of(context).brightness == Brightness.dark
        ? const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          )
        : const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          );
    final viewPadding = MediaQuery.viewPaddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: cs.surface,
        extendBody: true,
        body: DecoratedBox(
          decoration: BoxDecoration(color: cs.surface),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: desktop ? 520 : 430),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 32 : 20,
                  (desktop ? 34 : 18) + viewPadding.top,
                  desktop ? 32 : 20,
                  (desktop ? 34 : 18) + viewPadding.bottom,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _bodyForStatus(l10n, key: ValueKey(_status.stage)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyForStatus(AppLocalizations l10n, {required Key key}) {
    return switch (_status.stage) {
      HiveToSqliteMigrationStage.intro => _IntroStep(
        key: key,
        status: _status,
        onStart: _busy ? null : _pickBackupAndStart,
      ),
      HiveToSqliteMigrationStage.backupReady ||
      HiveToSqliteMigrationStage.backingUp ||
      HiveToSqliteMigrationStage.migrating => _ProgressStep(
        key: key,
        status: _status,
      ),
      HiveToSqliteMigrationStage.complete => _CompleteStep(
        key: key,
        status: _status,
        onRestart: PlatformUtils.restartApp,
      ),
      HiveToSqliteMigrationStage.failed => _FailedStep(
        key: key,
        status: _status,
        onRetry: _busy ? null : _retry,
      ),
    };
  }
}

class _IntroStep extends StatelessWidget {
  const _IntroStep({super.key, required this.status, required this.onStart});

  final HiveToSqliteMigrationStatus status;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _StepShell(
      key: key,
      showStepper: false,
      activeStep: 0,
      children: [
        _Header(
          title: l10n.migrationIntroTitle,
          subtitle: l10n.migrationIntroSubtitle,
        ),
        const SizedBox(height: 18),
        _MigrationViz(active: false),
        const SizedBox(height: 14),
        _NoteCard(
          icon: Lucide.Shield,
          color: cs.primary,
          text: l10n.migrationBackupNote,
        ),
        const SizedBox(height: 10),
        _NoteCard(
          icon: Lucide.Zap,
          color: cs.primary,
          text: l10n.migrationPerformanceNote,
        ),
        const Spacer(),
        _PrimaryButton(
          icon: Lucide.FolderPlus,
          label: Platform.isAndroid || Platform.isIOS
              ? l10n.migrationSaveBackupButton
              : l10n.migrationChooseFolderButton,
          onPressed: onStart,
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({super.key, required this.status});

  final HiveToSqliteMigrationStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inMigration = status.stage == HiveToSqliteMigrationStage.migrating;
    final backupFileReady =
        status.stage == HiveToSqliteMigrationStage.backupReady || inMigration;
    return _StepShell(
      key: key,
      activeStep: inMigration ? 1 : 0,
      children: [
        _Header(
          title: inMigration
              ? l10n.migrationMigratingTitle
              : l10n.migrationBackingUpTitle,
          subtitle: inMigration
              ? l10n.migrationMigratingSubtitle
              : l10n.migrationBackingUpSubtitle,
        ),
        const SizedBox(height: 18),
        _ProgressBlock(
          label: inMigration
              ? _migratingDetail(l10n, status)
              : status.stage == HiveToSqliteMigrationStage.backupReady
              ? l10n.migrationBackupReadyDetail
              : status.detail == 'saving_zip'
              ? l10n.migrationSavingBackupZipDetail
              : l10n.migrationBackingUpDetail(status.detail),
          animateLabel: inMigration,
          progress: status.progress,
          showPercent: status.progress > 0 && status.detail != 'saving_zip',
        ),
        const SizedBox(height: 14),
        _ChecklistCard(
          items: inMigration ? _migrationItems(l10n) : _backupItems(),
        ),
        if (backupFileReady && status.backupPath != null) ...[
          const SizedBox(height: 12),
          _BackupFileCard(path: status.backupPath!),
        ],
      ],
    );
  }

  List<_ChecklistItem> _backupItems() {
    if (status.backupItems.isEmpty) {
      return const <_ChecklistItem>[];
    }
    return status.backupItems
        .map((item) {
          final state = switch (item.state) {
            HiveToSqliteBackupItemState.done => _TaskState.done,
            HiveToSqliteBackupItemState.active => _TaskState.active,
            HiveToSqliteBackupItemState.pending => _TaskState.pending,
          };
          final trailing =
              item.state == HiveToSqliteBackupItemState.active && item.bytes > 0
              ? '${_formatBytes(item.writtenBytes)} / ${_formatBytes(item.bytes)}'
              : item.bytes > 0
              ? _formatBytes(item.bytes)
              : null;
          return _ChecklistItem(item.name, state: state, trailing: trailing);
        })
        .toList(growable: false);
  }

  List<_ChecklistItem> _migrationItems(AppLocalizations l10n) {
    final detail = status.detail;
    return [
      _ChecklistItem(
        l10n.migrationChecklistPrepareSqlite,
        state: detail == 'schema' ? _TaskState.active : _TaskState.done,
      ),
      _ChecklistItem(
        l10n.migrationChecklistMigrateMessages,
        state: switch (detail) {
          'schema' => _TaskState.pending,
          'messages' => _TaskState.active,
          _ => _TaskState.done,
        },
        trailing: status.messages > 0 ? '${status.messages}' : null,
      ),
      _ChecklistItem(
        l10n.migrationChecklistMigrateToolEvents,
        state: switch (detail) {
          'tool_events' => _TaskState.active,
          'validate' || 'done' => _TaskState.done,
          _ => _TaskState.pending,
        },
      ),
      _ChecklistItem(
        l10n.migrationChecklistValidate,
        state: switch (detail) {
          'validate' => _TaskState.active,
          'done' => _TaskState.done,
          _ => _TaskState.pending,
        },
      ),
    ];
  }

  String _migratingDetail(
    AppLocalizations l10n,
    HiveToSqliteMigrationStatus status,
  ) {
    return switch (status.detail) {
      'schema' => l10n.migrationMigratingPrepareDetail,
      'tool_events' => l10n.migrationMigratingToolEventsDetail,
      'validate' => l10n.migrationMigratingValidateDetail,
      _ => l10n.migrationMigratingDetail(status.messages),
    };
  }
}

class _CompleteStep extends StatelessWidget {
  const _CompleteStep({
    super.key,
    required this.status,
    required this.onRestart,
  });

  final HiveToSqliteMigrationStatus status;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _StepShell(
      key: key,
      activeStep: 2,
      children: [
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.84, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) =>
              Transform.scale(scale: value, child: child),
          child: Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Lucide.Check, color: cs.primary, size: 42),
          ),
        ),
        const SizedBox(height: 18),
        _Header(
          title: l10n.migrationCompleteTitle,
          subtitle: l10n.migrationCompleteSubtitle,
        ),
        const SizedBox(height: 14),
        _StatsCard(
          conversations: status.conversations,
          messages: status.messages,
        ),
        const SizedBox(height: 12),
        if (status.backupPath != null)
          _BackupFileCard(path: status.backupPath!),
        const Spacer(),
        _PrimaryButton(
          icon: Lucide.RefreshCw,
          label: l10n.migrationRestartButton,
          onPressed: onRestart,
        ),
      ],
    );
  }
}

class _FailedStep extends StatelessWidget {
  const _FailedStep({super.key, required this.status, required this.onRetry});

  final HiveToSqliteMigrationStatus status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _StepShell(
      key: key,
      activeStep: 1,
      children: [
        Icon(Lucide.TriangleAlert, color: cs.error, size: 58),
        const SizedBox(height: 16),
        _Header(
          title: l10n.migrationFailedTitle,
          subtitle: l10n.migrationFailedSubtitle,
        ),
        const SizedBox(height: 14),
        _ErrorCard(error: status.error ?? l10n.migrationUnknownError),
        const SizedBox(height: 12),
        if (status.backupPath != null)
          _BackupFileCard(path: status.backupPath!),
        const SizedBox(height: 12),
        _LogCard(lines: status.log),
        const Spacer(),
        _PrimaryButton(
          icon: Lucide.RotateCcw,
          label: l10n.migrationRetryButton,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({
    super.key,
    required this.children,
    required this.activeStep,
    this.showStepper = true,
  });

  final List<Widget> children;
  final int activeStep;
  final bool showStepper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: double.infinity,
      child: Column(
        children: [
          if (showStepper) ...[
            _DotSteps(activeStep: activeStep),
            const SizedBox(height: 22),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        ReelText(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: AppFontWeights.emphasis,
            color: cs.onSurface,
          ),
          options: const ReelTextOptions(
            direction: ReelTextDirection.up,
            duration: Duration(milliseconds: 340),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MigrationViz extends StatelessWidget {
  const _MigrationViz({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DatabaseBubble(
              label: l10n.migrationSourceDatabaseLabel,
              color: cs.onSurfaceVariant,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Icon(Lucide.ArrowRight, color: cs.primary),
            ),
            _DatabaseBubble(
              label: l10n.migrationTargetDatabaseLabel,
              color: cs.primary,
              active: active,
            ),
          ],
        ),
      ),
    );
  }
}

class _DatabaseBubble extends StatelessWidget {
  const _DatabaseBubble({
    required this.label,
    required this.color,
    this.active = false,
  });

  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: active ? cs.primaryContainer : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Lucide.Database, color: color, size: 28),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFontWeights.semibold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ProgressBlock extends StatefulWidget {
  const _ProgressBlock({
    required this.label,
    required this.progress,
    this.animateLabel = true,
    this.showPercent = true,
  });

  final String label;
  final double progress;
  final bool animateLabel;
  final bool showPercent;

  @override
  State<_ProgressBlock> createState() => _ProgressBlockState();
}

class _ProgressBlockState extends State<_ProgressBlock> {
  static const _displayInterval = Duration(milliseconds: 1200);

  Timer? _timer;
  late String _displayLabel;
  late int _displayPercent;
  late DateTime _lastDisplayUpdate;

  @override
  void initState() {
    super.initState();
    _displayLabel = widget.label;
    _displayPercent = _percentFor(widget.progress);
    _lastDisplayUpdate = DateTime.now();
  }

  @override
  void didUpdateWidget(covariant _ProgressBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextPercent = _percentFor(widget.progress);
    if (widget.label == _displayLabel && nextPercent == _displayPercent) {
      return;
    }
    final elapsed = DateTime.now().difference(_lastDisplayUpdate);
    if (elapsed >= _displayInterval ||
        widget.progress >= 1 ||
        oldWidget.showPercent != widget.showPercent) {
      _applyDisplay(widget.label, nextPercent);
      return;
    }
    _timer ??= Timer(_displayInterval - elapsed, () {
      _timer = null;
      if (!mounted) return;
      _applyDisplay(widget.label, _percentFor(widget.progress));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _applyDisplay(String label, int percent) {
    _timer?.cancel();
    _timer = null;
    _lastDisplayUpdate = DateTime.now();
    if (mounted) {
      setState(() {
        _displayLabel = label;
        _displayPercent = percent;
      });
    } else {
      _displayLabel = label;
      _displayPercent = percent;
    }
  }

  int _percentFor(double progress) {
    return (progress * 100).clamp(0, 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: widget.progress <= 0 ? null : widget.progress,
            color: cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: widget.animateLabel
                  ? ReelText(
                      _displayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                      options: const ReelTextOptions(
                        direction: ReelTextDirection.up,
                        duration: Duration(milliseconds: 320),
                      ),
                    )
                  : Text(
                      _displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
            if (widget.showPercent)
              ReelText(
                '$_displayPercent%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.emphasis,
                  color: cs.primary,
                ),
                options: const ReelTextOptions(
                  direction: ReelTextDirection.up,
                  duration: Duration(milliseconds: 320),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  const kb = 1024;
  const mb = 1024 * kb;
  const gb = 1024 * mb;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

enum _TaskState { pending, active, done }

class _ChecklistItem {
  const _ChecklistItem(this.label, {required this.state, this.trailing});

  final String label;
  final _TaskState state;
  final String? trailing;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({required this.items});

  final List<_ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(
                        top: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.28),
                        ),
                      ),
              ),
              child: Row(
                children: [
                  _StatusDot(state: items[i].state),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFontWeights.semibold,
                        color: items[i].state == _TaskState.pending
                            ? cs.onSurfaceVariant
                            : cs.onSurface,
                      ),
                    ),
                  ),
                  if (items[i].trailing != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      items[i].trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: items[i].state == _TaskState.active
                            ? AppFontWeights.semibold
                            : FontWeight.w500,
                        color: items[i].state == _TaskState.active
                            ? cs.primary
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state});

  final _TaskState state;

  static const Color _success = Colors.green;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 20,
      height: 20,
      child: switch (state) {
        _TaskState.done => Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _success, width: 1.55),
          ),
          child: const Icon(Lucide.Check, size: 13, color: _success),
        ),
        _TaskState.active => _SpinningStatusDot(color: cs.primary),
        _TaskState.pending => CustomPaint(
          painter: _DashedCirclePainter(color: cs.outlineVariant),
        ),
      },
    );
  }
}

class _SpinningStatusDot extends StatefulWidget {
  const _SpinningStatusDot({required this.color});

  final Color color;

  @override
  State<_SpinningStatusDot> createState() => _SpinningStatusDotState();
}

class _SpinningStatusDotState extends State<_SpinningStatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CustomPaint(painter: _ActiveCirclePainter(color: widget.color)),
    );
  }
}

class _ActiveCirclePainter extends CustomPainter {
  const _ActiveCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 2.6) / 2;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.22);
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 0.78,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ActiveCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 1.8) / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..color = color;
    const segments = 14;
    const gapRatio = 0.46;
    for (var i = 0; i < segments; i++) {
      final start = i * 2 * math.pi / segments;
      final sweep = (2 * math.pi / segments) * gapRatio;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DotSteps extends StatelessWidget {
  const _DotSteps({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final labels = [
      l10n.migrationStepBackup,
      l10n.migrationStepMigrate,
      l10n.migrationStepComplete,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i <= activeStep
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: i <= activeStep ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 22),
                color: i < activeStep
                    ? cs.primary.withValues(alpha: 0.6)
                    : cs.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
        ],
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            child: Center(child: Icon(icon, color: color, size: 18)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupFileCard extends StatelessWidget {
  const _BackupFileCard({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Lucide.databaseBackup,
              size: 17,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.migrationBackupFileSavedTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  p.basename(path),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.conversations, required this.messages});

  final int conversations;
  final int messages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              label: l10n.migrationConversationCount,
              value: conversations,
            ),
          ),
          Container(width: 1, height: 42, color: cs.outlineVariant),
          Expanded(
            child: _Stat(label: l10n.migrationMessageCount, value: messages),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        ReelText(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: AppFontWeights.emphasis,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Lucide.TriangleAlert, size: 18, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.55,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.migrationFailureLogTitle,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 120),
            child: SingleChildScrollView(
              child: Text(
                lines.take(24).join('\n'),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileButtonSurface(
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: onPressed == null
                      ? cs.surfaceContainerHighest
                      : cs.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: onPressed == null
                          ? cs.onSurfaceVariant.withValues(alpha: 0.55)
                          : cs.onPrimary,
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: ReelText(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: AppFontWeights.semibold,
                          color: onPressed == null
                              ? cs.onSurfaceVariant.withValues(alpha: 0.55)
                              : cs.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TactileButtonSurface extends StatefulWidget {
  const _TactileButtonSurface({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  State<_TactileButtonSurface> createState() => _TactileButtonSurfaceState();
}

class _TactileButtonSurfaceState extends State<_TactileButtonSurface> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.985 : 1.0;
    final opacity = !_enabled
        ? 1.0
        : _pressed
        ? 0.86
        : _hovered
        ? 0.94
        : 1.0;
    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: _enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: _enabled ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: opacity,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: child,
    );
  }
}

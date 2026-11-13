import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/webdav_backup_schedule_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';

/// The same schedule controls are available in mobile and desktop settings.
class WebDavBackupScheduleSection extends StatefulWidget {
  const WebDavBackupScheduleSection({super.key, this.desktop = false});

  final bool desktop;

  @override
  State<WebDavBackupScheduleSection> createState() =>
      _WebDavBackupScheduleSectionState();
}

class _WebDavBackupScheduleSectionState
    extends State<WebDavBackupScheduleSection> {
  bool _saving = false;

  Future<void> _save(
    WebDavBackupScheduleProvider provider,
    WebDavBackupScheduleSettings settings,
  ) async {
    setState(() => _saving = true);
    try {
      await provider.updateSettings(settings);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: AppLocalizations.of(context)!.webDavScheduleSaveFailed,
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _runNow(WebDavBackupScheduleProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    var success = false;
    try {
      success = await provider.runNow();
    } catch (_) {
      // Storage and platform failures should stay visible in the settings UI.
    }
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: success
          ? l10n.webDavScheduleSucceeded
          : webDavScheduleErrorLabel(l10n, provider.state.lastError),
      type: success ? NotificationType.success : NotificationType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    // A backup page may also be embedded without the application's scheduler.
    final provider = context.watch<WebDavBackupScheduleProvider?>();
    if (provider == null) return const SizedBox.shrink();
    // Saving server settings changes whether this device can enable backups.
    context.watch<SettingsProvider?>();
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = provider.settings;
    final available = provider.initialized && !_saving && !provider.busy;
    final nextRun = provider.nextRunAt;
    final rawError = provider.state.lastError;
    final errorDetails =
        rawError == null ||
            const {
              'wifi_required',
              'network_unavailable',
              'webdav_not_configured',
              'backup_busy',
              'backup_timeout',
              'backup_password_required',
            }.contains(rawError)
        ? null
        : WebDavBackupSchedule.safeError(rawError);
    final status = provider.busy
        ? l10n.webDavScheduleRunning
        : !provider.configured
        ? l10n.webDavScheduleNotConfigured
        : provider.state.lastError != null
        ? webDavScheduleErrorLabel(l10n, provider.state.lastError)
        : !settings.enabled
        ? l10n.webDavScheduleDisabled
        : l10n.webDavScheduleReady;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.desktop)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 6),
            child: Text(
              l10n.webDavScheduleTitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        SectionCard(
          radius: widget.desktop ? 18 : 12,
          children: [
            if (widget.desktop)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.webDavScheduleTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ),
            _ScheduleRow(
              icon: Lucide.Timer,
              title: l10n.webDavScheduleEnabled,
              trailing: IosSwitch(
                key: const ValueKey('webdav-schedule-enabled'),
                semanticLabel: l10n.webDavScheduleEnabled,
                value: settings.enabled,
                onChanged:
                    provider.initialized &&
                        !_saving &&
                        (settings.enabled || !provider.busy) &&
                        (provider.configured || settings.enabled)
                    ? (value) =>
                          _save(provider, settings.copyWith(enabled: value))
                    : null,
              ),
            ),
            if (settings.enabled) ...[
              const _ScheduleDivider(),
              _ScheduleRow(
                key: const ValueKey('webdav-schedule-interval'),
                icon: Lucide.Repeat,
                title: l10n.webDavScheduleInterval,
                detail: webDavScheduleIntervalLabel(
                  l10n,
                  settings.intervalHours,
                ),
                onTap: available
                    ? () async {
                        final hours = await showWebDavScheduleIntervalPicker(
                          context,
                          selectedHours: settings.intervalHours,
                          desktop: widget.desktop,
                        );
                        if (hours == null || !mounted) return;
                        await _save(
                          provider,
                          settings.copyWith(intervalHours: hours),
                        );
                      }
                    : null,
              ),
            ],
            const _ScheduleDivider(),
            _ScheduleRow(
              icon: Lucide.Network,
              title: l10n.webDavScheduleWifiOnly,
              subtitle: l10n.webDavScheduleWifiOnlyHint,
              trailing: IosSwitch(
                key: const ValueKey('webdav-schedule-wifi-only'),
                semanticLabel: l10n.webDavScheduleWifiOnly,
                value: settings.wifiOnly,
                onChanged: available
                    ? (value) =>
                          _save(provider, settings.copyWith(wifiOnly: value))
                    : null,
              ),
            ),
            const _ScheduleDivider(),
            _ScheduleRow(
              icon: Lucide.CheckCircle,
              title: l10n.webDavScheduleLastSuccess,
              detail: _dateTimeLabel(
                context,
                provider.state.lastSuccess,
                l10n.webDavScheduleNever,
              ),
            ),
            if (settings.enabled) ...[
              const _ScheduleDivider(),
              _ScheduleRow(
                icon: Lucide.Calendar,
                title: l10n.webDavScheduleNextRun,
                detail: nextRun == null || !DateTime.now().isBefore(nextRun)
                    ? l10n.webDavScheduleDue
                    : _dateTimeLabel(context, nextRun, l10n.webDavScheduleDue),
              ),
            ],
            const _ScheduleDivider(),
            _ScheduleRow(
              icon: Lucide.Activity,
              title: l10n.webDavScheduleStatus,
              subtitle: errorDetails == null
                  ? status
                  : '$status\n$errorDetails',
            ),
            const _ScheduleDivider(),
            _ScheduleRow(
              key: const ValueKey('webdav-schedule-run-now'),
              icon: Lucide.Upload,
              title: provider.busy
                  ? l10n.webDavScheduleRunning
                  : l10n.webDavScheduleRunNow,
              action: true,
              onTap: available && provider.configured
                  ? () => _runNow(provider)
                  : null,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            !provider.configured
                ? l10n.webDavScheduleConfigureFirst
                : provider.supportsBackground
                ? l10n.webDavScheduleAndroidHint
                : l10n.webDavScheduleForegroundHint,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

String webDavScheduleIntervalLabel(AppLocalizations l10n, int hours) =>
    hours == 24
    ? l10n.webDavScheduleEveryDay
    : l10n.webDavScheduleEveryHours(hours);

String webDavScheduleErrorLabel(AppLocalizations l10n, String? error) =>
    switch (error) {
      'wifi_required' => l10n.webDavScheduleWifiRequired,
      'network_unavailable' => l10n.webDavScheduleNetworkUnavailable,
      'webdav_not_configured' => l10n.webDavScheduleNotConfigured,
      'backup_busy' => l10n.webDavScheduleBackupBusy,
      'backup_timeout' => l10n.webDavScheduleTimedOut,
      'backup_password_required' => l10n.webDavSchedulePasswordRequired,
      _ => l10n.webDavScheduleFailed,
    };

String _dateTimeLabel(BuildContext context, DateTime? value, String empty) {
  if (value == null) return empty;
  final local = value.toLocal();
  final material = MaterialLocalizations.of(context);
  return '${material.formatCompactDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))}';
}

/// Uses a sheet on mobile and a dialog on desktop.
Future<int?> showWebDavScheduleIntervalPicker(
  BuildContext context, {
  required int selectedHours,
  required bool desktop,
}) {
  final l10n = AppLocalizations.of(context)!;
  Widget options(BuildContext ctx) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final hours in WebDavBackupScheduleSettings.intervalPresets)
        IosCardPress(
          key: ValueKey('webdav-schedule-hours-$hours'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: () => Navigator.of(ctx).pop(hours),
          child: Row(
            children: [
              Expanded(child: Text(webDavScheduleIntervalLabel(l10n, hours))),
              if (hours == selectedHours)
                Icon(
                  Lucide.Check,
                  size: 18,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
            ],
          ),
        ),
    ],
  );

  if (desktop) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('webdav-schedule-interval-dialog'),
        title: Text(l10n.webDavScheduleInterval),
        content: SizedBox(width: 320, child: options(ctx)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.backupPageCancel),
          ),
        ],
      ),
    );
  }
  return showFormSheet<int>(
    context,
    builder: (ctx) => FormSheet(
      key: const ValueKey('webdav-schedule-interval-sheet'),
      title: l10n.webDavScheduleInterval,
      children: [options(ctx)],
    ),
  );
}

class _ScheduleDivider extends StatelessWidget {
  const _ScheduleDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 60, end: 12),
    child: Divider(
      height: 1,
      thickness: 0.6,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.2),
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.action = false,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = action
        ? cs.primary.withValues(alpha: onTap == null ? 0.45 : 1)
        : cs.onSurface;
    return IosCardPress(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Row(
          children: [
            SizedBox(width: 36, child: Icon(icon, size: 20, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, color: color)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  detail!,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (onTap != null && !action) ...[
              const SizedBox(width: 6),
              Icon(Lucide.ChevronRight, size: 16, color: cs.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

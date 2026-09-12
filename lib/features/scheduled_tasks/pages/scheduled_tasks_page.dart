import 'dart:async';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/widgets/desktop_scheduled_task_tile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/models/scheduled_task.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../widgets/scheduled_tasks_scaffold.dart';
import 'scheduled_task_editor_page.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/scheduled_tasks_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/scheduled_task_tile.dart';
import '../../settings/pages/mobile_background_settings_page.dart';
import '../../settings/widgets/custom_theme_widgets.dart';

String _repeatLabel(ScheduledTask task, AppLocalizations l) {
  if (task.onceDate != null) return scheduledRepeatLabel(task.repeat, l);
  if (task.weekdays.length == 7) return l.scheduledTasksEveryDay;
  if (task.weekdays.length == 5 && task.weekdays.every((d) => d <= 5)) {
    return l.scheduledTasksWeekdays;
  }
  return task.weekdays
      .map((d) => DateFormat.E(l.localeName).format(DateTime(2024, 1, d)))
      .join(' · ');
}

String _date(DateTime date, AppLocalizations l) =>
    DateFormat.Md(l.localeName).add_Hm().format(date);

/// Controls use Kelivo's shared iOS/R3 components on mobile and desktop.
class ScheduledTasksPage extends StatefulWidget {
  const ScheduledTasksPage({
    super.key,
    this.service,
    this.embedded = false,
    this.requestNotificationsPermission =
        NotificationService.ensureAndroidNotificationsPermission,
  });
  final ScheduledTasksService? service;
  final bool embedded;
  final Future<bool> Function() requestNotificationsPermission;
  @override
  State<ScheduledTasksPage> createState() => _ScheduledTasksPageState();
}

class _ScheduledTasksPageState extends State<ScheduledTasksPage>
    with WidgetsBindingObserver {
  late final service = widget.service ?? ScheduledTasksService.instance;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service.addListener(_changed);
    unawaited(service.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(service.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    service.removeListener(_changed);
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: e.toString(),
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _edit([ScheduledTask? task]) async {
    final assistants = context.read<AssistantProvider>();
    await assistants.loaded;
    if (!mounted) return;
    await context.read<ChatService>().init();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ScheduledTaskEditorPage(
          task: task,
          assistants: assistants.assistants,
          initialAssistantId: assistants.currentAssistant?.id,
          onSave: _save,
        ),
      ),
    );
  }

  Future<void> _save(ScheduledTask task, {bool? enabled}) async {
    if (!service.isDesktop && (enabled ?? task.enabled)) {
      await widget.requestNotificationsPermission();
    }
    await service.save(task, enabled: enabled);
  }

  Future<void> _details(
    ScheduledTask original, {
    String? action,
    Offset? position,
  }) async {
    final l = AppLocalizations.of(context)!;
    final items = <OptionSheetItem<String>>[
      if (!original.running)
        OptionSheetItem(
          value: 'run',
          icon: LucideIcons.play,
          label: l.scheduledTasksRunNow,
        ),
      OptionSheetItem(
        value: 'history',
        icon: LucideIcons.history,
        label: l.scheduledTasksHistory,
      ),
      if (!original.running) ...[
        OptionSheetItem(
          value: 'edit',
          icon: LucideIcons.pencil,
          label: l.scheduledTasksEdit,
        ),
        OptionSheetItem(
          value: 'delete',
          icon: LucideIcons.trash2,
          label: l.scheduledTasksDelete,
        ),
      ],
    ];
    if (action == null) {
      if (service.isDesktop) {
        await showDesktopContextMenuAt(
          context,
          globalPosition: position!,
          items: [
            for (final item in items)
              DesktopContextMenuItem(
                icon: item.icon,
                label: item.label,
                danger: item.value == 'delete',
                onTap: () => action = item.value,
              ),
          ],
        );
      } else {
        action = await showOptionSheet<String>(
          context,
          title: original.name,
          items: items,
        );
      }
    }
    if (!mounted) return;
    switch (action) {
      case 'run':
        await _perform(() async {
          if (!service.isDesktop) await widget.requestNotificationsPermission();
          await service.runNow(original.id);
        });
      case 'edit':
        await _edit(original);
      case 'delete':
        await _showPanel(
          (ctx) => _panel(
            ctx,
            title: l.scheduledTasksDelete,
            actions: FormSheetActions(
              cancelLabel: l.scheduledTasksCancel,
              confirmLabel: l.scheduledTasksDelete,
              destructive: true,
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () async {
                await _perform(() => service.delete(original.id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            children: [IosSectionFooter(text: l.scheduledTasksDeleteDetail)],
          ),
        );
      case 'history':
        await _showPanel(
          (_) => ListenableBuilder(
            listenable: service,
            builder: (ctx, _) {
              final task =
                  service.tasks.where((t) => t.id == original.id).firstOrNull ??
                  original;
              return _panel(
                ctx,
                title: l.scheduledTasksHistory,
                children: [
                  if (task.runs.isEmpty)
                    IosSectionFooter(text: l.scheduledTasksNoRuns),
                  for (final run in task.runs) ...[
                    SectionCard(
                      children: [
                        IosNavRow(
                          label: _status(run.status, l),
                          detailText: _date(run.startedAt, l),
                          icon: run.status == 'completed'
                              ? LucideIcons.check
                              : LucideIcons.clock,
                        ),
                        if ((run.preview ?? '').isNotEmpty)
                          IosSectionFooter(text: run.preview!),
                        if ((run.error ?? '').isNotEmpty)
                          IosSectionFooter(text: _error(run.error!, l)),
                        if (run.conversationId != null)
                          IosNavRow(
                            label: l.scheduledTasksOpenChat,
                            icon: LucideIcons.messagesSquare,
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                              NotificationService.openConversation(
                                run.conversationId!,
                              );
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        );
    }
  }

  Future<void> _showPanel(WidgetBuilder builder) async {
    if (service.isDesktop) {
      await showAppDialog<void>(
        context,
        maxWidth: 600,
        child: Builder(builder: builder),
      );
    } else {
      await showFormSheet<void>(context, builder: builder);
    }
  }

  Widget _panel(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    Widget? actions,
  }) {
    if (!service.isDesktop) {
      return FormSheet(title: title, actions: actions, children: children);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogHeader(title: title),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...children,
                if (actions != null) ...[const SizedBox(height: 12), actions],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _status(String status, AppLocalizations l) => switch (status) {
    'completed' => l.scheduledTasksCompleted,
    'running' => l.scheduledTasksRunning,
    'interrupted' => l.scheduledTasksInterrupted,
    _ => l.scheduledTasksFailed,
  };
  String _error(String value, AppLocalizations l) {
    if (value.contains('user_interaction_required')) {
      return l.scheduledTasksNeedsInput;
    }
    if (value.contains('execution_timeout')) return l.scheduledTasksTimeout;
    if (value.contains('process_terminated')) {
      return l.scheduledTasksProcessTerminated;
    }
    if (value.contains('assistant_missing')) {
      return l.scheduledTasksAssistantMissing;
    }
    if (value.contains('conversation_missing')) {
      return l.scheduledTasksChatMissing;
    }
    if (value.contains('message_missing')) {
      return l.scheduledTasksMessageMissing;
    }
    if (value.contains('model_missing')) return l.scheduledTasksModelMissing;
    if (value.contains('in_flight')) return l.scheduledTasksChatBusy;
    return value;
  }

  String _taskDetail(ScheduledTask task, AppLocalizations l) => task.running
      ? l.scheduledTasksRunning
      : task.exhausted
      ? l.scheduledTasksFinished
      : !task.enabled
      ? l.scheduledTasksPaused
      : task.nextRunAt == null
      ? l.scheduledTasksLoading
      : l.scheduledTasksNextRun(_date(task.nextRunAt!, l));

  Widget _desktopLayout(AppLocalizations l) {
    final cs = Theme.of(context).colorScheme;
    return ScheduledTasksScaffold(
      embedded: widget.embedded,
      title: l.scheduledTasksTitle,
      actionIcon: LucideIcons.plus,
      actionLabel: l.scheduledTasksAdd,
      onAction: _edit,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (service.error != null) IosSectionFooter(text: service.error!),
          if (!service.loaded) IosSectionFooter(text: l.scheduledTasksLoading),
          if (service.loaded && service.tasks.isEmpty)
            Padding(
              key: const ValueKey('desktop-scheduled-tasks-empty'),
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Text(
                    l.scheduledTasksDesktopEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface.withValues(alpha: .6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      l.scheduledTasksEmptyDetail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: .5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final task in service.tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DesktopScheduledTaskTile(
                name: task.name,
                time: task.timeLabel,
                repeat: _repeatLabel(task, l),
                detail: _taskDetail(task, l),
                enabled: task.enabled,
                running: task.running,
                onChanged: (value) =>
                    _perform(() => _save(task, enabled: value)),
                onEdit: () => _edit(task),
                onHistory: () => _details(task, action: 'history'),
                onMenu: (position) => _details(task, position: position),
              ),
            ),
          Padding(
            key: const ValueKey('scheduled-tasks-desktop-reliability'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              l.scheduledTasksDesktopReliability,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: cs.onSurface.withValues(alpha: .55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    if (service.isDesktop) return _desktopLayout(l);
    return ScheduledTasksScaffold(
      embedded: widget.embedded,
      title: l.scheduledTasksTitle,
      actionIcon: LucideIcons.plus,
      actionLabel: l.scheduledTasksAdd,
      onAction: _edit,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (service.error != null) IosSectionFooter(text: service.error!),
          if (!service.loaded) IosSectionFooter(text: l.scheduledTasksLoading),
          if (!service.isDesktop && service.loaded && !service.exactAlarms) ...[
            SectionCard(
              children: [
                IosNavRow(
                  icon: LucideIcons.alarmClock,
                  label: l.scheduledTasksPermission,
                  subtitle: l.scheduledTasksPermissionDetail,
                  subtitleMaxLines: null,
                  detailText: l.scheduledTasksPermissionAction,
                  onTap: () => _perform(service.requestPermission),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          if (service.loaded && service.tasks.isEmpty) ...[
            const SizedBox(height: 36),
            Icon(
              LucideIcons.clock,
              size: 44,
              color: cs.onSurface.withValues(alpha: .4),
            ),
            const SizedBox(height: 20),
            Text(
              l.scheduledTasksEmpty,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            IosSectionFooter(text: l.scheduledTasksEmptyDetail),
            const SizedBox(height: 20),
            IosTileButton(
              label: l.scheduledTasksAdd,
              icon: LucideIcons.plus,
              onTap: _edit,
            ),
            const SizedBox(height: 40),
          ],
          for (final task in service.tasks) ...[
            ScheduledTaskTile(
              name: task.name,
              time: task.timeLabel,
              repeat: _repeatLabel(task, l),
              detail: task.running
                  ? l.scheduledTasksRunning
                  : task.exhausted
                  ? l.scheduledTasksFinished
                  : !task.enabled
                  ? l.scheduledTasksPaused
                  : !service.isDesktop && !service.exactAlarms
                  ? l.scheduledTasksWaitingPermission
                  : task.nextRunAt == null
                  ? l.scheduledTasksWaitingPermission
                  : l.scheduledTasksNextRun(_date(task.nextRunAt!, l)),
              enabled: task.enabled,
              running: task.running,
              onTap: () => _details(task),
              onChanged: (enabled) =>
                  _perform(() => _save(task, enabled: enabled)),
            ),
            const SizedBox(height: 12),
          ],
          IosSectionFooter(
            key: const ValueKey('scheduled-tasks-description'),
            text: l.scheduledTasksDescription,
          ),
          ...[
            const SizedBox(height: 24),
            SectionCard(
              key: const ValueKey('scheduled-tasks-background-settings'),
              children: [
                IosNavRow(
                  icon: LucideIcons.battery,
                  label: l.backgroundSettingsTitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MobileBackgroundSettingsPage(),
                    ),
                  ),
                ),
              ],
            ),
            IosSectionFooter(text: l.scheduledTasksReliability),
          ],
        ],
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/assistant.dart';
import '../../../core/models/scheduled_task.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/scheduled_tasks_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/scheduled_task_tile.dart';
import '../../settings/pages/mobile_background_settings_page.dart';

String _repeatLabel(ScheduledTask task, AppLocalizations l) {
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

/// Android-only screen. Controls use Kelivo's shared iOS/R3 components.
class ScheduledTasksPage extends StatefulWidget {
  const ScheduledTasksPage({super.key, this.service});
  final ScheduledTasksService? service;
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
    await showFormSheet<void>(
      context,
      builder: (_) => ScheduledTaskEditor(
        task: task,
        assistants: assistants.assistants,
        initialAssistantId: assistants.currentAssistant?.id,
        onSave: (value) => service.save(value),
      ),
    );
  }

  Future<void> _details(ScheduledTask original) async {
    final l = AppLocalizations.of(context)!;
    final action = await showOptionSheet<String>(
      context,
      title: original.name,
      items: [
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
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'run':
        await _perform(() => service.runNow(original.id));
      case 'edit':
        await _edit(original);
      case 'delete':
        await showFormSheet<void>(
          context,
          builder: (ctx) => FormSheet(
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
        await showFormSheet<void>(
          context,
          builder: (_) => ListenableBuilder(
            listenable: service,
            builder: (ctx, _) {
              final task =
                  service.tasks.where((t) => t.id == original.id).firstOrNull ??
                  original;
              return FormSheet(
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
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!,
      child: ColoredBox(
        color: cs.surface,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IosIconButton(
                      icon: LucideIcons.arrowLeft,
                      semanticLabel: l.settingsPageBackButton,
                      onTap: () => Navigator.maybePop(context),
                    ),
                    Expanded(
                      child: Text(
                        l.scheduledTasksTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    IosIconButton(
                      icon: LucideIcons.plus,
                      semanticLabel: l.scheduledTasksAdd,
                      onTap: _edit,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (service.error != null)
                      IosSectionFooter(text: service.error!),
                    if (!service.loaded)
                      IosSectionFooter(text: l.scheduledTasksLoading),
                    if (service.loaded && !service.exactAlarms) ...[
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
                            : !task.enabled
                            ? l.scheduledTasksPaused
                            : !service.exactAlarms
                            ? l.scheduledTasksWaitingPermission
                            : task.nextRunAt == null
                            ? l.scheduledTasksWaitingPermission
                            : l.scheduledTasksNextRun(
                                _date(task.nextRunAt!, l),
                              ),
                        enabled: task.enabled,
                        running: task.running,
                        onTap: () => _details(task),
                        onChanged: (enabled) => _perform(
                          () => service.save(task, enabled: enabled),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    IosSectionFooter(text: l.scheduledTasksDescription),
                    SectionCard(
                      children: [
                        IosNavRow(
                          icon: LucideIcons.battery,
                          label: l.backgroundSettingsTitle,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MobileBackgroundSettingsPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    IosSectionFooter(text: l.scheduledTasksReliability),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScheduledTaskEditor extends StatefulWidget {
  const ScheduledTaskEditor({
    super.key,
    this.task,
    required this.assistants,
    this.initialAssistantId,
    required this.onSave,
  });
  final ScheduledTask? task;
  final List<Assistant> assistants;
  final String? initialAssistantId;
  final Future<void> Function(ScheduledTask) onSave;
  @override
  State<ScheduledTaskEditor> createState() => _ScheduledTaskEditorState();
}

class _ScheduledTaskEditorState extends State<ScheduledTaskEditor> {
  late final name = TextEditingController(text: widget.task?.name);
  late final prompt = TextEditingController(text: widget.task?.prompt);
  late final time = TextEditingController(
    text: widget.task?.timeLabel ?? '08:00',
  );
  late String? assistantId =
      widget.task?.assistantId ?? widget.initialAssistantId;
  late final days = {
    ...widget.task?.weekdays ?? [1, 2, 3, 4, 5, 6, 7],
  };
  late bool enabled = widget.task?.enabled ?? true;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    prompt.dispose();
    time.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time.text.trim());
    final hour = match == null ? -1 : int.parse(match[1]!);
    final minute = match == null ? -1 : int.parse(match[2]!);
    if (name.text.trim().isEmpty ||
        name.text.trim().length > 200 ||
        prompt.text.trim().isEmpty ||
        prompt.text.trim().length > 32000 ||
        !widget.assistants.any((a) => a.id == assistantId) ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        days.isEmpty) {
      setState(() => error = l.scheduledTasksInvalid);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave(
        ScheduledTask(
          id: widget.task?.id ?? const Uuid().v4(),
          name: name.text.trim(),
          prompt: prompt.text.trim(),
          assistantId: assistantId!,
          hour: hour,
          minute: minute,
          weekdays: days.toList()..sort(),
          enabled: enabled,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final assistant = widget.assistants
        .where((a) => a.id == assistantId)
        .firstOrNull;
    return FormSheet(
      title: widget.task == null ? l.scheduledTasksAdd : l.scheduledTasksEdit,
      actions: FormSheetActions(
        cancelLabel: l.scheduledTasksCancel,
        confirmLabel: l.scheduledTasksSave,
        onCancel: () => Navigator.pop(context),
        onConfirm: busy ? null : _save,
        busy: busy,
      ),
      children: [
        IosFormTextField(
          label: l.scheduledTasksName,
          hintText: l.scheduledTasksNameHint,
          controller: name,
          inlineLabel: false,
        ),
        IosFormTextField(
          label: l.scheduledTasksPrompt,
          hintText: l.scheduledTasksPromptHint,
          controller: prompt,
          inlineLabel: false,
          maxLines: 5,
          minLines: 3,
        ),
        SectionCard(
          children: [
            IosNavRow(
              icon: LucideIcons.bot,
              label: l.scheduledTasksAssistant,
              subtitle: assistant?.name ?? l.scheduledTasksChooseAssistant,
              onTap: () async {
                final id = await showOptionSheet<String>(
                  context,
                  title: l.scheduledTasksChooseAssistant,
                  selected: assistantId,
                  items: widget.assistants
                      .map(
                        (a) => OptionSheetItem(
                          value: a.id,
                          label: a.name,
                          icon: LucideIcons.bot,
                        ),
                      )
                      .toList(),
                );
                if (id != null && mounted) setState(() => assistantId = id);
              },
            ),
            const IosRowDivider(),
            IosFormTextField(
              label: l.scheduledTasksTime,
              hintText: l.scheduledTasksTimeHint,
              controller: time,
              fieldWidth: 110,
              keyboardType: TextInputType.datetime,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        IosSectionHeader(text: l.scheduledTasksRepeat),
        SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int d = 1; d <= 7; d++)
                    Semantics(
                      selected: days.contains(d),
                      button: true,
                      child: IosTileButton(
                        label: DateFormat.E(
                          l.localeName,
                        ).format(DateTime(2024, 1, d)),
                        icon: days.contains(d)
                            ? LucideIcons.check
                            : LucideIcons.minus,
                        backgroundColor: days.contains(d)
                            ? Theme.of(context).colorScheme.primary
                            : null,
                        onTap: () => setState(() {
                          if (!days.remove(d)) days.add(d);
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const IosRowDivider(indent: 12),
            IosSwitchRow(
              label: l.scheduledTasksEnabled,
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
          ],
        ),
        IosSectionFooter(text: l.scheduledTasksExecutionDetail),
        if (error != null) IosSectionFooter(text: error!),
      ],
    );
  }
}

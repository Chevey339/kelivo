import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/scheduled_task.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_date_picker.dart';
import '../../../shared/widgets/ios_form_text_field.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_time_picker.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../../shared/widgets/section_card.dart';
import '../../assistant/widgets/assistant_select_sheet.dart';
import '../../home/utils/model_display_helper.dart';
import '../../home/widgets/assistant_avatar.dart';
import '../../home/widgets/model_icon.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../widgets/scheduled_target_picker.dart';
import '../widgets/scheduled_tasks_scaffold.dart';
import '../widgets/scheduled_weekday_selector.dart';

String scheduledRepeatLabel(ScheduledTaskRepeat repeat, AppLocalizations l) =>
    switch (repeat) {
      ScheduledTaskRepeat.once => l.scheduledTasksOnce,
      ScheduledTaskRepeat.daily => l.scheduledTasksEveryDay,
      ScheduledTaskRepeat.weekdays => l.scheduledTasksWeekdays,
      ScheduledTaskRepeat.custom => l.scheduledTasksCustom,
    };

String scheduledModeLabel(ScheduledTaskMode mode, AppLocalizations l) =>
    switch (mode) {
      ScheduledTaskMode.newChat => l.scheduledTasksNewChat,
      ScheduledTaskMode.followUp => l.scheduledTasksFollowUp,
      ScheduledTaskMode.regenerate => l.scheduledTasksRegenerate,
    };

class ScheduledTaskEditorPage extends StatefulWidget {
  const ScheduledTaskEditorPage({
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
  State<ScheduledTaskEditorPage> createState() =>
      _ScheduledTaskEditorPageState();
}

class _ScheduledTaskEditorPageState extends State<ScheduledTaskEditorPage> {
  final scroll = ScrollController();
  late final name = TextEditingController(text: widget.task?.name);
  late final prompt = TextEditingController(text: widget.task?.prompt);
  late String? assistantId =
      widget.task?.assistantId ?? widget.initialAssistantId;
  late ScheduledTaskMode mode = widget.task?.mode ?? ScheduledTaskMode.newChat;
  late ScheduledTaskRepeat repeat =
      widget.task?.repeat ?? ScheduledTaskRepeat.daily;
  late Set<int> days = {
    ...widget.task?.weekdays ?? [1, 2, 3, 4, 5, 6, 7],
  };
  late int minutes = (widget.task?.hour ?? 8) * 60 + (widget.task?.minute ?? 0);
  late bool enabled = widget.task?.enabled ?? true;
  late String? conversationId = widget.task?.conversationId;
  late String? messageId = widget.task?.messageId;
  late String? modelProvider = widget.task?.modelProvider;
  late String? modelId = widget.task?.modelId;
  late DateTime? onceDate = widget.task?.onceDate;
  late DateTime? startDate = widget.task?.startDate;
  late DateTime? endDate = widget.task?.endDate;
  String? messagePreview;
  String? error;
  bool busy = false;

  Assistant? get assistant =>
      widget.assistants.where((a) => a.id == assistantId).firstOrNull;
  Conversation? get conversation => conversationId == null
      ? null
      : context.read<ChatService>().getConversation(conversationId!);

  @override
  void initState() {
    super.initState();
    if (messageId != null) unawaited(_loadMessagePreview());
  }

  Future<void> _loadMessagePreview() async {
    try {
      final message = await context
          .read<ChatService>()
          .chatRepositoryOrNull
          ?.getMessage(messageId!);
      if (mounted) {
        setState(
          () =>
              messagePreview = message?.content.characters.take(100).toString(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    name.dispose();
    prompt.dispose();
    super.dispose();
  }

  void _showError(String value) {
    setState(() => error = value);
    if (scroll.hasClients) {
      unawaited(
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  DateTime get today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickAssistant() async {
    FocusScope.of(context).unfocus();
    final id = await showAssistantMoveSelector(context);
    if (!mounted || id == null || id == assistantId) return;
    setState(() {
      assistantId = id;
      conversationId = null;
      messageId = null;
      messagePreview = null;
    });
  }

  Future<void> _pickConversation() async {
    final chat = context.read<ChatService>();
    await chat.init();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final choices = chat
        .getAllConversations()
        .where(
          (c) =>
              c.assistantId == assistantId &&
              !chat.isTemporaryConversation(c.id),
        )
        .toList();
    final id = await showScheduledTargetPicker(
      context,
      title: l.scheduledTasksChooseChat,
      selected: conversationId,
      choices: [
        for (final c in choices)
          ScheduledTargetChoice(
            c.id,
            c.title,
            DateFormat.yMMMd(l.localeName).format(c.updatedAt),
          ),
      ],
    );
    if (!mounted || id == null || id == conversationId) return;
    setState(() {
      conversationId = id;
      messageId = null;
      messagePreview = null;
    });
  }

  Future<void> _pickMessage() async {
    if (conversationId == null) return;
    final repo = context.read<ChatService>().chatRepositoryOrNull;
    final messages = await repo?.getSelectedMessageProjections(conversationId!);
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    final choices =
        messages?.where((m) => m.role == 'user').toList().reversed.toList() ??
        [];
    final id = await showScheduledTargetPicker(
      context,
      title: l.scheduledTasksChooseMessage,
      selected: messageId,
      choices: [
        for (final m in choices)
          ScheduledTargetChoice(
            m.id,
            m.content.isEmpty ? l.scheduledTasksAttachmentMessage : m.content,
            DateFormat.Md(l.localeName).add_Hm().format(m.timestamp),
          ),
      ],
    );
    if (!mounted || id == null) return;
    setState(() {
      messageId = id;
      messagePreview = choices.firstWhere((m) => m.id == id).content;
    });
  }

  Future<void> _pickRepeat() async {
    final l = AppLocalizations.of(context)!;
    final value = await showOptionSheet<ScheduledTaskRepeat>(
      context,
      title: l.scheduledTasksRepeat,
      selected: repeat,
      items: [
        for (final value in ScheduledTaskRepeat.values)
          OptionSheetItem(value: value, label: scheduledRepeatLabel(value, l)),
      ],
    );
    if (!mounted || value == null) return;
    setState(() {
      repeat = value;
      if (value == ScheduledTaskRepeat.daily) days = {1, 2, 3, 4, 5, 6, 7};
      if (value == ScheduledTaskRepeat.weekdays) days = {1, 2, 3, 4, 5};
      if (value == ScheduledTaskRepeat.once && onceDate == null) {
        final now = DateTime.now();
        onceDate = DateTime(
          now.year,
          now.month,
          now.day + (minutes <= now.hour * 60 + now.minute ? 1 : 0),
        );
      }
    });
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final value = await showIosTimePicker(
      context,
      title: AppLocalizations.of(context)!.scheduledTasksTime,
      initialMinutes: minutes,
    );
    if (mounted && value != null) setState(() => minutes = value);
  }

  Future<void> _pickDate(DateTime? value, ValueChanged<DateTime> save) async {
    FocusScope.of(context).unfocus();
    final initial = value ?? today;
    final picked = await showIosDatePicker(
      context,
      firstDate: DateTime(
        initial.year < today.year ? initial.year : today.year,
      ),
      lastDate: DateTime(
        initial.year > today.year + 30 ? initial.year : today.year + 30,
        12,
        31,
      ),
      initialDate: initial,
    );
    if (mounted && picked != null) setState(() => save(picked));
  }

  Future<void> _pickModel() async {
    final settings = context.read<SettingsProvider>();
    final inherited = resolveChatModel(
      settings,
      assistant: assistant,
      conversation: mode == ScheduledTaskMode.newChat ? null : conversation,
    );
    final value = await showModelSelector(
      context,
      initialProviderKey: modelProvider ?? inherited.providerKey,
      initialModelId: modelId ?? inherited.modelId,
      allowInherit: true,
      inheritLabel: AppLocalizations.of(context)!.scheduledTasksModelDefault,
    );
    if (!mounted || value == null) return;
    setState(() {
      modelProvider = value.providerKey.isEmpty ? null : value.providerKey;
      modelId = value.modelId.isEmpty ? null : value.modelId;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    String? validation;
    if (name.text.trim().isEmpty ||
        name.text.trim().length > 200 ||
        assistant == null ||
        (mode != ScheduledTaskMode.regenerate && prompt.text.trim().isEmpty) ||
        prompt.text.trim().length > 32000 ||
        (repeat == ScheduledTaskRepeat.custom && days.isEmpty)) {
      validation = l.scheduledTasksInvalid;
    }
    if (mode != ScheduledTaskMode.newChat && conversation == null) {
      validation = l.scheduledTasksChooseChat;
    }
    if (mode == ScheduledTaskMode.regenerate && messageId == null) {
      validation = l.scheduledTasksChooseMessage;
    }
    if (repeat == ScheduledTaskRepeat.once) {
      final date = onceDate;
      if (date == null ||
          (enabled &&
              !DateTime(
                date.year,
                date.month,
                date.day,
                minutes ~/ 60,
                minutes % 60,
              ).isAfter(DateTime.now()))) {
        validation = l.scheduledTasksFutureDate;
      }
    } else if (startDate != null &&
        endDate != null &&
        endDate!.isBefore(startDate!)) {
      validation = l.scheduledTasksDateRangeInvalid;
    } else if (enabled && endDate != null && endDate!.isBefore(today)) {
      validation = l.scheduledTasksFutureDate;
    }
    if (validation != null) {
      _showError(validation);
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
          hour: minutes ~/ 60,
          minute: minutes % 60,
          weekdays: days.isEmpty
              ? [1, 2, 3, 4, 5, 6, 7]
              : (days.toList()..sort()),
          enabled: enabled,
          mode: mode,
          conversationId: mode == ScheduledTaskMode.newChat
              ? null
              : conversationId,
          messageId: mode == ScheduledTaskMode.regenerate ? messageId : null,
          modelProvider: modelProvider,
          modelId: modelId,
          onceDate: repeat == ScheduledTaskRepeat.once ? onceDate : null,
          startDate: repeat == ScheduledTaskRepeat.once ? null : startDate,
          endDate: repeat == ScheduledTaskRepeat.once ? null : endDate,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        _showError(
          e is PlatformException && e.message == 'schedule_ended'
              ? l.scheduledTasksFutureDate
              : e.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _dateRow(
    String label,
    DateTime? date,
    ValueChanged<DateTime?> setDate, {
    bool clearable = true,
  }) {
    final l = AppLocalizations.of(context)!;
    return IosNavRow(
      label: label,
      detailText: date == null
          ? l.scheduledTasksDateUnrestricted
          : DateFormat.yMMMd(l.localeName).format(date),
      trailing: clearable && date != null
          ? IosIconButton(
              icon: LucideIcons.x,
              size: 16,
              minSize: 36,
              semanticLabel: '${l.scheduledTasksClear} $label',
              onTap: () => setState(() => setDate(null)),
            )
          : null,
      onTap: () => _perform(() => _pickDate(date, (value) => setDate(value))),
    );
  }

  List<Widget> _taskFields(AppLocalizations l) {
    final settings = context.watch<SettingsProvider>();
    final display = getModelDisplayInfo(
      settings,
      assistant: modelId == null
          ? assistant
          : assistant?.copyWith(
              chatModelProvider: modelProvider,
              chatModelId: modelId,
            ),
      conversation: modelId != null || mode == ScheduledTaskMode.newChat
          ? null
          : conversation,
    );
    return [
      SectionCard(
        children: [
          IosFormTextField(
            label: l.scheduledTasksName,
            hintText: l.scheduledTasksNameHint,
            controller: name,
            inlineLabel: false,
          ),
        ],
      ),
      IosSectionHeader(text: l.scheduledTasksExecution),
      SectionCard(
        children: [
          IosNavRow(
            leading: AssistantAvatar(assistant: assistant, size: 30),
            label: l.scheduledTasksAssistant,
            subtitle: assistant?.name ?? l.scheduledTasksChooseAssistant,
            onTap: () => _perform(_pickAssistant),
          ),
          const IosRowDivider(),
          IosNavRow(
            icon: LucideIcons.workflow,
            label: l.scheduledTasksMode,
            detailText: scheduledModeLabel(mode, l),
            onTap: () async {
              final value = await showOptionSheet<ScheduledTaskMode>(
                context,
                title: l.scheduledTasksMode,
                selected: mode,
                items: [
                  for (final value in ScheduledTaskMode.values)
                    OptionSheetItem(
                      value: value,
                      label: scheduledModeLabel(value, l),
                    ),
                ],
              );
              if (mounted && value != null) setState(() => mode = value);
            },
          ),
          if (mode != ScheduledTaskMode.newChat) ...[
            const IosRowDivider(),
            IosNavRow(
              icon: LucideIcons.messagesSquare,
              label: l.scheduledTasksChat,
              subtitle: conversation?.title ?? l.scheduledTasksChooseChat,
              onTap: () => _perform(_pickConversation),
            ),
          ],
          if (mode == ScheduledTaskMode.regenerate) ...[
            const IosRowDivider(),
            IosNavRow(
              icon: LucideIcons.rotateCw,
              label: l.scheduledTasksMessage,
              subtitle: messagePreview ?? l.scheduledTasksChooseMessage,
              subtitleMaxLines: 2,
              onTap: conversationId == null
                  ? null
                  : () => _perform(_pickMessage),
            ),
          ],
          const IosRowDivider(),
          IosNavRow(
            leading: display.isConfigured
                ? CurrentModelIcon(
                    providerKey: display.providerKey,
                    modelId: display.modelId,
                    size: 30,
                  )
                : const Icon(LucideIcons.box, size: 20),
            label: l.scheduledTasksModel,
            subtitle: display.modelDisplay ?? l.scheduledTasksChooseModel,
            caption: modelId == null
                ? l.scheduledTasksModelDefault
                : display.providerName,
            onTap: () => _perform(_pickModel),
          ),
        ],
      ),
      if (mode == ScheduledTaskMode.regenerate)
        IosSectionFooter(text: l.scheduledTasksRegenerateDetail)
      else ...[
        const SizedBox(height: 18),
        SectionCard(
          children: [
            IosFormTextField(
              label: l.scheduledTasksPrompt,
              hintText: l.scheduledTasksPromptHint,
              controller: prompt,
              inlineLabel: false,
              minLines: 4,
              maxLines: 8,
            ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _scheduleFields(AppLocalizations l, {required bool first}) => [
    IosSectionHeader(text: l.scheduledTasksSchedule, first: first),
    SectionCard(
      children: [
        IosNavRow(
          icon: LucideIcons.clock,
          label: l.scheduledTasksTime,
          detailText: TimeOfDay(
            hour: minutes ~/ 60,
            minute: minutes % 60,
          ).format(context),
          onTap: () => _perform(_pickTime),
        ),
        const IosRowDivider(),
        IosNavRow(
          icon: LucideIcons.repeat,
          label: l.scheduledTasksRepeat,
          detailText: scheduledRepeatLabel(repeat, l),
          onTap: _pickRepeat,
        ),
        if (repeat == ScheduledTaskRepeat.custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: ScheduledWeekdaySelector(
              days: days,
              onChanged: (value) => setState(() => days = value),
            ),
          ),
        if (repeat == ScheduledTaskRepeat.once) ...[
          const IosRowDivider(indent: 12),
          _dateRow(
            l.scheduledTasksDate,
            onceDate,
            (value) => onceDate = value,
            clearable: false,
          ),
        ],
      ],
    ),
    if (repeat != ScheduledTaskRepeat.once) ...[
      IosSectionHeader(text: l.scheduledTasksActiveWindow),
      SectionCard(
        children: [
          _dateRow(
            l.scheduledTasksStartDate,
            startDate,
            (value) => startDate = value,
          ),
          const IosRowDivider(indent: 12),
          _dateRow(
            l.scheduledTasksEndDate,
            endDate,
            (value) => endDate = value,
          ),
        ],
      ),
      IosSectionFooter(text: l.scheduledTasksActiveWindowDetail),
    ],
    const SizedBox(height: 24),
    SectionCard(
      children: [
        IosSwitchRow(
          label: l.scheduledTasksEnabled,
          value: enabled,
          onChanged: (value) => setState(() => enabled = value),
        ),
      ],
    ),
    IosSectionFooter(text: l.scheduledTasksExecutionDetail),
  ];

  Widget _mobileLayout(AppLocalizations l) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [..._taskFields(l), ..._scheduleFields(l, first: false)],
  );

  Widget _desktopLayout(AppLocalizations l) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _taskFields(l),
        ),
      ),
      const SizedBox(width: 24),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _scheduleFields(l, first: true),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ScheduledTasksScaffold(
      title: widget.task == null ? l.scheduledTasksAdd : l.scheduledTasksEdit,
      actionIcon: LucideIcons.check,
      actionLabel: busy ? l.scheduledTasksSaving : l.scheduledTasksSave,
      onAction: busy ? null : _save,
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveHelper.isDesktop(context) ? 1080 : 640,
              ),
              child: ResponsiveHelper.isDesktop(context)
                  ? _desktopLayout(l)
                  : _mobileLayout(l),
            ),
          ),
        ],
      ),
    );
  }
}

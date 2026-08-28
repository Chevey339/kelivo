part of 'assistant_settings_edit_page.dart';

class _MemorySettingsNavCard extends StatelessWidget {
  const _MemorySettingsNavCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: MemorySectionCard(
        padding: EdgeInsets.zero,
        children: [
          MemoryNavRow(
            title: l10n.settingsPageMemory,
            subtitle: l10n.memorySettingsGlobalSubtitle,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _MemoryTab extends StatefulWidget {
  const _MemoryTab({required this.assistantId});
  final String assistantId;

  @override
  State<_MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<_MemoryTab> {
  bool _organizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MemoryProviderV2>().initialize(
        assistantId: widget.assistantId,
      );
    });
  }

  Future<void> _showAddEditSheet({MemoryEntry? existing}) {
    final assistant = context.read<AssistantProvider>().getById(
      widget.assistantId,
    );
    final writeScope = assistant?.memoryWriteScope;
    final prefersAssistant =
        writeScope == MemoryWriteScope.alwaysAssistant ||
        writeScope == MemoryWriteScope.toolDefaultAssistant;
    return showMemoryEntryEditor(
      context,
      existing: existing,
      defaultAssistantId: widget.assistantId,
      defaultScope: existing == null && prefersAssistant
          ? MemoryScope.assistant
          : MemoryScope.global,
    );
  }

  Future<void> _runOrganize() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    if (settings.memoryModelProvider == null ||
        settings.memoryModelId == null) {
      showAppSnackBar(
        context,
        message: l10n.memoryOrganizeNeedsModel,
        type: NotificationType.warning,
      );
      return;
    }
    final chat = context.read<ChatService>();
    final convId = chat.currentConversationId;
    final conv = convId == null ? null : chat.getConversation(convId);
    if (conv == null || conv.assistantId != widget.assistantId) {
      showAppSnackBar(
        context,
        message: l10n.memoryOrganizeNeedsConversation,
        type: NotificationType.warning,
      );
      return;
    }
    setState(() => _organizing = true);
    try {
      final pipeline = context.read<MemoryPipelineService>();
      await pipeline.runNow(
        conversationId: conv.id,
        assistantId: widget.assistantId,
      );
      if (mounted) {
        await context.read<MemoryProviderV2>().refresh(
          assistantId: widget.assistantId,
        );
      }
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  String _statusLine(AppLocalizations l10n, MemoryOrganizeStatus status) {
    final lastAt = status.lastAt;
    final result = status.lastResult;
    if (lastAt == null || result == null) {
      return l10n.memoryOrganizeStatusNever;
    }
    final when = _formatRelative(l10n, lastAt);
    final parts = <String>[l10n.memoryOrganizeStatusLast(when)];
    if (result.error != null && result.error!.isNotEmpty) {
      final code = result.error!;
      final label = memoryOutcomeLabel(l10n, code);
      if (MemoryPipelineService.skipReasonCodes.contains(code)) {
        parts.add(l10n.memoryOrganizeStatusSkippedReason(label));
      } else {
        parts.add(l10n.memoryOrganizeStatusFailed(label));
      }
    } else if (result.gate == MemoryGateParseResult.skip ||
        (result.extractedCount == 0 && result.advanced)) {
      parts.add(l10n.memoryOrganizeStatusSkipped);
    } else {
      parts.add(l10n.memoryOrganizeStatusExtracted(result.extractedCount));
    }
    return parts.join(' · ');
  }

  String _formatRelative(AppLocalizations l10n, DateTime at) {
    final delta = DateTime.now().difference(at);
    if (delta.inMinutes < 1) return l10n.memoryOrganizeJustNow;
    if (delta.inHours < 1) {
      return l10n.memoryOrganizeMinutesAgo(delta.inMinutes);
    }
    if (delta.inDays < 1) {
      return l10n.memoryOrganizeHoursAgo(delta.inHours);
    }
    return l10n.memoryOrganizeDaysAgo(delta.inDays);
  }

  Future<void> _goMemorySettings() async {
    if (PlatformUtils.isDesktopTarget) {
      await showDesktopMemorySettingsDialog(context);
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemorySettingsPage()));
  }

  bool get _isDesktopPlatform {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.windows;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (settings.legacyMemoryMode) {
      return _LegacyMemoryTabBody(
        assistantId: widget.assistantId,
        footer: _MemorySettingsNavCard(onTap: _goMemorySettings),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    final mp = context.watch<MemoryProviderV2>();
    final pipeline = context.read<MemoryPipelineService>();
    final modelMissing =
        settings.memoryModelProvider == null || settings.memoryModelId == null;

    final visible = mp.visibleFor(widget.assistantId);
    final archived = mp.archivedFor(widget.assistantId);
    final chat = context.watch<ChatService>();
    final convId = chat.currentConversationId;
    final conv = convId == null ? null : chat.getConversation(convId);
    final canOrganize =
        !modelMissing &&
        conv != null &&
        conv.assistantId == widget.assistantId &&
        !_organizing;

    Widget sectionCard({
      required Widget child,
      EdgeInsets padding = const EdgeInsets.symmetric(vertical: 6),
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SectionCard(padding: padding, child: child),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
      children: [
        sectionCard(
          child: Column(
            children: [
              _iosSwitchRow(
                context,
                icon: Lucide.bookHeart,
                label: l10n.assistantEditMemorySwitchTitle,
                tip: l10n.assistantEditMemorySwitchSubtitle,
                value: a.enableMemory,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(enableMemory: v),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: a.enableMemory
                    ? Column(
                        children: [
                          _iosDivider(context),
                          _iosSwitchRow(
                            context,
                            icon: Lucide.Sparkles,
                            label: l10n.assistantEditAutoOrganizeTitle,
                            tip: l10n.assistantEditAutoOrganizeSubtitle,
                            value: a.autoOrganizeMemory,
                            onChanged: (v) async {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(
                                    a.copyWith(autoOrganizeMemory: v),
                                  );
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: a.autoOrganizeMemory
                                ? Column(
                                    children: [
                                      _iosDivider(context),
                                      if (modelMissing)
                                        MemoryModelMissingNotice(
                                          onGoSelect: _goMemorySettings,
                                        ),
                                      _MemoryOrganizeFrequencySection(
                                        assistant: a,
                                        desktop: _isDesktopPlatform,
                                      ),
                                      _iosDivider(context),
                                      _MemoryDedupeModeSection(
                                        assistant: a,
                                        desktop: _isDesktopPlatform,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                          _iosDivider(context),
                          _MemoryWriteScopeSection(
                            assistant: a,
                            desktop: _isDesktopPlatform,
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              _iosDivider(context),
              _iosSwitchRow(
                context,
                icon: Lucide.History,
                label: l10n.assistantEditAllowPastRecallTitle,
                tip: l10n.assistantEditAllowPastRecallSubtitle,
                value: a.allowPastConversationRecall,
                onChanged: (v) async {
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(
                      allowPastConversationRecall: v,
                      generateConversationSummary: v
                          ? a.generateConversationSummary
                          : false,
                    ),
                  );
                },
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: a.allowPastConversationRecall
                    ? Column(
                        children: [
                          _iosDivider(context),
                          _iosSwitchRow(
                            context,
                            icon: Lucide.FileText,
                            label: l10n.assistantEditGenerateSummaryTitle,
                            tip: l10n.assistantEditGenerateSummarySubtitle,
                            value: a.generateConversationSummary,
                            onChanged: (v) async {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(
                                    a.copyWith(generateConversationSummary: v),
                                  );
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            child: a.generateConversationSummary
                                ? Column(
                                    children: [
                                      _iosDivider(context),
                                      _RecentChatsSummaryFrequencySection(
                                        assistant: a,
                                        desktop: _isDesktopPlatform,
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        _MemorySettingsNavCard(onTap: _goMemorySettings),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.assistantEditManageMemoryTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
              ),
              Tooltip(
                message: modelMissing
                    ? l10n.memoryOrganizeNeedsModel
                    : (!canOrganize && !_organizing
                          ? l10n.memoryOrganizeNeedsConversation
                          : l10n.memoryOrganizeButton),
                child: _TactileRow(
                  onTap: canOrganize ? _runOrganize : null,
                  pressedScale: 0.97,
                  builder: (pressed) {
                    final enabled = canOrganize;
                    final color = !enabled
                        ? cs.onSurface.withValues(alpha: 0.35)
                        : (pressed
                              ? cs.primary.withValues(alpha: 0.7)
                              : cs.primary);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_organizing)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        else
                          Icon(Lucide.Sparkles, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          l10n.memoryOrganizeButton,
                          style: TextStyle(
                            color: color,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              _TactileRow(
                onTap: () => _showAddEditSheet(),
                pressedScale: 0.97,
                builder: (pressed) {
                  final color = pressed
                      ? cs.primary.withValues(alpha: 0.7)
                      : cs.primary;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 16, color: color),
                      const SizedBox(width: 4),
                      Text(
                        l10n.memoryEntryActionAdd,
                        style: TextStyle(
                          color: color,
                          fontWeight: AppFontWeights.semibold,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            _statusLine(l10n, pipeline.lastStatus),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),

        if (!a.enableMemory)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.memoryEntryEmptyDisabled,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          )
        else if (visible.isEmpty && archived.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              l10n.memoryEntryEmpty,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),

        ...visible.map(
          (m) => MemoryEntryCard(
            entry: m,
            useThisAssistantLabel: true,
            scopeToggleAssistantId: widget.assistantId,
            onEdit: () => _showAddEditSheet(existing: m),
          ),
        ),
        if (archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.memoryEntryArchivedSection,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
          ),
          ...archived.map(
            (m) => MemoryEntryCard(
              entry: m,
              useThisAssistantLabel: true,
              scopeToggleAssistantId: widget.assistantId,
              onEdit: () => _showAddEditSheet(existing: m),
            ),
          ),
        ],

        if (a.allowPastConversationRecall && a.generateConversationSummary) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              l10n.assistantEditManageSummariesTitle,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.emphasis,
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final chatService = context.watch<ChatService>();
              final summaries = chatService
                  .getConversationsWithSummaryForAssistant(widget.assistantId);
              if (summaries.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    l10n.assistantEditSummaryEmpty,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return Column(
                children: summaries.map((conv) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: SectionCard(
                      radius: 14,
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            conv.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.6),
                              fontWeight: AppFontWeights.medium,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  conv.summary ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              _TactileIconButton(
                                icon: Lucide.Pencil,
                                size: 18,
                                color: cs.primary,
                                onTap: () => _showEditSummarySheet(
                                  context,
                                  conv,
                                  chatService,
                                ),
                              ),
                              _TactileIconButton(
                                icon: Lucide.Trash2,
                                size: 18,
                                color: cs.error,
                                onTap: () => _confirmDeleteSummary(
                                  context,
                                  conv.id,
                                  chatService,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Future<void> _showEditSummarySheet(
    BuildContext context,
    Conversation conversation,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final text = await _showMemoryTextSheet(
      context,
      title: l10n.assistantEditSummaryDialogTitle,
      label: l10n.assistantEditSummaryDialogTitle,
      hintText: l10n.assistantEditSummaryDialogHint,
      initialValue: conversation.summary ?? '',
      allowEmpty: true,
    );
    if (text == null) return;
    if (text.isEmpty) {
      await chatService.clearConversationSummary(conversation.id);
    } else {
      await chatService.updateConversationSummary(
        conversation.id,
        text,
        conversation.lastSummarizedMessageCount,
      );
    }
  }

  Future<void> _confirmDeleteSummary(
    BuildContext context,
    String conversationId,
    ChatService chatService,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.assistantEditDeleteSummaryTitle),
        content: Text(l10n.assistantEditDeleteSummaryContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.assistantEditClearButton),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await chatService.clearConversationSummary(conversationId);
    }
  }
}

/// Text/number input: centered Dialog on desktop, bottom sheet on mobile.
/// Controller lives in a [State] so it survives the exit transition.
Future<String?> _showMemoryTextSheet(
  BuildContext context, {
  required String title,
  required String label,
  required String initialValue,
  String? hintText,
  String? description,
  int minLines = 3,
  int maxLines = 10,
  TextInputType? keyboardType,
  bool allowEmpty = false,
}) {
  if (PlatformUtils.isDesktopTarget) {
    return showDesktopMemoryTextInputDialog(
      context,
      title: title,
      label: label,
      initialValue: initialValue,
      hintText: hintText,
      description: description,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      allowEmpty: allowEmpty,
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MemoryTextInputForm(
      title: title,
      label: label,
      hintText: hintText,
      description: description,
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      allowEmpty: allowEmpty,
    ),
  );
}

class _MemoryTextInputForm extends StatefulWidget {
  const _MemoryTextInputForm({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.minLines,
    required this.maxLines,
    required this.allowEmpty,
    this.hintText,
    this.description,
    this.keyboardType,
  });

  final String title;
  final String label;
  final String initialValue;
  final String? hintText;
  final String? description;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool allowEmpty;

  @override
  State<_MemoryTextInputForm> createState() => _MemoryTextInputFormState();
}

class _MemoryTextInputFormState extends State<_MemoryTextInputForm> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    // Cap to available height above the keyboard so the Column cannot overflow.
    final maxHeight = (media.size.height - bottomInset) * 0.9;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [
                    MemorySectionCard(
                      children: [
                        IosFormTextField(
                          label: widget.label,
                          controller: _controller,
                          hintText: widget.hintText,
                          minLines: widget.minLines,
                          maxLines: widget.maxLines,
                          inlineLabel: false,
                          autofocus: true,
                          textAlign: TextAlign.start,
                          keyboardType: widget.keyboardType,
                        ),
                      ],
                    ),
                    if (widget.description != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          widget.description!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => MemorySheetActions(
                    confirmLabel: l10n.userProfileSave,
                    confirmEnabled:
                        widget.allowEmpty || value.text.trim().isNotEmpty,
                    onCancel: () => Navigator.of(context).maybePop(),
                    onConfirm: () =>
                        Navigator.of(context).pop(_controller.text.trim()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const int _kMemoryFrequencyCustomSentinel = -1;

bool _isDesktopMemorySettings(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux ||
      platform == TargetPlatform.windows;
}

Future<T?> _showMemoryChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T value, String label)> options,
  required T selected,
  (T value, String label)? trailingAction,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      Widget optionRow({
        required String label,
        required bool isSelected,
        required VoidCallback onTap,
        IconData? trailingIcon,
      }) {
        return _TactileRow(
          onTap: onTap,
          builder: (pressed) {
            final base = cs.onSurface;
            final color = pressed
                ? (Color.lerp(base, cs.surface, 0.55) ?? base)
                : base;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.medium,
                        color: color,
                      ),
                    ),
                  ),
                  if (trailingIcon != null)
                    Icon(trailingIcon, size: 18, color: color)
                  else if (isSelected)
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                ],
              ),
            );
          },
        );
      }

      final maxHeight = MediaQuery.sizeOf(ctx).height * 0.8;
      return SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFontWeights.semibold,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ),
                    ),
                    for (final option in options)
                      optionRow(
                        label: option.$2,
                        isSelected: option.$1 == selected,
                        onTap: () => Navigator.of(ctx).pop(option.$1),
                      ),
                    if (trailingAction != null)
                      optionRow(
                        label: trailingAction.$2,
                        isSelected: false,
                        trailingIcon: Lucide.Pencil,
                        onTap: () => Navigator.of(ctx).pop(trailingAction.$1),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _memoryDesktopSelectRow<T>({
  required BuildContext context,
  required IconData icon,
  required String label,
  required T value,
  required List<DesktopSelectOption<T>> options,
  required Future<void> Function(T value) onSelected,
  String? subtitle,
  String? tip,
}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Row(
      children: [
        SizedBox(
          width: 36,
          child: Icon(
            icon,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: subtitle == null
              ? Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        color: cs.onSurface.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
        ),
        if (tip != null) MemoryTipIcon(message: tip),
        const SizedBox(width: 8),
        DesktopSelectDropdown<T>(
          value: value,
          options: options,
          onSelected: onSelected,
          minWidth: 140,
          maxLabelWidth: 220,
        ),
      ],
    ),
  );
}

class _MemoryOrganizeFrequencySection extends StatelessWidget {
  const _MemoryOrganizeFrequencySection({
    required this.assistant,
    required this.desktop,
  });

  final Assistant assistant;
  final bool desktop;

  static const _options = [1, 3, 5, 10];

  Future<void> _showCustom(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.read<AssistantProvider>();
    final input = await _showMemoryTextSheet(
      context,
      title: l10n.assistantEditOrganizeFrequencyCustomTitle,
      label: l10n.assistantEditOrganizeFrequencyCustomLabel,
      hintText: l10n.assistantEditOrganizeFrequencyCustomHint,
      description: l10n.assistantEditOrganizeFrequencyCustomDescription,
      initialValue: assistant.memoryOrganizeEveryNTurns.toString(),
      minLines: 1,
      maxLines: 1,
      keyboardType: TextInputType.number,
    );
    final parsed = input == null ? null : int.tryParse(input);
    if (parsed == null) return;
    if (parsed < Assistant.minMemoryOrganizeEveryNTurns ||
        parsed > Assistant.maxMemoryOrganizeEveryNTurns) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: l10n.assistantEditOrganizeFrequencyCustomInvalid,
          type: NotificationType.error,
        );
      }
      return;
    }
    await ap.updateAssistant(
      assistant.copyWith(memoryOrganizeEveryNTurns: parsed),
    );
  }

  Future<void> _apply(BuildContext context, int count) async {
    if (count == _kMemoryFrequencyCustomSentinel) {
      await _showCustom(context);
      return;
    }
    await context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(memoryOrganizeEveryNTurns: count),
    );
  }

  Future<void> _openMobilePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.memoryOrganizeEveryNTurns;
    final counts = <int>{..._options, selected}.toList()..sort();
    final choice = await _showMemoryChoiceSheet<int>(
      context,
      title: l10n.assistantEditOrganizeFrequencyTitle,
      selected: selected,
      options: [
        for (final count in counts)
          (count, l10n.assistantEditOrganizeFrequencyOption(count)),
      ],
      trailingAction: (
        _kMemoryFrequencyCustomSentinel,
        l10n.assistantEditOrganizeFrequencyCustomButton,
      ),
    );
    if (choice == null || !context.mounted) return;
    await _apply(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.memoryOrganizeEveryNTurns;
    final detail = l10n.assistantEditOrganizeFrequencyOption(selected);

    if (desktop || _isDesktopMemorySettings(context)) {
      final counts = <int>{..._options, selected}.toList()..sort();
      return _memoryDesktopSelectRow<int>(
        context: context,
        icon: Lucide.FileClock,
        label: l10n.assistantEditOrganizeFrequencyTitle,
        tip: l10n.assistantEditOrganizeFrequencySubtitle,
        value: selected,
        options: [
          for (final count in counts)
            DesktopSelectOption(
              value: count,
              label: l10n.assistantEditOrganizeFrequencyOption(count),
            ),
          DesktopSelectOption(
            value: _kMemoryFrequencyCustomSentinel,
            label: l10n.assistantEditOrganizeFrequencyCustomButton,
          ),
        ],
        onSelected: (count) => _apply(context, count),
      );
    }

    return _iosNavRow(
      context,
      icon: Lucide.FileClock,
      label: l10n.assistantEditOrganizeFrequencyTitle,
      tip: l10n.assistantEditOrganizeFrequencySubtitle,
      detailText: detail,
      onTap: () => _openMobilePicker(context),
    );
  }
}

class _MemoryDedupeModeSection extends StatelessWidget {
  const _MemoryDedupeModeSection({
    required this.assistant,
    required this.desktop,
  });

  final Assistant assistant;
  final bool desktop;

  String _label(AppLocalizations l10n, MemorySmartAddMode mode) {
    return switch (mode) {
      MemorySmartAddMode.batched => l10n.assistantEditDedupeModeBatched,
      MemorySmartAddMode.perItem => l10n.assistantEditDedupeModePerItem,
    };
  }

  String _subtitle(AppLocalizations l10n, MemorySmartAddMode mode) {
    return switch (mode) {
      MemorySmartAddMode.batched => l10n.assistantEditDedupeModeBatchedSubtitle,
      MemorySmartAddMode.perItem => l10n.assistantEditDedupeModePerItemSubtitle,
    };
  }

  List<MemoryPickerOption<MemorySmartAddMode>> _options(
    AppLocalizations l10n,
  ) => [
    for (final mode in MemorySmartAddMode.values)
      MemoryPickerOption(
        value: mode,
        label: _label(l10n, mode),
        subtitle: _subtitle(l10n, mode),
      ),
  ];

  Future<void> _apply(BuildContext context, MemorySmartAddMode mode) async {
    await context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(memorySmartAddMode: mode),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showMemoryOptionPicker<MemorySmartAddMode>(
      context,
      title: l10n.assistantEditDedupeModeTitle,
      selected: assistant.memorySmartAddMode,
      options: _options(l10n),
    );
    if (choice == null || !context.mounted) return;
    await _apply(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.memorySmartAddMode;

    if (desktop || _isDesktopMemorySettings(context)) {
      return _memoryDesktopSelectRow<MemorySmartAddMode>(
        context: context,
        icon: Lucide.Layers,
        label: l10n.assistantEditDedupeModeTitle,
        tip: l10n.assistantEditDedupeModeSubtitle,
        value: selected,
        options: [
          for (final mode in MemorySmartAddMode.values)
            DesktopSelectOption(
              value: mode,
              label: _label(l10n, mode),
              subtitle: _subtitle(l10n, mode),
            ),
        ],
        onSelected: (mode) => _apply(context, mode),
      );
    }

    return _iosNavRow(
      context,
      icon: Lucide.Layers,
      label: l10n.assistantEditDedupeModeTitle,
      tip: l10n.assistantEditDedupeModeSubtitle,
      detailText: _label(l10n, selected),
      onTap: () => _openPicker(context),
    );
  }
}

class _MemoryWriteScopeSection extends StatelessWidget {
  const _MemoryWriteScopeSection({
    required this.assistant,
    required this.desktop,
  });

  final Assistant assistant;
  final bool desktop;

  List<MemoryPickerOption<MemoryWriteScope>> _options(AppLocalizations l10n) =>
      [
        MemoryPickerOption(
          value: MemoryWriteScope.alwaysGlobal,
          label: l10n.assistantEditWriteScopeAlwaysGlobal,
          subtitle: l10n.assistantEditWriteScopeAlwaysGlobalSubtitle,
        ),
        MemoryPickerOption(
          value: MemoryWriteScope.alwaysAssistant,
          label: l10n.assistantEditWriteScopeAlwaysAssistant,
          subtitle: l10n.assistantEditWriteScopeAlwaysAssistantSubtitle,
        ),
        MemoryPickerOption(
          value: MemoryWriteScope.toolDefaultGlobal,
          label: l10n.assistantEditWriteScopeToolDefaultGlobal,
          subtitle: l10n.assistantEditWriteScopeToolDefaultGlobalSubtitle,
        ),
        MemoryPickerOption(
          value: MemoryWriteScope.toolDefaultAssistant,
          label: l10n.assistantEditWriteScopeToolDefaultAssistant,
          subtitle: l10n.assistantEditWriteScopeToolDefaultAssistantSubtitle,
        ),
      ];

  String _label(AppLocalizations l10n, MemoryWriteScope scope) {
    for (final item in _options(l10n)) {
      if (item.value == scope) return item.label;
    }
    return _options(l10n).first.label;
  }

  Future<void> _apply(BuildContext context, MemoryWriteScope scope) async {
    await context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(memoryWriteScope: scope),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showMemoryOptionPicker<MemoryWriteScope>(
      context,
      title: l10n.assistantEditWriteScopeTitle,
      selected: assistant.memoryWriteScope,
      options: _options(l10n),
    );
    if (choice == null || !context.mounted) return;
    await _apply(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.memoryWriteScope;

    if (desktop || _isDesktopMemorySettings(context)) {
      return _memoryDesktopSelectRow<MemoryWriteScope>(
        context: context,
        icon: Lucide.Globe,
        label: l10n.assistantEditWriteScopeTitle,
        tip: l10n.assistantEditWriteScopeSubtitle,
        value: selected,
        options: [
          for (final item in _options(l10n))
            DesktopSelectOption(
              value: item.value,
              label: item.label,
              subtitle: item.subtitle,
            ),
        ],
        onSelected: (scope) => _apply(context, scope),
      );
    }

    return _iosNavRow(
      context,
      icon: Lucide.Globe,
      label: l10n.assistantEditWriteScopeTitle,
      tip: l10n.assistantEditWriteScopeSubtitle,
      detailText: _label(l10n, selected),
      onTap: () => _openPicker(context),
    );
  }
}

class _RecentChatsSummaryFrequencySection extends StatelessWidget {
  const _RecentChatsSummaryFrequencySection({
    required this.assistant,
    required this.desktop,
  });

  final Assistant assistant;
  final bool desktop;

  Future<void> _showCustomCountInput(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.read<AssistantProvider>();
    final input = await _showMemoryTextSheet(
      context,
      title: l10n.assistantEditRecentChatsSummaryFrequencyCustomTitle,
      label: l10n.assistantEditRecentChatsSummaryFrequencyCustomLabel,
      hintText: l10n.assistantEditRecentChatsSummaryFrequencyCustomHint,
      initialValue: assistant.recentChatsSummaryMessageCount.toString(),
      minLines: 1,
      maxLines: 1,
      keyboardType: TextInputType.number,
    );
    final parsed = input == null ? null : int.tryParse(input);
    if (parsed == null || parsed < 1) return;
    await ap.updateAssistant(
      assistant.copyWith(recentChatsSummaryMessageCount: parsed),
    );
  }

  Future<void> _apply(BuildContext context, int count) async {
    if (count == _kMemoryFrequencyCustomSentinel) {
      await _showCustomCountInput(context);
      return;
    }
    await context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(recentChatsSummaryMessageCount: count),
    );
  }

  Future<void> _openMobilePicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.recentChatsSummaryMessageCount;
    final counts = <int>{
      ...Assistant.recentChatsSummaryMessageCountOptions,
      selected,
    }.toList()..sort();
    final choice = await _showMemoryChoiceSheet<int>(
      context,
      title: l10n.assistantEditRecentChatsSummaryFrequencyTitle,
      selected: selected,
      options: [
        for (final count in counts)
          (count, l10n.assistantEditRecentChatsSummaryFrequencyOption(count)),
      ],
      trailingAction: (
        _kMemoryFrequencyCustomSentinel,
        l10n.assistantEditRecentChatsSummaryFrequencyCustomButton,
      ),
    );
    if (choice == null || !context.mounted) return;
    await _apply(context, choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = assistant.recentChatsSummaryMessageCount;
    final detail = l10n.assistantEditRecentChatsSummaryFrequencyOption(
      selected,
    );

    if (desktop || _isDesktopMemorySettings(context)) {
      final counts = <int>{
        ...Assistant.recentChatsSummaryMessageCountOptions,
        selected,
      }.toList()..sort();
      return _memoryDesktopSelectRow<int>(
        context: context,
        icon: Lucide.FileClock,
        label: l10n.assistantEditRecentChatsSummaryFrequencyTitle,
        value: selected,
        options: [
          for (final count in counts)
            DesktopSelectOption(
              value: count,
              label: l10n.assistantEditRecentChatsSummaryFrequencyOption(count),
            ),
          DesktopSelectOption(
            value: _kMemoryFrequencyCustomSentinel,
            label: l10n.assistantEditRecentChatsSummaryFrequencyCustomButton,
          ),
        ],
        onSelected: (count) => _apply(context, count),
      );
    }

    return _iosNavRow(
      context,
      icon: Lucide.FileClock,
      label: l10n.assistantEditRecentChatsSummaryFrequencyTitle,
      detailText: detail,
      onTap: () => _openMobilePicker(context),
    );
  }
}

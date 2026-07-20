part of 'assistant_settings_edit_page.dart';

class _ProactiveLetterTab extends StatefulWidget {
  const _ProactiveLetterTab({required this.assistantId});

  final String assistantId;

  @override
  State<_ProactiveLetterTab> createState() => _ProactiveLetterTabState();
}

class _ProactiveLetterTabState extends State<_ProactiveLetterTab> {
  late final TextEditingController _carePromptCtrl;
  late final TextEditingController _decisionPromptCtrl;
  String? _boundAssistantId;

  @override
  void initState() {
    super.initState();
    _carePromptCtrl = TextEditingController();
    _decisionPromptCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant _ProactiveLetterTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      _boundAssistantId = null;
      _syncControllers(force: true);
    }
  }

  void _syncControllers({bool force = false}) {
    final a = context.read<AssistantProvider>().getById(widget.assistantId);
    if (a == null) return;
    if (!force && _boundAssistantId == a.id) return;
    _boundAssistantId = a.id;

    final l10n = AppLocalizations.of(context)!;
    final defaultDecision =
        l10n.assistantEditProactiveCareDecisionPromptDefault;

    final careText = a.proactiveCarePrompt.isEmpty
        ? l10n.assistantEditProactiveCarePromptDefault
        : a.proactiveCarePrompt;
    if (_carePromptCtrl.text != careText) {
      _carePromptCtrl.text = careText;
    }
    final decisionText = a.proactiveCareDecisionPrompt.isEmpty
        ? defaultDecision
        : a.proactiveCareDecisionPrompt;
    if (_decisionPromptCtrl.text != decisionText) {
      _decisionPromptCtrl.text = decisionText;
    }
  }

  @override
  void dispose() {
    _carePromptCtrl.dispose();
    _decisionPromptCtrl.dispose();
    super.dispose();
  }

  InputDecoration _promptDecoration(BuildContext context, {String? hint}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    );
  }

  Future<void> _pickNextMessageTime(Assistant a) async {
    final picked = await showProactiveCareDateTimePicker(
      context,
      initial: a.proactiveCareNextMessageAt,
    );
    if (!mounted || picked == null) return;
    await context.read<AssistantProvider>().updateAssistant(
      a.copyWith(proactiveCareNextMessageAt: picked),
    );
  }

  Future<void> _onProactiveCareChanged(Assistant a, bool enabled) async {
    if (enabled) {
      // Auto-request the exact alarm + notification permissions needed to
      // wake the app and notify the user at the scheduled care time.
      final perms = await ProactiveCareAlarmService.ensurePermissions();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (!perms.exactAlarm) {
        showAppSnackBar(
          context,
          message: l10n.assistantEditProactiveCareExactAlarmPermissionDenied,
          type: NotificationType.warning,
        );
      } else if (!perms.notifications) {
        showAppSnackBar(
          context,
          message: l10n.assistantEditProactiveCareNotificationPermissionDenied,
          type: NotificationType.warning,
        );
      }
    }
    if (enabled && a.proactiveCareNextMessageAt == null) {
      await context.read<AssistantProvider>().updateAssistant(
        a.copyWith(
          enableProactiveCare: true,
          proactiveCareNextMessageAt: DateTime.now().add(
            const Duration(hours: 24),
          ),
        ),
      );
      return;
    }
    await context.read<AssistantProvider>().updateAssistant(
      a.copyWith(enableProactiveCare: enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final a = context.watch<AssistantProvider>().getById(widget.assistantId);
    if (a == null) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _iosSectionCard(
          children: [
            _iosSwitchRow(
              context,
              icon: Lucide.HeartPulse,
              label: l10n.assistantEditProactiveCareEnableTitle,
              value: a.enableProactiveCare,
              onChanged: (v) => _onProactiveCareChanged(a, v),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: a.enableProactiveCare
                  ? Column(
                      children: [
                        _iosDivider(context),
                        _iosNavRow(
                          context,
                          icon: Lucide.clock,
                          label: l10n
                              .assistantEditProactiveCareNextMessageTimeTitle,
                          detailText: proactiveCareNextMessageLabel(
                            context,
                            a.proactiveCareNextMessageAt,
                          ),
                          onTap: () => _pickNextMessageTime(a),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        if (a.enableProactiveCare) ...[
          const SizedBox(height: 16),
          Text(
            l10n.assistantEditProactiveCarePromptTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.emphasis,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _carePromptCtrl,
            onChanged: (v) => context.read<AssistantProvider>().updateAssistant(
              a.copyWith(proactiveCarePrompt: v),
            ),
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: _promptDecoration(
              context,
              hint: l10n.assistantEditProactiveCarePromptHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.assistantEditProactiveCareDecisionPromptTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.emphasis,
              color: cs.onSurface.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _decisionPromptCtrl,
            onChanged: (v) => context.read<AssistantProvider>().updateAssistant(
              a.copyWith(proactiveCareDecisionPrompt: v),
            ),
            maxLines: null,
            minLines: 8,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            decoration: _promptDecoration(context),
          ),
        ],
      ],
    );
  }
}

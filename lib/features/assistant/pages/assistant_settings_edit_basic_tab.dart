part of 'assistant_settings_edit_page.dart';

class _BasicSettingsTab extends StatefulWidget {
  const _BasicSettingsTab({required this.assistantId});
  final String assistantId;

  @override
  State<_BasicSettingsTab> createState() => _BasicSettingsTabState();
}

class _BasicSettingsTabState extends State<_BasicSettingsTab> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _thinkingCtrl;
  late final TextEditingController _maxTokensCtrl;
  late final TextEditingController _backgroundCtrl;

  @override
  void initState() {
    super.initState();
    final ap = context.read<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;
    _nameCtrl = TextEditingController(text: a.name);
    _thinkingCtrl = TextEditingController(
      text: a.thinkingBudget?.toString() ?? '',
    );
    _maxTokensCtrl = TextEditingController(text: a.maxTokens?.toString() ?? '');
    _backgroundCtrl = TextEditingController(text: a.background ?? '');
  }

  @override
  void didUpdateWidget(covariant _BasicSettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assistantId != widget.assistantId) {
      final ap = context.read<AssistantProvider>();
      final a = ap.getById(widget.assistantId)!;
      _nameCtrl.text = a.name;
      _thinkingCtrl.text = a.thinkingBudget?.toString() ?? '';
      _maxTokensCtrl.text = a.maxTokens?.toString() ?? '';
      _backgroundCtrl.text = a.background ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _thinkingCtrl.dispose();
    _maxTokensCtrl.dispose();
    _backgroundCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ap = context.watch<AssistantProvider>();
    final a = ap.getById(widget.assistantId)!;

    Widget titleDesc(String title, String? desc) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (desc != null) ...[
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ],
    );

    Widget avatarWidget({double size = 56}) {
      final bg = cs.primary.withOpacity(isDark ? 0.18 : 0.12);
      Widget inner;
      final av = a.avatar?.trim();
      if (av != null && av.isNotEmpty) {
        if (av.startsWith('http')) {
          inner = FutureBuilder<String?>(
            future: AvatarCache.getPath(av),
            builder: (ctx, snap) {
              final p = snap.data;
              if (p != null && File(p).existsSync()) {
                return ClipOval(
                  child: Image.file(
                    File(p),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
                );
              }
              return ClipOval(
                child: Image.network(
                  av,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                ),
              );
            },
          );
        } else if (av.startsWith('/') || av.contains(':')) {
          final fixed = SandboxPathResolver.fix(av);
          inner = ClipOval(
            child: Image.file(
              File(fixed),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        } else {
          inner = Text(
            av,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42,
            ),
          );
        }
      } else {
        inner = Text(
          (a.name.trim().isNotEmpty
              ? String.fromCharCode(a.name.trim().runes.first).toUpperCase()
              : 'A'),
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.42,
          ),
        );
      }
      return InkWell(
        customBorder: const CircleBorder(),
        onTap: () => _showAvatarPicker(context, a),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: bg,
          child: inner,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Identity card (avatar + name) - iOS style
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                avatarWidget(size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: _InputRow(
                    label: l10n.assistantEditAssistantNameLabel,
                    controller: _nameCtrl,
                    onChanged: (v) => context
                        .read<AssistantProvider>()
                        .updateAssistant(a.copyWith(name: v)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // iOS section card with all settings (without Use Assistant Avatar and Stream Output)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: _iosSectionCard(
            children: [
              // Temperature
              _iosNavRow(
                context,
                icon: Lucide.Thermometer,
                label: 'Temperature',
                detailText: a.temperature != null
                    ? a.temperature!.toStringAsFixed(2)
                    : l10n.assistantEditParameterDisabled,
                onTap: () => _showTemperatureSheet(context, a),
              ),
              _iosDivider(context),
              // Top P
              _iosNavRow(
                context,
                icon: Lucide.Wand2,
                label: 'Top P',
                detailText: a.topP != null
                    ? a.topP!.toStringAsFixed(2)
                    : l10n.assistantEditParameterDisabled,
                onTap: () => _showTopPSheet(context, a),
              ),
              _iosDivider(context),
              // Context messages
              _iosNavRow(
                context,
                icon: Lucide.MessagesSquare,
                label: l10n.assistantEditContextMessagesTitle,
                detailText: a.limitContextMessages
                    ? a.contextMessageSize.toString()
                    : l10n.assistantEditParameterDisabled2,
                onTap: () => _showContextMessagesSheet(context, a),
              ),
              _iosDivider(context),
              // Thinking budget
              _iosNavRow(
                context,
                icon: Lucide.Brain,
                label: l10n.assistantEditThinkingBudgetTitle,
                detailText: a.thinkingBudget?.toString() ?? '-',
                onTap: () async {
                  final currentBudget = a.thinkingBudget;
                  if (currentBudget != null) {
                    context.read<SettingsProvider>().setThinkingBudget(
                      currentBudget,
                    );
                  }
                  await showReasoningBudgetSheet(context);
                  final chosen = context
                      .read<SettingsProvider>()
                      .thinkingBudget;
                  await context.read<AssistantProvider>().updateAssistant(
                    a.copyWith(thinkingBudget: chosen),
                  );
                },
              ),
              _iosDivider(context),
              // Max tokens
              _iosNavRow(
                context,
                icon: Lucide.Hash,
                label: l10n.assistantEditMaxTokensTitle,
                detailText:
                    a.maxTokens?.toString() ?? l10n.assistantEditMaxTokensHint,
                onTap: () => _showMaxTokensSheet(context, a),
              ),
              _iosDivider(context),
              // Use assistant avatar
              _iosSwitchRow(
                context,
                icon: Lucide.User,
                label: l10n.assistantEditUseAssistantAvatarTitle,
                value: a.useAssistantAvatar,
                onChanged: (v) => context
                    .read<AssistantProvider>()
                    .updateAssistant(a.copyWith(useAssistantAvatar: v)),
              ),
              _iosDivider(context),
              // Stream output
              _iosSwitchRow(
                context,
                icon: Lucide.Zap,
                label: l10n.assistantEditStreamOutputTitle,
                value: a.streamOutput,
                onChanged: (v) => context
                    .read<AssistantProvider>()
                    .updateAssistant(a.copyWith(streamOutput: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Chat model card (moved down, styled like DefaultModelPage)
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.MessageCircle, size: 18, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditChatModelTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (a.chatModelProvider != null && a.chatModelId != null)
                      Tooltip(
                        message: l10n.defaultModelPageResetDefault,
                        child: _TactileIconButton(
                          icon: Lucide.RotateCcw,
                          color: cs.onSurface,
                          size: 20,
                          onTap: () async {
                            await context
                                .read<AssistantProvider>()
                                .updateAssistant(
                                  a.copyWith(clearChatModel: true),
                                );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.assistantEditChatModelSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                _TactileRow(
                  onTap: () async {
                    final sel = await showModelSelector(context);
                    if (sel != null) {
                      await context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(
                          chatModelProvider: sel.providerKey,
                          chatModelId: sel.modelId,
                        ),
                      );
                    }
                  },
                  pressedScale: 0.98,
                  builder: (pressed) {
                    final bg = isDark
                        ? Colors.white10
                        : const Color(0xFFF2F3F5);
                    final overlay = isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.05);
                    final pressedBg = Color.alphaBlend(overlay, bg);
                    final l10n = AppLocalizations.of(context)!;
                    final settings = context.read<SettingsProvider>();
                    String display = l10n.assistantEditModelUseGlobalDefault;
                    String brandName = display;
                    if (a.chatModelProvider != null && a.chatModelId != null) {
                      try {
                        final cfg = settings.getProviderConfig(
                          a.chatModelProvider!,
                        );
                        final ov = cfg.modelOverrides[a.chatModelId] as Map?;
                        brandName = cfg.name.isNotEmpty
                            ? cfg.name
                            : a.chatModelProvider!;
                        final mdl =
                            (ov != null &&
                                (ov['name'] as String?)?.isNotEmpty == true)
                            ? (ov['name'] as String)
                            : a.chatModelId!;
                        display = mdl;
                      } catch (_) {
                        brandName = a.chatModelProvider ?? '';
                        display = a.chatModelId ?? '';
                      }
                    }
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pressed ? pressedBg : bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _BrandAvatarLike(name: display, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              display,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Chat background (separate iOS card)
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06),
              width: 0.6,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Lucide.Image, size: 18, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.assistantEditChatBackgroundTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.assistantEditChatBackgroundDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                if ((a.background ?? '').isEmpty) ...[
                  // Single button when no background (full width)
                  _TactileRow(
                    onTap: () => _pickBackground(context, a),
                    pressedScale: 0.98,
                    builder: (pressed) {
                      final bg = isDark
                          ? Colors.white10
                          : const Color(0xFFF2F3F5);
                      final overlay = isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.05);
                      final pressedBg = Color.alphaBlend(overlay, bg);
                      final iconColor = cs.onSurface.withOpacity(0.75);
                      final textColor = cs.onSurface.withOpacity(0.9);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: pressed ? pressedBg : bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cs.outlineVariant.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 2.0,
                              ), // Material icon spacing
                              child: Icon(
                                Icons.image,
                                size: 18,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.assistantEditChooseImageButton,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ] else ...[
                  // Two buttons when background exists
                  Row(
                    children: [
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditChooseImageButton,
                          icon: Icons.image,
                          onTap: () => _pickBackground(context, a),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _IosButton(
                          label: l10n.assistantEditClearButton,
                          icon: Lucide.X,
                          onTap: () =>
                              context.read<AssistantProvider>().updateAssistant(
                                a.copyWith(clearBackground: true),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((a.background ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _BackgroundPreview(path: a.background!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showAvatarPicker(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final maxH = MediaQuery.of(ctx).size.height * 0.8;
        Widget row(String text, Future<void> Function() action) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              height: 48,
              child: IosCardPress(
                borderRadius: BorderRadius.circular(14),
                baseColor: cs.surface,
                duration: const Duration(milliseconds: 260),
                onTap: () async {
                  Haptics.light();
                  Navigator.of(ctx).pop();
                  await Future<void>.delayed(const Duration(milliseconds: 10));
                  await action();
                },
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    row(
                      l10n.assistantEditAvatarChooseImage,
                      () async => _pickLocalImage(context, a),
                    ),
                    row(l10n.assistantEditAvatarChooseEmoji, () async {
                      final emoji = await _pickEmoji(context);
                      if (emoji != null) {
                        await context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(avatar: emoji),
                        );
                      }
                    }),
                    row(
                      l10n.assistantEditAvatarEnterLink,
                      () async => _inputAvatarUrl(context, a),
                    ),
                    row(
                      l10n.assistantEditAvatarImportQQ,
                      () async => _inputQQAvatar(context, a),
                    ),
                    row(l10n.assistantEditAvatarReset, () async {
                      await context.read<AssistantProvider>().updateAssistant(
                        a.copyWith(clearAvatar: true),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBackground(BuildContext context, Assistant a) async {
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(background: file.path),
        );
      }
    } catch (_) {}
  }

  Future<void> _showTemperatureSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final cs = theme.colorScheme;
                final isDark = theme.brightness == Brightness.dark;
                final value =
                    context
                        .watch<AssistantProvider>()
                        .getById(widget.assistantId)
                        ?.temperature ??
                    0.6;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Temperature',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IosSwitch(
                          value: a.temperature != null,
                          onChanged: (v) async {
                            if (v) {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(
                                    a.copyWith(temperature: 0.6),
                                  );
                            } else {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(
                                    a.copyWith(clearTemperature: true),
                                  );
                            }
                            // Close the bottom sheet after toggle
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (a.temperature != null) ...[
                      _SliderTileNew(
                        value: value.clamp(0.0, 2.0),
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        label: value.toStringAsFixed(2),
                        onChanged: (v) => context
                            .read<AssistantProvider>()
                            .updateAssistant(a.copyWith(temperature: v)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.assistantEditTemperatureDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.assistantEditParameterDisabled,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTopPSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final cs = theme.colorScheme;
                final isDark = theme.brightness == Brightness.dark;
                final value =
                    context
                        .watch<AssistantProvider>()
                        .getById(widget.assistantId)
                        ?.topP ??
                    1.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Top P',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IosSwitch(
                          value: a.topP != null,
                          onChanged: (v) async {
                            if (v) {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(a.copyWith(topP: 1.0));
                            } else {
                              await context
                                  .read<AssistantProvider>()
                                  .updateAssistant(a.copyWith(clearTopP: true));
                            }
                            // Close the bottom sheet after toggle
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (a.topP != null) ...[
                      _SliderTileNew(
                        value: value.clamp(0.0, 1.0),
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: value.toStringAsFixed(2),
                        onChanged: (v) => context
                            .read<AssistantProvider>()
                            .updateAssistant(a.copyWith(topP: v)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.assistantEditTopPDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.assistantEditParameterDisabled,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showContextMessagesSheet(
    BuildContext context,
    Assistant a,
  ) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: false,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Builder(
              builder: (context) {
                final cs = Theme.of(context).colorScheme;
                final value = _clampContextMessages(
                  context
                          .watch<AssistantProvider>()
                          .getById(widget.assistantId)
                          ?.contextMessageSize ??
                      20,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurface.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.assistantEditContextMessagesTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IosSwitch(
                          value: a.limitContextMessages,
                          onChanged: (v) async {
                            final next =
                                v && a.contextMessageSize < _contextMessageMin
                                ? a.copyWith(
                                    limitContextMessages: v,
                                    contextMessageSize: _contextMessageMin,
                                  )
                                : a.copyWith(limitContextMessages: v);
                            await context
                                .read<AssistantProvider>()
                                .updateAssistant(next);
                            // Close the bottom sheet after toggle
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (a.limitContextMessages) ...[
                      _SliderTileNew(
                        value: value.toDouble(),
                        min: _contextMessageMin.toDouble(),
                        max: _contextMessageMax.toDouble(),
                        divisions: _contextMessageMax - _contextMessageMin,
                        label: value.toString(),
                        customLabelStops: const <double>[
                          1.0,
                          32.0,
                          64.0,
                          128.0,
                          256.0,
                        ],
                        onLabelTap: () async {
                          final chosen = await _showContextMessageInputDialog(
                            context,
                            initialValue: value,
                          );
                          if (chosen != null) {
                            await context
                                .read<AssistantProvider>()
                                .updateAssistant(
                                  a.copyWith(contextMessageSize: chosen),
                                );
                          }
                        },
                        onChanged: (v) =>
                            context.read<AssistantProvider>().updateAssistant(
                              a.copyWith(
                                contextMessageSize: _clampContextMessages(v),
                              ),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.assistantEditContextMessagesDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.assistantEditParameterDisabled2,
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMaxTokensSheet(BuildContext context, Assistant a) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(
      text: a.maxTokens?.toString() ?? '',
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Header with Close (X) and Save buttons
                Row(
                  children: [
                    _TactileIconButton(
                      icon: Lucide.X,
                      color: cs.onSurface,
                      size: 20,
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          l10n.assistantEditMaxTokensTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    _TactileRow(
                      onTap: () {
                        final val = int.tryParse(controller.text.trim());
                        context.read<AssistantProvider>().updateAssistant(
                          a.copyWith(
                            maxTokens: val,
                            clearMaxTokens: controller.text.trim().isEmpty,
                          ),
                        );
                        Navigator.of(ctx).pop();
                      },
                      pressedScale: 0.95,
                      builder: (pressed) {
                        final color = pressed
                            ? cs.primary.withOpacity(0.7)
                            : cs.primary;
                        return Text(
                          l10n.assistantSettingsAddSheetSave, // "Save"
                          style: TextStyle(
                            color: color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.assistantEditMaxTokensHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark
                        ? Colors.white10
                        : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withOpacity(0.4),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: cs.primary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.assistantEditMaxTokensDescription,
                  style: TextStyle(
                    color: cs.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackgroundPreview extends StatefulWidget {
  const _BackgroundPreview({required this.path});
  final String path;

  @override
  State<_BackgroundPreview> createState() => _BackgroundPreviewState();
}

class _BackgroundPreviewState extends State<_BackgroundPreview> {
  Size? _size;

  @override
  void initState() {
    super.initState();
    _resolveSize();
  }

  @override
  void didUpdateWidget(covariant _BackgroundPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _size = null;
      _resolveSize();
    }
  }

  Future<void> _resolveSize() async {
    try {
      if (widget.path.startsWith('http')) {
        // Skip network size probe; render with a sensible max height
        setState(() => _size = null);
        return;
      }
      final file = File(SandboxPathResolver.fix(widget.path));
      if (!await file.exists()) {
        setState(() => _size = null);
        return;
      }
      final bytes = await file.readAsBytes();
      final img = await decodeImageFromList(bytes);
      final s = Size(img.width.toDouble(), img.height.toDouble());
      if (mounted) setState(() => _size = s);
    } catch (_) {
      if (mounted) setState(() => _size = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNetwork = widget.path.startsWith('http');
    final imageWidget = isNetwork
        ? Image.network(widget.path, fit: BoxFit.contain)
        : (() {
            final fixed = SandboxPathResolver.fix(widget.path);
            final f = File(fixed);
            if (!f.existsSync()) {
              // Gracefully fallback to empty box when local file missing (e.g., imported from mobile)
              return const SizedBox.shrink();
            }
            return Image.file(f, fit: BoxFit.contain);
          })();
    // When size known, maintain aspect ratio; otherwise cap the height to avoid overflow
    if (_size != null && _size!.width > 0 && _size!.height > 0) {
      final ratio = _size!.width / _size!.height;
      return SizedBox(
        width: double.infinity,
        child: AspectRatio(aspectRatio: ratio, child: imageWidget),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 280,
        minHeight: 100,
        minWidth: double.infinity,
      ),
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        child: SizedBox(width: 400, height: 240, child: imageWidget),
      ),
    );
  }
}

class _SliderTileNew extends StatelessWidget {
  const _SliderTileNew({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.label,
    required this.onChanged,
    this.customLabelStops,
    this.onLabelTap,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final List<double>? customLabelStops;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final useCustomLabels =
        customLabelStops != null && customLabelStops!.isNotEmpty;
    final stops = useCustomLabels
        ? (customLabelStops!.where((v) => v >= min && v <= max).toSet().toList()
            ..sort())
        : const <double>[];

    final active = cs.primary;
    final inactive = cs.onSurface.withOpacity(isDark ? 0.25 : 0.20);
    final double clamped = value.clamp(min, max);
    final double? step = (divisions != null && divisions! > 0)
        ? (max - min) / divisions!
        : null;
    // Compute a readable major interval and minor tick count
    final total = (max - min).abs();
    double interval;
    if (total <= 0) {
      interval = 1;
    } else if ((divisions ?? 0) <= 20) {
      interval = total / 4; // up to 5 major ticks inc endpoints
    } else if ((divisions ?? 0) <= 50) {
      interval = total / 5;
    } else {
      interval = total / 8;
    }
    if (interval <= 0) interval = 1;
    int minor = 0;
    if (step != null && step > 0) {
      // Ensure minor ticks align with the chosen step size
      minor = ((interval / step) - 1).round();
      if (minor < 0) minor = 0;
      if (minor > 8) minor = 8;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SfSliderTheme(
                    data: SfSliderThemeData(
                      activeTrackHeight: 8,
                      inactiveTrackHeight: 8,
                      overlayRadius: 14,
                      activeTrackColor: active,
                      inactiveTrackColor: inactive,
                      // Waterdrop tooltip uses theme primary background with onPrimary text
                      tooltipBackgroundColor: cs.primary,
                      tooltipTextStyle: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      thumbStrokeColor: Colors.transparent,
                      thumbStrokeWidth: 0,
                      activeTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.45 : 0.35,
                      ),
                      inactiveTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.30 : 0.25,
                      ),
                      activeMinorTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.34 : 0.28,
                      ),
                      inactiveMinorTickColor: cs.onSurface.withOpacity(
                        isDark ? 0.24 : 0.20,
                      ),
                    ),
                    child: SfSlider(
                      value: clamped,
                      min: min,
                      max: max,
                      stepSize: step,
                      enableTooltip: true,
                      // Show the paddle tooltip only while interacting
                      shouldAlwaysShowTooltip: false,
                      showTicks: true,
                      showLabels: !useCustomLabels,
                      interval: interval,
                      minorTicksPerInterval: minor,
                      activeColor: active,
                      inactiveColor: inactive,
                      tooltipTextFormatterCallback: (actual, text) => label,
                      tooltipShape: const SfPaddleTooltipShape(),
                      labelFormatterCallback: (actual, formattedText) {
                        // Prefer integers for wide ranges, keep 2 decimals for 0..1
                        if (total <= 2.0) return actual.toStringAsFixed(2);
                        if (actual == actual.roundToDouble())
                          return actual.toStringAsFixed(0);
                        return actual.toStringAsFixed(1);
                      },
                      thumbIcon: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                      ),
                      onChanged: (v) =>
                          onChanged(v is num ? v.toDouble() : (v as double)),
                    ),
                  ),
                  if (useCustomLabels && stops.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (_, __) {
                        final range = (max - min).abs();
                        return SizedBox(
                          height: 18,
                          child: Stack(
                            fit: StackFit.expand,
                            children: stops.map((v) {
                              final t = range == 0
                                  ? 0.0
                                  : ((v - min) / range).clamp(0.0, 1.0);
                              return Align(
                                alignment: Alignment(-1 + t * 2, 0),
                                child: Text(
                                  v == v.roundToDouble()
                                      ? v.toInt().toString()
                                      : v.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withOpacity(0.65),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ValuePill(text: label, onTap: onLabelTap),
          ],
        ),
        // Remove explicit min/max captions since ticks already indicate range
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: onTap != null
          ? HitTestBehavior.opaque
          : HitTestBehavior.deferToChild,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.primary.withOpacity(isDark ? 0.28 : 0.22),
          ),
          boxShadow: isDark ? [] : AppShadows.soft,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

extension _AssistantAvatarActions on _BasicSettingsTabState {
  Future<String?> _pickEmoji(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String value = '';
    bool validGrapheme(String s) {
      final trimmed = s.characters.take(1).toString().trim();
      return trimmed.isNotEmpty && trimmed == s.trim();
    }

    final List<String> quick = const [
      '😀',
      '😁',
      '😂',
      '🤣',
      '😃',
      '😄',
      '😅',
      '😊',
      '😍',
      '😘',
      '😗',
      '😙',
      '😚',
      '🙂',
      '🤗',
      '🤩',
      '🫶',
      '🤝',
      '👍',
      '👎',
      '👋',
      '🙏',
      '💪',
      '🔥',
      '✨',
      '🌟',
      '💡',
      '🎉',
      '🎊',
      '🎈',
      '🌈',
      '☀️',
      '🌙',
      '⭐',
      '⚡',
      '☁️',
      '❄️',
      '🌧️',
      '🍎',
      '🍊',
      '🍋',
      '🍉',
      '🍇',
      '🍓',
      '🍒',
      '🍑',
      '🥭',
      '🍍',
      '🥝',
      '🍅',
      '🥕',
      '🌽',
      '🍞',
      '🧀',
      '🍔',
      '🍟',
      '🍕',
      '🌮',
      '🌯',
      '🍣',
      '🍜',
      '🍰',
      '🍪',
      '🍩',
      '🍫',
      '🍻',
      '☕',
      '🧋',
      '🥤',
      '⚽',
      '🏀',
      '🏈',
      '🎾',
      '🏐',
      '🎮',
      '🎧',
      '🎸',
      '🎹',
      '🎺',
      '📚',
      '✏️',
      '💼',
      '💻',
      '🖥️',
      '📱',
      '🛩️',
      '✈️',
      '🚗',
      '🚕',
      '🚙',
      '🚌',
      '🚀',
      '🛰️',
      '🧠',
      '🫀',
      '💊',
      '🩺',
      '🐶',
      '🐱',
      '🐭',
      '🐹',
      '🐰',
      '🦊',
      '🐻',
      '🐼',
      '🐨',
      '🐯',
      '🦁',
      '🐮',
      '🐷',
      '🐸',
      '🐵',
    ];
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final media = MediaQuery.of(ctx);
            final avail = media.size.height - media.viewInsets.bottom;
            final double gridHeight = (avail * 0.28).clamp(120.0, 220.0);
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditEmojiDialogTitle),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: EmojiText(
                        value.isEmpty
                            ? '🙂'
                            : value.characters.take(1).toString(),
                        fontSize: 40,
                        optimizeEmojiAlign: true,
                        nudge: Offset.zero, // picker preview: no extra nudge
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (v) => setLocal(() => value = v),
                      onSubmitted: (_) {
                        if (validGrapheme(value))
                          Navigator.of(
                            ctx,
                          ).pop(value.characters.take(1).toString());
                      },
                      decoration: InputDecoration(
                        hintText: l10n.assistantEditEmojiDialogHint,
                        filled: true,
                        fillColor: Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white10
                            : const Color(0xFFF2F3F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.transparent),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: cs.primary.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: gridHeight,
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 8,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                        itemCount: quick.length,
                        itemBuilder: (c, i) {
                          final e = quick[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(ctx).pop(e),
                            child: Container(
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: EmojiText(
                                e,
                                fontSize: 20,
                                optimizeEmojiAlign: true,
                                nudge:
                                    Offset.zero, // picker grid: no extra nudge
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.assistantEditEmojiDialogCancel),
                ),
                TextButton(
                  onPressed: validGrapheme(value)
                      ? () => Navigator.of(
                          ctx,
                        ).pop(value.characters.take(1).toString())
                      : null,
                  child: Text(
                    l10n.assistantEditEmojiDialogSave,
                    style: TextStyle(
                      color: validGrapheme(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _inputAvatarUrl(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool valid(String s) =>
            s.trim().startsWith('http://') || s.trim().startsWith('https://');
        String value = '';
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditImageUrlDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.assistantEditImageUrlDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx).pop(true);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.assistantEditImageUrlDialogCancel),
                ),
                TextButton(
                  onPressed: valid(value)
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: Text(
                    l10n.assistantEditImageUrlDialogSave,
                    style: TextStyle(
                      color: valid(value)
                          ? cs.primary
                          : cs.onSurface.withOpacity(0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final url = controller.text.trim();
      if (url.isNotEmpty) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: url),
        );
      }
    }
  }

  Future<void> _inputQQAvatar(BuildContext context, Assistant a) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        String value = '';
        bool valid(String s) => RegExp(r'^[0-9]{5,12}$').hasMatch(s.trim());
        String randomQQ() {
          final lengths = <int>[5, 6, 7, 8, 9, 10, 11];
          final weights = <int>[1, 20, 80, 100, 500, 5000, 80];
          final total = weights.fold<int>(0, (a, b) => a + b);
          final rnd = math.Random();
          int roll = rnd.nextInt(total) + 1;
          int chosenLen = lengths.last;
          int acc = 0;
          for (int i = 0; i < lengths.length; i++) {
            acc += weights[i];
            if (roll <= acc) {
              chosenLen = lengths[i];
              break;
            }
          }
          final sb = StringBuffer();
          final firstGroups = <List<int>>[
            [1, 2],
            [3, 4],
            [5, 6, 7, 8],
            [9],
          ];
          final firstWeights = <int>[128, 4, 2, 1];
          final firstTotal = firstWeights.fold<int>(0, (a, b) => a + b);
          int r2 = rnd.nextInt(firstTotal) + 1;
          int idx = 0;
          int a2 = 0;
          for (int i = 0; i < firstGroups.length; i++) {
            a2 += firstWeights[i];
            if (r2 <= a2) {
              idx = i;
              break;
            }
          }
          final group = firstGroups[idx];
          sb.write(group[rnd.nextInt(group.length)]);
          for (int i = 1; i < chosenLen; i++) {
            sb.write(rnd.nextInt(10));
          }
          return sb.toString();
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.surface,
              title: Text(l10n.assistantEditQQAvatarDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.assistantEditQQAvatarDialogHint,
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark
                      ? Colors.white10
                      : const Color(0xFFF2F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cs.primary.withOpacity(0.4)),
                  ),
                ),
                onChanged: (v) => setLocal(() => value = v),
                onSubmitted: (_) {
                  if (valid(value)) Navigator.of(ctx).pop(true);
                },
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                TextButton(
                  onPressed: () async {
                    const int maxTries = 20;
                    bool applied = false;
                    for (int i = 0; i < maxTries; i++) {
                      final qq = randomQQ();
                      final url =
                          'https://q2.qlogo.cn/headimg_dl?dst_uin=' +
                          qq +
                          '&spec=100';
                      try {
                        final resp = await http
                            .get(Uri.parse(url))
                            .timeout(const Duration(seconds: 5));
                        if (resp.statusCode == 200 &&
                            resp.bodyBytes.isNotEmpty) {
                          await context
                              .read<AssistantProvider>()
                              .updateAssistant(a.copyWith(avatar: url));
                          applied = true;
                          break;
                        }
                      } catch (_) {}
                    }
                    if (applied) {
                      if (Navigator.of(ctx).canPop())
                        Navigator.of(ctx).pop(false);
                    } else {
                      showAppSnackBar(
                        context,
                        message: l10n.assistantEditQQAvatarFailedMessage,
                        type: NotificationType.error,
                      );
                    }
                  },
                  child: Text(l10n.assistantEditQQAvatarRandomButton),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l10n.assistantEditQQAvatarDialogCancel),
                    ),
                    TextButton(
                      onPressed: valid(value)
                          ? () => Navigator.of(ctx).pop(true)
                          : null,
                      child: Text(
                        l10n.assistantEditQQAvatarDialogSave,
                        style: TextStyle(
                          color: valid(value)
                              ? cs.primary
                              : cs.onSurface.withOpacity(0.38),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
    if (ok == true) {
      final qq = controller.text.trim();
      if (qq.isNotEmpty) {
        final url =
            'https://q2.qlogo.cn/headimg_dl?dst_uin=' + qq + '&spec=100';
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: url),
        );
      }
    }
  }

  Future<void> _pickLocalImage(BuildContext context, Assistant a) async {
    if (kIsWeb) {
      await _inputAvatarUrl(context, a);
      return;
    }
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 90,
      );
      if (!mounted) return;
      if (file != null) {
        await context.read<AssistantProvider>().updateAssistant(
          a.copyWith(avatar: file.path),
        );
        return;
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGalleryErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context, a);
      return;
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(
        context,
        message: l10n.assistantEditGeneralErrorMessage,
        type: NotificationType.error,
      );
      await _inputAvatarUrl(context, a);
      return;
    }
  }
}

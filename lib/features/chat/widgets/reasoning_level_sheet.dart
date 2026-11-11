import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/services/api/response_speed.dart';
import '../../../core/services/auth/provider_oauth_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/model_override_payload_parser.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/reasoning/reasoning_level_options.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/dialogs/reasoning_budget_custom_dialog.dart';
import '../../../shared/widgets/effort_slider.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';

Future<void> showReasoningLevelSheet(
  BuildContext context, {
  required ProviderConfig config,
  required String modelId,
  Assistant? assistant,
  String? conversationId,
}) => showReasoningPickerSheet<void>(
  context: context,
  builder: (context) => ReasoningLevelPicker(
    config: config,
    modelId: modelId,
    assistant: assistant,
    conversationId: conversationId,
  ),
);

/// Plain content-sized mobile sheet: handle + child, no title or close.
Future<T?> showReasoningPickerSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ReasoningPickerSheet(child: builder(ctx)),
  );
}

class ReasoningPickerSheet extends StatelessWidget {
  const ReasoningPickerSheet({super.key, required this.child});

  static const panelKey = ValueKey<String>('reasoning_picker_sheet_panel');

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: panelKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

String reasoningLevelLabel(AppLocalizations l10n, ReasoningLevel level) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAuto,
    ReasoningLevel.off => l10n.reasoningLevelOff,
    ReasoningLevel.on => l10n.reasoningLevelOn,
    ReasoningLevel.minimal => l10n.reasoningLevelMinimal,
    ReasoningLevel.low => l10n.reasoningLevelLow,
    ReasoningLevel.medium => l10n.reasoningLevelMedium,
    ReasoningLevel.high => l10n.reasoningLevelHigh,
    ReasoningLevel.xhigh => l10n.reasoningLevelXhigh,
    ReasoningLevel.max => l10n.reasoningLevelMax,
  };
}

String reasoningLevelCompactLabel(AppLocalizations l10n, ReasoningLevel level) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAuto,
    ReasoningLevel.off => l10n.reasoningLevelOff,
    ReasoningLevel.on => l10n.reasoningLevelOn,
    ReasoningLevel.minimal => l10n.reasoningLevelCompactMin,
    ReasoningLevel.low => l10n.reasoningLevelCompactLow,
    ReasoningLevel.medium => l10n.reasoningLevelCompactMid,
    ReasoningLevel.high => l10n.reasoningLevelCompactHigh,
    ReasoningLevel.xhigh => l10n.reasoningLevelCompactXhigh,
    ReasoningLevel.max => l10n.reasoningLevelCompactMax,
  };
}

String reasoningLevelEffortSubtitle(
  AppLocalizations l10n,
  ReasoningLevel level,
) {
  return switch (level) {
    ReasoningLevel.auto => l10n.reasoningLevelAutoSubtitle,
    ReasoningLevel.off => l10n.reasoningLevelOffSubtitle,
    ReasoningLevel.on => l10n.reasoningLevelOnSubtitle,
    ReasoningLevel.minimal => l10n.reasoningLevelMinimalSubtitle,
    ReasoningLevel.low => l10n.reasoningLevelLowSubtitle,
    ReasoningLevel.medium => l10n.reasoningLevelMediumSubtitle,
    ReasoningLevel.high => l10n.reasoningLevelHighSubtitle,
    ReasoningLevel.xhigh => l10n.reasoningLevelXhighSubtitle,
    ReasoningLevel.max => l10n.reasoningLevelMaxSubtitle,
  };
}

String? reasoningLevelStopSubtitle(
  AppLocalizations l10n,
  ReasoningLevelPickerSnapshot snapshot,
  ReasoningLevelRow row,
) {
  return switch (row.kind) {
    ReasoningLevelRowKind.auto => l10n.reasoningLevelAutoSubtitle,
    ReasoningLevelRowKind.off => l10n.reasoningLevelOffSubtitle,
    ReasoningLevelRowKind.level
        when snapshot.isBudgetStyle && row.budget != null =>
      l10n.reasoningLevelBudgetTokens(formatReasoningBudgetK(row.budget!)),
    ReasoningLevelRowKind.level when row.level != null =>
      reasoningLevelEffortSubtitle(l10n, row.level!),
    _ => null,
  };
}

class ReasoningLevelPicker extends StatelessWidget {
  const ReasoningLevelPicker({
    super.key,
    required this.config,
    required this.modelId,
    this.assistant,
    this.conversationId,
    this.compact = false,
  });

  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
  final String? conversationId;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final config = settings.providerConfigs[this.config.id] ?? this.config;
    final spec = ModelSpecResolver.instance.spec(config, modelId);
    if (!spec.supportsReasoning) {
      return const _UnsupportedState();
    }
    final snapshot = buildReasoningLevelPickerSnapshot(
      settings: settings,
      config: config,
      modelId: modelId,
      spec: spec,
      assistant: assistant,
    );
    if (snapshot.sliderStops.isEmpty) {
      return const _UnsupportedState();
    }
    return _SliderPicker(
      snapshot: snapshot,
      config: config,
      modelId: modelId,
      assistant: assistant,
      conversationId: conversationId,
      compact: compact,
    );
  }
}

class _UnsupportedState extends StatelessWidget {
  const _UnsupportedState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('reasoning-unsupported'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Text(
        l10n.reasoningLevelNoReasoning,
        style: TextStyle(
          fontSize: 14,
          color: cs.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _SliderPicker extends StatefulWidget {
  const _SliderPicker({
    required this.snapshot,
    required this.config,
    required this.modelId,
    this.assistant,
    this.conversationId,
    this.compact = false,
  });

  final ReasoningLevelPickerSnapshot snapshot;
  final ProviderConfig config;
  final String modelId;
  final Assistant? assistant;
  final String? conversationId;
  final bool compact;

  @override
  State<_SliderPicker> createState() => _SliderPickerState();
}

class _SliderPickerState extends State<_SliderPicker> {
  bool _saving = false;
  bool _loadingTiers = false;

  @override
  void initState() {
    super.initState();
    final config = widget.config;
    final override = config.modelOverrides[widget.modelId];
    if (config.oauthProvider == OAuthProvider.chatgpt &&
        config.oauthCredentials != null &&
        (override is! Map ||
            override['oauthServiceTierSessionId'] !=
                config.oauthCredentials!.sessionId)) {
      _loadingTiers = true;
      unawaited(
        Future<void>(() async {
          try {
            await ProviderOAuthService.instance.syncModels(config.id);
          } catch (_) {
            // Keep reasoning controls usable offline; never probe availability
            // with a generation request.
          } finally {
            if (mounted) setState(() => _loadingTiers = false);
          }
        }),
      );
    }
  }

  String _speedLabel(AppLocalizations l10n, ResponseSpeed speed) =>
      switch (speed) {
        ResponseSpeed.standard => l10n.responseSpeedStandard,
        ResponseSpeed.fast => 'Fast',
        ResponseSpeed.ultrafast => 'UltraFast',
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final snapshot = widget.snapshot;
    final stops = snapshot.sliderStops;
    final chat = widget.conversationId == null
        ? null
        : context.watch<ChatService>();
    final conversation = chat?.getConversation(widget.conversationId!);
    final capabilities = ResponseSpeedCapabilities.resolve(
      widget.config,
      widget.modelId,
    );
    final speed = ConversationResponseSpeed.effective(
      conversation,
      widget.config,
      widget.modelId,
      assistantBody: ModelOverridePayloadParser.customBodyFromRows(
        widget.assistant?.customBody,
      ),
    );
    final speedVisible = capabilities.supportedProvider && conversation != null;
    final savedSpeed = ConversationResponseSpeed.selected(
      conversation,
      widget.config.id,
      widget.modelId,
    );
    final nextSpeed = capabilities.next(speed);
    final speedColor = switch (speed) {
      ResponseSpeed.standard => cs.onSurface.withValues(alpha: 0.5),
      ResponseSpeed.fast => cs.primary,
      ResponseSpeed.ultrafast =>
        Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFAD8CFF)
            : const Color(0xFF7951C2),
    };
    final speedHint = _loadingTiers
        ? l10n.responseSpeedLoading
        : nextSpeed != speed
        ? l10n.responseSpeedTapTo(_speedLabel(l10n, nextSpeed))
        : l10n.responseSpeedUnavailable;
    final speedTooltip = [
      '${_speedLabel(l10n, speed)} · $speedHint',
      if (speed == ResponseSpeed.fast &&
          capabilities.ultrafastRequiresResponses)
        l10n.responseSpeedUltrafastNeedsResponses,
      if (savedSpeed != null && !capabilities.supports(savedSpeed))
        l10n.responseSpeedSelectionUnavailable,
    ].join('\n');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EffortSliderGroup(
          selectedIndex: snapshot.sliderIndex,
          customSelected: snapshot.customSelected,
          customIcon: Icon(Lucide.Hash, size: 16, color: cs.primary),
          customIconKey: 'custom',
          customTitle: l10n.reasoningLevelCustomBudget,
          customSubtitle: snapshot.selected.budgetTokens?.toString(),
          compact: widget.compact,
          headerTitleStyle: TextStyle(
            fontSize: widget.compact ? 14 : 16,
            fontWeight: AppFontWeights.medium,
          ),
          headerSpacing: widget.compact ? 6 : 10,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 28),
          animatedTrack: speedVisible && speed != ResponseSpeed.standard,
          headerAction: speedVisible
              ? IosIconButton(
                  key: const ValueKey('response-speed-toggle'),
                  icon: Lucide.Zap,
                  size: widget.compact ? 14 : 16,
                  minSize: 32,
                  visualSize: widget.compact ? 26 : 28,
                  padding: const EdgeInsets.all(6),
                  color: speedColor,
                  tooltip: speedTooltip,
                  semanticLabel:
                      '${l10n.responseSpeedLabel}: ${_speedLabel(l10n, speed)}',
                  enabled: !_saving && !_loadingTiers && nextSpeed != speed,
                  onTap: _toggleSpeed,
                )
              : null,
          onCommit: (index) => _commitStop(stops[index]),
          stops: [
            for (final stop in stops)
              EffortSliderStop(
                stopKey: stop.key,
                icon: ReasoningIcons.levelIcon(
                  stop.level ?? ReasoningLevel.auto,
                  size: 16,
                  color: cs.primary,
                ),
                iconKey: stop.level ?? ReasoningLevel.auto,
                title: reasoningLevelLabel(
                  l10n,
                  stop.level ?? ReasoningLevel.auto,
                ),
                subtitle: reasoningLevelStopSubtitle(l10n, snapshot, stop),
              ),
          ],
        ),
        if (snapshot.isBudgetStyle) ...[
          SizedBox(height: widget.compact ? 8 : 20),
          _CustomBudgetRow(
            selected: snapshot.customSelected,
            budget: snapshot.customSelected
                ? snapshot.selected.budgetTokens
                : null,
            onTap: _pickCustomBudget,
          ),
        ],
        SizedBox(height: widget.compact ? 4 : 12),
      ],
    );
  }

  Future<void> _toggleSpeed() async {
    if (_saving || _loadingTiers || widget.conversationId == null) return;
    final config = context.read<SettingsProvider>().getProviderConfig(
      widget.config.id,
    );
    final capabilities = ResponseSpeedCapabilities.resolve(
      config,
      widget.modelId,
    );
    final current = ConversationResponseSpeed.effective(
      context.read<ChatService>().getConversation(widget.conversationId!),
      config,
      widget.modelId,
      assistantBody: ModelOverridePayloadParser.customBodyFromRows(
        widget.assistant?.customBody,
      ),
    );
    final next = capabilities.next(current);
    if (next == current) return;
    Haptics.soft();
    await _saveSpeed(next);
  }

  Future<void> _saveSpeed(ResponseSpeed speed) async {
    final id = widget.conversationId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    try {
      await context.read<ChatService>().updateConversationExtras(
        id,
        (extras) => ConversationResponseSpeed.updateExtras(
          extras,
          widget.config.id,
          widget.modelId,
          speed,
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.responseSpeedSaveFailed,
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _commitStop(ReasoningLevelRow row) async {
    final request = row.request;
    if (request == null) return;
    await commitReasoningChoice(
      context.read<SettingsProvider>(),
      widget.config,
      widget.modelId,
      widget.assistant,
      request,
    );
  }

  Future<void> _pickCustomBudget() async {
    Haptics.light();
    final snapshot = widget.snapshot;

    final chosen = await ReasoningBudgetCustomDialog.show(
      context,
      initialValue: snapshot.customSelected
          ? (snapshot.selected.budgetTokens ?? 2048)
          : 2048,
    );
    if (!mounted || chosen == null) return;
    await commitReasoningChoice(
      context.read<SettingsProvider>(),
      widget.config,
      widget.modelId,
      widget.assistant,
      requestForCustomBudget(snapshot.spec, chosen),
    );
  }
}

class _CustomBudgetRow extends StatelessWidget {
  const _CustomBudgetRow({
    required this.selected,
    required this.onTap,
    this.budget,
  });

  final bool selected;
  final VoidCallback onTap;
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        key: const ValueKey('reasoning-row-custom'),
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: sheetTileColor(context),
          duration: const Duration(milliseconds: 260),
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Lucide.Hash,
                size: 20,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.reasoningLevelCustomBudget,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected && budget != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      budget.toString(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Lucide.Check, size: 18, color: cs.primary),
                  ],
                )
              else
                Icon(
                  Lucide.ChevronRight,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

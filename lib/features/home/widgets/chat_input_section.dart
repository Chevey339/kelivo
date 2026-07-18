import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_input_data.dart';
import '../../../core/models/assistant.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/chat_model_selection_provider.dart';
import '../../../core/models/chat_model_target.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../utils/model_display_helper.dart';
import 'chat_input_bar.dart';
import 'model_icon.dart';

/// Callback for checking if a model supports tool calling.
typedef IsToolModelCallback = bool Function(String providerKey, String modelId);

/// Callback for checking if a model supports reasoning.
typedef IsReasoningModelCallback =
    bool Function(String providerKey, String modelId);

/// Callback for checking if reasoning is enabled.
typedef IsReasoningEnabledCallback = bool Function(int? budget);

/// Widget that wraps ChatInputBar with all the necessary logic and callbacks.
///
/// This widget extracts the _buildChatInputBar logic from HomePageState
/// to reduce coupling and improve maintainability.
class ChatInputSection extends StatelessWidget {
  const ChatInputSection({
    super.key,
    required this.inputBarKey,
    required this.inputFocus,
    required this.inputController,
    required this.mediaController,
    required this.isTablet,
    required this.isLoading,
    this.canStop = true,
    required this.isToolModel,
    required this.isReasoningModel,
    required this.isReasoningEnabled,
    this.onMore,
    this.onSelectModel,
    this.onLongPressSelectModel,
    this.onOpenMcp,
    this.onLongPressMcp,
    this.onOpenSearch,
    this.onConfigureReasoning,
    this.onSend,
    this.onStop,
    this.hasQueuedInput = false,
    this.queuedPreviewText,
    this.onCancelQueuedInput,
    this.onQuickPhrase,
    this.onLongPressQuickPhrase,
    this.onToggleOcr,
    this.onOpenMiniMap,
    this.onPickCamera,
    this.onPickPhotos,
    this.onUploadFiles,
    this.onToggleLearningMode,
    this.onOpenWorldBook, // 新增世界书支持桌面端
    this.onLongPressLearning,
    this.onClearContext,
    this.onCompressContext,
    this.conversationId,
    this.sendButtonTooltip,
    this.backgroundImageActive = false,
  });

  final GlobalKey inputBarKey;
  final FocusNode inputFocus;
  final TextEditingController inputController;
  final ChatInputBarController mediaController;
  final bool isTablet;
  final bool isLoading;
  final bool canStop;

  // Model capability checkers
  final IsToolModelCallback isToolModel;
  final IsReasoningModelCallback isReasoningModel;
  final IsReasoningEnabledCallback isReasoningEnabled;

  // Callbacks
  final VoidCallback? onMore;
  final VoidCallback? onSelectModel;
  final VoidCallback? onLongPressSelectModel;
  final VoidCallback? onOpenMcp;
  final VoidCallback? onLongPressMcp;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onConfigureReasoning;
  final Future<ChatInputSubmissionResult> Function(ChatInputData)? onSend;
  final VoidCallback? onStop;
  final bool hasQueuedInput;
  final String? queuedPreviewText;
  final VoidCallback? onCancelQueuedInput;
  final VoidCallback? onQuickPhrase;
  final VoidCallback? onLongPressQuickPhrase;
  final VoidCallback? onToggleOcr;
  final VoidCallback? onOpenMiniMap;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickPhotos;
  final VoidCallback? onUploadFiles;
  final VoidCallback? onToggleLearningMode;
  final VoidCallback? onOpenWorldBook;
  final VoidCallback? onLongPressLearning;
  final VoidCallback? onClearContext;
  final VoidCallback? onCompressContext;
  final String? conversationId;
  final String? sendButtonTooltip;
  final bool backgroundImageActive;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final ap = context.watch<AssistantProvider>();
    final a = ap.currentAssistant;
    final assistantId = a?.id;

    // Use unified helper to get model identifiers
    final modelIds = getActiveModelIds(settings, assistant: a);
    final pk = modelIds.providerKey;
    final mid = modelIds.modelId;
    final selectionProvider = context.watch<ChatModelSelectionProvider?>();
    final targets = pk != null && mid != null
        ? selectionProvider?.effectiveTargets(
                fallback: ChatModelTarget(providerKey: pk, modelId: mid),
                assistantId: assistantId,
                conversationId: conversationId,
              ) ??
              <ChatModelTarget>[ChatModelTarget(providerKey: pk, modelId: mid)]
        : const <ChatModelTarget>[];
    final multiModelActive = targets.length > 1;

    // Enforce model capabilities: disable MCP selection if model doesn't support tools
    if (!multiModelActive) {
      _enforceModelCapabilities(context, settings, ap, a, pk, mid);
    }

    final isDesktop = _isDesktopPlatform(context);
    final hasWorldBooks =
        isTablet && context.watch<WorldBookProvider>().books.isNotEmpty;

    return ChatInputBar(
      key: inputBarKey,
      onMore: onMore,
      onSelectModel: onSelectModel,
      onLongPressSelectModel: onLongPressSelectModel,
      conversationId: conversationId,
      allowImagesApiRouting: !multiModelActive,
      onOpenMcp: onOpenMcp,
      onLongPressMcp: onLongPressMcp,
      onStop: onStop,
      canStop: canStop,
      modelIcon: multiModelActive
          ? _MultiModelIcon(targets: targets)
          : (pk != null && mid != null)
          ? CurrentModelIcon(
              providerKey: pk,
              modelId: mid,
              size: 40,
              withBackground: true,
              backgroundColor: Colors.transparent,
            )
          : null,
      focusNode: inputFocus,
      controller: inputController,
      mediaController: mediaController,
      onConfigureReasoning: onConfigureReasoning,
      reasoningActive: isReasoningEnabled(
        (context.watch<AssistantProvider>().currentAssistant?.thinkingBudget) ??
            settings.thinkingBudget,
      ),
      reasoningBudget:
          (context
              .watch<AssistantProvider>()
              .currentAssistant
              ?.thinkingBudget) ??
          settings.thinkingBudget,
      supportsReasoning: (pk != null && mid != null)
          ? isReasoningModel(pk, mid)
          : false,
      onOpenSearch: onOpenSearch,
      onSend: onSend,
      loading: isLoading,
      sendButtonTooltip: sendButtonTooltip,
      hasQueuedInput: hasQueuedInput,
      queuedPreviewText: queuedPreviewText,
      onCancelQueuedInput: onCancelQueuedInput,
      showMcpButton:
          !multiModelActive &&
          _shouldShowMcpButton(context, settings, a, pk, mid),
      mcpActive: _isMcpActive(context, a),
      showQuickPhraseButton: _hasQuickPhrases(context, a),
      onQuickPhrase: onQuickPhrase,
      onLongPressQuickPhrase: onLongPressQuickPhrase,
      // OCR button: show on desktop for mobile layout, always check settings for tablet layout
      showOcrButton: isTablet
          ? (settings.ocrModelProvider != null && settings.ocrModelId != null)
          : (isDesktop &&
                settings.ocrModelProvider != null &&
                settings.ocrModelId != null),
      ocrActive: settings.ocrEnabled,
      onToggleOcr: onToggleOcr,
      // Tablet-specific parameters
      showMiniMapButton: isTablet,
      onOpenMiniMap: isTablet ? onOpenMiniMap : null,
      onPickCamera: isTablet ? (isDesktop ? null : onPickCamera) : null,
      onPickPhotos: isTablet ? (isDesktop ? null : onPickPhotos) : null,
      onUploadFiles: isTablet ? onUploadFiles : null,
      onToggleLearningMode: isTablet ? onToggleLearningMode : null,
      onOpenWorldBook: hasWorldBooks ? onOpenWorldBook : null,
      onLongPressLearning: isTablet ? onLongPressLearning : null,
      learningModeActive: isTablet
          ? context
                .watch<InstructionInjectionProvider>()
                .activeIdsFor(assistantId)
                .isNotEmpty
          : false,
      worldBookActive: isTablet
          ? context
                .watch<WorldBookProvider>()
                .activeBookIdsFor(assistantId)
                .isNotEmpty
          : false,
      showMoreButton: !isTablet,
      onClearContext: isTablet ? onClearContext : null,
      onCompressContext: isTablet ? onCompressContext : null,
      backgroundImageActive: backgroundImageActive,
      inputBackgroundOpacityLight: settings.chatInputBackgroundOpacityLight,
      inputBackgroundOpacityDark: settings.chatInputBackgroundOpacityDark,
    );
  }

  bool _isDesktopPlatform(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  void _enforceModelCapabilities(
    BuildContext context,
    SettingsProvider settings,
    AssistantProvider ap,
    Assistant? a,
    String? pk,
    String? mid,
  ) {
    if (pk == null || mid == null) return;

    final supportsTools = isToolModel(pk, mid);
    if (!supportsTools && (a?.mcpServerIds.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final aa = ap.currentAssistant;
        if (aa != null && aa.mcpServerIds.isNotEmpty) {
          ap.updateAssistant(aa.copyWith(mcpServerIds: const <String>[]));
        }
      });
    }

    final supportsReasoning = isReasoningModel(pk, mid);
    if (!supportsReasoning && a != null) {
      final enabledNow = isReasoningEnabled(
        a.thinkingBudget ?? settings.thinkingBudget,
      );
      if (enabledNow) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final aa = ap.currentAssistant;
          if (aa != null) {
            await ap.updateAssistant(aa.copyWith(thinkingBudget: 0));
          }
        });
      }
    }
  }

  bool _shouldShowMcpButton(
    BuildContext context,
    SettingsProvider settings,
    Assistant? a,
    String? pk,
    String? mid,
  ) {
    final pk2 = a?.chatModelProvider ?? settings.currentModelProvider;
    final mid3 = a?.chatModelId ?? settings.currentModelId;
    if (pk2 == null || mid3 == null) return false;
    final hasEnabledMcp = context.watch<McpProvider>().hasAnyEnabled;
    return isToolModel(pk2, mid3) && hasEnabledMcp;
  }

  bool _isMcpActive(BuildContext context, Assistant? a) {
    final connected = context.watch<McpProvider>().connectedServers;
    final selected = a?.mcpServerIds ?? const <String>[];
    if (selected.isEmpty || connected.isEmpty) return false;
    return connected.any((s) => selected.contains(s.id));
  }

  bool _hasQuickPhrases(BuildContext context, Assistant? a) {
    final quickPhraseProvider = context.watch<QuickPhraseProvider>();
    final globalCount = quickPhraseProvider.globalPhrases.length;
    final assistantCount = a != null
        ? quickPhraseProvider.getForAssistant(a.id).length
        : 0;
    return (globalCount + assistantCount) > 0;
  }
}

class _MultiModelIcon extends StatelessWidget {
  const _MultiModelIcon({required this.targets});

  final List<ChatModelTarget> targets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = targets.take(3).toList(growable: false);
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final (index, target) in visible.indexed)
            Positioned(
              left: index * 7,
              top: index * 3,
              child: CurrentModelIcon(
                providerKey: target.providerKey,
                modelId: target.modelId,
                size: 25,
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${targets.length}',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

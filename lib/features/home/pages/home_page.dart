import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../shared/widgets/interactive_drawer.dart';
import '../../../shared/responsive/breakpoints.dart';
import '../../../theme/design_tokens.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/services/android_process_text.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/platform_utils.dart';
import '../../../desktop/search_provider_popover.dart';
import '../../../desktop/reasoning_budget_popover.dart';
import '../../../desktop/mcp_servers_popover.dart';
import '../../../desktop/mini_map_popover.dart';
import '../../../desktop/quick_phrase_popover.dart';
import '../../../desktop/instruction_injection_popover.dart';
import '../../chat/widgets/bottom_tools_sheet.dart';
import '../../chat/widgets/reasoning_budget_sheet.dart';
import '../../search/widgets/search_settings_sheet.dart';
import '../../model/widgets/model_select_sheet.dart';
import '../../mcp/pages/mcp_page.dart';
import '../../provider/pages/providers_page.dart';
import '../../assistant/widgets/mcp_assistant_sheet.dart';
import '../../quick_phrase/pages/quick_phrases_page.dart';
import '../../quick_phrase/widgets/quick_phrase_menu.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/mini_map_sheet.dart';
import '../widgets/instruction_injection_sheet.dart';
import '../widgets/learning_prompt_sheet.dart';
import '../widgets/scroll_nav_buttons.dart';
import '../widgets/selection_toolbar.dart';
import '../widgets/message_list_view.dart';
import '../widgets/chat_input_section.dart';
import '../utils/model_display_helper.dart';
import '../utils/chat_layout_constants.dart';
import '../controllers/home_page_controller.dart';
import 'home_mobile_layout.dart';
import 'home_desktop_layout.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  // ============================================================================
  // UI Controllers (owned by State for lifecycle management)
  // ============================================================================

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final InteractiveDrawerController _drawerController = InteractiveDrawerController();
  final ValueNotifier<int> _assistantPickerCloseTick = ValueNotifier<int>(0);
  final FocusNode _inputFocus = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final ChatInputBarController _mediaController = ChatInputBarController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _inputBarKey = GlobalKey();
  StreamSubscription<String>? _processTextSub;

  // ============================================================================
  // Page Controller (manages all business logic and state)
  // ============================================================================

  late HomePageController _controller;

  // ============================================================================
  // Lifecycle
  // ============================================================================

  @override
  void initState() {
    super.initState();
    try { WidgetsBinding.instance.addObserver(this); } catch (_) {}

    _controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: _scaffoldKey,
      inputBarKey: _inputBarKey,
      inputFocus: _inputFocus,
      inputController: _inputController,
      mediaController: _mediaController,
      scrollController: _scrollController,
    );

    _controller.addListener(_onControllerChanged);
    _drawerController.addListener(_onDrawerValueChanged);

    _controller.initChat();
    _initProcessText();

    WidgetsBinding.instance.addPostFrameCallback((_) => _controller.measureInputBar());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.onAppLifecycleStateChanged(state);
  }

  @override
  void didPushNext() {
    _controller.onDidPushNext();
  }

  @override
  void didPopNext() {
    _controller.onDidPopNext();
  }

  @override
  void dispose() {
    try { WidgetsBinding.instance.removeObserver(this); } catch (_) {}
    _processTextSub?.cancel();
    _controller.removeListener(_onControllerChanged);
    _drawerController.removeListener(_onDrawerValueChanged);
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _controller.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onDrawerValueChanged() {
    _controller.onDrawerValueChanged(_drawerController.value);
    // Close assistant picker when drawer closes
    if (_drawerController.value < 0.95) {
      final sp = context.read<SettingsProvider>();
      if (!sp.keepAssistantListExpandedOnSidebarClose) {
        _assistantPickerCloseTick.value++;
      }
    }
  }

  void _initProcessText() {
    if (!PlatformUtils.isAndroid) return;
    AndroidProcessText.ensureInitialized();
    _processTextSub = AndroidProcessText.stream.listen(_handleProcessText);
    AndroidProcessText.getInitialText().then((text) {
      if (text != null) {
        _handleProcessText(text);
      }
    });
  }

  void _handleProcessText(String text) {
    if (!mounted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = _inputController.text;
    final selection = _inputController.selection;
    final start = (selection.start >= 0 && selection.start <= current.length)
        ? selection.start
        : current.length;
    final end = (selection.end >= 0 && selection.end <= current.length && selection.end >= start)
        ? selection.end
        : start;
    final next = current.replaceRange(start, end, trimmed);
    _inputController.value = _inputController.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: start + trimmed.length),
      composing: TextRange.empty,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.forceScrollToBottomSoon(animate: false);
      _inputFocus.requestFocus();
    });
  }

  // ============================================================================
  // Build Methods
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final assistant = context.watch<AssistantProvider>().currentAssistant;

    final modelInfo = getModelDisplayInfo(settings, assistant: assistant);

    final title = ((_controller.currentConversation?.title ?? '').trim().isNotEmpty)
        ? _controller.currentConversation!.title
        : _controller.titleForLocale();

    if (width >= AppBreakpoints.tablet) {
      return _buildTabletLayout(
        context,
        title: title,
        providerName: modelInfo.providerName,
        modelDisplay: modelInfo.modelDisplay,
        cs: cs,
      );
    }

    return _buildMobileLayout(
      context,
      title: title,
      providerName: modelInfo.providerName,
      modelDisplay: modelInfo.modelDisplay,
      cs: cs,
    );
  }

  Widget _buildMobileLayout(
    BuildContext context, {
    required String title,
    required String? providerName,
    required String? modelDisplay,
    required ColorScheme cs,
  }) {
    return HomeMobileScaffold(
      scaffoldKey: _scaffoldKey,
      drawerController: _drawerController,
      assistantPickerCloseTick: _assistantPickerCloseTick,
      loadingConversationIds: _controller.loadingConversationIds,
      title: title,
      providerName: providerName,
      modelDisplay: modelDisplay,
      onToggleDrawer: () => _drawerController.toggle(),
      onDismissKeyboard: _controller.dismissKeyboard,
      onSelectConversation: (id) {
        _controller.switchConversationAnimated(id);
      },
      onNewConversation: () async {
        await _controller.createNewConversationAnimated();
      },
      onOpenMiniMap: () async {
        final collapsed = _controller.collapseVersions(_controller.messages);
        String? selectedId;
        if (PlatformUtils.isDesktop) {
          selectedId = await showDesktopMiniMapPopover(context, anchorKey: _inputBarKey, messages: collapsed);
        } else {
          selectedId = await showMiniMapSheet(context, collapsed);
        }
        if (!mounted) return;
        if (selectedId != null && selectedId.isNotEmpty) {
          await _controller.scrollToMessageId(selectedId);
        }
      },
      onCreateNewConversation: () async {
        await _controller.createNewConversationAnimated();
        if (mounted) {
          _controller.forceScrollToBottomSoon(animate: false);
        }
      },
      onSelectModel: () => showModelSelectSheet(context),
      body: _wrapWithDropTarget(_buildMobileBody(context, cs)),
    );
  }

  Widget _buildMobileBody(BuildContext context, ColorScheme cs) {
    return Stack(
      children: [
        // Background
        _buildChatBackground(context, cs),
        // Main content
        Padding(
          padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.paddingOf(context).top),
          child: Column(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final content = KeyedSubtree(
                      key: ValueKey<String>(_controller.currentConversation?.id ?? 'none'),
                      child: _buildMessageListView(
                        context,
                        dividerPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: AppSpacing.md),
                      ),
                    );
                    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
                    Widget w = content;
                    if (!isAndroid) {
                      w = w
                          .animate(key: ValueKey('mob_body_'+(_controller.currentConversation?.id ?? 'none')))
                          .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic);
                      w = FadeTransition(opacity: _controller.convoFade, child: w);
                    }
                    return w;
                  },
                ),
              ),
              // Input bar
              NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (n) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _controller.measureInputBar());
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: Builder(
                    builder: (context) => _buildChatInputBar(context, isTablet: false),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Selection toolbar overlay
        _buildSelectionToolbarOverlay(),
        // Scroll navigation buttons
        _buildScrollButtons(),
      ],
    );
  }

  Widget _buildTabletLayout(
    BuildContext context, {
    required String title,
    required String? providerName,
    required String? modelDisplay,
    required ColorScheme cs,
  }) {
    _controller.initDesktopUi();

    return HomeDesktopScaffold(
      scaffoldKey: _scaffoldKey,
      assistantPickerCloseTick: _assistantPickerCloseTick,
      loadingConversationIds: _controller.loadingConversationIds,
      title: title,
      providerName: providerName,
      modelDisplay: modelDisplay,
      tabletSidebarOpen: _controller.tabletSidebarOpen,
      rightSidebarOpen: _controller.rightSidebarOpen,
      embeddedSidebarWidth: _controller.embeddedSidebarWidth,
      rightSidebarWidth: _controller.rightSidebarWidth,
      sidebarMinWidth: HomePageController.sidebarMinWidth,
      sidebarMaxWidth: HomePageController.sidebarMaxWidth,
      onToggleSidebar: _controller.toggleTabletSidebar,
      onToggleRightSidebar: _controller.toggleRightSidebar,
      onSelectConversation: (id) {
        _controller.switchConversationAnimated(id);
      },
      onNewConversation: () async {
        await _controller.createNewConversationAnimated();
      },
      onCreateNewConversation: () async {
        await _controller.createNewConversationAnimated();
        if (mounted) _controller.forceScrollToBottomSoon(animate: false);
      },
      onSelectModel: () => showModelSelectSheet(context),
      onSidebarWidthChanged: _controller.updateSidebarWidth,
      onSidebarWidthChangeEnd: _controller.saveSidebarWidth,
      onRightSidebarWidthChanged: _controller.updateRightSidebarWidth,
      onRightSidebarWidthChangeEnd: _controller.saveRightSidebarWidth,
      buildAssistantBackground: _buildAssistantBackground,
      body: _wrapWithDropTarget(_buildTabletBody(context, cs)),
    );
  }

  Widget _buildTabletBody(BuildContext context, ColorScheme cs) {
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.paddingOf(context).top),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: _controller.convoFade,
                  child: KeyedSubtree(
                    key: ValueKey<String>(_controller.currentConversation?.id ?? 'none'),
                    child: _buildMessageListView(
                      context,
                      dividerPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ).animate(key: ValueKey('tab_body_'+(_controller.currentConversation?.id ?? 'none')))
                   .fadeIn(duration: 200.ms, curve: Curves.easeOutCubic),
                ),
              ),
              NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (n) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _controller.measureInputBar());
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: Builder(
                    builder: (context) {
                      Widget input = _buildChatInputBar(context, isTablet: true);
                      input = Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: ChatLayoutConstants.maxInputWidth,
                          ),
                          child: input,
                        ),
                      );
                      return input;
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildSelectionToolbarOverlay(),
        _buildScrollButtons(),
      ],
    );
  }

  // ============================================================================
  // UI Component Builders
  // ============================================================================

  Widget _buildChatBackground(BuildContext context, ColorScheme cs) {
    return Builder(
      builder: (context) {
        final bg = context.watch<AssistantProvider>().currentAssistant?.background;
        final maskStrength = context.watch<SettingsProvider>().chatBackgroundMaskStrength;
        if (bg == null || bg.trim().isEmpty) return const SizedBox.shrink();
        ImageProvider provider;
        if (bg.startsWith('http')) {
          provider = NetworkImage(bg);
        } else {
          final localPath = SandboxPathResolver.fix(bg);
          final file = File(localPath);
          if (!file.existsSync()) return const SizedBox.shrink();
          provider = FileImage(file);
        }
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: provider,
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.04), BlendMode.srcATop),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: () {
                          final top = (0.20 * maskStrength).clamp(0.0, 1.0);
                          final bottom = (0.50 * maskStrength).clamp(0.0, 1.0);
                          return [
                            cs.background.withOpacity(top),
                            cs.background.withOpacity(bottom),
                          ];
                        }(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssistantBackground(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assistant = context.watch<AssistantProvider>().currentAssistant;
    final bgRaw = (assistant?.background ?? '').trim();
    Widget? bg;
    if (bgRaw.isNotEmpty) {
      if (bgRaw.startsWith('http')) {
        bg = Image.network(bgRaw, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink());
      } else {
        try {
          final fixed = SandboxPathResolver.fix(bgRaw);
          final f = File(fixed);
          if (f.existsSync()) {
            bg = Image(image: FileImage(f), fit: BoxFit.cover);
          }
        } catch (_) {}
      }
    }
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: cs.background),
          if (bg != null) Opacity(opacity: 0.9, child: bg),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  cs.background.withOpacity(0.08),
                  cs.background.withOpacity(0.36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageListView(
    BuildContext context, {
    required EdgeInsetsGeometry dividerPadding,
  }) {
    return MessageListView(
      isProcessingFiles: _controller.isProcessingFiles,
      scrollController: _scrollController,
      messages: _controller.messages,
      versionSelections: _controller.versionSelections,
      currentConversation: _controller.currentConversation,
      messageKeys: _controller.messageKeys,
      reasoning: _controller.reasoning,
      reasoningSegments: _controller.reasoningSegments,
      toolParts: _controller.toolParts,
      translations: _buildTranslationUiStates(),
      selecting: _controller.selecting,
      selectedItems: _controller.selectedItems,
      dividerPadding: dividerPadding,
      streamingContentNotifier: _controller.streamingContentNotifier,
      onVersionChange: (groupId, version) async {
        await _controller.setSelectedVersion(groupId, version);
      },
      onRegenerateMessage: (message) => _controller.regenerateAtMessage(message),
      onResendMessage: (message) => _controller.regenerateAtMessage(message),
      onTranslateMessage: (message) => _controller.translateMessage(message),
      onEditMessage: (message) => _controller.editMessage(message),
      onDeleteMessage: (message, byGroup) => _handleDeleteMessage(context, message, byGroup),
      onForkConversation: (message) => _controller.forkConversation(message),
      onShareMessage: (index, messages) => _controller.shareMessage(index, messages),
      onSpeakMessage: (message) => _controller.speakMessage(message),
      onToggleSelection: (messageId, selected) {
        _controller.toggleSelection(messageId, selected);
      },
      onToggleReasoning: (messageId) {
        _controller.toggleReasoning(messageId);
      },
      onToggleTranslation: (messageId) {
        _controller.toggleTranslation(messageId);
      },
      onToggleReasoningSegment: (messageId, segmentIndex) {
        _controller.toggleReasoningSegment(messageId, segmentIndex);
      },
    );
  }

  Widget _buildChatInputBar(BuildContext context, {required bool isTablet}) {
    return ChatInputSection(
      inputBarKey: _inputBarKey,
      inputFocus: _inputFocus,
      inputController: _inputController,
      mediaController: _mediaController,
      isTablet: isTablet,
      isLoading: _controller.isCurrentConversationLoading,
      isToolModel: _controller.isToolModel,
      isReasoningModel: _controller.isReasoningModel,
      isReasoningEnabled: _controller.isReasoningEnabled,
      onMore: _toggleTools,
      onSelectModel: () => showModelSelectSheet(context),
      onLongPressSelectModel: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProvidersPage()),
        );
      },
      onOpenMcp: () {
        final a = context.read<AssistantProvider>().currentAssistant;
        if (a != null) {
          if (PlatformUtils.isDesktop) {
            showDesktopMcpServersPopover(context, anchorKey: _inputBarKey, assistantId: a.id);
          } else {
            showAssistantMcpSheet(context, assistantId: a.id);
          }
        }
      },
      onLongPressMcp: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const McpPage()),
        );
      },
      onOpenSearch: _openSearchSettings,
      onConfigureReasoning: () async {
        final assistant = context.read<AssistantProvider>().currentAssistant;
        if (assistant != null) {
          if (assistant.thinkingBudget != null) {
            context.read<SettingsProvider>().setThinkingBudget(assistant.thinkingBudget);
          }
          await _openReasoningSettings();
          final chosen = context.read<SettingsProvider>().thinkingBudget;
          await context.read<AssistantProvider>().updateAssistant(
            assistant.copyWith(thinkingBudget: chosen),
          );
        }
      },
      onSend: (text) {
        _controller.sendMessage(text);
        _inputController.clear();
        if (PlatformUtils.isMobile) {
          _controller.dismissKeyboard();
        } else {
          _inputFocus.requestFocus();
        }
      },
      onStop: _controller.cancelStreaming,
      onQuickPhrase: _showQuickPhraseMenu,
      onLongPressQuickPhrase: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuickPhrasesPage()),
        );
      },
      onToggleOcr: () async {
        final sp = context.read<SettingsProvider>();
        await sp.setOcrEnabled(!sp.ocrEnabled);
      },
      onOpenMiniMap: () async {
        final collapsed = _controller.collapseVersions(_controller.messages);
        String? selectedId;
        if (PlatformUtils.isDesktop) {
          selectedId = await showDesktopMiniMapPopover(context, anchorKey: _inputBarKey, messages: collapsed);
        } else {
          selectedId = await showMiniMapSheet(context, collapsed);
        }
        if (selectedId != null && selectedId.isNotEmpty) {
          await _controller.scrollToMessageId(selectedId);
        }
      },
      onPickCamera: _controller.onPickCamera,
      onPickPhotos: _controller.onPickPhotos,
      onUploadFiles: _controller.onPickFiles,
      onToggleLearningMode: _openInstructionInjectionPopover,
      onLongPressLearning: _showLearningPromptSheet,
      onClearContext: _controller.clearContext,
    );
  }

  Widget _buildSelectionToolbarOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 122),
          child: AnimatedSelectionBar(
            visible: _controller.selecting,
            child: SelectionToolbar(
              onCancel: _controller.cancelSelection,
              onConfirm: _controller.confirmSelection,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollButtons() {
    return Builder(builder: (context) {
      final showSetting = context.watch<SettingsProvider>().showMessageNavButtons;
      if (!showSetting || _controller.messages.isEmpty) return const SizedBox.shrink();
      return ScrollNavButtonsPanel(
        visible: _controller.scrollCtrl.showNavButtons,
        bottomOffset: _controller.inputBarHeight + 12,
        onScrollToTop: _controller.scrollToTop,
        onPreviousMessage: _controller.jumpToPreviousQuestion,
        onNextMessage: _controller.jumpToNextQuestion,
        onScrollToBottom: _controller.forceScrollToBottom,
      );
    });
  }

  Widget _wrapWithDropTarget(Widget child) {
    if (!_controller.isDesktopPlatform) return child;
    return DropTarget(
      onDragEntered: (_) {
        _controller.setDragHovering(true);
      },
      onDragExited: (_) {
        _controller.setDragHovering(false);
      },
      onDragDone: (details) async {
        _controller.setDragHovering(false);
        try {
          final files = details.files;
          await _controller.onFilesDroppedDesktop(files);
        } catch (_) {}
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (_controller.isDragHovering)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4), width: 2),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.homePageDropToUpload,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // Action Handlers (UI-specific, not in controller)
  // ============================================================================

  void _openSearchSettings() {
    if (PlatformUtils.isDesktop) {
      showDesktopSearchProviderPopover(context, anchorKey: _inputBarKey);
    } else {
      showSearchSettingsSheet(context);
    }
  }

  Future<void> _openReasoningSettings() async {
    if (PlatformUtils.isDesktop) {
      await showDesktopReasoningBudgetPopover(context, anchorKey: _inputBarKey);
    } else {
      await showReasoningBudgetSheet(context);
    }
  }

  Future<void> _openInstructionInjectionPopover() async {
    final isDesktop = PlatformUtils.isDesktop;
    final assistantId = context.read<AssistantProvider>().currentAssistantId;
    final provider = context.read<InstructionInjectionProvider>();
    await provider.initialize();
    final items = provider.items;
    if (items.isEmpty) return;

    if (isDesktop) {
      await showDesktopInstructionInjectionPopover(
        context,
        anchorKey: _inputBarKey,
        items: items,
        assistantId: assistantId,
      );
    } else {
      await showInstructionInjectionSheet(context, assistantId: assistantId);
    }
  }

  Future<void> _showLearningPromptSheet() async {
    await showLearningPromptSheet(context);
  }

  void _toggleTools() async {
    _controller.dismissKeyboard();
    final cs = Theme.of(context).colorScheme;
    final assistantId = context.read<AssistantProvider>().currentAssistantId;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: BottomToolsSheet(
            onPhotos: () {
              Navigator.of(ctx).maybePop();
              _controller.onPickPhotos();
            },
            onCamera: () {
              Navigator.of(ctx).maybePop();
              _controller.onPickCamera();
            },
            onUpload: () {
              Navigator.of(ctx).maybePop();
              _controller.onPickFiles();
            },
            onClear: () async {
              Navigator.of(ctx).maybePop();
              await _controller.clearContext();
            },
            clearLabel: _controller.clearContextLabel(),
            assistantId: assistantId,
          ),
        );
      },
    );
  }

  Future<void> _showQuickPhraseMenu() async {
    final assistant = context.read<AssistantProvider>().currentAssistant;
    final quickPhraseProvider = context.read<QuickPhraseProvider>();
    final globalPhrases = quickPhraseProvider.globalPhrases;
    final assistantPhrases = assistant != null
        ? quickPhraseProvider.getForAssistant(assistant.id)
        : <QuickPhrase>[];

    final allAvailable = [...globalPhrases, ...assistantPhrases];
    if (allAvailable.isEmpty) return;

    final RenderBox? inputBox = _inputBarKey.currentContext?.findRenderObject() as RenderBox?;
    if (inputBox == null) return;

    final inputBarHeight = inputBox.size.height;
    final topLeft = inputBox.localToGlobal(Offset.zero);
    final position = Offset(topLeft.dx, inputBarHeight);

    _controller.dismissKeyboard();

    QuickPhrase? selected;
    if (PlatformUtils.isDesktop) {
      selected = await showDesktopQuickPhrasePopover(context, anchorKey: _inputBarKey, phrases: allAvailable);
    } else {
      selected = await showQuickPhraseMenu(
        context: context,
        phrases: allAvailable,
        position: position,
      );
    }

    if (selected != null && mounted) {
      await _controller.handleQuickPhraseSelection(selected);
    }
  }

  Future<void> _handleDeleteMessage(
    BuildContext context,
    ChatMessage message,
    Map<String, List<ChatMessage>> byGroup,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.homePageDeleteMessage),
        content: Text(l10n.homePageDeleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.homePageDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _controller.deleteMessage(message: message, byGroup: byGroup);
  }

  Map<String, TranslationUiState> _buildTranslationUiStates() {
    final result = <String, TranslationUiState>{};
    for (final entry in _controller.translations.entries) {
      result[entry.key] = TranslationUiState(
        expanded: entry.value.expanded,
        onToggle: () {
          _controller.toggleTranslation(entry.key);
        },
      );
    }
    return result;
  }
}

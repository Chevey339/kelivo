import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate' show ReceivePort;
import 'dart:ui' show IsolateNameServer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/quick_phrase.dart';
import '../../../core/models/assistant_regex.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../core/providers/tts_provider.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/tts/tts_text_selection.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/proactive_care_alarm_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/platform_utils.dart';
import '../../../utils/assistant_regex.dart';
import '../../chat/models/message_edit_result.dart';
import '../../chat/widgets/chat_message_widget.dart' show ToolUIPart;
import '../../chat/widgets/message_edit_sheet.dart';
import '../../chat/widgets/message_export_sheet.dart';
import '../../../desktop/message_edit_dialog.dart';
import '../../../desktop/hotkeys/chat_action_bus.dart';
import '../../../desktop/hotkeys/sidebar_tab_bus.dart';
import 'chat_controller.dart';
import 'stream_controller.dart' as stream_ctrl;
import 'generation_controller.dart';
import 'scroll_controller.dart' as scroll_ctrl;
import 'home_view_model.dart';
import '../services/message_builder_service.dart';
import '../services/message_generation_service.dart';
import '../services/multi_ai_engine.dart';
import '../widgets/synthesize_task_selector.dart'
    show showSynthesizeTaskSelector;
import '../models/synthesize_task.dart' show synthesizeTasks;
import '../services/message_pipeline.dart';
import '../services/ask_user_interaction_service.dart';
import '../services/ocr_service.dart';
import '../services/translation_service.dart';
import '../services/file_upload_service.dart';
import '../widgets/chat_input_bar.dart';
import '../../model/widgets/model_select_sheet.dart';

enum ChatSelectionMode { share, delete }

/// Translation data for UI state (expanded/collapsed).
class TranslationData {
  bool expanded = true; // default to expanded when translation is added
}

class UserMessageEditState {
  const UserMessageEditState({
    required this.messageId,
    required this.previewText,
  });

  final String messageId;
  final String previewText;
}

/// Controller that manages all state and service wiring for HomePage.
///
/// This controller extracts the non-UI logic from _HomePageState to:
/// - Centralize state management
/// - Make the code more testable
/// - Allow reuse across different page layouts (mobile/tablet/desktop)
/// - Reduce the complexity of the State class
///
/// The HomePage widget now only manages:
/// - Lifecycle (initState, dispose)
/// - Layout selection (mobile vs tablet)
/// - Building the UI tree
class HomePageController extends ChangeNotifier {
  HomePageController({
    required BuildContext context,
    required TickerProvider vsync,
    required GlobalKey<ScaffoldState> scaffoldKey,
    required GlobalKey inputBarKey,
    required FocusNode inputFocus,
    required TextEditingController inputController,
    required ChatInputBarController mediaController,
    required ScrollController scrollController,
  }) : this._(
         context,
         vsync,
         scaffoldKey,
         inputBarKey,
         inputFocus,
         inputController,
         mediaController,
         scrollController,
       );

  HomePageController._(
    this._context,
    this._vsync,
    this._scaffoldKey,
    this._inputBarKey,
    this._inputFocus,
    this._inputController,
    this._mediaController,
    this._scrollController,
  ) {
    _initialize();
  }

  // ============================================================================
  // Dependencies (injected)
  // ============================================================================

  final BuildContext _context;
  final TickerProvider _vsync;
  final GlobalKey<ScaffoldState> _scaffoldKey;
  final GlobalKey _inputBarKey;
  final FocusNode _inputFocus;
  final TextEditingController _inputController;
  final ChatInputBarController _mediaController;
  final ScrollController _scrollController;

  // ============================================================================
  // Services & Controllers (created internally)
  // ============================================================================

  late ChatService _chatService;
  late ChatController _chatController;
  late stream_ctrl.StreamController _streamController;
  late GenerationController _generationController;
  late MessageBuilderService _messageBuilderService;
  late MessageGenerationService _messageGenerationService;
  late HomeViewModel _viewModel;
  late OcrService _ocrService;
  late TranslationService _translationService;
  late FileUploadService _fileUploadService;
  late scroll_ctrl.ChatScrollController _scrollCtrl;

  McpProvider? _mcpProvider;
  StreamSubscription<ChatAction>? _chatActionSub;
  ReceivePort? _proactiveCarePort;

  // ============================================================================
  // Animation Controllers
  // ============================================================================

  late AnimationController _convoFadeController;
  late Animation<double> _convoFade;
  bool _chatControllerReady = false;

  // ============================================================================
  // State Fields
  // ============================================================================

  // Translations UI state
  final Map<String, TranslationData> _translations =
      <String, TranslationData>{};

  // Note: GlobalKey-based message navigation removed; using ListObserverController instead.

  // Selection mode
  bool _selecting = false;
  ChatSelectionMode _selectionMode = ChatSelectionMode.share;
  final Set<String> _selectedItems = <String>{};
  bool _showThinkingTools = false;
  bool _showThinkingContent = false;

  // Desktop drag-and-drop
  bool _isDragHovering = false;

  // Multi-AI comparison mode engine
  late final MultiAIEngine multiAIEngine;

  // App lifecycle (currently unused but kept for future notification logic)
  // ignore: unused_field
  bool _appInForeground = true;

  // Sidebar state (tablet/desktop)
  bool _tabletSidebarOpen = true;
  bool _rightSidebarOpen = true;
  double _embeddedSidebarWidth = 300;
  double _rightSidebarWidth = 300;
  bool _desktopUiInited = false;

  // Drawer state
  double _lastDrawerValue = 0.0;

  // Desktop global-search mode
  bool _isGlobalSearchMode = false;
  String _globalSearchQuery = '';

  // Message-level spotlight target after selecting a global search result
  String? _spotlightMessageId;
  int _spotlightToken = 0;

  // Input bar measurement
  double _inputBarHeight = 72;

  UserMessageEditState? _userMessageEditState;

  // Animation tuning
  static const Duration _postSwitchScrollDelay = Duration(milliseconds: 220);
  static const double _sidebarMinWidth = 200;
  static const double _sidebarMaxWidth = 360;

  // ============================================================================
  // Getters - State Access
  // ============================================================================

  GlobalKey<ScaffoldState> get scaffoldKey => _scaffoldKey;
  GlobalKey get inputBarKey => _inputBarKey;
  FocusNode get inputFocus => _inputFocus;
  TextEditingController get inputController => _inputController;
  ChatInputBarController get mediaController => _mediaController;
  ScrollController get scrollController => _scrollController;
  Animation<double> get convoFade => _convoFade;
  AnimationController get convoFadeController => _convoFadeController;

  Map<String, TranslationData> get translations => _translations;
  ChatController get chatController => _chatController;
  bool get selecting => _selecting;
  ChatSelectionMode get selectionMode => _selectionMode;
  Set<String> get selectedItems => _selectedItems;
  int get selectedCount => _selectedItems.length;
  bool get showThinkingTools => _showThinkingTools;
  bool get showThinkingContent => _showThinkingContent;
  bool get isDragHovering => _isDragHovering;

  // Multi-AI comparison mode
  bool get isMultiAIMode => multiAIEngine.isActive;

  bool get tabletSidebarOpen => _tabletSidebarOpen;
  bool get rightSidebarOpen => _rightSidebarOpen;
  double get embeddedSidebarWidth => _embeddedSidebarWidth;
  double get rightSidebarWidth => _rightSidebarWidth;
  double get inputBarHeight => _inputBarHeight;
  bool get desktopUiInited => _desktopUiInited;
  bool get isGlobalSearchMode => _isGlobalSearchMode;
  String get globalSearchQuery => _globalSearchQuery;
  String? get spotlightMessageId => _spotlightMessageId;
  int get spotlightToken => _spotlightToken;
  UserMessageEditState? get userMessageEditState => _userMessageEditState;
  bool get isUserMessageEditActive => _userMessageEditState != null;

  static double get sidebarMinWidth => _sidebarMinWidth;
  static double get sidebarMaxWidth => _sidebarMaxWidth;

  // Delegate to ChatController
  Conversation? get currentConversation => _chatController.currentConversation;
  List<ChatMessage> get messages => _chatController.messages;
  Map<String, int> get versionSelections => _chatController.versionSelections;
  Set<String> get loadingConversationIds =>
      _chatController.loadingConversationIds;
  Map<String, StreamSubscription<dynamic>> get conversationStreams =>
      _chatController.conversationStreams;

  // Delegate to StreamController
  Map<String, stream_ctrl.ReasoningData> get reasoning =>
      _streamController.reasoning;
  Map<String, List<stream_ctrl.ReasoningSegmentData>> get reasoningSegments =>
      _streamController.reasoningSegments;
  Map<String, stream_ctrl.ContentSplitData> get contentSplits =>
      _streamController.contentSplits;
  Map<String, List<ToolUIPart>> get toolParts => _streamController.toolParts;

  /// Lightweight notifier for streaming content updates.
  /// Use this with ValueListenableBuilder in MessageListView to avoid full page rebuilds.
  stream_ctrl.StreamingContentNotifier get streamingContentNotifier =>
      _streamController.streamingContentNotifier;

  // Delegate to scroll controller
  scroll_ctrl.ChatScrollController get scrollCtrl => _scrollCtrl;

  bool get isDesktopPlatform => PlatformUtils.isDesktopTarget;

  bool get isCurrentConversationLoading {
    final cid = currentConversation?.id;
    if (cid == null) return false;
    return loadingConversationIds.contains(cid);
  }

  QueuedChatInput? get currentQueuedInput => _viewModel.currentQueuedInput;

  ValueNotifier<bool> get isProcessingFiles => _viewModel.isProcessingFiles;

  bool get isTemporaryConversation =>
      _chatService.isTemporaryConversation(currentConversation?.id);

  bool get canToggleTemporaryConversation =>
      currentConversation != null && messages.isEmpty;

  @override
  void notifyListeners() {
    if (_chatControllerReady) {
      _chatController.invalidateCache();
    }
    super.notifyListeners();
  }

  // ============================================================================
  // Initialization
  // ============================================================================

  void _initialize() {
    _initializeAnimations();
    _initializeScrollController();
    _initializeControllers();
    _initializeServices();
    _initializeViewModel();
    _wireViewModelCallbacks();
    _initializeProviders();
    _setupKeyboardListeners();
    _setupDesktopFeatures();
    _registerProactiveCarePort();
  }

  /// Register the main-isolate port so the alarm background isolate can
  /// forward proactive care triggers to [HomeViewModel.handleProactiveCareTrigger].
  void _registerProactiveCarePort() {
    if (!Platform.isAndroid || !ProactiveCareAlarmService.isSupported) return;
    _proactiveCarePort = ReceivePort();
    IsolateNameServer.registerPortWithName(
      _proactiveCarePort!.sendPort,
      proactiveCareMainPortName,
    );
    _proactiveCarePort!.listen((dynamic data) {
      final assistantId = data as String?;
      if (assistantId == null || assistantId.isEmpty) return;
      _viewModel.handleProactiveCareTrigger(assistantId);
    });
  }

  void _initializeAnimations() {
    _convoFadeController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 180),
    );
    _convoFade = CurvedAnimation(
      parent: _convoFadeController,
      curve: Curves.easeOutCubic,
    );
    _convoFadeController.value = 1.0;
  }

  void _initializeControllers() {
    _chatService = _context.read<ChatService>();
    _chatController = ChatController(chatService: _chatService);
    _chatControllerReady = true;
    _streamController = stream_ctrl.StreamController(
      chatService: _chatService,
      onStateChanged: () => notifyListeners(),
      getSettingsProvider: () => _context.read<SettingsProvider>(),
      getCurrentConversationId: () => currentConversation?.id,
      onStreamTick: () => _scrollCtrl.autoScrollToBottomIfNeeded(),
    );
  }

  void _initializeServices() {
    _ocrService = OcrService(chatService: _chatService);
    _translationService = TranslationService(
      chatService: _chatService,
      getContext: () => _scaffoldKey.currentContext ?? _context,
    );
    _fileUploadService = FileUploadService(
      getContext: () => _context,
      mediaController: _mediaController,
    );
    _messageBuilderService = MessageBuilderService(
      chatService: _chatService,
      contextProvider: _context,
      ocrHandler: (imagePaths) =>
          _ocrService.getOcrTextForImages(imagePaths, _context),
      geminiThoughtSignatureHandler: _appendGeminiThoughtSignatureForApi,
    );
    _messageBuilderService.ocrTextWrapper = _ocrService.wrapOcrBlock;
    _generationController = GenerationController(
      chatService: _chatService,
      chatController: _chatController,
      streamController: _streamController,
      messageBuilderService: _messageBuilderService,
      contextProvider: _context,
      onStateChanged: () => notifyListeners(),
      getTitleForLocale: _titleForLocale,
    );
    _messageGenerationService = MessageGenerationService(
      chatService: _chatService,
      messageBuilderService: _messageBuilderService,
      generationController: _generationController,
      streamController: _streamController,
      contextProvider: _context,
    );
  }

  void _initializeViewModel() {
    _viewModel = HomeViewModel(
      chatService: _chatService,
      messageBuilderService: _messageBuilderService,
      messageGenerationService: _messageGenerationService,
      generationController: _generationController,
      streamController: _streamController,
      chatController: _chatController,
      contextProvider: _context,
      getTitleForLocale: _titleForLocale,
    );
    _viewModel.addListener(notifyListeners);

    final pipeline = MessagePipeline(
      chatService: _chatService,
      messageGenerationService: _messageGenerationService,
      streamController: _streamController,
      generationController: _generationController,
      executeStream: (ctx, {streamKeyOverride, requestIdOverride}) =>
          _viewModel.executeStream(
            ctx,
            streamKeyOverride: streamKeyOverride,
            requestIdOverride: requestIdOverride,
          ),
    );

    multiAIEngine = MultiAIEngine(
      chatService: _chatService,
      chatController: _chatController,
      messageGenerationService: _messageGenerationService,
      streamController: _streamController,
      pipeline: pipeline,
    );
    multiAIEngine.addListener(notifyListeners);
  }

  void _wireViewModelCallbacks() {
    _viewModel.onError = (error) {
      final l10n = AppLocalizations.of(_context)!;
      showAppSnackBar(
        _context,
        message: _localizeGenerationError(l10n, error),
        type: NotificationType.error,
      );
    };
    _viewModel.onWarning = (warning) {
      final l10n = AppLocalizations.of(_context)!;
      if (warning == 'no_model') {
        showAppSnackBar(
          _context,
          message: l10n.homePagePleaseSelectModel,
          type: NotificationType.warning,
        );
      }
    };
    _viewModel.onScrollToBottom = () => _scrollToBottomSoon();
    _viewModel.onHapticFeedback = () {
      try {
        final settings = _context.read<SettingsProvider>();
        if (settings.hapticsOnGenerate) Haptics.light();
      } catch (_) {}
    };
    _viewModel.onScheduleImageSanitize =
        (messageId, content, {bool immediate = false}) {
          _scheduleInlineImageSanitize(
            messageId,
            latestContent: content,
            immediate: immediate,
          );
        };
    _viewModel.onConversationSwitched = () {
      _restoreMessageUiState();
      _scrollToBottom(animate: false);
    };
    _viewModel.onStreamFinished = () {
      // Trigger UI update when streaming finishes
      notifyListeners();
    };
    _viewModel.onAssistantMessageFinished = _handleAssistantMessageFinished;
  }

  String _localizeGenerationError(AppLocalizations l10n, String error) {
    switch (error) {
      case 'audio_attachment_unsupported':
        return l10n.homePageAudioAttachmentUnsupported;
      default:
        return '${l10n.generationInterrupted}: $error';
    }
  }

  void _initializeScrollController() {
    _scrollCtrl = scroll_ctrl.ChatScrollController(
      scrollController: _scrollController,
      onStateChanged: () => notifyListeners(),
      getAutoScrollEnabled: () =>
          _context.read<SettingsProvider>().autoScrollEnabled,
      getAutoScrollIdleSeconds: () =>
          _context.read<SettingsProvider>().autoScrollIdleSeconds,
    );
  }

  void _initializeProviders() {
    try {
      final quickPhraseProvider = _context.read<QuickPhraseProvider>();
      Future.microtask(() async {
        try {
          await quickPhraseProvider.initialize();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      final instructionProvider = _context.read<InstructionInjectionProvider>();
      Future.microtask(() async {
        try {
          await instructionProvider.initialize();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      final memoryProvider = _context.read<MemoryProvider>();
      Future.microtask(() async {
        try {
          await memoryProvider.initialize();
        } catch (_) {}
      });
    } catch (_) {}
    try {
      _mcpProvider = _context.read<McpProvider>();
      _mcpProvider!.addListener(_onMcpChanged);
    } catch (_) {}
  }

  void _setupKeyboardListeners() {}

  void _setupDesktopFeatures() {
    if (isDesktopPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocus.requestFocus();
      });
    }
    _chatActionSub = ChatActionBus.instance.stream.listen((action) {
      final ctx = _context;
      if (!ctx.mounted) return;
      final settingsProvider = ctx.read<SettingsProvider>();
      switch (action) {
        case ChatAction.newTopic:
          unawaited(createNewConversationAnimated());
          break;
        case ChatAction.toggleLeftPanelTopics:
        case ChatAction.toggleLeftPanelAssistants:
          if (settingsProvider.desktopTopicPosition !=
              DesktopTopicPosition.left) {
            return;
          }
          final wantAssistants =
              (action == ChatAction.toggleLeftPanelAssistants);
          if (!_tabletSidebarOpen) {
            _tabletSidebarOpen = true;
            notifyListeners();
            try {
              settingsProvider.setDesktopSidebarOpen(true);
            } catch (_) {}
          }
          if (wantAssistants) {
            DesktopSidebarTabBus.instance.switchToAssistants();
          } else {
            DesktopSidebarTabBus.instance.switchToTopics();
          }
          break;
        case ChatAction.focusInput:
          if (isDesktopPlatform) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _inputFocus.requestFocus();
            });
          }
          break;
        case ChatAction.switchModel:
          unawaited(showModelSelectSheet(ctx));
          break;
        case ChatAction.enterGlobalSearch:
          enterGlobalSearchMode(preserveQuery: true);
          break;
        case ChatAction.exitGlobalSearch:
          exitGlobalSearchMode(clearQuery: true);
          break;
      }
    });
  }

  void enterGlobalSearchMode({bool preserveQuery = true}) {
    _isGlobalSearchMode = true;
    if (!preserveQuery) _globalSearchQuery = '';
    notifyListeners();
  }

  void exitGlobalSearchMode({bool clearQuery = true}) {
    _isGlobalSearchMode = false;
    if (clearQuery) _globalSearchQuery = '';
    notifyListeners();
  }

  void setGlobalSearchQuery(String value) {
    if (_globalSearchQuery == value) return;
    _globalSearchQuery = value;
    notifyListeners();
  }

  Future<void> openGlobalSearchResult({
    required String conversationId,
    required String messageId,
  }) async {
    await switchConversationAnimated(conversationId);
    // Wait one extra frame so the new conversation's message widgets have
    // had a chance to build for the observer controller.
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
    if (messageId.isNotEmpty) {
      await scrollToMessageId(messageId);
      _spotlightMessageId = messageId;
      _spotlightToken++;
      notifyListeners();
    }
  }

  Future<void> initChat() async {
    final prefs = _context.read<SettingsProvider>();
    final assistantProvider = _context.read<AssistantProvider>();
    final ctx = _context;
    await _chatService.init();
    if (!ctx.mounted) return;
    await assistantProvider.ensureDefaults(ctx);
    if (prefs.newChatOnLaunch) {
      await _createNewConversation();
    } else {
      final conversations = _chatService.getAllConversations();
      if (conversations.isNotEmpty) {
        final recent = conversations.first;
        if ((recent.assistantId ?? '').isNotEmpty) {
          try {
            await assistantProvider.setCurrentAssistant(recent.assistantId!);
          } catch (_) {}
        }
        _chatService.setCurrentConversation(recent.id);
        _chatController.setCurrentConversation(recent);
        _streamController.clearGeminiThoughtSigs();
        _restoreMessageUiState();
        notifyListeners();
        _scrollToBottomSoon(animate: false);
      } else {
        // No conversations exist — create a new empty one so the UI
        // correctly shows the temporary-chat toggle button instead of
        // falling back to "new conversation" button.
        await _createNewConversation();
      }
      recoverMultiAIState();
    }
  }

  void initDesktopUi() {
    if (PlatformUtils.isDesktopTarget && !_desktopUiInited) {
      _desktopUiInited = true;
      try {
        final sp = _context.read<SettingsProvider>();
        _embeddedSidebarWidth = sp.desktopSidebarWidth.clamp(
          _sidebarMinWidth,
          _sidebarMaxWidth,
        );
        _tabletSidebarOpen = sp.desktopSidebarOpen;
        _rightSidebarOpen = sp.desktopRightSidebarOpen;
        _rightSidebarWidth = sp.desktopRightSidebarWidth.clamp(
          _sidebarMinWidth,
          _sidebarMaxWidth,
        );
      } catch (_) {}
    }
  }

  // ============================================================================
  // Public Methods - Message Actions
  // ============================================================================

  Future<ChatInputSubmissionResult> sendMessage(ChatInputData input) async {
    final content = input.text.trim();
    if (content.isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return ChatInputSubmissionResult.rejected;
    }
    final editState = _userMessageEditState;
    if (editState != null) {
      final newMsg = await _saveEditedUserMessageVersion(input, editState);
      if (newMsg == null) return ChatInputSubmissionResult.rejected;
      _exitUserMessageEdit(clearDraft: false);
      await regenerateAtMessage(newMsg);
      return ChatInputSubmissionResult.sent;
    }
    if (currentConversation == null) {
      await _createNewConversation();
    }

    ChatInputSubmissionResult result;
    if (multiAIEngine.isActive &&
        multiAIEngine.mode == MultiAIMode.synthesize) {
      result = await _sendSynthesize(input);
    } else if (multiAIEngine.isActive) {
      if (!_context.mounted) return ChatInputSubmissionResult.rejected;
      final settings = _context.read<SettingsProvider>();
      final assistant = await _context
          .read<AssistantProvider>()
          .getLoadedCurrentAssistant();
      final gid = await multiAIEngine.startRound(
        input: input,
        conversation: currentConversation!,
        settings: settings,
        assistant: assistant,
      );
      result = gid.isNotEmpty
          ? ChatInputSubmissionResult.sent
          : ChatInputSubmissionResult.rejected;
    } else {
      result = await _viewModel.sendMessage(input);
    }
    if (result != ChatInputSubmissionResult.rejected) {
      notifyListeners();
    }
    return result;
  }

  Future<ChatInputSubmissionResult> _sendSynthesize(ChatInputData input) async {
    if (currentConversation == null) return ChatInputSubmissionResult.rejected;

    final allMsgs = _chatController.allMessagesForCurrentConversationContext();
    final contextMsgs = MultiAIEngine.selectMessagesBeforeMultiAI(allMsgs);

    // Fork new conversation with messages before first multi-AI anchor
    final newConvo = await _chatService.forkConversation(
      title: _titleForLocale(_context),
      assistantId: currentConversation!.assistantId,
      sourceMessages: contextMsgs,
    );

    // Switch to new conversation
    _chatService.setCurrentConversation(newConvo.id);
    _chatController.setCurrentConversation(newConvo);
    _viewModel.restoreMessageUiState();

    // Generate XML from all messages with current version selections
    final xml = multiAIEngine.multiRoundsToXML(
      allMsgs,
      multiAIEngine.selectedVersionByThread,
    );
    final fullContent = '${input.text}\n\n$xml';

    // Send as normal single-model message
    final syntheticInput = ChatInputData(
      text: fullContent,
      imagePaths: input.imagePaths,
      documents: input.documents,
      allowImagesApiRouting: input.allowImagesApiRouting,
    );
    final result = await _viewModel.sendMessage(syntheticInput);
    if (result != ChatInputSubmissionResult.rejected) {
      // Reset engine to continue mode so the original conversation's
      // mode switch row shows "继续" as active when user switches back.
      await multiAIEngine.setMode(MultiAIMode.continue_);
      notifyListeners();
    }
    return result;
  }

  Future<void> sendSuggestion(String suggestion) async {
    final text = suggestion.trim();
    if (text.isEmpty) return;
    final settings = _context.read<SettingsProvider>();
    if (settings.insertSuggestionOnTapOnly) {
      _replaceInputWithSuggestion(text);
      return;
    }
    await sendMessage(ChatInputData(text: text));
  }

  void _replaceInputWithSuggestion(String text) {
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_context.mounted) return;
      _inputFocus.requestFocus();
    });
    notifyListeners();
  }

  Future<void> toggleTemporaryConversation() async {
    await _viewModel.toggleTemporaryConversation();
  }

  void cancelQueuedMessage() {
    final restored = _viewModel.cancelCurrentQueuedInput();
    if (restored == null) return;

    _inputController.value = TextEditingValue(
      text: restored.text,
      selection: TextSelection.collapsed(offset: restored.text.length),
      composing: TextRange.empty,
    );
    _mediaController.restoreInput(restored);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_context.mounted) return;
      _inputFocus.requestFocus();
    });
    notifyListeners();
  }

  bool _isRetryableInMultiAI(ChatMessage message) {
    // In multi-AI mode with active rounds, only the last assistant message or
    // its immediately preceding user message can be retried.
    if (!multiAIEngine.isActive ||
        _chatController.subgroupActiveGroupIds.isEmpty) {
      return true;
    }

    final msgs = _chatController.messages;
    ChatMessage? lastAssistant;
    int? lastAssistantIdx;
    for (int i = msgs.length - 1; i >= 0; i--) {
      if (msgs[i].role == 'assistant' && msgs[i].subgroupId != null) {
        lastAssistant = msgs[i];
        lastAssistantIdx = i;
        break;
      }
    }
    if (lastAssistant == null) return true;

    // Allow retry of the last subgroup assistant message.
    if (message.id == lastAssistant.id) return true;

    // Allow retry of the user message preceding the last assistant round.
    // Walk backwards past sibling assistants to find the anchor user.
    if (lastAssistantIdx != null && lastAssistantIdx > 0) {
      for (int i = lastAssistantIdx - 1; i >= 0; i--) {
        if (msgs[i].role == 'user') {
          final msgGid = message.groupId ?? message.id;
          final anchorGid = msgs[i].groupId ?? msgs[i].id;
          if (msgGid == anchorGid) return true;
          break; // 找到第一个 user 就停，不穿透到更早轮次
        }
      }
    }

    return false;
  }

  Future<void> regenerateAtMessage(
    ChatMessage message, {
    bool assistantAsNewReply = false,
  }) async {
    if (currentConversation == null) return;

    final l10n = AppLocalizations.of(_context)!;

    if (!multiAIEngine.isActive &&
        _chatController.subgroupActiveGroupIds.isNotEmpty) {
      showAppSnackBar(
        _context,
        message: l10n.multiAIRetryBlockedUnresolvedComparison,
        type: NotificationType.warning,
      );
      return;
    }

    if (!_isRetryableInMultiAI(message)) {
      showAppSnackBar(
        _context,
        message: l10n.multiAIRetryBlockedUnresolvedComparison,
        type: NotificationType.warning,
      );
      return;
    }

    if (multiAIEngine.isActive &&
        _chatController.subgroupActiveGroupIds.isEmpty &&
        message.role == 'assistant') {
      _tagTriggerMessageForMultiAI(message);
      final settings = _context.read<SettingsProvider>();
      final assistant = _context.read<AssistantProvider>().currentAssistant;
      await multiAIEngine.startRoundFromHistory(
        triggerMessage: message,
        conversation: currentConversation!,
        settings: settings,
        assistant: assistant,
      );
      notifyListeners();
      return;
    }

    if (message.role == 'user' &&
        multiAIEngine.isActive &&
        _chatController.subgroupActiveGroupIds.isEmpty) {
      final nextAssistant = _findNextAssistantAfter(message);
      final settings = _context.read<SettingsProvider>();
      final assistant = _context.read<AssistantProvider>().currentAssistant;
      if (nextAssistant != null) {
        _tagTriggerMessageForMultiAI(nextAssistant);
        await multiAIEngine.startRoundFromHistory(
          triggerMessage: nextAssistant,
          conversation: currentConversation!,
          settings: settings,
          assistant: assistant,
        );
      } else {
        await multiAIEngine.startRoundFromUserMessage(
          userMessage: message,
          conversation: currentConversation!,
          settings: settings,
          assistant: assistant,
        );
      }
      notifyListeners();
      return;
    }

    if (message.role == 'user' &&
        multiAIEngine.isActive &&
        _chatController.subgroupActiveGroupIds.isNotEmpty) {
      final anchorUserMsgId = message.groupId ?? message.id;
      final settings = _context.read<SettingsProvider>();
      final assistant = _context.read<AssistantProvider>().currentAssistant;
      await multiAIEngine.retryRound(
        anchorUserMsgId: anchorUserMsgId,
        conversation: currentConversation!,
        settings: settings,
        assistant: assistant,
      );
      notifyListeners();
      return;
    }

    final settings = _context.read<SettingsProvider>();
    if (settings.regenerateDeleteTrailingMessages) {
      final versioning = _messageGenerationService
          .calculateRegenerationVersioning(
            message: message,
            messages: messages,
            assistantAsNewReply: assistantAsNewReply,
          );
      if (versioning.lastKeep >= 0 &&
          versioning.lastKeep < messages.length - 1) {
        for (int i = versioning.lastKeep + 1; i < messages.length; i++) {
          _translations.remove(messages[i].id);
        }
      }
    }

    final success = await _viewModel.regenerateAtMessage(
      message,
      assistantAsNewReply: assistantAsNewReply,
      allowImagesApiRouting: _mediaController.allowImagesApiRouting,
    );
    if (success) {
      notifyListeners();
    }
  }

  Future<void> retryMultiAIThread({
    required String threadId,
    required String anchorUserMsgId,
    required ChatMessage message,
  }) async {
    if (currentConversation == null || !multiAIEngine.isActive) return;
    final settings = _context.read<SettingsProvider>();
    final assistant = _context.read<AssistantProvider>().currentAssistant;
    await multiAIEngine.retryThread(
      threadId: threadId,
      anchorUserMsgId: anchorUserMsgId,
      conversation: currentConversation!,
      settings: settings,
      assistant: assistant,
    );
    notifyListeners();
  }

  Future<void> submitRecoveredAskUserAnswer(
    ChatMessage message,
    ToolUIPart part,
    AskUserResult result,
  ) async {
    if (currentConversation == null) return;

    final content = result.toJsonString();
    await _chatService.upsertToolEvent(
      message.id,
      id: part.id,
      name: part.toolName,
      arguments: part.arguments,
      content: content,
    );

    final parts = List<ToolUIPart>.of(
      _streamController.getToolParts(message.id) ?? const <ToolUIPart>[],
    );
    final idx = parts.indexWhere(
      (candidate) =>
          candidate.id == part.id ||
          (candidate.id.isEmpty && candidate.toolName == part.toolName),
    );
    final answeredPart = ToolUIPart(
      id: part.id,
      toolName: part.toolName,
      arguments: part.arguments,
      content: content,
      loading: false,
    );
    if (idx >= 0) {
      parts[idx] = answeredPart;
    } else {
      parts.add(answeredPart);
    }
    _streamController.setToolParts(message.id, parts);
    notifyListeners();

    await _viewModel.continueAssistantMessageAfterToolAnswer(
      message,
      allowImagesApiRouting: _mediaController.allowImagesApiRouting,
    );
  }

  Future<void> cancelStreaming() async {
    await _viewModel.cancelStreaming();
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - Conversation Management
  // ============================================================================

  Future<void> switchConversationAnimated(String id) async {
    if (currentConversation?.id == id) return;
    multiAIEngine.exit();
    try {
      await _viewModel.flushCurrentConversationProgress();
    } catch (_) {}
    _exitUserMessageEdit(clearDraft: true);
    if (!isDesktopPlatform) {
      try {
        await _convoFadeController.reverse();
      } catch (_) {}
    } else {
      try {
        _convoFadeController.stop();
        _convoFadeController.value = 1.0;
      } catch (_) {}
    }

    await _viewModel.switchConversation(id);
    _scrollCtrl.clearObserverCache();
    recoverMultiAIState();
    notifyListeners();
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
    _scrollToBottom(animate: false);

    if (!isDesktopPlatform) {
      try {
        await _convoFadeController.forward();
      } catch (_) {}
    }
    if (isDesktopPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocus.requestFocus();
      });
    }
  }

  Future<void> createNewConversationAnimated() async {
    try {
      await _viewModel.flushCurrentConversationProgress();
    } catch (_) {}
    _exitUserMessageEdit(clearDraft: true);
    if (!isDesktopPlatform) {
      try {
        await _convoFadeController.reverse();
      } catch (_) {}
    }
    await _createNewConversation();
    _scrollCtrl.clearObserverCache();
    if (!isDesktopPlatform) {
      try {
        await _convoFadeController.forward();
      } catch (_) {}
    }
    if (isDesktopPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocus.requestFocus();
      });
    }
  }

  Future<void> _createNewConversation() async {
    _exitUserMessageEdit(clearDraft: true);
    _translations.clear();
    await _viewModel.createNewConversation();
    notifyListeners();
    _scrollToBottomSoon(animate: false);
  }

  Future<void> clearContext() async {
    await _viewModel.clearContext();
    notifyListeners();
  }

  /// Compress context: summarize via LLM, create new conversation.
  /// Returns null on success, or an error string on failure.
  Future<String?> compressContext({
    required CompressContextOptions options,
  }) async {
    final result = await _viewModel.compressContext(options: options);
    if (result == null) {
      // Success - switched to new conversation
      _translations.clear();
      notifyListeners();
      _scrollToBottomSoon(animate: false);
    }
    return result;
  }

  // ============================================================================
  // Public Methods - Message Operations
  // ============================================================================

  Future<void> deleteMessage({
    required ChatMessage message,
    required Map<String, List<ChatMessage>> byGroup,
  }) async {
    _translations.remove(message.id);
    await _viewModel.deleteMessage(message: message, byGroup: byGroup);
    notifyListeners();
  }

  Future<void> deleteAllMessageVersions({
    required ChatMessage message,
    required Map<String, List<ChatMessage>> byGroup,
  }) async {
    final gid = (message.groupId ?? message.id);
    for (final version in byGroup[gid] ?? const <ChatMessage>[]) {
      _translations.remove(version.id);
    }
    await _viewModel.deleteAllMessageVersions(
      message: message,
      byGroup: byGroup,
    );
    notifyListeners();
  }

  Future<void> deleteSelectedMessages({required bool deleteAllVersions}) async {
    final selectedMessageIds = Set<String>.of(_selectedItems);
    if (selectedMessageIds.isEmpty) return;

    final deletedMessageIds = _selectedMessageIdsForDeletion(
      selectedMessageIds,
      deleteAllVersions: deleteAllVersions,
    );
    for (final id in deletedMessageIds) {
      _translations.remove(id);
    }
    await _viewModel.deleteMessages(
      messageIds: selectedMessageIds,
      deleteAllVersions: deleteAllVersions,
    );
    _selecting = false;
    _selectedItems.clear();
    notifyListeners();
  }

  Set<String> _selectedMessageIdsForDeletion(
    Set<String> selectedMessageIds, {
    required bool deleteAllVersions,
  }) {
    if (!deleteAllVersions) return selectedMessageIds;

    final selectedGroupIds = <String>{};
    final allMessages = _allCurrentConversationMessages();
    for (final message in allMessages) {
      if (selectedMessageIds.contains(message.id)) {
        selectedGroupIds.add(message.groupId ?? message.id);
      }
    }
    return {
      for (final message in allMessages)
        if (selectedGroupIds.contains(message.groupId ?? message.id))
          message.id,
    };
  }

  Future<void> forkConversation(ChatMessage message) async {
    if (currentConversation == null) return;
    if (!isDesktopPlatform) {
      await _convoFadeController.reverse();
    }

    await _viewModel.forkConversation(message);
    notifyListeners();
    try {
      await WidgetsBinding.instance.endOfFrame;
    } catch (_) {}
    _scrollToBottom(animate: false);
    if (!isDesktopPlatform) {
      await _convoFadeController.forward();
    }
  }

  Future<void> editMessage(ChatMessage message) async {
    if (message.role == 'user') {
      await startUserMessageEdit(message);
      return;
    }

    final ctx = _context;
    if (!ctx.mounted) return;
    final isDesktop = isDesktopPlatform;
    final Future<MessageEditResult?> future = isDesktop
        ? showMessageEditDesktopDialog(ctx, message: message)
        : showMessageEditSheet(ctx, message: message);
    final MessageEditResult? result = await future;
    if (result == null) return;

    if (currentConversation != null) {
      await _chatService.clearConversationSuggestions(currentConversation!.id);
      _viewModel.updateCurrentConversation(
        _chatService.getConversation(currentConversation!.id),
      );
    }

    final newMsg = await _chatService.appendMessageVersion(
      messageId: message.id,
      content: result.content,
    );
    if (newMsg == null) return;

    if (_chatController.appendPersistedTailMessage(newMsg)) {
      _viewModel.restoreMessageUiState();
    }
    final gid = (newMsg.groupId ?? newMsg.id);
    versionSelections[gid] = newMsg.version;
    notifyListeners();

    if (currentConversation != null) {
      try {
        await _chatService.setSelectedVersion(
          currentConversation!.id,
          gid,
          newMsg.version,
        );
      } catch (_) {}
    }

    if (!result.shouldSend) return;
    if (message.role == 'assistant') {
      await regenerateAtMessage(newMsg, assistantAsNewReply: true);
    }
  }

  Future<void> startUserMessageEdit(ChatMessage message) async {
    final ctx = _context;
    if (!ctx.mounted) return;
    if (message.role != 'user') {
      final l10n = AppLocalizations.of(ctx)!;
      showAppSnackBar(
        ctx,
        message: l10n.userMessageEditUnsupportedSnackbar,
        type: NotificationType.warning,
      );
      return;
    }

    final hasDraft =
        _inputController.text.trim().isNotEmpty ||
        _mediaController.hasDraftMedia;
    if (hasDraft) {
      final overwrite = await _confirmOverwriteInputDraft(ctx);
      if (overwrite != true) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!ctx.mounted) return;
    }

    _enterUserMessageEdit(message);
  }

  void cancelUserMessageEdit() {
    _exitUserMessageEdit(clearDraft: true);
  }

  void focusUserMessageEditInput() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_context.mounted) return;
      _inputFocus.requestFocus();
    });
  }

  Future<void> saveUserMessageEditOnly() async {
    final editState = _userMessageEditState;
    if (editState == null) return;
    final input = _mediaController.snapshotInput(_inputController.text);
    if (input.text.trim().isEmpty &&
        input.imagePaths.isEmpty &&
        input.documents.isEmpty) {
      return;
    }
    final newMsg = await _saveEditedUserMessageVersion(input, editState);
    if (newMsg == null) return;
    _exitUserMessageEdit(clearDraft: true);
  }

  void _enterUserMessageEdit(ChatMessage message) {
    final input = _messageBuilderService.parseInputFromRaw(
      message.content,
      includeMediaFilePathsAsImages: false,
    );
    final messageId = message.id;
    _inputController.value = TextEditingValue(
      text: input.text,
      selection: TextSelection.collapsed(offset: input.text.length),
      composing: TextRange.empty,
    );
    _mediaController.restoreInput(input);
    _userMessageEditState = UserMessageEditState(
      messageId: message.id,
      previewText: input.text.isNotEmpty ? input.text : message.content.trim(),
    );
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_context.mounted) return;
      if (_userMessageEditState?.messageId != messageId) return;
      _inputFocus.requestFocus();
    });
  }

  void _exitUserMessageEdit({required bool clearDraft}) {
    if (_userMessageEditState == null) return;
    _userMessageEditState = null;
    if (clearDraft) {
      _mediaController.clearDraft();
    }
    notifyListeners();
    if (PlatformUtils.isMobileTarget) {
      dismissKeyboard();
    }
  }

  Future<ChatMessage?> _saveEditedUserMessageVersion(
    ChatInputData input,
    UserMessageEditState editState,
  ) async {
    final conversation = currentConversation;
    if (conversation == null) return null;
    final assistant = _context.read<AssistantProvider>().currentAssistant;
    final content = MessageGenerationService.buildPersistedUserMessageContent(
      input,
      assistant: assistant,
    );

    await _chatService.clearConversationSuggestions(conversation.id);
    _viewModel.updateCurrentConversation(
      _chatService.getConversation(conversation.id),
    );

    final newMsg = await _chatService.appendMessageVersion(
      messageId: editState.messageId,
      content: content,
    );
    if (newMsg == null) return null;

    if (_chatController.appendPersistedTailMessage(newMsg)) {
      _viewModel.restoreMessageUiState();
    }
    final gid = newMsg.groupId ?? newMsg.id;
    versionSelections[gid] = newMsg.version;
    try {
      await _chatService.setSelectedVersion(
        conversation.id,
        gid,
        newMsg.version,
      );
    } catch (_) {}
    notifyListeners();
    return newMsg;
  }

  Future<bool?> _confirmOverwriteInputDraft(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.userMessageEditOverwriteTitle),
        content: Text(l10n.userMessageEditOverwriteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.homePageCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.modelDetailSheetConfirmButton),
          ),
        ],
      ),
    );
  }

  Future<void> translateMessage(ChatMessage message) async {
    final ctx = _scaffoldKey.currentContext ?? _context;
    final l10n = AppLocalizations.of(ctx)!;

    final result = await _translationService.translateMessage(
      message: message,
      onTranslationStarted: () {
        final loadingMessage = message.copyWith(
          translation: l10n.homePageTranslating,
        );
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          messages[index] = loadingMessage;
        }
        // Messages are mutated externally; invalidate ChatController caches so
        // collapsed/grouped views reflect updates immediately.
        _chatController.invalidateCache();
        _translations[message.id] = TranslationData();
        notifyListeners();
      },
      onTranslationUpdate: (translation) {
        final updatingMessage = message.copyWith(translation: translation);
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          messages[index] = updatingMessage;
        }
        _chatController.invalidateCache();
        notifyListeners();
      },
      onTranslationCleared: () {
        final clearedMessage = message.copyWith(translation: '');
        final index = messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          messages[index] = clearedMessage;
        }
        _chatController.invalidateCache();
        _translations.remove(message.id);
        notifyListeners();
      },
    );

    if (result.isCancelled) return;
    if (!ctx.mounted) return;

    if (result.type == TranslationResultType.noModelConfigured) {
      showAppSnackBar(
        ctx,
        message: l10n.homePagePleaseSetupTranslateModel,
        type: NotificationType.warning,
      );
      return;
    }

    if (result.type == TranslationResultType.error) {
      showAppSnackBar(
        ctx,
        message: l10n.homePageTranslateFailed(result.errorMessage ?? ''),
        type: NotificationType.error,
      );
    }
  }

  void _handleAssistantMessageFinished(ChatMessage message) {
    if (!_context.mounted || message.role != 'assistant') return;
    final settings = _context.read<SettingsProvider>();
    if (!settings.ttsAutoPlayAssistantReplies) return;
    unawaited(_speakAssistantMessage(message, autoPlay: true));
  }

  Future<void> speakMessage(ChatMessage message) async {
    await _speakAssistantMessage(message, autoPlay: false);
  }

  Future<void> _speakAssistantMessage(
    ChatMessage message, {
    required bool autoPlay,
  }) async {
    final tts = _context.read<TtsProvider>();
    if (!autoPlay && tts.playbackState.isActive) {
      await tts.stop();
      return;
    }

    if (PlatformUtils.isDesktopTarget) {
      final sp = _context.read<SettingsProvider>();
      final hasNetworkTts = sp.selectedTtsService != null;
      if (!hasNetworkTts && !tts.isAvailable) {
        showAppSnackBar(
          _context,
          message: AppLocalizations.of(_context)!.desktopTtsPleaseAddProvider,
          type: NotificationType.warning,
        );
        return;
      }
    }

    final sp = _context.read<SettingsProvider>();
    final text = TtsTextSelection.apply(
      message.content,
      mode: sp.ttsTextSelectionMode,
    );
    if (text.trim().isEmpty) return;
    await tts.speak(text);
  }

  void shareMessage(int messageIndex, List<ChatMessage> messageList) {
    startMessageSelection(
      messageIndex: messageIndex,
      messageList: messageList,
      mode: ChatSelectionMode.share,
    );
  }

  void startMessageSelection({
    required int messageIndex,
    required List<ChatMessage> messageList,
    required ChatSelectionMode mode,
  }) {
    dismissKeyboard();
    _selecting = true;
    _selectionMode = mode;
    _selectedItems.clear();
    _showThinkingTools = false;
    _showThinkingContent = false;

    if (messageIndex < 0 || messageIndex >= messageList.length) {
      notifyListeners();
      return;
    }

    final anchor = messageList[messageIndex];
    const userRole = 'user';
    const assistantRole = 'assistant';

    int? findPrevRoleIndex(int start, String role) {
      for (int i = start; i >= 0; i--) {
        if (messageList[i].role == role) return i;
      }
      return null;
    }

    int? findNextRoleIndex(int start, String role) {
      for (int i = start; i < messageList.length; i++) {
        if (messageList[i].role == role) return i;
      }
      return null;
    }

    void addIfSelectable(int? index) {
      if (index == null) return;
      final m = messageList[index];
      if (m.role == userRole || m.role == assistantRole) {
        _selectedItems.add(m.id);
      }
    }

    if (anchor.role == assistantRole) {
      addIfSelectable(messageIndex);
      addIfSelectable(findPrevRoleIndex(messageIndex - 1, userRole));
    } else if (anchor.role == userRole) {
      addIfSelectable(messageIndex);
      addIfSelectable(findNextRoleIndex(messageIndex + 1, assistantRole));
    } else {
      addIfSelectable(findPrevRoleIndex(messageIndex, userRole));
      addIfSelectable(findNextRoleIndex(messageIndex, assistantRole));
    }

    if (_selectedItems.isEmpty &&
        (anchor.role == userRole || anchor.role == assistantRole)) {
      _selectedItems.add(anchor.id);
    }
    notifyListeners();
  }

  bool get selectedMessagesIncludeMultipleVersions {
    return _selectedSelectionGroupIds().any((groupId) {
      var count = 0;
      for (final message in _allCurrentConversationMessages()) {
        if ((message.groupId ?? message.id) == groupId) count++;
        if (count > 1) return true;
      }
      return false;
    });
  }

  Set<String> _selectedSelectionGroupIds() {
    if (_selectedItems.isEmpty) return const <String>{};
    return {
      for (final message
          in _chatController.allCollapsedMessagesForCurrentConversation())
        if (_selectedItems.contains(message.id)) message.groupId ?? message.id,
    };
  }

  List<ChatMessage> _allCurrentConversationMessages() {
    final conversation = currentConversation;
    if (conversation == null) return const <ChatMessage>[];
    return _chatService.getMessagesRange(
      conversation.id,
      start: 0,
      limit: _chatService.getMessageCount(conversation.id),
    );
  }

  void selectAll() {
    final collapsed = _chatController
        .allCollapsedMessagesForCurrentConversation();
    for (final m in collapsed) {
      if (m.role == 'user' || m.role == 'assistant') {
        _selectedItems.add(m.id);
      }
    }
    notifyListeners();
  }

  void toggleSelectAll() {
    final collapsed = _chatController
        .allCollapsedMessagesForCurrentConversation();
    final selectable = collapsed
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .toList();
    if (selectable.isEmpty) return;

    final allSelected = selectable.every((m) => _selectedItems.contains(m.id));
    if (allSelected) {
      for (final m in selectable) {
        _selectedItems.remove(m.id);
      }
    } else {
      for (final m in selectable) {
        _selectedItems.add(m.id);
      }
    }
    notifyListeners();
  }

  void invertSelection() {
    final collapsed = _chatController
        .allCollapsedMessagesForCurrentConversation();
    for (final m in collapsed) {
      if (m.role != 'user' && m.role != 'assistant') continue;
      if (_selectedItems.contains(m.id)) {
        _selectedItems.remove(m.id);
      } else {
        _selectedItems.add(m.id);
      }
    }
    notifyListeners();
  }

  void toggleThinkingTools() {
    _showThinkingTools = !_showThinkingTools;
    if (!_showThinkingTools) _showThinkingContent = false;
    notifyListeners();
  }

  void toggleThinkingContent() {
    if (!_showThinkingTools) return;
    _showThinkingContent = !_showThinkingContent;
    notifyListeners();
  }

  List<ChatMessage> _selectedCollapsedMessages() {
    final convo = currentConversation;
    if (convo == null) return const <ChatMessage>[];
    final storedMessages = _chatService.getMessagesRange(
      convo.id,
      start: 0,
      limit: _chatService.getMessageCount(convo.id),
    );
    return ChatController.selectedCollapsedMessagesForExport(
      collapsedMessages: _chatController.collapseVersions(storedMessages),
      selectedIds: _selectedItems,
      storedMessages: storedMessages,
    );
  }

  Future<void> exportSelectedAsMarkdown() async {
    final convo = currentConversation;
    if (convo == null) return;

    final selected = _selectedCollapsedMessages();
    if (selected.isEmpty) {
      final l10n = AppLocalizations.of(_context)!;
      showAppSnackBar(
        _context,
        message: l10n.homePageSelectMessagesToShare,
        type: NotificationType.info,
      );
      return;
    }

    final showThinkingTools = _showThinkingTools;
    final showThinkingContent = _showThinkingContent;
    cancelSelection();
    await exportChatMessagesMarkdown(
      _context,
      conversation: convo,
      messages: selected,
      showThinkingAndToolCards: showThinkingTools,
      expandThinkingContent: showThinkingContent,
    );
  }

  Future<void> exportSelectedAsTxt() async {
    final convo = currentConversation;
    if (convo == null) return;

    final selected = _selectedCollapsedMessages();
    if (selected.isEmpty) {
      final l10n = AppLocalizations.of(_context)!;
      showAppSnackBar(
        _context,
        message: l10n.homePageSelectMessagesToShare,
        type: NotificationType.info,
      );
      return;
    }

    final showThinkingTools = _showThinkingTools;
    final showThinkingContent = _showThinkingContent;
    cancelSelection();
    await exportChatMessagesTxt(
      _context,
      conversation: convo,
      messages: selected,
      showThinkingAndToolCards: showThinkingTools,
      expandThinkingContent: showThinkingContent,
    );
  }

  Future<void> exportSelectedAsImage() async {
    final convo = currentConversation;
    if (convo == null) return;

    final selected = _selectedCollapsedMessages();
    if (selected.isEmpty) {
      final l10n = AppLocalizations.of(_context)!;
      showAppSnackBar(
        _context,
        message: l10n.homePageSelectMessagesToShare,
        type: NotificationType.info,
      );
      return;
    }

    final showThinkingTools = _showThinkingTools;
    final showThinkingContent = _showThinkingContent;
    cancelSelection();
    await exportChatMessagesImage(
      _context,
      conversation: convo,
      messages: selected,
      showThinkingAndToolCards: showThinkingTools,
      expandThinkingContent: showThinkingContent,
    );
  }

  Future<void> confirmSelection() async {
    final convo = currentConversation;
    if (convo == null) return;
    final selected = _selectedCollapsedMessages();
    if (selected.isEmpty) {
      final l10n = AppLocalizations.of(_context)!;
      showAppSnackBar(
        _context,
        message: l10n.homePageSelectMessagesToShare,
        type: NotificationType.info,
      );
      return;
    }
    _selecting = false;
    notifyListeners();
    await showChatExportSheet(
      _context,
      conversation: convo,
      selectedMessages: selected,
    );
    _selectedItems.clear();
    notifyListeners();
  }

  void cancelSelection() {
    _selecting = false;
    _selectionMode = ChatSelectionMode.share;
    _selectedItems.clear();
    notifyListeners();
  }

  void toggleSelection(String messageId, bool selected) {
    if (selected) {
      _selectedItems.add(messageId);
    } else {
      _selectedItems.remove(messageId);
    }
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - Version Management
  // ============================================================================

  Future<void> setSelectedVersion(String groupId, int version) async {
    versionSelections[groupId] = version;
    await _chatService.setSelectedVersion(
      currentConversation!.id,
      groupId,
      version,
    );
    notifyListeners();
  }

  List<ChatMessage> collapseVersions(List<ChatMessage> items) {
    return _chatController.collapseVersions(items);
  }

  // ============================================================================
  // Public Methods - Multi-AI Comparison Mode
  // ============================================================================

  void exitMultiAIMode() => multiAIEngine.exit();

  /// Recover multi-AI state from current conversation's messages.
  void recoverMultiAIState() {
    if (currentConversation == null) return;
    multiAIEngine.recoverFromMessages(_chatController.messages);
    if (multiAIEngine.isActive) {
      _chatController.invalidateCache();
    }
  }

  /// Get current multi-AI model selections for input bar badge.
  List<ModelSelection> get multiAIModelSelections => multiAIEngine.models;

  /// Whether the "启动对比" action should be visible on the message more sheet.
  bool get canStartMultiAIComparison =>
      multiAIEngine.isActive &&
      multiAIEngine.models.length >= 2 &&
      _chatController.subgroupActiveGroupIds.isEmpty;

  /// Tag a trigger assistant message with its matching subgroupId from the
  /// engine's model list. If the trigger's model matches a pre-selected model,
  /// the message gets tagged so it becomes part of the multi-AI round.
  /// Otherwise it's left untouched (stays as a regular assistant message).
  Future<void> _tagTriggerMessageForMultiAI(ChatMessage triggerMessage) async {
    final threadIds = multiAIEngine.threadIds.toList();
    final triggerKey = '${triggerMessage.providerId}|${triggerMessage.modelId}';
    final modelIdx = multiAIEngine.models.indexWhere(
      (m) => '${m.providerKey}|${m.modelId}' == triggerKey,
    );
    if (modelIdx < 0) return;
    final tid = threadIds[modelIdx];
    final idx = _chatController.messages.indexWhere(
      (m) => m.id == triggerMessage.id,
    );
    if (idx == -1) return;
    final updated = triggerMessage.copyWith(subgroupId: tid);
    _chatController.messages[idx] = updated;
    await _chatService.updateMessage(
      triggerMessage.id,
      subgroupId: tid,
      content: updated.content,
      totalTokens: updated.totalTokens,
      isStreaming: updated.isStreaming,
    );
  }

  /// Find the first assistant message immediately after [target].
  ChatMessage? _findNextAssistantAfter(ChatMessage target) {
    final msgs = _chatController.messages;
    int idx = msgs.indexWhere((m) => m.id == target.id);
    if (idx < 0) return null;
    for (int i = idx + 1; i < msgs.length; i++) {
      if (msgs[i].role == 'assistant') return msgs[i];
    }
    return null;
  }

  /// Handle "启动对比" (Start Comparison) action from assistant message more
  /// sheet. Requires multi-select mode already active with ≥2 models and zero
  /// existing subgroup messages in the conversation.
  Future<void> handleMultiAIAction(ChatMessage triggerMessage) async {
    if (triggerMessage.role != 'assistant') return;
    if (currentConversation == null) return;
    if (!multiAIEngine.isActive || multiAIEngine.models.length < 2) return;
    // Prevent starting comparison after multi-AI rounds have begun.
    if (_chatController.subgroupActiveGroupIds.isNotEmpty) return;

    await _tagTriggerMessageForMultiAI(triggerMessage);

    _chatController.invalidateCache();
    notifyListeners();

    if (!_context.mounted) return;
    final settings = _context.read<SettingsProvider>();
    final assistant = _context.read<AssistantProvider>().currentAssistant;
    unawaited(
      multiAIEngine
          .startRoundFromHistory(
            triggerMessage: triggerMessage,
            conversation: currentConversation!,
            settings: settings,
            assistant: assistant,
          )
          .then((_) {
            notifyListeners();
          }),
    );
  }

  /// Switch the multi-AI engine to synthesize mode.
  ///
  /// Shows a task type selector (bottom sheet / dialog), switches to
  /// single-select on the model selector, pre-fills the chat input with the
  /// chosen prompt, and calls [MultiAIEngine.setMode].
  Future<void> switchToSynthesizeMode() async {
    final engine = multiAIEngine;
    if (engine.mode == MultiAIMode.synthesize) return;

    // Show task type selector
    final taskType = await showSynthesizeTaskSelector(_context);
    if (taskType == null) return; // user cancelled

    // Switch engine mode
    await engine.setMode(MultiAIMode.synthesize);

    // Pre-fill prompt
    if (!_context.mounted) return;
    final l10n = AppLocalizations.of(_context)!;
    final task = synthesizeTasks.firstWhere((t) => t.type == taskType);
    final prompt = _resolveSynthesizePrompt(l10n, task.defaultPromptKey);
    _inputController.text = prompt;
    _inputController.selection = TextSelection.collapsed(offset: prompt.length);

    notifyListeners();
  }

  String _resolveSynthesizePrompt(AppLocalizations l10n, String key) {
    switch (key) {
      case 'multiAISynthesizeSummarizePrompt':
        return l10n.multiAISynthesizeSummarizePrompt;
      case 'multiAISynthesizeFusePrompt':
        return l10n.multiAISynthesizeFusePrompt;
      case 'multiAISynthesizeCommentPrompt':
        return l10n.multiAISynthesizeCommentPrompt;
      default:
        return key;
    }
  }

  /// Enter multi-AI mode with pre-selected models (from model selector multi-select).
  void enterMultiAIMode(List<ModelSelection> models) {
    if (models.length < 2 || currentConversation == null) return;
    final threadIds = List<String>.generate(
      models.length,
      (_) => const Uuid().v4(),
    );
    multiAIEngine.enter(models, existingThreadIds: threadIds);
    notifyListeners();
  }

  /// Show multi-model selector from input bar.
  Future<void> showMultiAIModelSelector() async {
    if (multiAIEngine.isActive) return;
    final models = await showMultiModelSelector(_context);
    if (models == null || models.length < 2) return;
    if (currentConversation == null) return;

    final threadIds = List<String>.generate(
      models.length,
      (_) => const Uuid().v4(),
    );
    multiAIEngine.enter(models, existingThreadIds: threadIds);
    notifyListeners();
  }

  /// Edit model selection before any round has started (badge tap at
  /// roundCount == 0). Opens the selector with current models pre-selected
  /// but fully editable (no locked keys).
  Future<void> editMultiAIModels() async {
    final engine = multiAIEngine;
    if (!engine.isActive || engine.roundCount != 0) return;
    if (currentConversation == null) return;

    final existingKeys = engine.models
        .map((m) => ModelMultiSelectState.keyFor(m.providerKey, m.modelId))
        .toSet();

    final result = await showMultiModelSelector(
      _context,
      preselectedKeys: existingKeys,
    );
    if (result == null || result.isEmpty) return;
    if (!_context.mounted) return;

    if (result.length == 1) {
      final sel = result.first;
      final assistant = _context.read<AssistantProvider>().currentAssistant;
      engine.exit();
      if (assistant != null) {
        await _context.read<AssistantProvider>().updateAssistant(
          assistant.copyWith(
            chatModelProvider: sel.providerKey,
            chatModelId: sel.modelId,
          ),
        );
      }
      notifyListeners();
      return;
    }

    final threadIds = List<String>.generate(
      result.length,
      (_) => const Uuid().v4(),
    );
    engine.exit();
    engine.enter(result, existingThreadIds: threadIds);
    notifyListeners();
  }

  /// Show model selector with locked existing models for adding models
  /// mid-round (the "+" button on first-round card footer).
  Future<void> addMultiAIModels() async {
    final engine = multiAIEngine;
    if (!engine.isActive || engine.roundCount != 1) return;
    if (currentConversation == null) return;

    final existingKeys = engine.models
        .map((m) => ModelMultiSelectState.keyFor(m.providerKey, m.modelId))
        .toSet();

    final result = await showMultiModelSelector(
      _context,
      preselectedKeys: existingKeys,
      lockedKeys: existingKeys,
    );
    if (result == null) return;
    if (!_context.mounted) return;

    final newModels = result
        .where(
          (m) => !existingKeys.contains(
            ModelMultiSelectState.keyFor(m.providerKey, m.modelId),
          ),
        )
        .toList();
    if (newModels.isEmpty) return;

    final settings = _context.read<SettingsProvider>();
    final assistant = _context.read<AssistantProvider>().currentAssistant;

    await engine.addModelsAndExecute(
      newModels: newModels,
      conversation: currentConversation!,
      settings: settings,
      assistant: assistant,
    );
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - UI State
  // ============================================================================

  void toggleReasoning(String messageId) {
    final r = reasoning[messageId];
    if (r != null) {
      r.expanded = !r.expanded;
      // Check if reasoning is still loading (finishedAt == null means streaming)
      // This is O(1) - no list traversal needed
      final isStillStreaming = r.finishedAt == null && r.text.isNotEmpty;
      if (isStillStreaming && streamingContentNotifier.hasNotifier(messageId)) {
        // For actively streaming messages, use lightweight notifier update
        streamingContentNotifier.forceRebuild(messageId);
      } else {
        // For non-streaming messages, trigger full page rebuild
        notifyListeners();
      }
    }
  }

  void toggleTranslation(String messageId) {
    final t = _translations[messageId];
    if (t != null) {
      t.expanded = !t.expanded;
      notifyListeners();
    }
  }

  void toggleReasoningSegment(String messageId, int segmentIndex) {
    final segments = reasoningSegments[messageId];
    if (segments != null && segmentIndex < segments.length) {
      final seg = segments[segmentIndex];
      seg.expanded = !seg.expanded;
      // Check if this segment is still loading (finishedAt == null means streaming)
      // This is O(1) - no list traversal needed
      final isStillStreaming = seg.finishedAt == null && seg.text.isNotEmpty;
      if (isStillStreaming && streamingContentNotifier.hasNotifier(messageId)) {
        // For actively streaming messages, use lightweight notifier update
        streamingContentNotifier.forceRebuild(messageId);
      } else {
        // For non-streaming messages, trigger full page rebuild
        notifyListeners();
      }
    }
  }

  void setDragHovering(bool hovering) {
    _isDragHovering = hovering;
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - Sidebar Management
  // ============================================================================

  void toggleTabletSidebar() {
    dismissKeyboard();
    try {
      if (_context.read<SettingsProvider>().hapticsOnDrawer) {
        Haptics.drawerPulse();
      }
    } catch (_) {}
    _tabletSidebarOpen = !_tabletSidebarOpen;
    notifyListeners();
    try {
      _context.read<SettingsProvider>().setDesktopSidebarOpen(
        _tabletSidebarOpen,
      );
    } catch (_) {}
  }

  void toggleRightSidebar() {
    dismissKeyboard();
    try {
      if (_context.read<SettingsProvider>().hapticsOnDrawer) {
        Haptics.drawerPulse();
      }
    } catch (_) {}
    _rightSidebarOpen = !_rightSidebarOpen;
    notifyListeners();
    try {
      _context.read<SettingsProvider>().setDesktopRightSidebarOpen(
        _rightSidebarOpen,
      );
    } catch (_) {}
  }

  void updateSidebarWidth(double dx) {
    _embeddedSidebarWidth = (_embeddedSidebarWidth + dx).clamp(
      _sidebarMinWidth,
      _sidebarMaxWidth,
    );
    notifyListeners();
  }

  void saveSidebarWidth() {
    try {
      _context.read<SettingsProvider>().setDesktopSidebarWidth(
        _embeddedSidebarWidth,
      );
    } catch (_) {}
  }

  void updateRightSidebarWidth(double dx) {
    _rightSidebarWidth = (_rightSidebarWidth - dx).clamp(
      _sidebarMinWidth,
      _sidebarMaxWidth,
    );
    notifyListeners();
  }

  void saveRightSidebarWidth() {
    try {
      _context.read<SettingsProvider>().setDesktopRightSidebarWidth(
        _rightSidebarWidth,
      );
    } catch (_) {}
  }

  // ============================================================================
  // Public Methods - Drawer
  // ============================================================================

  void onDrawerValueChanged(double value) {
    if (_lastDrawerValue <= 0.01 && value > 0.01) {
      dismissKeyboard();
    }
    if (_lastDrawerValue < 0.95 && value >= 0.95) {
      try {
        if (_context.read<SettingsProvider>().hapticsOnDrawer) {
          Haptics.drawerPulse();
        }
      } catch (_) {}
    }
    if (_lastDrawerValue > 0.05 && value <= 0.05) {
      try {
        if (_context.read<SettingsProvider>().hapticsOnDrawer) {
          Haptics.drawerPulse();
        }
      } catch (_) {}
    }
    _lastDrawerValue = value;
  }

  // ============================================================================
  // Public Methods - Input
  // ============================================================================

  void dismissKeyboard() {
    _inputFocus.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    } catch (_) {}
  }

  void measureInputBar() {
    try {
      final ctx = _inputBarKey.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if ((_inputBarHeight - h).abs() > 1.0) {
        _inputBarHeight = h;
        notifyListeners();
      }
    } catch (_) {}
  }

  // ============================================================================
  // Public Methods - Quick Phrases
  // ============================================================================

  Future<void> handleQuickPhraseSelection(QuickPhrase? selected) async {
    if (selected == null) return;
    final text = _inputController.text;
    final selection = _inputController.selection;
    final start = (selection.start >= 0 && selection.start <= text.length)
        ? selection.start
        : text.length;
    final end =
        (selection.end >= 0 &&
            selection.end <= text.length &&
            selection.end >= start)
        ? selection.end
        : start;

    final newText = text.replaceRange(start, end, selected.content);
    _inputController.value = _inputController.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
        offset: start + selected.content.length,
      ),
      composing: TextRange.empty,
    );
    notifyListeners();
  }

  // ============================================================================
  // Public Methods - File Upload
  // ============================================================================

  Future<void> onPickPhotos() => _fileUploadService.onPickPhotos();
  Future<void> onPickCamera() => _fileUploadService.onPickCamera(_context);
  Future<void> onPickFiles() => _fileUploadService.onPickFiles();
  Future<void> onFilesDroppedDesktop(List<XFile> files) =>
      _fileUploadService.onFilesDroppedDesktop(files);

  // ============================================================================
  // Public Methods - Scroll
  // ============================================================================

  void scrollToBottom({bool animate = true}) =>
      _scrollToBottom(animate: animate);
  void forceScrollToBottomSoon({bool animate = true}) =>
      _scrollCtrl.forceScrollToBottomSoon(
        animate: animate,
        postSwitchDelay: _postSwitchScrollDelay,
      );

  bool loadMoreBefore() => _viewModel.loadMoreBefore();

  bool loadMoreAfter() => _viewModel.loadMoreAfter();

  List<ChatMessage> allCollapsedMessagesForCurrentConversation() =>
      _chatController.allCollapsedMessagesForCurrentConversation();

  Future<void> scrollToMessageId(String targetId) async {
    if (_chatController.indexOfCollapsedMessageId(targetId) < 0) {
      final loaded = _viewModel.loadUntilMessageVisible(targetId);
      if (loaded) {
        _scrollCtrl.clearObserverCache();
      }
      try {
        await WidgetsBinding.instance.endOfFrame;
      } catch (_) {}
    }
    final index = _chatController.indexOfCollapsedMessageId(targetId);
    if (index < 0) return;
    await _scrollCtrl.scrollToMessageId(targetId: targetId, targetIndex: index);
  }

  Future<void> jumpToPreviousQuestion() async {
    await _scrollCtrl.jumpToPreviousQuestion(
      messages: _chatController.collapsedMessages,
      indexOfId: (id) => _chatController.indexOfCollapsedMessageId(id),
    );
  }

  Future<void> jumpToNextQuestion() async {
    await _scrollCtrl.jumpToNextQuestion(
      messages: _chatController.collapsedMessages,
      indexOfId: (id) => _chatController.indexOfCollapsedMessageId(id),
    );
  }

  void scrollToTop({bool animate = true}) {
    if (_chatController.hasMoreBefore) {
      final loaded = _chatController.loadStartWindow();
      if (loaded) {
        _viewModel.restoreMessageUiState();
        _scrollCtrl.clearObserverCache();
      }
    }
    _scrollCtrl.scrollToTop(animate: animate);
  }

  void forceScrollToBottom({bool animate = true}) {
    if (_chatController.hasMoreAfter) {
      final loaded = _chatController.loadEndWindow();
      if (loaded) {
        _viewModel.restoreMessageUiState();
        _scrollCtrl.clearObserverCache();
      }
    }
    _scrollToBottom(animate: animate);
  }

  // ============================================================================
  // Public Methods - Model Checks
  // ============================================================================

  bool isReasoningModel(String providerKey, String modelId) {
    return _generationController.isReasoningModel(providerKey, modelId);
  }

  bool isToolModel(String providerKey, String modelId) {
    return _generationController.isToolModel(providerKey, modelId);
  }

  bool isReasoningEnabled(int? budget) {
    if (budget == null) return true;
    if (budget == -1) return true;
    return budget >= 1024;
  }

  // ============================================================================
  // Public Methods - Helpers
  // ============================================================================

  String titleForLocale() => _titleForLocale(_context);

  String clearContextLabel() {
    final l10n = AppLocalizations.of(_context)!;
    return _viewModel.getClearContextLabel(
      (actual, configured) =>
          l10n.homePageClearContextWithCount(actual, configured),
      l10n.homePageClearContext,
    );
  }

  String? currentStreamingMessageId() {
    for (int i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.role == 'assistant' && m.isStreaming) return m.id;
    }
    return null;
  }

  bool shouldPinStreamingIndicator(String? messageId) {
    if (messageId == null) return false;
    if (_scrollCtrl.isUserScrolling) return false;
    if (!_scrollCtrl.hasEnoughContentToScroll(56.0)) return false;
    if (!_scrollCtrl.isNearBottom(48)) return false;
    return true;
  }

  /// Transform raw content using assistant regexes.
  String transformAssistantContent(
    stream_ctrl.StreamingState state, [
    String? raw,
  ]) {
    return applyAssistantRegexes(
      raw ?? state.fullContentRaw,
      assistant: state.ctx.assistant,
      scope: AssistantRegexScope.assistant,
      target: AssistantRegexTransformTarget.persist,
    );
  }

  // ============================================================================
  // Lifecycle Management
  // ============================================================================

  void onAppLifecycleStateChanged(AppLifecycleState state) {
    _appInForeground = (state == AppLifecycleState.resumed);
  }

  void onDidPopNext() {
    if (isDesktopPlatform) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _inputFocus.requestFocus();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => dismissKeyboard());
    }
  }

  void onDidPushNext() {
    dismissKeyboard();
  }

  // ============================================================================
  // Private Methods
  // ============================================================================

  String _titleForLocale(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.titleForLocale;
  }

  void _scrollToBottom({bool animate = true}) =>
      _scrollCtrl.scrollToBottom(animate: animate);
  void _scrollToBottomSoon({bool animate = true}) =>
      _scrollCtrl.scrollToBottomSoon(animate: animate);

  // _getViewportBounds removed: ListObserverController handles visibility.

  void _restoreMessageUiState() {
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.role == 'assistant') {
        _streamController.restoreMessageUiState(
          m,
          getToolEventsFromDb: (id) => _chatService.getToolEvents(id),
          getGeminiThoughtSigFromDb: (id) =>
              _chatService.getGeminiThoughtSignature(id),
        );

        final cleanedContent = _streamController.captureGeminiThoughtSignature(
          m.content,
          m.id,
        );
        if (cleanedContent != m.content) {
          final updated = m.copyWith(content: cleanedContent);
          messages[i] = updated;
          unawaited(_chatService.updateMessage(m.id, content: cleanedContent));
        }

        _scheduleInlineImageSanitize(
          m.id,
          latestContent: messages[i].content,
          immediate: true,
        );
      }

      if (m.translation != null && m.translation!.isNotEmpty) {
        final td = TranslationData();
        td.expanded = false;
        _translations[m.id] = td;
      }
    }
  }

  void _scheduleInlineImageSanitize(
    String messageId, {
    String? latestContent,
    bool immediate = false,
  }) {
    final snapshot =
        latestContent ??
        (() {
          final idx = messages.indexWhere((m) => m.id == messageId);
          return idx == -1 ? '' : messages[idx].content;
        })();
    if (snapshot.isEmpty ||
        !snapshot.contains('data:image') ||
        !snapshot.contains('base64,')) {
      return;
    }

    _streamController.scheduleInlineImageSanitize(
      messageId,
      latestContent: snapshot,
      immediate: immediate,
      onSanitized: (id, sanitized) async {
        await _chatService.updateMessage(id, content: sanitized);
        final i = messages.indexWhere((m) => m.id == id);
        if (i != -1) {
          messages[i] = messages[i].copyWith(content: sanitized);
        }
        notifyListeners();
      },
    );
  }

  String _appendGeminiThoughtSignatureForApi(
    ChatMessage message,
    String content,
  ) {
    return _streamController.appendGeminiThoughtSignatureForApi(
      message,
      content,
    );
  }

  Future<void> _onMcpChanged() async {
    // Kept for potential future use
  }

  // ============================================================================
  // Disposal
  // ============================================================================

  @override
  void dispose() {
    _proactiveCarePort?.close();
    IsolateNameServer.removePortNameMapping(proactiveCareMainPortName);
    _convoFadeController.dispose();
    _mcpProvider?.removeListener(_onMcpChanged);
    _scrollCtrl.dispose();
    try {
      _chatActionSub?.cancel();
    } catch (_) {}
    _chatController.dispose();
    _streamController.dispose();
    super.dispose();
  }
}

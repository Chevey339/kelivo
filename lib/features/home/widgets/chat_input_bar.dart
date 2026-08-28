import 'package:flutter/material.dart';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../theme/design_tokens.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../icons/reasoning_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/file_import_helper.dart';
import '../../../utils/image_compressor.dart';
import '../../../utils/upload_dedupe.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../shared/responsive/breakpoints.dart';
import 'dart:async';
import 'dart:io';
import '../../../core/models/chat_input_data.dart';
import '../../../utils/clipboard_images.dart';
import '../../../core/providers/asr_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../utils/brand_assets.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/app_directories.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../desktop/desktop_context_menu.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

class ChatInputBarController {
  _ChatInputBarState? _state;
  void _bind(_ChatInputBarState s) => _state = s;
  void _unbind(_ChatInputBarState s) {
    if (identical(_state, s)) _state = null;
  }

  bool get allowImagesApiRouting => _state?._allowImagesApiRouting ?? true;
  bool get hasDraftMedia => _state?._hasDraftMedia ?? false;
  bool get hasUnreadyImages => _state?._hasUnreadyImages ?? false;

  void addImages(List<String> paths) => _state?._addImages(paths);
  void enqueueImages(
    List<String> paths,
    ImageCompressConfig config, {
    bool deleteSourcesAfterProcessing = false,
  }) => _state?._enqueueImages(
    paths,
    config,
    deleteSourcesAfterProcessing: deleteSourcesAfterProcessing,
  );
  void clearImages() => _state?._clearImages();
  void addFiles(List<DocumentAttachment> docs) => _state?._addFiles(docs);
  void clearFiles() => _state?._clearFiles();
  void restoreInput(ChatInputData input) => _state?._restoreInput(input);
  ChatInputData snapshotInput(String text) =>
      _state?._snapshotInput(text) ?? ChatInputData(text: text.trim());
  void clearDraft() => _state?._clearDraft();
}

class _DraftImage {
  _DraftImage({required this.id, required this.path});

  final int id;
  String path;
}

class _ImageProcessingTask {
  const _ImageProcessingTask({
    required this.id,
    required this.sourcePath,
    required this.config,
    required this.deleteSourceAfterProcessing,
  });

  final int id;
  final String sourcePath;
  final ImageCompressConfig config;

  /// Only ever true for app-owned temp sources (clipboard paste temps);
  /// user-picked files must never be flagged for deletion.
  final bool deleteSourceAfterProcessing;
}

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.chatModelProviderKey,
    this.chatModelId,
    this.onSend,
    this.onStop,
    this.onSelectModel,
    this.onLongPressSelectModel,
    this.onOpenMcp,
    this.onLongPressMcp,
    this.onOpenSearch,
    this.onMore,
    this.onConfigureReasoning,
    this.moreOpen = false,
    this.focusNode,
    this.modelIcon,
    this.controller,
    this.mediaController,
    this.asrProvider,
    this.loading = false,
    this.hasQueuedInput = false,
    this.queuedPreviewText,
    this.onCancelQueuedInput,
    this.reasoningActive = false,
    this.reasoningBudget,
    this.supportsReasoning = true,
    this.showMcpButton = false,
    this.mcpActive = false,
    this.showMiniMapButton = false,
    this.onOpenMiniMap,
    this.onPickCamera,
    this.onPickPhotos,
    this.onUploadFiles,
    this.onToggleLearningMode,
    this.onOpenWorldBook,
    this.onClearContext,
    this.onCompressContext,
    this.onLongPressLearning,
    this.learningModeActive = false,
    this.worldBookActive = false,
    this.showMoreButton = true,
    this.showQuickPhraseButton = false,
    this.onQuickPhrase,
    this.onLongPressQuickPhrase,
    this.showOcrButton = false,
    this.ocrActive = false,
    this.onToggleOcr,
    this.conversationId,
    this.sendButtonTooltip,
    this.backgroundImageActive = false,
    this.inputBackgroundOpacityLight =
        SettingsProvider.defaultChatInputBackgroundOpacityLight,
    this.inputBackgroundOpacityDark =
        SettingsProvider.defaultChatInputBackgroundOpacityDark,
  });

  final Future<ChatInputSubmissionResult> Function(ChatInputData)? onSend;
  final VoidCallback? onStop;
  final VoidCallback? onSelectModel;
  final VoidCallback? onLongPressSelectModel;
  final VoidCallback? onOpenMcp;
  final VoidCallback? onLongPressMcp;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onMore;
  final VoidCallback? onConfigureReasoning;
  final bool moreOpen;
  final FocusNode? focusNode;
  final Widget? modelIcon;
  final TextEditingController? controller;
  final ChatInputBarController? mediaController;
  final AsrProvider? asrProvider;
  final bool loading;
  final bool hasQueuedInput;
  final String? queuedPreviewText;
  final VoidCallback? onCancelQueuedInput;
  final bool reasoningActive;
  final int? reasoningBudget;
  final bool supportsReasoning;
  final bool showMcpButton;
  final bool mcpActive;
  final bool showMiniMapButton;
  final VoidCallback? onOpenMiniMap;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickPhotos;
  final VoidCallback? onUploadFiles;
  final VoidCallback? onToggleLearningMode;
  final VoidCallback? onOpenWorldBook;
  final VoidCallback? onClearContext;
  final VoidCallback? onCompressContext;
  final VoidCallback? onLongPressLearning;
  final bool learningModeActive;
  final bool worldBookActive;
  final bool showMoreButton;
  final bool showQuickPhraseButton;
  final VoidCallback? onQuickPhrase;
  final VoidCallback? onLongPressQuickPhrase;
  final bool showOcrButton;
  final bool ocrActive;
  final VoidCallback? onToggleOcr;
  final String? conversationId;

  /// The model this conversation sends with, already resolved through
  /// conversation override -> assistant -> global default.
  final String? chatModelProviderKey;
  final String? chatModelId;
  final String? sendButtonTooltip;
  final bool backgroundImageActive;
  final double inputBackgroundOpacityLight;
  final double inputBackgroundOpacityDark;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with WidgetsBindingObserver {
  late TextEditingController _controller;
  bool _isExpanded = false; // Track expand/collapse state for input field
  // The ASR provider owns microphone capture. This widget only owns the
  // composer presentation and an exact snapshot used by Cancel.
  final List<double> _voiceLevels = <double>[];
  final ValueNotifier<int> _voiceLevelsVersion = ValueNotifier<int>(0);
  static const int _maxVoiceLevels = 400;
  Timer? _voiceLevelTimer;
  TextEditingValue? _voiceBaseValue;
  bool _ownsVoiceSession = false;
  bool _finishingVoice = false;
  String? _lastReportedVoiceError;
  final List<_DraftImage> _images = <_DraftImage>[];
  final Queue<_ImageProcessingTask> _imageProcessingQueue =
      Queue<_ImageProcessingTask>();
  final Set<int> _processingImageIds = <int>{};
  final Set<int> _failedImageIds = <int>{};
  final Set<int> _pendingImagePasteIds = <int>{};
  final Set<int> _pendingTextPasteIds = <int>{};
  static const int _maxConcurrentImageTasks = 2;
  int _activeImageTasks = 0;
  int _nextImageId = 0;
  int _nextImagePasteId = 0;
  int _nextTextPasteId = 0;
  int _draftReplacementRevision = 0;
  Future<void> _textPasteWriteTail = Future<void>.value();
  final List<DocumentAttachment> _docs =
      <DocumentAttachment>[]; // files to upload
  final Map<LogicalKeyboardKey, Timer?> _repeatTimers = {};
  static const Duration _repeatInitialDelay = Duration(milliseconds: 300);
  static const Duration _repeatPeriod = Duration(milliseconds: 35);
  // Anchor for the responsive overflow menu on the left action bar
  final GlobalKey _leftOverflowAnchorKey = GlobalKey(
    debugLabel: 'left-overflow-anchor',
  );
  final GlobalKey _contextMgmtAnchorKey = GlobalKey(
    debugLabel: 'context-mgmt-anchor',
  );
  static const double _documentPreviewHeight = 48;
  static const double _imagePreviewHeight = 64;
  static const double _imageRemoveButtonSize = 18;
  // Suppress context menu briefly after app resume to avoid flickering
  bool _suppressContextMenu = false;
  bool _isSubmitting = false;
  int _submitSerial = 0;
  String? _imageModeModelKey;
  String? _lastImageModeModelKey;
  String? _dismissedImageModeModelKey;

  bool get _composerLocked => widget.hasQueuedInput;

  Color _inputFillColor({
    required ThemeData theme,
    required bool backgroundImageActive,
    required double lightOpacity,
    required double darkOpacity,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final configuredOpacity = (isDark ? darkOpacity : lightOpacity)
        .clamp(0.0, 1.0)
        .toDouble();
    final backgroundRatio = isDark
        ? 0.545 / SettingsProvider.defaultChatInputBackgroundOpacityDark
        : 0.5296 / SettingsProvider.defaultChatInputBackgroundOpacityLight;
    final targetOpacity = backgroundImageActive
        ? configuredOpacity * backgroundRatio
        : configuredOpacity;
    final overlayAlpha = isDark ? (backgroundImageActive ? 0.09 : 0.07) : 0.02;
    final overlayTint = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: overlayAlpha)
        : theme.colorScheme.primary.withValues(alpha: overlayAlpha);
    final baseAlpha = ((targetOpacity - overlayAlpha) / (1.0 - overlayAlpha))
        .clamp(0.0, 1.0)
        .toDouble();
    final base = theme.colorScheme.surface.withValues(alpha: baseAlpha);
    return Color.alphaBlend(overlayTint, base).withValues(alpha: targetOpacity);
  }

  bool _supportsImagesApiRouting(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final providerKey = widget.chatModelProviderKey;
    final modelId = widget.chatModelId;
    if (providerKey == null || modelId == null) {
      _imageModeModelKey = null;
      return false;
    }
    final cfg = settings.getProviderConfig(providerKey);
    final supported = ChatApiService.supportsOpenAIImagesApiRouting(
      cfg,
      modelId,
    );
    final nextKey = supported
        ? '${widget.conversationId ?? ''}::$providerKey::$modelId'
        : null;
    if (nextKey != _lastImageModeModelKey) {
      _dismissedImageModeModelKey = null;
      _lastImageModeModelKey = nextKey;
    }
    _imageModeModelKey = nextKey;
    return supported;
  }

  bool get _imageModeActive {
    final key = _imageModeModelKey;
    return key != null && key != _dismissedImageModeModelKey;
  }

  bool get _allowImagesApiRouting {
    final key = _imageModeModelKey;
    return key == null || key != _dismissedImageModeModelKey;
  }

  bool get _hasDraftMedia => _images.isNotEmpty || _docs.isNotEmpty;
  bool get _hasUnreadyImages =>
      _processingImageIds.isNotEmpty ||
      _failedImageIds.isNotEmpty ||
      _pendingImagePasteIds.isNotEmpty ||
      _pendingTextPasteIds.isNotEmpty;

  // Instance method for onChanged to avoid recreating the callback on every build
  void _onTextChanged(String _) => setState(() {});

  void _addImages(List<String> paths) {
    if (paths.isEmpty) return;
    setState(() {
      _images.addAll(
        paths.map((path) => _DraftImage(id: _nextImageId++, path: path)),
      );
    });
  }

  void _enqueueImages(
    List<String> paths,
    ImageCompressConfig config, {
    required bool deleteSourcesAfterProcessing,
  }) {
    if (paths.isEmpty) return;
    setState(() {
      for (final path in paths) {
        final image = _DraftImage(id: _nextImageId++, path: path);
        _images.add(image);
        _processingImageIds.add(image.id);
        _imageProcessingQueue.add(
          _ImageProcessingTask(
            id: image.id,
            sourcePath: path,
            config: config,
            deleteSourceAfterProcessing: deleteSourcesAfterProcessing,
          ),
        );
      }
    });
    _pumpImageProcessingQueue();
  }

  void _pumpImageProcessingQueue() {
    while (mounted &&
        _activeImageTasks < _maxConcurrentImageTasks &&
        _imageProcessingQueue.isNotEmpty) {
      final task = _imageProcessingQueue.removeFirst();
      if (!_processingImageIds.contains(task.id)) continue;
      _activeImageTasks++;
      unawaited(_processImage(task));
    }
  }

  Future<void> _processImage(_ImageProcessingTask task) async {
    UploadWrite? saved;
    try {
      final dir = await AppDirectories.getUploadDirectory();
      saved = await ImageCompressor.compressToUploadDir(
        task.sourcePath,
        dir,
        task.config,
      );
    } catch (_) {
      saved = null;
    } finally {
      if (task.deleteSourceAfterProcessing &&
          (saved == null ||
              !p.equals(
                p.normalize(p.absolute(task.sourcePath)),
                p.normalize(p.absolute(saved.path)),
              ))) {
        await _deleteTemporaryImageSource(task.sourcePath);
      }
      _activeImageTasks--;
    }
    final savedPath = saved?.path;

    final index = mounted
        ? _images.indexWhere((image) => image.id == task.id)
        : -1;
    final taskIsActive = index >= 0 && _processingImageIds.contains(task.id);
    // Only a copy this task created, that no other import has resolved to in
    // the meantime, may be cleaned up.
    if (!taskIsActive &&
        savedPath != null &&
        !saved!.reused &&
        !UploadDedupe.isShared(savedPath) &&
        !p.equals(
          p.normalize(p.absolute(task.sourcePath)),
          p.normalize(p.absolute(savedPath)),
        )) {
      try {
        await File(savedPath).delete();
      } catch (error) {
        debugPrint(
          '[ChatInputBar] Failed to delete discarded compressed image $savedPath: $error',
        );
      }
    }

    if (!mounted) return;
    if (taskIsActive) {
      setState(() {
        _processingImageIds.remove(task.id);
        if (savedPath == null) {
          _failedImageIds.add(task.id);
        } else {
          _images[index].path = savedPath;
        }
      });
    }
    _pumpImageProcessingQueue();
  }

  void _discardImageState(Iterable<int> ids) {
    final discarded = ids.toSet();
    final discardedQueuedTasks = _imageProcessingQueue
        .where((task) => discarded.contains(task.id))
        .toList(growable: false);
    _processingImageIds.removeAll(discarded);
    _failedImageIds.removeAll(discarded);
    _imageProcessingQueue.removeWhere((task) => discarded.contains(task.id));
    for (final task in discardedQueuedTasks) {
      if (task.deleteSourceAfterProcessing) {
        unawaited(_deleteTemporaryImageSource(task.sourcePath));
      }
    }
  }

  void _clearImages() {
    setState(() {
      _pendingImagePasteIds.clear();
      _discardImageState(_images.map((image) => image.id));
      _images.clear();
    });
  }

  void _addFiles(List<DocumentAttachment> docs) {
    if (docs.isEmpty) return;
    setState(() => _docs.addAll(docs));
  }

  void _clearFiles() {
    setState(() {
      _pendingTextPasteIds.clear();
      _docs.clear();
    });
  }

  void _restoreInput(ChatInputData input) {
    setState(() {
      _draftReplacementRevision++;
      _pendingImagePasteIds.clear();
      _pendingTextPasteIds.clear();
      _discardImageState(_images.map((image) => image.id));
      _images
        ..clear()
        ..addAll(
          input.imagePaths.map(
            (path) => _DraftImage(
              id: _nextImageId++,
              path: isRemoteOrDataUri(path)
                  ? path
                  : SandboxPathResolver.fix(path),
            ),
          ),
        );
      _docs
        ..clear()
        ..addAll(input.documents);
    });
  }

  ChatInputData _snapshotInput(String text) {
    return ChatInputData(
      text: text.trim(),
      imagePaths: [
        for (final image in _images)
          if (!_processingImageIds.contains(image.id) &&
              !_failedImageIds.contains(image.id))
            image.path,
      ],
      documents: List<DocumentAttachment>.of(_docs),
      allowImagesApiRouting: _allowImagesApiRouting,
    );
  }

  void _clearDraft() {
    setState(() {
      _draftReplacementRevision++;
      _controller.clear();
      _pendingImagePasteIds.clear();
      _pendingTextPasteIds.clear();
      _discardImageState(_images.map((image) => image.id));
      _images.clear();
      _docs.clear();
    });
  }

  void _removeImageAt(int index) {
    setState(() {
      final image = _images.removeAt(index);
      _discardImageState([image.id]);
    });
  }

  void _removeDocumentAt(int index) {
    setState(() => _docs.removeAt(index));
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    widget.mediaController?._bind(this);
    widget.asrProvider?.addListener(_handleAsrChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, suppress context menu briefly to avoid flickering
    if (state == AppLifecycleState.resumed) {
      _suppressContextMenu = true;
      // Also unfocus to reset any stuck toolbar state
      widget.focusNode?.unfocus();
      // Re-enable context menu after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() => _suppressContextMenu = false);
        }
      });
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // When going to background, hide any open toolbar
      _suppressContextMenu = true;
      widget.focusNode?.unfocus();
      if (_ownsVoiceSession) unawaited(_cancelVoiceInput());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopVoiceLevelSampling();
    final asr = widget.asrProvider;
    asr?.removeListener(_handleAsrChanged);
    if (_ownsVoiceSession && asr != null) unawaited(asr.cancel());
    for (final timer in _repeatTimers.values) {
      try {
        timer?.cancel();
      } catch (_) {}
    }
    _repeatTimers.clear();
    _pendingImagePasteIds.clear();
    _pendingTextPasteIds.clear();
    _discardImageState(_images.map((image) => image.id));
    _imageProcessingQueue.clear();
    _processingImageIds.clear();
    _failedImageIds.clear();
    widget.mediaController?._unbind(this);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _voiceLevelsVersion.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousConversationId = oldWidget.conversationId;
    final nextConversationId = widget.conversationId;
    if (previousConversationId != null &&
        nextConversationId != null &&
        previousConversationId != nextConversationId) {
      // The composer is reused across conversations (stable GlobalKey). A
      // submit that is still awaiting onSend must not lock the next chat.
      _submitSerial++;
      _isSubmitting = false;
      _draftReplacementRevision++;
    }
    if (!identical(oldWidget.asrProvider, widget.asrProvider)) {
      _stopVoiceLevelSampling();
      oldWidget.asrProvider?.removeListener(_handleAsrChanged);
      if (_ownsVoiceSession && oldWidget.asrProvider != null) {
        unawaited(oldWidget.asrProvider!.cancel());
        final original = _voiceBaseValue;
        if (original != null) _controller.value = original;
        _voiceBaseValue = null;
        _ownsVoiceSession = false;
        _finishingVoice = false;
        _voiceLevels.clear();
      }
      widget.asrProvider?.addListener(_handleAsrChanged);
    }
  }

  String _hint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.chatInputBarHint;
  }

  /// Returns the number of lines in the input text (minimum 1).
  int get _lineCount {
    final text = _controller.text;
    if (text.isEmpty) return 1;
    return text.split('\n').length;
  }

  /// Whether to show the expand/collapse button (when text has 3+ lines).
  bool get _showExpandButton => _lineCount >= 3;

  // ---------------------------------------------------------------------------
  // Voice input
  // ---------------------------------------------------------------------------

  Future<void> _startVoiceInput() async {
    final asr = widget.asrProvider;
    final selected = context.read<SettingsProvider>().selectedAsrService;
    if (_composerLocked ||
        widget.loading ||
        _ownsVoiceSession ||
        asr == null ||
        asr.isActive ||
        selected == null ||
        !asr.canUse(selected)) {
      return;
    }

    _voiceBaseValue = _controller.value;
    _ownsVoiceSession = true;
    _finishingVoice = false;
    _lastReportedVoiceError = null;
    _voiceLevels.clear();
    setState(() {});
    widget.focusNode?.unfocus();

    try {
      await asr.start(selected);
      if (mounted && _ownsVoiceSession && asr.isListening) {
        _startVoiceLevelSampling();
      }
    } catch (error) {
      _stopVoiceLevelSampling();
      if (!mounted) return;
      // Provider failures normally arrive through its listener first. This is
      // the fallback for errors raised before the provider can publish state.
      if (_ownsVoiceSession) {
        final original = _voiceBaseValue;
        if (original != null) _controller.value = original;
        _voiceBaseValue = null;
        _ownsVoiceSession = false;
        _finishingVoice = false;
        _voiceLevels.clear();
        setState(() {});
      }
      if (_lastReportedVoiceError == null) _reportVoiceFailure(error);
    }
  }

  void _handleAsrChanged() {
    if (!mounted || !_ownsVoiceSession) return;
    final asr = widget.asrProvider;
    if (asr == null) return;

    _applyVoiceTranscript(asr.transcript);
    final error = asr.error;
    if (error != null && error.trim().isNotEmpty) {
      _stopVoiceLevelSampling();
      _voiceBaseValue = null;
      _ownsVoiceSession = false;
      _finishingVoice = false;
      _voiceLevels.clear();
      _reportVoiceFailure(error);
      scheduleMicrotask(asr.clearError);
    } else if (!asr.isActive && !_finishingVoice) {
      // Some system recognizers publish a final result and stop on their own.
      _stopVoiceLevelSampling();
      final detectedSpeech = asr.transcript.trim().isNotEmpty;
      _voiceBaseValue = null;
      _ownsVoiceSession = false;
      _voiceLevels.clear();
      if (!detectedSpeech) _reportNoSpeech();
    }
    setState(() {});
    _ensureCaretVisible();
  }

  void _startVoiceLevelSampling() {
    _voiceLevelTimer?.cancel();
    _voiceLevelTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!mounted || !_ownsVoiceSession || _finishingVoice) return;
      final asr = widget.asrProvider;
      if (asr?.isListening != true) return;
      final level = asr!.soundLevel.clamp(0.0, 1.0).toDouble();
      final previous = _voiceLevels.isEmpty ? 0.03 : _voiceLevels.last;
      _voiceLevels.add(previous + (level - previous) * 0.55);
      if (_voiceLevels.length > _maxVoiceLevels) _voiceLevels.removeAt(0);
      _voiceLevelsVersion.value++;
    });
  }

  void _stopVoiceLevelSampling() {
    _voiceLevelTimer?.cancel();
    _voiceLevelTimer = null;
  }

  void _applyVoiceTranscript(String transcript) {
    final baseValue = _voiceBaseValue;
    if (baseValue == null) return;
    final text = _joinVoiceText(baseValue.text, transcript);
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }

  String _joinVoiceText(String base, String transcript) {
    final spoken = transcript.trim();
    if (spoken.isEmpty) return base;
    if (base.isEmpty || RegExp(r'\s$').hasMatch(base)) return '$base$spoken';

    final first = spoken.substring(0, 1);
    final last = base.substring(base.length - 1);
    final punctuation = RegExp(r'^[,.;:!?，。！？、；：)\]}>》」』】…]');
    final cjk = RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]');
    final separator =
        punctuation.hasMatch(first) || cjk.hasMatch(first) || cjk.hasMatch(last)
        ? ''
        : ' ';
    return '$base$separator$spoken';
  }

  Future<void> _cancelVoiceInput() async {
    if (!_ownsVoiceSession) return;
    _stopVoiceLevelSampling();
    final asr = widget.asrProvider;
    final original = _voiceBaseValue;
    _voiceBaseValue = null;
    _ownsVoiceSession = false;
    _finishingVoice = false;
    _voiceLevels.clear();
    if (original != null) _controller.value = original;
    if (mounted) setState(() {});
    try {
      await asr?.cancel();
    } catch (error) {
      if (mounted) _reportVoiceFailure(error);
    }
  }

  Future<void> _finishVoiceInput({required bool sendAfter}) async {
    final asr = widget.asrProvider;
    if (!_ownsVoiceSession || _finishingVoice || asr == null) return;
    _stopVoiceLevelSampling();
    _finishingVoice = true;
    setState(() {});

    try {
      final transcript = await asr.finish();
      if (!mounted) return;
      _applyVoiceTranscript(transcript);
      final detectedSpeech = transcript.trim().isNotEmpty;
      _voiceBaseValue = null;
      _ownsVoiceSession = false;
      _finishingVoice = false;
      _voiceLevels.clear();
      setState(() {});
      _ensureCaretVisible();
      if (!detectedSpeech) {
        _reportNoSpeech();
      } else if (sendAfter && _controller.text.trim().isNotEmpty) {
        await _handleSend();
      }
    } catch (error) {
      if (!mounted) return;
      if (_ownsVoiceSession) {
        _voiceBaseValue = null;
        _ownsVoiceSession = false;
        _voiceLevels.clear();
        setState(() {});
      }
      if (_lastReportedVoiceError == null) _reportVoiceFailure(error);
    } finally {
      _finishingVoice = false;
      if (mounted) setState(() {});
    }
  }

  void _reportNoSpeech() {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.asrServicesNoSpeechDetected,
      type: NotificationType.warning,
    );
  }

  void _reportVoiceFailure(Object error) {
    if (!mounted) return;
    final raw = error
        .toString()
        .replaceFirst(RegExp(r'^\w+(?:<[^>]+>)?:\s*'), '')
        .trim();
    if (_lastReportedVoiceError == raw) return;
    _lastReportedVoiceError = raw;
    final lower = raw.toLowerCase();
    final l10n = AppLocalizations.of(context)!;
    final message =
        lower.contains('microphone') &&
            (lower.contains('permission') ||
                lower.contains('denied') ||
                lower.contains('not granted'))
        ? l10n.asrServicesMicrophonePermissionDenied
        : lower.contains('no speech') || lower.contains('silence')
        ? l10n.asrServicesNoSpeechDetected
        : lower.contains('system') && lower.contains('unavailable')
        ? l10n.asrServicesSystemCheckFailed
        : l10n.asrServicesRecognitionFailed(raw);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppSnackBar(context, message: message, type: NotificationType.error);
    });
  }

  /// Bottom row shown while recording: cancel (X) — waveform — stop — send.
  Widget _buildVoiceRecordingRow(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final canFinish =
        widget.asrProvider?.isListening == true && !_finishingVoice;
    return Row(
      key: const ValueKey('voice'),
      children: [
        _CompactIconButton(
          tooltip: l10n.chatInputBarVoiceCancelTooltip,
          icon: Lucide.X,
          onTap: _finishingVoice ? null : () => unawaited(_cancelVoiceInput()),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 2),
            // Match the normal action row height (32) so the input bar
            // doesn't jump when switching in/out of recording state
            child: SizedBox(
              height: 32,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
                child: _finishingVoice
                    ? _VoiceTranscribingIndicator(
                        key: const ValueKey('voice-transcribing-indicator'),
                        label: l10n.chatInputBarVoiceTranscribing,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.72,
                        ),
                      )
                    : ValueListenableBuilder<int>(
                        valueListenable: _voiceLevelsVersion,
                        builder: (context, _, _) => _VoiceWaveform(
                          key: const ValueKey('voice-waveform'),
                          levels: _voiceLevels,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        // Stop: finish recording and transcribe into the input field
        _CompactIconButton(
          tooltip: l10n.chatInputBarVoiceStopTooltip,
          icon: Lucide.Square,
          onTap: canFinish
              ? () => unawaited(_finishVoiceInput(sendAfter: false))
              : null,
          childBuilder: (c) => Center(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(3.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send: transcribe and send the message right away
        _CompactSendButton(
          enabled: canFinish,
          onSend: () => unawaited(_finishVoiceInput(sendAfter: true)),
          color: theme.colorScheme.primary,
          icon: Lucide.Check,
          tooltip: l10n.chatInputBarVoiceSendTooltip,
        ),
      ],
    );
  }

  Future<void> _handleSend() async {
    if (_isSubmitting ||
        _hasUnreadyImages ||
        _ownsVoiceSession ||
        _finishingVoice) {
      return;
    }
    final submittedValue = _controller.value;
    final submittedText = submittedValue.text;
    final text = submittedText.trim();
    if (text.isEmpty && _images.isEmpty && _docs.isEmpty) return;
    final submittedImages = List<_DraftImage>.of(_images);
    final submittedImageIds = submittedImages.map((image) => image.id).toSet();
    final submittedDocuments = List<DocumentAttachment>.of(_docs);
    final submittedDraftRevision = _draftReplacementRevision;
    final submitSerial = ++_submitSerial;
    _isSubmitting = true;
    // Attachments leave the composer with the text, not when the send future
    // completes: that future now resolves at send time, but the draft must not
    // depend on it at all. A rejected send puts everything back below.
    setState(() {
      _controller.clear();
      _images.removeWhere((image) => submittedImageIds.contains(image.id));
      for (final document in submittedDocuments) {
        _docs.remove(document);
      }
    });
    try {
      final result =
          await widget.onSend?.call(
            ChatInputData(
              text: text,
              imagePaths: submittedImages.map((image) => image.path).toList(),
              documents: List<DocumentAttachment>.of(submittedDocuments),
              allowImagesApiRouting: _allowImagesApiRouting,
            ),
          ) ??
          ChatInputSubmissionResult.rejected;
      if (!mounted || submitSerial != _submitSerial) return;
      if (result == ChatInputSubmissionResult.sent ||
          result == ChatInputSubmissionResult.queued) {
        if (_draftReplacementRevision != submittedDraftRevision) return;
        _discardImageState(submittedImageIds);
        setState(() {});
        // Keep focus on desktop so user can continue typing
        try {
          if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
            widget.focusNode?.requestFocus();
          }
        } catch (_) {}
      } else if (_draftReplacementRevision == submittedDraftRevision) {
        setState(
          () => _restoreSubmittedDraft(
            submittedValue,
            submittedImages,
            submittedDocuments,
          ),
        );
      }
    } catch (_) {
      if (mounted &&
          submitSerial == _submitSerial &&
          _draftReplacementRevision == submittedDraftRevision) {
        setState(
          () => _restoreSubmittedDraft(
            submittedValue,
            submittedImages,
            submittedDocuments,
          ),
        );
      }
      rethrow;
    } finally {
      if (submitSerial == _submitSerial) {
        _isSubmitting = false;
      }
    }
  }

  /// Puts a rejected submission back into the composer: text first, then the
  /// attachments ahead of anything added while the send was in flight.
  void _restoreSubmittedDraft(
    TextEditingValue submittedValue,
    List<_DraftImage> submittedImages,
    List<DocumentAttachment> submittedDocuments,
  ) {
    _restoreSubmittedText(submittedValue);
    final existingImageIds = _images.map((image) => image.id).toSet();
    _images.insertAll(
      0,
      submittedImages.where((image) => !existingImageIds.contains(image.id)),
    );
    _docs.insertAll(
      0,
      submittedDocuments.where((document) => !_docs.contains(document)),
    );
  }

  void _restoreSubmittedText(TextEditingValue submittedValue) {
    final currentValue = _controller.value;
    if (currentValue.text.isEmpty) {
      _controller.value = submittedValue;
      return;
    }
    final offset = submittedValue.text.length;
    final selection = currentValue.selection.isValid
        ? currentValue.selection.copyWith(
            baseOffset: currentValue.selection.baseOffset + offset,
            extentOffset: currentValue.selection.extentOffset + offset,
          )
        : currentValue.selection;
    final composing = currentValue.composing.isValid
        ? TextRange(
            start: currentValue.composing.start + offset,
            end: currentValue.composing.end + offset,
          )
        : currentValue.composing;
    _controller.value = currentValue.copyWith(
      text: submittedValue.text + currentValue.text,
      selection: selection,
      composing: composing,
    );
  }

  void _insertNewlineAtCursor() {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;
    if (!selection.isValid) {
      _controller.text = '$text\n';
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = text.replaceRange(start, end, '\n');
      _controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + 1),
        composing: TextRange.empty,
      );
    }
    setState(() {});
    _ensureCaretVisible();
  }

  // Keep the caret visible after programmatic edits (e.g., Shift+Enter insert)
  void _ensureCaretVisible() {
    try {
      final selection = _controller.selection;
      if (!selection.isValid) return;
      final focusNode = widget.focusNode ?? Focus.maybeOf(context);
      final focusContext = focusNode?.context;
      if (focusContext == null) return;
      final editable = focusContext
          .findAncestorStateOfType<EditableTextState>();
      if (editable == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          editable.bringIntoView(selection.extent);
        } catch (_) {}
      });
    } catch (_) {}
  }

  // Instance method for contextMenuBuilder to avoid flickering caused by recreating
  // the callback on every build. See: https://github.com/flutter/flutter/issues/150551
  Widget _buildContextMenu(BuildContext context, EditableTextState state) {
    // Suppress context menu during app lifecycle transitions to avoid flickering
    if (_suppressContextMenu) {
      return const SizedBox.shrink();
    }
    if (Platform.isIOS) {
      final items = <ContextMenuButtonItem>[];
      try {
        final appL10n = AppLocalizations.of(context)!;
        final materialL10n = MaterialLocalizations.of(context);
        final value = _controller.value;
        final selection = value.selection;
        final hasSelection = selection.isValid && !selection.isCollapsed;
        final hasText = value.text.isNotEmpty;

        // Cut
        if (hasSelection) {
          items.add(
            ContextMenuButtonItem(
              onPressed: () async {
                try {
                  final start = selection.start;
                  final end = selection.end;
                  final text = value.text.substring(start, end);
                  await Clipboard.setData(ClipboardData(text: text));
                  final newText = value.text.replaceRange(start, end, '');
                  _controller.value = value.copyWith(
                    text: newText,
                    selection: TextSelection.collapsed(offset: start),
                  );
                } catch (_) {}
                state.hideToolbar();
              },
              label: materialL10n.cutButtonLabel,
            ),
          );
        }

        // Copy
        if (hasSelection) {
          items.add(
            ContextMenuButtonItem(
              onPressed: () async {
                try {
                  final start = selection.start;
                  final end = selection.end;
                  final text = value.text.substring(start, end);
                  await Clipboard.setData(ClipboardData(text: text));
                } catch (_) {}
                state.hideToolbar();
              },
              label: materialL10n.copyButtonLabel,
            ),
          );
        }

        // Paste (text or image via _handlePasteFromClipboard)
        items.add(
          ContextMenuButtonItem(
            onPressed: () {
              _handlePasteFromClipboard();
              state.hideToolbar();
            },
            label: materialL10n.pasteButtonLabel,
          ),
        );

        // Insert newline
        items.add(
          ContextMenuButtonItem(
            onPressed: () {
              _insertNewlineAtCursor();
              state.hideToolbar();
            },
            label: appL10n.chatInputBarInsertNewline,
          ),
        );

        // Select all
        if (hasText) {
          items.add(
            ContextMenuButtonItem(
              onPressed: () {
                try {
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: value.text.length,
                  );
                } catch (_) {}
                state.hideToolbar();
              },
              label: materialL10n.selectAllButtonLabel,
            ),
          );
        }
      } catch (_) {}
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: state.contextMenuAnchors,
        buttonItems: items,
      );
    }

    final items = state.contextMenuButtonItems
        .map((item) {
          if (item.type != ContextMenuButtonType.paste) return item;
          return item.copyWith(
            onPressed: () {
              unawaited(_handlePasteFromClipboard());
              state.hideToolbar();
            },
          );
        })
        .toList(growable: false);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Enhance hardware keyboard behavior
    final w = MediaQuery.sizeOf(node.context!).width;
    final isTabletOrDesktop = w >= AppBreakpoints.tablet;
    final isIosTablet = Platform.isIOS && isTabletOrDesktop;

    final isDown = event is KeyDownEvent;
    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    final isArrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    final isPasteV = key == LogicalKeyboardKey.keyV;

    // Enter handling on tablet/desktop: configurable shortcut
    if (isEnter && isTabletOrDesktop) {
      if (!isDown) return KeyEventResult.handled; // ignore key up
      // Respect IME composition (e.g., Chinese Pinyin). If composing, let IME handle Enter.
      final composing = _controller.value.composing;
      final composingActive = composing.isValid && !composing.isCollapsed;
      if (composingActive) return KeyEventResult.ignored;
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final shift =
          keys.contains(LogicalKeyboardKey.shiftLeft) ||
          keys.contains(LogicalKeyboardKey.shiftRight);
      final ctrl =
          keys.contains(LogicalKeyboardKey.controlLeft) ||
          keys.contains(LogicalKeyboardKey.controlRight);
      final meta =
          keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
      final ctrlOrMeta = ctrl || meta;
      // Get send shortcut setting
      final sendShortcut = Provider.of<SettingsProvider>(
        node.context!,
        listen: false,
      ).desktopSendShortcut;
      if (sendShortcut == DesktopSendShortcut.ctrlEnter) {
        // Ctrl/Cmd+Enter to send, Enter to newline
        if (ctrlOrMeta) {
          unawaited(_handleSend());
        } else if (!shift) {
          _insertNewlineAtCursor();
        } else {
          // Shift+Enter also newline
          _insertNewlineAtCursor();
        }
      } else {
        // Enter to send, Shift+Enter or Ctrl/Cmd+Enter to newline (default)
        if (shift || ctrlOrMeta) {
          _insertNewlineAtCursor();
        } else {
          unawaited(_handleSend());
        }
      }
      return KeyEventResult.handled;
    }

    // Paste handling for images on iOS/macOS (tablet/desktop)
    if (isDown && isPasteV) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final meta =
          keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
      final ctrl =
          keys.contains(LogicalKeyboardKey.controlLeft) ||
          keys.contains(LogicalKeyboardKey.controlRight);
      if (meta || ctrl) {
        _handlePasteFromClipboard();
        return KeyEventResult.handled;
      }
    }

    // Arrow repeat fix only needed on iOS tablets
    if (!isIosTablet || !isArrow) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final alt =
        keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);

    void moveOnce() {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveCaret(-1, extend: shift, byWord: alt);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _moveCaret(1, extend: shift, byWord: alt);
      }
    }

    if (event is KeyDownEvent) {
      // Initial move
      moveOnce();
      // Start repeat timer if not already
      if (!_repeatTimers.containsKey(key)) {
        Timer? periodic;
        final starter = Timer(_repeatInitialDelay, () {
          periodic = Timer.periodic(_repeatPeriod, (_) => moveOnce());
          _repeatTimers[key] = periodic!;
        });
        // Store starter temporarily; replace when periodic begins
        _repeatTimers[key] = starter;
      }
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      // Key up -> cancel repeat
      final t = _repeatTimers.remove(key);
      try {
        t?.cancel();
      } catch (_) {}
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  Future<String?> _savePastedImageBytes(String format, Uint8List bytes) async {
    File? reserved;
    try {
      final dir = await AppDirectories.getSystemCacheDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final ext = format.toLowerCase();
      final fileExt = ext == 'jpeg' ? 'jpg' : ext;
      final baseName = 'paste_${DateTime.now().millisecondsSinceEpoch}';
      var counter = 0;
      while (true) {
        final suffix = counter == 0 ? '' : '_$counter';
        final file = File(p.join(dir.path, '$baseName$suffix.$fileExt'));
        try {
          await file.create(exclusive: true);
          reserved = file;
          break;
        } on FileSystemException {
          if (!await file.exists()) rethrow;
          counter++;
        }
      }
      await reserved.writeAsBytes(bytes, flush: true);
      return reserved.path;
    } catch (_) {
      if (reserved != null) await _deleteTemporaryImageSource(reserved.path);
      return null;
    }
  }

  Future<void> _deleteTemporaryImageSource(String path) async {
    try {
      await File(path).delete();
    } catch (error) {
      debugPrint(
        '[ChatInputBar] Failed to delete temporary image $path: $error',
      );
    }
  }

  void _handleInsertedContent(KeyboardInsertedContent content) {
    final format = switch (content.mimeType.toLowerCase()) {
      'image/png' => 'png',
      'image/jpeg' || 'image/jpg' => 'jpeg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      _ => null,
    };
    final bytes = content.data;
    if (!mounted || format == null || bytes == null || bytes.isEmpty) return;
    final pasteId = _nextImagePasteId++;
    setState(() => _pendingImagePasteIds.add(pasteId));
    unawaited(_enqueueInsertedImage(pasteId, format, bytes));
  }

  Future<void> _enqueueInsertedImage(
    int pasteId,
    String format,
    Uint8List bytes,
  ) async {
    final savedPath = await _savePastedImageBytes(format, bytes);
    if (savedPath == null) {
      if (mounted && _pendingImagePasteIds.contains(pasteId)) {
        setState(() => _pendingImagePasteIds.remove(pasteId));
      }
      return;
    }
    if (!mounted || !_pendingImagePasteIds.contains(pasteId)) {
      await _deleteTemporaryImageSource(savedPath);
      return;
    }
    final compressConfig = context
        .read<SettingsProvider>()
        .resolveImageCompressConfig();
    _pendingImagePasteIds.remove(pasteId);
    _enqueueImages(
      [savedPath],
      compressConfig,
      deleteSourcesAfterProcessing: true,
    );
  }

  Future<void> _handlePasteFromClipboard() async {
    final compressConfig = context
        .read<SettingsProvider>()
        .resolveImageCompressConfig();

    // 1) Prefer reading via super_clipboard for better Windows support
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();

        // Helper: read bytes for a given file format from DataReader (ClipboardReader or item)
        Future<Uint8List?> readFileBytes(
          DataReader dataReader,
          FileFormat format,
        ) async {
          try {
            final completer = Completer<Uint8List?>();
            final progress = dataReader.getFile(
              format,
              (file) async {
                try {
                  final bytes = await file.readAll();
                  if (!completer.isCompleted) completer.complete(bytes);
                } catch (e) {
                  if (!completer.isCompleted) completer.completeError(e);
                }
              },
              onError: (e) {
                if (!completer.isCompleted) completer.completeError(e);
              },
            );
            if (progress == null) {
              if (!completer.isCompleted) completer.complete(null);
            }
            return await completer.future;
          } catch (_) {
            return null;
          }
        }

        // Try aggregated formats in priority: png > jpeg > gif > webp
        Uint8List? bytes;
        String? fmt;
        if (reader.canProvide(Formats.png)) {
          bytes = await readFileBytes(reader, Formats.png);
          fmt = 'png';
        }
        bytes ??= reader.canProvide(Formats.jpeg)
            ? await readFileBytes(reader, Formats.jpeg)
            : null;
        fmt = (bytes != null && fmt == null) ? 'jpeg' : fmt;
        if (bytes == null && reader.canProvide(Formats.gif)) {
          bytes = await readFileBytes(reader, Formats.gif);
          fmt = 'gif';
        }
        if (bytes == null && reader.canProvide(Formats.webp)) {
          bytes = await readFileBytes(reader, Formats.webp);
          fmt = 'webp';
        }

        if (bytes == null) {
          // Try per-item formats
          for (final item in reader.items) {
            if (bytes == null && item.canProvide(Formats.png)) {
              bytes = await readFileBytes(item, Formats.png);
              fmt = 'png';
            }
            if (bytes == null && item.canProvide(Formats.jpeg)) {
              bytes = await readFileBytes(item, Formats.jpeg);
              fmt = 'jpeg';
            }
            if (bytes == null && item.canProvide(Formats.gif)) {
              bytes = await readFileBytes(item, Formats.gif);
              fmt = 'gif';
            }
            if (bytes == null && item.canProvide(Formats.webp)) {
              bytes = await readFileBytes(item, Formats.webp);
              fmt = 'webp';
            }
            if (bytes != null) break;
          }
        }

        if (bytes != null && bytes.isNotEmpty && fmt != null) {
          final savedPath = await _savePastedImageBytes(fmt, bytes);
          if (!mounted) {
            if (savedPath != null) {
              await _deleteTemporaryImageSource(savedPath);
            }
            return;
          }
          if (savedPath != null) {
            _enqueueImages(
              [savedPath],
              compressConfig,
              deleteSourcesAfterProcessing: true,
            );
            return;
          }
        }

        // If clipboard has plain text via super_clipboard, paste it
        if (reader.canProvide(Formats.plainText)) {
          try {
            final String? text = await reader.readValue(Formats.plainText);
            if (text != null && text.isNotEmpty) {
              await _handlePastedText(text);
              return;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2) Fallback: legacy platform channel image handling
    final imageTempPaths = await ClipboardImages.getImagePaths();
    if (imageTempPaths.isNotEmpty) {
      await _enqueueClipboardImages(imageTempPaths);
      return;
    }

    // 3) Try files via platform channel on desktop (Finder/Explorer copies)
    bool handledFiles = false;
    try {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final filePaths = await ClipboardImages.getFilePaths();
        if (filePaths.isNotEmpty) {
          final imagePaths = <String>[];
          final otherPaths = <String>[];
          for (final raw in filePaths) {
            final src = raw.startsWith('file://') ? raw.substring(7) : raw;
            if (_isImageExtension(p.basename(src))) {
              imagePaths.add(src);
            } else {
              otherPaths.add(src);
            }
          }
          _enqueueImages(
            imagePaths,
            compressConfig,
            deleteSourcesAfterProcessing: false,
          );

          final saved = await _copyFilesToUpload(otherPaths);
          if (saved.images.isNotEmpty) {
            _enqueueImages(
              saved.images,
              compressConfig,
              deleteSourcesAfterProcessing: false,
            );
          }
          if (saved.docs.isNotEmpty) _addFiles(saved.docs);
          handledFiles =
              imagePaths.isNotEmpty ||
              saved.images.isNotEmpty ||
              saved.docs.isNotEmpty;
        }
      }
    } catch (_) {}
    if (handledFiles) return;

    // 4) Last resort: paste text via Flutter Clipboard API
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      await _handlePastedText(text);
    } catch (_) {}
  }

  Future<void> _handlePastedText(String text) async {
    if (!mounted) return;
    final settings = context.read<SettingsProvider>();
    final threshold = settings.longPasteAsFileThreshold;
    final isLongPaste =
        settings.longPasteAsFile &&
        text.characters.take(threshold + 1).length > threshold;
    if (!isLongPaste) {
      _insertPastedText(text);
      return;
    }

    if (!mounted) return;
    final pasteId = _nextTextPasteId++;
    setState(() => _pendingTextPasteIds.add(pasteId));
    final previousWrite = _textPasteWriteTail;
    final writeDone = Completer<void>();
    _textPasteWriteTail = writeDone.future;

    try {
      await previousWrite;
      if (!mounted || !_pendingTextPasteIds.contains(pasteId)) return;

      File? file;
      DocumentAttachment? attachment;
      try {
        final dir = await AppDirectories.getUploadDirectory();
        await dir.create(recursive: true);
        file = await _reservePastedTextFile(dir);
        await file.writeAsString(text, flush: true);
        attachment = DocumentAttachment(
          path: file.path,
          fileName: p.basename(file.path),
          mime: 'text/plain',
        );
      } catch (_) {}

      if (attachment != null &&
          mounted &&
          _pendingTextPasteIds.contains(pasteId)) {
        setState(() {
          _pendingTextPasteIds.remove(pasteId);
          _docs.add(attachment!);
        });
        return;
      }

      await _deleteUnclaimedPastedText(file);
      if (!mounted || !_pendingTextPasteIds.contains(pasteId)) return;
      setState(() => _pendingTextPasteIds.remove(pasteId));
      _insertPastedText(text);
    } finally {
      writeDone.complete();
    }
  }

  void _insertPastedText(String text) {
    if (!mounted) return;
    final value = _controller.value;
    final selection = value.selection;
    if (!selection.isValid) {
      _controller.text = value.text + text;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = value.text.replaceRange(start, end, text);
      _controller.value = value.copyWith(
        text: newText,
        selection: TextSelection.collapsed(offset: start + text.length),
        composing: TextRange.empty,
      );
    }
    setState(() {});
  }

  Future<File> _reservePastedTextFile(Directory dir) async {
    final baseName = 'pasted_${DateTime.now().millisecondsSinceEpoch}';
    var counter = 0;
    while (true) {
      final suffix = counter == 0 ? '' : '($counter)';
      final file = File(p.join(dir.path, '$baseName$suffix.txt'));
      try {
        return await file.create(exclusive: true);
      } on FileSystemException {
        if (!await file.exists()) rethrow;
        counter++;
      }
    }
  }

  Future<void> _deleteUnclaimedPastedText(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint(
        '[ChatInputBar] Failed to delete unclaimed pasted text ${file.path}: $error',
      );
    }
  }

  // Copy arbitrary files to upload directory (without deleting the source),
  // split into images and document attachments.
  Future<({List<String> images, List<DocumentAttachment> docs})>
  _copyFilesToUpload(List<String> srcPaths) async {
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    try {
      final dir = await AppDirectories.getUploadDirectory();
      for (final raw in srcPaths) {
        if (!mounted) {
          return (images: images, docs: docs);
        }
        final src = raw.startsWith('file://') ? raw.substring(7) : raw;
        if (_isImageExtension(p.basename(src))) {
          images.add(src);
          continue;
        }
        final savedPath = await FileImportHelper.copyXFile(XFile(src), dir);
        if (savedPath != null) {
          final savedName = p.basename(savedPath);
          if (_isImageExtension(savedName)) {
            images.add(savedPath);
          } else {
            final mime = _inferMimeByExtension(savedName);
            docs.add(
              DocumentAttachment(
                path: savedPath,
                fileName: savedName,
                mime: mime,
              ),
            );
          }
        }
      }
    } catch (_) {}
    return (images: images, docs: docs);
  }

  // Build a responsive left action bar that hides overflowing actions
  // into an anchored "+" menu using DesktopContextMenu style.
  Widget _buildResponsiveLeftActions(BuildContext context) {
    const double spacing = 8;
    const double normalButtonW = 32; // 20 + padding(6*2)
    const double modelButtonW = 30; // 28 + padding(1*2)
    const double plusButtonW = 32;

    final l10n = AppLocalizations.of(context)!;
    VoidCallback? lockTap(VoidCallback? callback) {
      if (_composerLocked) return null;
      return callback;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final List<_OverflowAction> actions = [];

        // Model select (always present; can be hidden if overflow)
        actions.add(
          _OverflowAction(
            width: (widget.modelIcon != null) ? modelButtonW : normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.chatInputBarSelectModelTooltip,
              icon: Lucide.Boxes,
              modelIcon: true,
              onTap: lockTap(widget.onSelectModel),
              onLongPress: lockTap(widget.onLongPressSelectModel),
              child: widget.modelIcon,
            ),
            menu: DesktopContextMenuItem(
              icon: Lucide.Boxes,
              label: l10n.chatInputBarSelectModelTooltip,
              onTap: lockTap(widget.onSelectModel),
            ),
          ),
        );

        // Search button (stateful icon depending on provider config)
        final settings = context.watch<SettingsProvider>();
        final ap = context.watch<AssistantProvider>();
        final currentProviderKey = widget.chatModelProviderKey;
        final currentModelId = widget.chatModelId;
        final cfg = (currentProviderKey != null)
            ? settings.getProviderConfig(currentProviderKey)
            : null;
        // Check built-in tools state using helper
        final toolsState = BuiltInToolsHelper.getActiveTools(
          cfg: cfg,
          modelId: currentModelId,
        );
        final builtinSearchActive = toolsState.searchActive;
        final appSearchEnabled = ap.currentSearchEnabled;
        final brandAsset = (() {
          if (!appSearchEnabled || builtinSearchActive) return null;
          final services = settings.searchServices;
          final sel = settings.searchServiceSelected.clamp(
            0,
            services.isNotEmpty ? services.length - 1 : 0,
          );
          final options = services.isNotEmpty
              ? services[sel]
              : SearchServiceOptions.defaultOption;
          final svc = SearchService.getService(options);
          return BrandAssets.assetForName(svc.name);
        })();

        // Search button
        actions.add(
          _OverflowAction(
            width: normalButtonW,
            builder: () {
              // Not enabled at all -> default globe
              if (!appSearchEnabled && !builtinSearchActive) {
                return _CompactIconButton(
                  tooltip: l10n.chatInputBarOnlineSearchTooltip,
                  icon: Lucide.Globe,
                  active: false,
                  onTap: lockTap(widget.onOpenSearch),
                );
              }
              // Built-in search -> magnifier icon in theme color
              if (builtinSearchActive) {
                return _CompactIconButton(
                  tooltip: l10n.chatInputBarOnlineSearchTooltip,
                  icon: Lucide.Search,
                  active: true,
                  onTap: lockTap(widget.onOpenSearch),
                );
              }
              // External provider search -> brand icon
              return _CompactIconButton(
                tooltip: l10n.chatInputBarOnlineSearchTooltip,
                icon: Lucide.Globe,
                active: true,
                onTap: lockTap(widget.onOpenSearch),
                childBuilder: (c) {
                  final asset = brandAsset;
                  if (asset != null) {
                    if (asset.endsWith('.svg')) {
                      return SvgPicture.asset(
                        asset,
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
                      );
                    } else {
                      return Image.asset(
                        asset,
                        width: 20,
                        height: 20,
                        color: c,
                        colorBlendMode: BlendMode.srcIn,
                      );
                    }
                  } else {
                    return Icon(Lucide.Globe, size: 20, color: c);
                  }
                },
              );
            },
            menu: () {
              // Prefer vector icon if brandAsset is svg, otherwise pick reasonable default
              if (!appSearchEnabled && !builtinSearchActive) {
                return DesktopContextMenuItem(
                  icon: Lucide.Globe,
                  label: l10n.chatInputBarOnlineSearchTooltip,
                  onTap: lockTap(widget.onOpenSearch),
                );
              }
              if (builtinSearchActive) {
                return DesktopContextMenuItem(
                  icon: Lucide.Search,
                  label: l10n.chatInputBarOnlineSearchTooltip,
                  onTap: lockTap(widget.onOpenSearch),
                );
              }
              if (brandAsset != null && brandAsset.endsWith('.svg')) {
                return DesktopContextMenuItem(
                  svgAsset: brandAsset,
                  label: l10n.chatInputBarOnlineSearchTooltip,
                  onTap: lockTap(widget.onOpenSearch),
                );
              }
              return DesktopContextMenuItem(
                icon: Lucide.Globe,
                label: l10n.chatInputBarOnlineSearchTooltip,
                onTap: lockTap(widget.onOpenSearch),
              );
            }(),
          ),
        );

        if (widget.supportsReasoning) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.chatInputBarReasoningStrengthTooltip,
                icon: Lucide.Brain,
                active: widget.reasoningActive,
                onTap: lockTap(widget.onConfigureReasoning),
                childBuilder: (c) => ReasoningIcons.budgetIcon(
                  widget.reasoningBudget,
                  size: 20,
                  color: c,
                ),
              ),
              menu: DesktopContextMenuItem(
                svgAsset: ReasoningIcons.assetForBudget(widget.reasoningBudget),
                label: l10n.chatInputBarReasoningStrengthTooltip,
                onTap: lockTap(widget.onConfigureReasoning),
              ),
            ),
          );
        }

        // MCP button
        if (widget.showMcpButton) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.chatInputBarMcpServersTooltip,
                icon: Lucide.Hammer,
                active: widget.mcpActive,
                onTap: lockTap(widget.onOpenMcp),
                onLongPress: lockTap(widget.onLongPressMcp),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Hammer,
                label: l10n.chatInputBarMcpServersTooltip,
                onTap: lockTap(widget.onOpenMcp),
              ),
            ),
          );
        }

        if (widget.showQuickPhraseButton && widget.onQuickPhrase != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.chatInputBarQuickPhraseTooltip,
                icon: Lucide.Zap,
                onTap: lockTap(widget.onQuickPhrase),
                onLongPress: lockTap(widget.onLongPressQuickPhrase),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Zap,
                label: l10n.chatInputBarQuickPhraseTooltip,
                onTap: lockTap(widget.onQuickPhrase),
              ),
            ),
          );
        }

        if (widget.onPickCamera != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.bottomToolsSheetCamera,
                icon: Lucide.Camera,
                onTap: lockTap(widget.onPickCamera),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Camera,
                label: l10n.bottomToolsSheetCamera,
                onTap: lockTap(widget.onPickCamera),
              ),
            ),
          );
        }

        if (widget.onPickPhotos != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.bottomToolsSheetPhotos,
                icon: Lucide.Image,
                onTap: lockTap(widget.onPickPhotos),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Image,
                label: l10n.bottomToolsSheetPhotos,
                onTap: lockTap(widget.onPickPhotos),
              ),
            ),
          );
        }

        if (widget.onUploadFiles != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.bottomToolsSheetUpload,
                icon: Lucide.Paperclip,
                onTap: lockTap(widget.onUploadFiles),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Paperclip,
                label: l10n.bottomToolsSheetUpload,
                onTap: lockTap(widget.onUploadFiles),
              ),
            ),
          );
        }

        if (widget.onToggleLearningMode != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.instructionInjectionTitle,
                icon: Lucide.Layers,
                active: widget.learningModeActive,
                onTap: lockTap(widget.onToggleLearningMode),
                onLongPress: lockTap(widget.onLongPressLearning),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Layers,
                label: l10n.instructionInjectionTitle,
                onTap: lockTap(widget.onToggleLearningMode),
              ),
            ),
          );
        }

        if (widget.onOpenWorldBook != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.worldBookTitle,
                icon: Lucide.BookOpen,
                active: widget.worldBookActive,
                onTap: lockTap(widget.onOpenWorldBook),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.BookOpen,
                label: l10n.worldBookTitle,
                onTap: lockTap(widget.onOpenWorldBook),
              ),
            ),
          );
        }

        if (widget.onClearContext != null) {
          void showContextMenu() {
            showDesktopAnchoredMenu(
              context,
              anchorKey: _contextMgmtAnchorKey,
              items: [
                if (widget.onCompressContext != null)
                  DesktopContextMenuItem(
                    icon: Lucide.package2,
                    label: l10n.compressContext,
                    onTap: lockTap(widget.onCompressContext),
                  ),
                DesktopContextMenuItem(
                  icon: Lucide.Eraser,
                  label: l10n.bottomToolsSheetClearContext,
                  onTap: lockTap(widget.onClearContext),
                ),
              ],
            );
          }

          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => Container(
                key: _contextMgmtAnchorKey,
                child: _CompactIconButton(
                  tooltip: l10n.contextManagement,
                  icon: Lucide.Eraser,
                  onTap: _composerLocked ? null : showContextMenu,
                ),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Eraser,
                label: l10n.contextManagement,
                onTap: _composerLocked ? null : showContextMenu,
              ),
            ),
          );
        }

        if (widget.showMiniMapButton) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.miniMapTooltip,
                icon: Lucide.Map,
                onTap: lockTap(widget.onOpenMiniMap),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Map,
                label: l10n.miniMapTooltip,
                onTap: lockTap(widget.onOpenMiniMap),
              ),
            ),
          );
        }

        if (widget.showOcrButton && widget.onToggleOcr != null) {
          actions.add(
            _OverflowAction(
              width: normalButtonW,
              builder: () => _CompactIconButton(
                tooltip: l10n.chatInputBarOcrTooltip,
                icon: Lucide.Eye,
                active: widget.ocrActive,
                onTap: lockTap(widget.onToggleOcr),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Eye,
                label: l10n.chatInputBarOcrTooltip,
                onTap: lockTap(widget.onToggleOcr),
              ),
            ),
          );
        }

        // Compute total width with spacing to see if overflow is needed
        double full = 0;
        for (var i = 0; i < actions.length; i++) {
          if (i > 0) full += spacing;
          full += actions[i].width;
        }

        final maxW = constraints.maxWidth;
        int visibleCount = actions.length;
        if (full > maxW) {
          // First pass: include as many as possible ignoring the +
          double used = 0;
          visibleCount = 0;
          for (var i = 0; i < actions.length; i++) {
            final add = (visibleCount > 0 ? spacing : 0) + actions[i].width;
            if (used + add <= maxW) {
              used += add;
              visibleCount++;
            } else {
              break;
            }
          }
          // Ensure + button fits; remove items until it does
          while (visibleCount > 0 && used + spacing + plusButtonW > maxW) {
            // remove last
            used -= actions[visibleCount - 1].width;
            if (visibleCount - 1 > 0) used -= spacing;
            visibleCount--;
          }
        }

        final overflowItems = actions.sublist(visibleCount);

        final children = <Widget>[];
        for (var i = 0; i < visibleCount; i++) {
          if (i > 0) children.add(const SizedBox(width: spacing));
          children.add(actions[i].builder());
        }

        if (overflowItems.isNotEmpty) {
          if (children.isNotEmpty) children.add(const SizedBox(width: spacing));
          final menuItems = overflowItems
              .map((e) => e.menu)
              .toList(growable: false);
          children.add(
            Container(
              key: _leftOverflowAnchorKey,
              child: _CompactIconButton(
                tooltip: l10n.chatInputBarMoreTooltip,
                icon: Lucide.Plus,
                onTap: () {
                  showDesktopAnchoredMenu(
                    context,
                    anchorKey: _leftOverflowAnchorKey,
                    items: menuItems,
                  );
                },
              ),
            ),
          );
        }

        return Row(children: children);
      },
    );
  }

  String _inferMimeByExtension(String name) {
    final mediaMime = inferMediaMimeFromSource(name);
    if (mediaMime.isNotEmpty) return mediaMime;
    final lower = name.toLowerCase();
    // Documents / text
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.mdx')) {
      return 'text/plain';
    }
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.yml') || lower.endsWith('.yaml')) {
      return 'application/x-yaml';
    }
    if (lower.endsWith('.py')) return 'text/x-python';
    if (lower.endsWith('.java')) return 'text/x-java-source';
    if (lower.endsWith('.kt') || lower.endsWith('.kts')) return 'text/x-kotlin';
    if (lower.endsWith('.dart')) return 'text/x-dart';
    if (lower.endsWith('.ts')) return 'text/typescript';
    if (lower.endsWith('.tsx')) return 'text/tsx';
    return 'application/octet-stream';
  }

  bool _isImageExtension(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  Future<void> _enqueueClipboardImages(List<String> srcPaths) async {
    try {
      final compressConfig = context
          .read<SettingsProvider>()
          .resolveImageCompressConfig();
      final ready = <String>[];
      final temporary = <String>[];
      for (var raw in srcPaths) {
        try {
          // Normalize path (strip file:// if present)
          final src = raw.startsWith('file://') ? raw.substring(7) : raw;
          // If already under upload directory, just keep it
          if (src.contains('/upload/') || src.contains('\\upload\\')) {
            ready.add(src);
            continue;
          }
          if (await File(src).exists()) temporary.add(src);
        } catch (_) {
          // skip single file errors
        }
      }
      _addImages(ready);
      _enqueueImages(
        temporary,
        compressConfig,
        deleteSourcesAfterProcessing: true,
      );
    } catch (_) {}
  }

  void _moveCaret(int dir, {bool extend = false, bool byWord = false}) {
    final text = _controller.text;
    if (text.isEmpty) return;
    TextSelection sel = _controller.selection;
    if (!sel.isValid) {
      final off = dir < 0 ? text.length : 0;
      _controller.selection = TextSelection.collapsed(offset: off);
      return;
    }

    int nextOffset(int from, int direction) {
      if (!byWord) return (from + direction).clamp(0, text.length);
      // Move by simple word boundary: skip whitespace; then skip non-whitespace
      int i = from;
      if (direction < 0) {
        // Move left
        while (i > 0 && text[i - 1].trim().isEmpty) {
          i--;
        }
        while (i > 0 && text[i - 1].trim().isNotEmpty) {
          i--;
        }
      } else {
        // Move right
        while (i < text.length && text[i].trim().isEmpty) {
          i++;
        }
        while (i < text.length && text[i].trim().isNotEmpty) {
          i++;
        }
      }
      return i.clamp(0, text.length);
    }

    if (extend) {
      final newExtent = nextOffset(sel.extentOffset, dir);
      _controller.selection = sel.copyWith(extentOffset: newExtent);
    } else {
      final base = dir < 0 ? sel.start : sel.end;
      final collapsed = nextOffset(base, dir);
      _controller.selection = TextSelection.collapsed(offset: collapsed);
    }
    setState(() {});
  }

  Widget _buildInlineAttachmentPreviews(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final previewFill = theme.colorScheme.onSurface.withValues(
      alpha: isDark ? 0.08 : 0.045,
    );
    final previewBorder = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.10)
        : theme.colorScheme.outline.withValues(alpha: 0.13);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xxs,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_images.isNotEmpty)
            SizedBox(
              key: const ValueKey('chat-input-image-previews'),
              height: _imagePreviewHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final image = _images[idx];
                  final processing = _processingImageIds.contains(image.id);
                  final failed =
                      !processing && _failedImageIds.contains(image.id);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: previewBorder, width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: processing
                              ? ColoredBox(
                                  color: theme.colorScheme.scrim,
                                  child: const SizedBox(width: 64, height: 64),
                                )
                              : Image.file(
                                  File(image.path),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: previewFill,
                                    child: Icon(
                                      Icons.broken_image,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: processing
                              ? IgnorePointer(
                                  key: ValueKey(
                                    'chat-input-image-processing:${image.id}',
                                  ),
                                  child: Tooltip(
                                    message: l10n.chatInputBarImageProcessing,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.scrim
                                            .withValues(alpha: 0.32),
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      alignment: Alignment.center,
                                      child: const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors
                                                .white, // color-gate: ignore (on scrim over photo)
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('image-idle'),
                                ),
                        ),
                      ),
                      if (failed)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.priority_high,
                              size: 12,
                              color: theme.colorScheme.onTertiary,
                            ),
                          ),
                        ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IosCardPress(
                          key: ValueKey('chat-input-image-remove:$idx'),
                          haptics: false,
                          baseColor: theme.colorScheme.scrim.withValues(
                            alpha: isDark ? 0.50 : 0.46,
                          ),
                          pressedScale: 0.94,
                          borderRadius: BorderRadius.circular(
                            _imageRemoveButtonSize / 2,
                          ),
                          padding: EdgeInsets.zero,
                          duration: const Duration(milliseconds: 140),
                          onTap: () => _removeImageAt(idx),
                          child: const SizedBox(
                            width: _imageRemoveButtonSize,
                            height: _imageRemoveButtonSize,
                            child: Icon(
                              Icons.close,
                              size: 11,
                              color: Colors
                                  .white, // color-gate: ignore (on scrim over photo)
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          if (_images.isNotEmpty && _docs.isNotEmpty)
            const SizedBox(height: AppSpacing.xs),
          if (_docs.isNotEmpty)
            SizedBox(
              key: const ValueKey('chat-input-document-previews'),
              height: _documentPreviewHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final d = _docs[idx];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: previewFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: previewBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: Text(
                            d.fileName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 3),
                        IosIconButton(
                          key: ValueKey('chat-input-document-remove:$idx'),
                          icon: Icons.close,
                          size: 16,
                          padding: const EdgeInsets.all(3),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.58,
                          ),
                          onTap: () => _removeDocumentAt(idx),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final selectedAsrService = settings.selectedAsrService;
    final asr = widget.asrProvider;
    final showVoiceInput =
        asr != null &&
        selectedAsrService != null &&
        asr.canUse(selectedAsrService) &&
        !asr.isActive;
    final isDark = theme.brightness == Brightness.dark;
    final inputFillColor = _inputFillColor(
      theme: theme,
      backgroundImageActive: widget.backgroundImageActive,
      lightOpacity: widget.inputBackgroundOpacityLight,
      darkOpacity: widget.inputBackgroundOpacityDark,
    );
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImages = _images.isNotEmpty;
    final hasDocs = _docs.isNotEmpty;
    _supportsImagesApiRouting(context);
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bool isMobileLayout = size.width < AppBreakpoints.tablet;
    final double visibleHeight = size.height - viewInsets.bottom;
    final double attachmentPreviewHeight = (hasDocs || hasImages)
        ? AppSpacing.sm +
              (hasImages ? _imagePreviewHeight : 0) +
              (hasImages && hasDocs ? AppSpacing.xs : 0) +
              (hasDocs ? _documentPreviewHeight : 0) +
              AppSpacing.xxs
        : 0;
    const double baseChromeHeight = 120; // padding + action row + chrome buffer
    double maxInputHeight = double.infinity;
    if (isMobileLayout) {
      final double available =
          visibleHeight - attachmentPreviewHeight - baseChromeHeight;
      final double softCap = visibleHeight * 0.45;
      if (available > 0) {
        maxInputHeight = math.min(softCap, available);
        maxInputHeight = math.min(available, math.max(80.0, maxInputHeight));
      } else {
        maxInputHeight = math.max(80.0, softCap);
      }
    }
    // Cap text field height on mobile so expanded input stays above the keyboard.
    final BoxConstraints textFieldConstraints =
        (isMobileLayout && maxInputHeight.isFinite && maxInputHeight > 0)
        ? BoxConstraints(maxHeight: maxInputHeight)
        : const BoxConstraints();

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xxs,
          AppSpacing.sm,
          AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.hasQueuedInput) ...[
              _QueuedInputBanner(
                label: AppLocalizations.of(context)!.chatInputBarQueuedPending,
                previewText: widget.queuedPreviewText,
                cancelLabel: AppLocalizations.of(
                  context,
                )!.chatInputBarQueuedCancel,
                onCancel: widget.onCancelQueuedInput,
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Main input container with iOS-like frosted glass effect
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        // Translucent background over blurred content
                        color: inputFillColor,
                        borderRadius: BorderRadius.circular(20),
                        // Use previous gray border for better contrast on white
                        border: Border.all(
                          color: isDark
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.10,
                                )
                              : theme.colorScheme.outline.withValues(
                                  alpha: 0.20,
                                ),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          if (hasDocs || hasImages)
                            _buildInlineAttachmentPreviews(context, isDark),
                          // Input field with expand/collapse button
                          Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md,
                                  AppSpacing.xxs,
                                  AppSpacing.md,
                                  AppSpacing.xs,
                                ),
                                child: ConstrainedBox(
                                  constraints: textFieldConstraints,
                                  child: Focus(
                                    onKeyEvent: _handleKeyEvent,
                                    child: Builder(
                                      builder: (ctx) {
                                        // Desktop: show a right-click context menu with paste/cut/copy/select all
                                        // Future<void> _showDesktopContextMenu(Offset globalPos) async {
                                        //   bool isDesktop = false;
                                        //   try { isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux; } catch (_) {}
                                        //   if (!isDesktop) return;
                                        //   // Ensure input has focus so operations apply correctly
                                        //   try { widget.focusNode?.requestFocus(); } catch (_) {}
                                        //
                                        //   final sel = _controller.selection;
                                        //   final hasSelection = sel.isValid && !sel.isCollapsed;
                                        //   final hasText = _controller.text.isNotEmpty;
                                        //
                                        //   final l10n = MaterialLocalizations.of(ctx);
                                        //   await showDesktopContextMenuAt(
                                        //     ctx,
                                        //     globalPosition: globalPos,
                                        //     items: [
                                        //       DesktopContextMenuItem(
                                        //         icon: Lucide.Clipboard,
                                        //         label: l10n.pasteButtonLabel,
                                        //         onTap: () async {
                                        //           await _handlePasteFromClipboard();
                                        //         },
                                        //       ),
                                        //       DesktopContextMenuItem(
                                        //         icon: Lucide.Cut,
                                        //         label: l10n.cutButtonLabel,
                                        //         onTap: () async {
                                        //           final s = _controller.selection;
                                        //           if (s.isValid && !s.isCollapsed) {
                                        //             final text = _controller.text.substring(s.start, s.end);
                                        //             try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
                                        //             final newText = _controller.text.replaceRange(s.start, s.end, '');
                                        //             _controller.value = TextEditingValue(
                                        //               text: newText,
                                        //               selection: TextSelection.collapsed(offset: s.start),
                                        //             );
                                        //             setState(() {});
                                        //           }
                                        //         },
                                        //       ),
                                        //       DesktopContextMenuItem(
                                        //         icon: Lucide.Copy,
                                        //         label: l10n.copyButtonLabel,
                                        //         onTap: () async {
                                        //           final s2 = _controller.selection;
                                        //           if (s2.isValid && !s2.isCollapsed) {
                                        //             final text = _controller.text.substring(s2.start, s2.end);
                                        //             try { await Clipboard.setData(ClipboardData(text: text)); } catch (_) {}
                                        //           }
                                        //         },
                                        //       ),
                                        //       // DesktopContextMenuItem(
                                        //       //   // icon: Lucide.TextSelect,
                                        //       //   label: l10n.selectAllButtonLabel,
                                        //       //   onTap: () {
                                        //       //     if (hasText) {
                                        //       //       _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
                                        //       //       setState(() {});
                                        //       //     }
                                        //       //   },
                                        //       // ),
                                        //     ],
                                        //   );
                                        // }

                                        final enterToSend = context
                                            .watch<SettingsProvider>()
                                            .enterToSendOnMobile;
                                        return GestureDetector(
                                          behavior:
                                              HitTestBehavior.deferToChild,
                                          // onSecondaryTapDown: (details) {
                                          //   // _showDesktopContextMenu(details.globalPosition);
                                          // },
                                          child: TextField(
                                            controller: _controller,
                                            focusNode: widget.focusNode,
                                            onChanged: _onTextChanged,
                                            contentInsertionConfiguration:
                                                ContentInsertionConfiguration(
                                                  onContentInserted:
                                                      _handleInsertedContent,
                                                  allowedMimeTypes: const [
                                                    'image/png',
                                                    'image/jpeg',
                                                    'image/jpg',
                                                    'image/gif',
                                                    'image/webp',
                                                  ],
                                                ),
                                            readOnly:
                                                _composerLocked ||
                                                _ownsVoiceSession,
                                            minLines: 1,
                                            maxLines: _isExpanded ? 25 : 5,
                                            // On mobile, optionally show "Send" on the return key and submit on tap.
                                            // Still keep multiline so pasted text preserves line breaks.
                                            keyboardType:
                                                TextInputType.multiline,
                                            textInputAction: enterToSend
                                                ? TextInputAction.send
                                                : TextInputAction.newline,
                                            onSubmitted: enterToSend
                                                ? (_) =>
                                                      unawaited(_handleSend())
                                                : null,
                                            // Custom context menu: use instance method to avoid flickering
                                            // caused by recreating the callback on every build.
                                            // See: https://github.com/flutter/flutter/issues/150551
                                            contextMenuBuilder:
                                                _buildContextMenu,
                                            autofocus: false,
                                            decoration: InputDecoration(
                                              hintText: _hint(context),
                                              hintStyle: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.45),
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 2,
                                                  ),
                                            ),
                                            style: TextStyle(
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontSize:
                                                  (Platform.isWindows ||
                                                      Platform.isLinux ||
                                                      Platform.isMacOS)
                                                  ? 14
                                                  : 15,
                                            ),
                                            cursorColor:
                                                theme.colorScheme.primary,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Expand/Collapse icon button (only shown when 3+ lines)
                              if (_showExpandButton)
                                Positioned(
                                  top: 10,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _isExpanded = !_isExpanded,
                                      );
                                      _ensureCaretVisible();
                                    },
                                    child: Icon(
                                      _isExpanded
                                          ? Lucide.ChevronsDownUp
                                          : Lucide.ChevronsUpDown,
                                      size: 16,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Bottom buttons row (no divider)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xs,
                              0,
                              AppSpacing.xs,
                              AppSpacing.xs,
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                    opacity: anim,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.35),
                                        end: Offset.zero,
                                      ).animate(anim),
                                      child: child,
                                    ),
                                  ),
                              child: _ownsVoiceSession
                                  ? _buildVoiceRecordingRow(context, theme)
                                  : Row(
                                      key: const ValueKey('actions'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Responsive left action bar that overflows into a + menu on desktop
                                        Expanded(
                                          child: _buildResponsiveLeftActions(
                                            context,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            if (widget.showMoreButton) ...[
                                              _CompactIconButton(
                                                tooltip: AppLocalizations.of(
                                                  context,
                                                )!.chatInputBarMoreTooltip,
                                                icon: Lucide.Plus,
                                                active: widget.moreOpen,
                                                onTap: _composerLocked
                                                    ? null
                                                    : widget.onMore,
                                                childBuilder: (c) =>
                                                    AnimatedSwitcher(
                                                      duration: const Duration(
                                                        milliseconds: 200,
                                                      ),
                                                      transitionBuilder:
                                                          (
                                                            child,
                                                            anim,
                                                          ) => RotationTransition(
                                                            turns:
                                                                Tween<double>(
                                                                  begin: 0.85,
                                                                  end: 1,
                                                                ).animate(anim),
                                                            child:
                                                                FadeTransition(
                                                                  opacity: anim,
                                                                  child: child,
                                                                ),
                                                          ),
                                                      child: Icon(
                                                        widget.moreOpen
                                                            ? Lucide.X
                                                            : Lucide.Plus,
                                                        key: ValueKey(
                                                          widget.moreOpen
                                                              ? 'close'
                                                              : 'add',
                                                        ),
                                                        size: 20,
                                                        color: c,
                                                      ),
                                                    ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            if (showVoiceInput) ...[
                                              _CompactIconButton(
                                                tooltip: AppLocalizations.of(
                                                  context,
                                                )!.chatInputBarVoiceInputTooltip,
                                                icon: Lucide.Mic,
                                                onTap:
                                                    _composerLocked ||
                                                        widget.loading
                                                    ? null
                                                    : () => unawaited(
                                                        _startVoiceInput(),
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            _CompactSendButton(
                                              enabled:
                                                  (hasText ||
                                                      hasImages ||
                                                      hasDocs) &&
                                                  !_hasUnreadyImages &&
                                                  !widget.loading,
                                              loading: widget.loading,
                                              onSend: _handleSend,
                                              onStop: widget.loading
                                                  ? widget.onStop
                                                  : null,
                                              color: theme.colorScheme.primary,
                                              icon: Lucide.ArrowUp,
                                              tooltip: widget.sendButtonTooltip,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_imageModeActive)
                  PositionedDirectional(
                    top: -12,
                    start: AppSpacing.sm,
                    child: _ImageModePill(
                      label: AppLocalizations.of(
                        context,
                      )!.chatInputBarImageMode,
                      closeTooltip: AppLocalizations.of(
                        context,
                      )!.chatInputBarDisableImageModeTooltip,
                      onClose: _composerLocked
                          ? null
                          : () {
                              final key = _imageModeModelKey;
                              if (key == null) return;
                              setState(() {
                                _dismissedImageModeModelKey = key;
                              });
                            },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedInputBanner extends StatelessWidget {
  const _QueuedInputBanner({
    required this.label,
    required this.cancelLabel,
    this.previewText,
    this.onCancel,
  });

  final String label;
  final String cancelLabel;
  final String? previewText;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final preview = previewText?.trim();
    final hasPreview = preview != null && preview.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
            : theme.colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.schedule_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
                if (hasPreview) ...[
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IosCardPress(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(10),
            baseColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              cancelLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageModePill extends StatelessWidget {
  const _ImageModePill({
    required this.label,
    required this.closeTooltip,
    required this.onClose,
  });

  final String label;
  final String closeTooltip;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bg = scheme.surface.withValues(alpha: isDark ? 0.34 : 0.58);
    final border = isDark
        ? scheme.onSurface.withValues(alpha: 0.14)
        : scheme.primary.withValues(alpha: 0.36);
    final fg = isDark ? scheme.onSurface : scheme.primary;
    final iconColor = isDark ? scheme.primaryContainer : scheme.primary;
    final radius = BorderRadius.circular(999);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 172),
              child: SizedBox(
                height: 24,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 9, end: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Brush, size: 14, color: iconColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: AppFontWeights.semibold,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      Tooltip(
                        message: closeTooltip,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onClose,
                          child: Padding(
                            padding: const EdgeInsets.all(5),
                            child: Icon(
                              Lucide.X,
                              size: 13,
                              color: (isDark ? scheme.onSurfaceVariant : fg)
                                  .withValues(
                                    alpha: onClose == null ? 0.38 : 0.78,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Internal data model for responsive overflow actions on desktop
class _OverflowAction {
  final double width;
  final Widget Function() builder;
  final DesktopContextMenuItem menu;
  const _OverflowAction({
    required this.width,
    required this.builder,
    required this.menu,
  });
}

// New compact button for the integrated input bar
class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    this.onTap,
    this.onLongPress,
    this.tooltip,
    this.active = false,
    this.child,
    this.childBuilder,
    this.modelIcon = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final bool active;
  final Widget? child;
  final Widget Function(Color color)? childBuilder;
  final bool modelIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fgColor = active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.70 : 0.54);
    final bool isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    // Keep overall button size constant. For model icon with child, enlarge child slightly
    // and reduce padding so (2*padding + childSize) stays unchanged.
    final bool isModelChild = modelIcon && child != null;
    final double iconSize = 20.0; // default glyph size
    final double childSize = isModelChild
        ? 28.0
        : iconSize; // enlarge circle a bit more
    final double padding = isModelChild
        ? 1.0
        : 6.0; // keep total ~30px (2*1 + 28)

    final button = IosIconButton(
      size: isModelChild ? childSize : 20,
      padding: EdgeInsets.all(padding),
      onTap: onTap,
      // Disable long press on desktop platforms
      onLongPress: isDesktop ? null : onLongPress,
      color: fgColor,
      builder: childBuilder != null
          ? (c) => SizedBox(
              width: childSize,
              height: childSize,
              child: childBuilder!(c),
            )
          : (child != null
                ? (_) => SizedBox(
                    width: childSize,
                    height: childSize,
                    child: child,
                  )
                : null),
      icon: child == null && childBuilder == null ? icon : null,
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 350),
      child: Semantics(tooltip: tooltip!, child: button),
    );
  }
}

// New compact send button for the integrated input bar
class _CompactSendButton extends StatelessWidget {
  const _CompactSendButton({
    required this.enabled,
    required this.onSend,
    required this.color,
    required this.icon,
    this.loading = false,
    this.onStop,
    this.tooltip,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final Color color;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = (enabled || loading)
        ? color
        : cs.onSurface.withValues(alpha: 0.12);
    final fg = (enabled || loading)
        ? cs.onPrimary
        : cs.onSurface.withValues(alpha: 0.38);

    final button = Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? onStop : (enabled ? onSend : null),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: loading
                ? SvgPicture.asset(
                    key: const ValueKey('stop'),
                    'assets/icons/stop.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                  )
                : Icon(icon, key: const ValueKey('send'), size: 18, color: fg),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 350),
      child: Semantics(tooltip: tooltip!, child: button),
    );
  }
}

// Scrolling waveform driven by real mic amplitude samples (newest on the right).
class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({super.key, required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _VoiceWaveformPainter(levels: levels, color: color),
    );
  }
}

class _VoiceTranscribingIndicator extends StatefulWidget {
  const _VoiceTranscribingIndicator({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  State<_VoiceTranscribingIndicator> createState() =>
      _VoiceTranscribingIndicatorState();
}

class _VoiceTranscribingIndicatorState
    extends State<_VoiceTranscribingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(Lucide.Loader, size: 15, color: widget.color),
          ),
          const SizedBox(width: 7),
          Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: widget.color),
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveformPainter extends CustomPainter {
  _VoiceWaveformPainter({required this.levels, required this.color});

  /// Normalized mic levels in [0, 1]; the last entry is the newest sample.
  final List<double> levels;
  final Color color;

  static const double _barWidth = 3;
  static const double _barGap = 3.5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const step = _barWidth + _barGap;
    final count = ((size.width + _barGap) / step).floor();
    if (count <= 0) return;
    final centerY = size.height / 2;
    final maxH = size.height * 0.92;
    // Center the bar row so both ends get the same inset — the capsule
    // caps are then symmetric regardless of the exact width.
    final leftInset = (size.width - (count * step - _barGap)) / 2;
    // Samples are right-aligned onto the bar slots: the newest sample sits
    // at the right edge and older samples scroll left, like a real recorder.
    final visible = math.min(count, levels.length);
    final first = levels.length - visible;
    for (var i = 0; i < visible; i++) {
      final level = levels[first + i].clamp(0.0, 1.0);
      final slot = count - visible + i;
      final x = leftInset + slot * step;
      // True capsule silhouette: a rectangle with fully-rounded ends, i.e.
      // the corner radius equals half the max bar height. Bars inside the
      // cap are shortened along the semicircle but still follow the volume.
      final radius = maxH / 2;
      final dCenter =
          math.min(x, size.width - (x + _barWidth)) +
          _barWidth / 2; // bar center distance to the nearest edge
      double envelope = 1.0;
      if (dCenter < radius) {
        envelope =
            math.sqrt(
              math.max(
                0.0,
                radius * radius - (radius - dCenter) * (radius - dCenter),
              ),
            ) /
            radius;
      }
      final h = math.max(2.0, maxH * level * envelope);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - h / 2, _barWidth, h),
          const Radius.circular(_barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VoiceWaveformPainter oldDelegate) => true;
}

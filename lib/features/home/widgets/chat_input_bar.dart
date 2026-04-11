import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../theme/design_tokens.dart';
import '../../../icons/lucide_adapter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/file_import_helper.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../../../shared/responsive/breakpoints.dart';
import 'dart:async';
import 'dart:io';
import '../../../core/models/chat_input_data.dart';
import '../../../utils/clipboard_images.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/haptics.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../core/utils/multimodal_input_utils.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/voice_attachment_utils.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../services/voice_input_service.dart';
import '../utils/desktop_voice_input_utils.dart';

class ChatInputBarController {
  _ChatInputBarState? _state;
  void _bind(_ChatInputBarState s) => _state = s;
  void _unbind(_ChatInputBarState s) {
    if (identical(_state, s)) _state = null;
  }

  void addImages(List<String> paths) => _state?._addImages(paths);
  void clearImages() => _state?._clearImages();
  void addFiles(List<DocumentAttachment> docs) => _state?._addFiles(docs);
  void clearFiles() => _state?._clearFiles();
  void startDesktopVoiceHotkeyRecording() =>
      _state?._startDesktopVoiceHotkeyRecording();
  void finishDesktopVoiceHotkeyRecording() =>
      _state?._finishDesktopVoiceHotkeyRecording();
  void cancelDesktopVoiceSession() => _state?._cancelDesktopVoiceSession();
  bool hasDesktopVoiceSession() => _state?._hasDesktopVoiceSession() ?? false;
}

enum _DesktopVoiceState { idle, countdown, recording, confirm }

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    this.onSend,
    this.onStop,
    this.onSelectModel,
    this.onLongPressSelectModel,
    this.onOpenMcp,
    this.onLongPressMcp,
    this.onToggleSearch,
    this.onOpenSearch,
    this.onMore,
    this.onConfigureReasoning,
    this.moreOpen = false,
    this.focusNode,
    this.modelIcon,
    this.controller,
    this.mediaController,
    this.loading = false,
    this.reasoningActive = false,
    this.supportsReasoning = true,
    this.showMcpButton = false,
    this.mcpActive = false,
    this.searchEnabled = false,
    this.showMiniMapButton = false,
    this.onOpenMiniMap,
    this.onPickCamera,
    this.onPickPhotos,
    this.onUploadFiles,
    this.showVoiceInputButton = false,
    this.voiceRecording = false,
    this.onStartVoiceRecording,
    this.onStopVoiceRecording,
    this.onCancelVoiceRecording,
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
  });

  final ValueChanged<ChatInputData>? onSend;
  final VoidCallback? onStop;
  final VoidCallback? onSelectModel;
  final VoidCallback? onLongPressSelectModel;
  final VoidCallback? onOpenMcp;
  final VoidCallback? onLongPressMcp;
  final ValueChanged<bool>? onToggleSearch;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onMore;
  final VoidCallback? onConfigureReasoning;
  final bool moreOpen;
  final FocusNode? focusNode;
  final Widget? modelIcon;
  final TextEditingController? controller;
  final ChatInputBarController? mediaController;
  final bool loading;
  final bool reasoningActive;
  final bool supportsReasoning;
  final bool showMcpButton;
  final bool mcpActive;
  final bool searchEnabled;
  final bool showMiniMapButton;
  final VoidCallback? onOpenMiniMap;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickPhotos;
  final VoidCallback? onUploadFiles;
  final bool showVoiceInputButton;
  final bool voiceRecording;
  final Future<bool> Function()? onStartVoiceRecording;
  final Future<DocumentAttachment?> Function()? onStopVoiceRecording;
  final Future<void> Function()? onCancelVoiceRecording;
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

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with WidgetsBindingObserver {
  static const double _maxVoiceKeepZoneRadius = 130;
  static const int _desktopVoiceCountdownSeconds = 2;
  late TextEditingController _controller;
  bool _isExpanded = false; // Track expand/collapse state for input field
  final List<String> _images = <String>[]; // local file paths
  final List<DocumentAttachment> _docs =
      <DocumentAttachment>[]; // files to upload
  bool _voiceActionInFlight = false;
  Timer? _voiceAutoStopTimer;
  Timer? _desktopVoiceCountdownTimer;
  Timer? _desktopVoiceTicker;
  final GlobalKey _voiceButtonKey = GlobalKey(
    debugLabel: 'voice-button-anchor',
  );
  OverlayEntry? _voiceOverlayEntry;
  OverlayEntry? _desktopVoiceOverlayEntry;
  bool _voicePointerHeld = false;
  bool _voicePressActive = false;
  bool _voiceWillCancel = false;
  bool _desktopVoiceHotkeyHeld = false;
  bool _desktopVoiceHotkeyMode = false;
  bool _desktopVoiceCancelAfterStart = false;
  _DesktopVoiceState _desktopVoiceState = _DesktopVoiceState.idle;
  int _desktopVoiceCountdown = _desktopVoiceCountdownSeconds;
  DateTime? _desktopVoiceRecordingStartedAt;
  Duration _desktopVoiceElapsed = Duration.zero;
  DocumentAttachment? _desktopVoicePendingAttachment;
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
  // Suppress context menu briefly after app resume to avoid flickering
  bool _suppressContextMenu = false;

  // Instance method for onChanged to avoid recreating the callback on every build
  void _onTextChanged(String _) => setState(() {});

  void _addImages(List<String> paths) {
    if (paths.isEmpty) return;
    setState(() => _images.addAll(paths));
  }

  void _clearImages() {
    setState(() => _images.clear());
  }

  void _addFiles(List<DocumentAttachment> docs) {
    if (docs.isEmpty) return;
    setState(() => _docs.addAll(docs));
  }

  void _clearFiles() {
    setState(() => _docs.clear());
  }

  void _removeImageAt(int index) async {
    final path = _images[index];
    setState(() => _images.removeAt(index));
    // best-effort delete
    try {
      final f = File(path);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    widget.mediaController?._bind(this);
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
      _cancelDesktopVoiceSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voiceAutoStopTimer?.cancel();
    _desktopVoiceCountdownTimer?.cancel();
    _desktopVoiceTicker?.cancel();
    _removeVoiceOverlay();
    _removeDesktopVoiceOverlay();
    for (final timer in _repeatTimers.values) {
      try {
        timer?.cancel();
      } catch (_) {}
    }
    _repeatTimers.clear();
    widget.mediaController?._unbind(this);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voiceRecording && !widget.voiceRecording) {
      _voiceAutoStopTimer?.cancel();
      _removeVoiceOverlay();
      _voicePointerHeld = false;
      _voicePressActive = false;
      _voiceWillCancel = false;
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

  bool get _isDesktopVoiceSupported {
    return supportsDesktopVoiceInputPlatform(defaultTargetPlatform) &&
        widget.showVoiceInputButton &&
        widget.onStartVoiceRecording != null &&
        widget.onStopVoiceRecording != null &&
        widget.onCancelVoiceRecording != null;
  }

  bool _hasDesktopVoiceSession() {
    return _desktopVoiceState != _DesktopVoiceState.idle;
  }

  String _desktopVoiceShortcutLabel() =>
      desktopVoiceShortcutLabelForPlatform(defaultTargetPlatform);

  void _startDesktopVoiceHotkeyRecording() {
    if (!_isDesktopVoiceSupported) return;
    if (_voiceActionInFlight ||
        widget.loading ||
        _desktopVoiceState != _DesktopVoiceState.idle) {
      return;
    }
    _desktopVoiceHotkeyHeld = true;
    _desktopVoiceHotkeyMode = true;
    _desktopVoiceCancelAfterStart = false;
    unawaited(_startDesktopVoiceSession(skipCountdown: true));
  }

  void _finishDesktopVoiceHotkeyRecording() {
    final hadHold = _desktopVoiceHotkeyHeld;
    _desktopVoiceHotkeyHeld = false;
    if (!hadHold && !_desktopVoiceHotkeyMode) return;
    if (_desktopVoiceState == _DesktopVoiceState.recording &&
        !_voiceActionInFlight) {
      unawaited(_stopDesktopVoiceRecordingForConfirmation());
    }
  }

  Future<void> _onDesktopVoiceButtonTap() async {
    if (!_isDesktopVoiceSupported || _voiceActionInFlight || widget.loading) {
      return;
    }
    switch (_desktopVoiceState) {
      case _DesktopVoiceState.idle:
        await _startDesktopVoiceSession(skipCountdown: false);
        return;
      case _DesktopVoiceState.countdown:
        await _cancelDesktopVoiceSessionInternal();
        return;
      case _DesktopVoiceState.recording:
        await _stopDesktopVoiceRecordingForConfirmation();
        return;
      case _DesktopVoiceState.confirm:
        return;
    }
  }

  Future<bool> _startDesktopVoiceSession({required bool skipCountdown}) async {
    if (!_isDesktopVoiceSupported ||
        _voiceActionInFlight ||
        widget.loading ||
        _desktopVoiceState != _DesktopVoiceState.idle) {
      return false;
    }

    _desktopVoiceCancelAfterStart = false;
    _desktopVoicePendingAttachment = null;
    _desktopVoiceElapsed = Duration.zero;
    _desktopVoiceRecordingStartedAt = null;
    _desktopVoiceCountdownTimer?.cancel();
    _desktopVoiceTicker?.cancel();
    _voiceAutoStopTimer?.cancel();

    if (skipCountdown) {
      setState(() {
        _desktopVoiceState = _DesktopVoiceState.recording;
      });
      _showDesktopVoiceOverlay();
      _markDesktopVoiceOverlayNeedsBuild();
      return _beginDesktopVoiceRecording();
    }

    setState(() {
      _desktopVoiceHotkeyMode = false;
      _desktopVoiceCountdown = _desktopVoiceCountdownSeconds;
      _desktopVoiceState = _DesktopVoiceState.countdown;
    });
    _showDesktopVoiceOverlay();
    _markDesktopVoiceOverlayNeedsBuild();
    _desktopVoiceCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (!mounted || _desktopVoiceState != _DesktopVoiceState.countdown) {
        timer.cancel();
        _desktopVoiceCountdownTimer = null;
        return;
      }
      if (_desktopVoiceCountdown > 1) {
        setState(() {
          _desktopVoiceCountdown -= 1;
        });
        _markDesktopVoiceOverlayNeedsBuild();
        return;
      }
      timer.cancel();
      _desktopVoiceCountdownTimer = null;
      await _beginDesktopVoiceRecording();
    });
    return true;
  }

  Future<bool> _beginDesktopVoiceRecording() async {
    final startRecording = widget.onStartVoiceRecording;
    if (startRecording == null) {
      await _cancelDesktopVoiceSessionInternal();
      return false;
    }

    setState(() {
      _voiceActionInFlight = true;
      _desktopVoiceState = _DesktopVoiceState.recording;
      _desktopVoiceElapsed = Duration.zero;
    });
    _markDesktopVoiceOverlayNeedsBuild();

    try {
      final started = await startRecording();
      if (!mounted || !started) {
        await _cancelDesktopVoiceSessionInternal();
        return false;
      }
      if (_desktopVoiceCancelAfterStart) {
        _desktopVoiceCancelAfterStart = false;
        await widget.onCancelVoiceRecording?.call();
        await _cancelDesktopVoiceSessionInternal(deletePendingFile: false);
        return false;
      }

      _desktopVoiceRecordingStartedAt = DateTime.now();
      _desktopVoiceElapsed = Duration.zero;
      _desktopVoiceTicker?.cancel();
      _desktopVoiceTicker = Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) {
        final startedAt = _desktopVoiceRecordingStartedAt;
        if (!mounted ||
            _desktopVoiceState != _DesktopVoiceState.recording ||
            startedAt == null) {
          return;
        }
        final elapsed = DateTime.now().difference(startedAt);
        setState(() {
          _desktopVoiceElapsed =
              elapsed > VoiceInputService.maxRecordingDuration
              ? VoiceInputService.maxRecordingDuration
              : elapsed;
        });
        _markDesktopVoiceOverlayNeedsBuild();
      });
      _voiceAutoStopTimer?.cancel();
      _voiceAutoStopTimer = Timer(VoiceInputService.maxRecordingDuration, () {
        if (!mounted || _desktopVoiceState != _DesktopVoiceState.recording) {
          return;
        }
        unawaited(_stopDesktopVoiceRecordingForConfirmation());
      });
      if (_desktopVoiceHotkeyMode && !_desktopVoiceHotkeyHeld) {
        unawaited(_stopDesktopVoiceRecordingForConfirmation());
      }
      return true;
    } finally {
      if (mounted) {
        setState(() {
          _voiceActionInFlight = false;
        });
      }
    }
  }

  Future<void> _stopDesktopVoiceRecordingForConfirmation() async {
    if (_desktopVoiceState != _DesktopVoiceState.recording ||
        _voiceActionInFlight) {
      return;
    }
    final stopRecording = widget.onStopVoiceRecording;
    if (stopRecording == null) return;

    _desktopVoiceHotkeyHeld = false;
    _desktopVoiceHotkeyMode = false;
    _desktopVoiceCountdownTimer?.cancel();
    _desktopVoiceCountdownTimer = null;
    _desktopVoiceTicker?.cancel();
    _desktopVoiceTicker = null;
    _voiceAutoStopTimer?.cancel();
    _voiceAutoStopTimer = null;

    setState(() {
      _voiceActionInFlight = true;
    });
    _markDesktopVoiceOverlayNeedsBuild();

    try {
      final attachment = await stopRecording();
      if (!mounted) {
        if (attachment != null) {
          await _deleteVoiceAttachmentFile(attachment);
        }
        return;
      }
      if (attachment == null) {
        await _cancelDesktopVoiceSessionInternal(deletePendingFile: false);
        return;
      }
      setState(() {
        _desktopVoicePendingAttachment = attachment;
        _desktopVoiceState = _DesktopVoiceState.confirm;
      });
      _markDesktopVoiceOverlayNeedsBuild();
      widget.focusNode?.requestFocus();
    } finally {
      if (mounted) {
        setState(() {
          _voiceActionInFlight = false;
        });
      }
    }
  }

  void _confirmDesktopVoiceSend() {
    final attachment = _desktopVoicePendingAttachment;
    if (attachment == null || _voiceActionInFlight) return;
    _desktopVoicePendingAttachment = null;
    _clearDesktopVoiceUi(clearPendingAttachment: false);
    _sendCurrentInput(extraDocuments: [attachment]);
  }

  void _cancelDesktopVoiceSession() {
    unawaited(_cancelDesktopVoiceSessionInternal());
  }

  Future<void> _cancelDesktopVoiceSessionInternal({
    bool deletePendingFile = true,
  }) async {
    final currentState = _desktopVoiceState;
    final pendingAttachment = _desktopVoicePendingAttachment;
    _desktopVoiceHotkeyHeld = false;
    _desktopVoiceHotkeyMode = false;
    if (_voiceActionInFlight && currentState == _DesktopVoiceState.recording) {
      _desktopVoiceCancelAfterStart = true;
    }
    final cancelAfterStart = _desktopVoiceCancelAfterStart;
    _clearDesktopVoiceUi();

    if (currentState == _DesktopVoiceState.recording && !cancelAfterStart) {
      await widget.onCancelVoiceRecording?.call();
      return;
    }
    if (deletePendingFile && pendingAttachment != null) {
      await _deleteVoiceAttachmentFile(pendingAttachment);
    }
  }

  void _clearDesktopVoiceUi({bool clearPendingAttachment = true}) {
    _desktopVoiceCountdownTimer?.cancel();
    _desktopVoiceCountdownTimer = null;
    _desktopVoiceTicker?.cancel();
    _desktopVoiceTicker = null;
    _voiceAutoStopTimer?.cancel();
    _voiceAutoStopTimer = null;
    _desktopVoiceCountdown = _desktopVoiceCountdownSeconds;
    _desktopVoiceRecordingStartedAt = null;
    _desktopVoiceElapsed = Duration.zero;
    _desktopVoiceState = _DesktopVoiceState.idle;
    _desktopVoiceCancelAfterStart = false;
    if (clearPendingAttachment) {
      _desktopVoicePendingAttachment = null;
    }
    if (mounted) {
      setState(() {});
    }
    _removeDesktopVoiceOverlay();
  }

  Future<void> _deleteVoiceAttachmentFile(DocumentAttachment attachment) async {
    try {
      final file = File(attachment.path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void _handleSend() {
    _sendCurrentInput();
  }

  void _sendCurrentInput({List<DocumentAttachment> extraDocuments = const []}) {
    final text = _controller.text.trim();
    final documents = <DocumentAttachment>[..._docs, ...extraDocuments];
    if (text.isEmpty && _images.isEmpty && documents.isEmpty) return;
    widget.onSend?.call(
      ChatInputData(
        text: text,
        imagePaths: List.of(_images),
        documents: documents,
      ),
    );
    _controller.clear();
    _images.clear();
    _docs.clear();
    setState(() {});
    // Keep focus on desktop so user can continue typing
    try {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        widget.focusNode?.requestFocus();
      }
    } catch (_) {}
  }

  Future<void> _startVoicePress(Offset globalPosition) async {
    if (_voiceActionInFlight ||
        _voicePressActive ||
        widget.voiceRecording ||
        widget.loading) {
      return;
    }
    final startRecording = widget.onStartVoiceRecording;
    if (startRecording == null) return;

    setState(() => _voiceActionInFlight = true);
    try {
      final started = await startRecording();
      if (!mounted || !started) return;
      if (!_voicePointerHeld) {
        final cancelRecording = widget.onCancelVoiceRecording;
        if (cancelRecording != null) {
          await cancelRecording();
        } else {
          await widget.onStopVoiceRecording?.call();
        }
        return;
      }
      Haptics.soft();
      _voicePressActive = true;
      _voiceWillCancel = false;
      _showVoiceOverlay();
      _updateVoiceDrag(globalPosition);
      _voiceAutoStopTimer?.cancel();
      _voiceAutoStopTimer = Timer(VoiceInputService.maxRecordingDuration, () {
        if (!mounted || !_voicePressActive) return;
        unawaited(_finishVoicePress());
      });
      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() => _voiceActionInFlight = false);
      }
    }
  }

  void _updateVoiceDrag(Offset globalPosition) {
    if (!_voicePressActive) return;
    final geometry = _resolveVoiceOverlayGeometry();
    final bool willCancel =
        geometry == null || !_isPointInVoiceKeepZone(globalPosition, geometry);
    if (willCancel == _voiceWillCancel) return;
    setState(() => _voiceWillCancel = willCancel);
    _markVoiceOverlayNeedsBuild();
  }

  Future<void> _finishVoicePress({bool forceCancel = false}) async {
    _voicePointerHeld = false;
    if (_voiceActionInFlight || !_voicePressActive) return;
    final stopRecording = widget.onStopVoiceRecording;
    final cancelRecording = widget.onCancelVoiceRecording;
    if (stopRecording == null) return;

    final shouldCancel = forceCancel || _voiceWillCancel;
    _voiceAutoStopTimer?.cancel();
    _removeVoiceOverlay();
    setState(() {
      _voiceActionInFlight = true;
      _voicePressActive = false;
      _voiceWillCancel = false;
    });

    try {
      if (shouldCancel) {
        if (cancelRecording != null) {
          await cancelRecording();
        } else {
          await stopRecording();
        }
        return;
      }
      final attachment = await stopRecording();
      if (!mounted) return;
      if (attachment != null) {
        _sendCurrentInput(extraDocuments: [attachment]);
      }
    } finally {
      if (mounted) {
        setState(() => _voiceActionInFlight = false);
      }
    }
  }

  void _showVoiceOverlay() {
    _removeVoiceOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _voiceOverlayEntry = OverlayEntry(
      builder: (context) {
        final geometry = _resolveVoiceOverlayGeometry();
        if (!_voicePressActive || geometry == null) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _VoiceKeepZonePainter(
                geometry: geometry,
                cancelling: _voiceWillCancel,
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_voiceOverlayEntry!);
  }

  void _removeVoiceOverlay() {
    _voiceOverlayEntry?.remove();
    _voiceOverlayEntry = null;
  }

  void _markVoiceOverlayNeedsBuild() {
    _voiceOverlayEntry?.markNeedsBuild();
  }

  void _showDesktopVoiceOverlay() {
    _removeDesktopVoiceOverlay();
    final overlay = Overlay.of(context, rootOverlay: true);
    _desktopVoiceOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        final anchorRect = _resolveDesktopVoiceAnchorRect();
        if (_desktopVoiceState == _DesktopVoiceState.idle ||
            anchorRect == null) {
          return const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(overlayContext);
        final overlayBox = overlay.context.findRenderObject() as RenderBox?;
        if (overlayBox == null) return const SizedBox.shrink();

        const width = 320.0;
        final panelHeight = switch (_desktopVoiceState) {
          _DesktopVoiceState.countdown => 168.0,
          _DesktopVoiceState.recording => 188.0,
          _DesktopVoiceState.confirm => 182.0,
          _DesktopVoiceState.idle => 0.0,
        };
        final left = (anchorRect.center.dx - width / 2).clamp(
          12.0,
          overlayBox.size.width - width - 12.0,
        );
        var top = anchorRect.top - panelHeight - 14.0;
        final minTop = mediaQuery.padding.top + 12.0;
        final maxTop = overlayBox.size.height - panelHeight - 12.0;
        if (top < minTop) {
          top = anchorRect.bottom + 14.0;
        }
        top = top.clamp(minTop, maxTop);

        final dismissOnTapOutside =
            _desktopVoiceState != _DesktopVoiceState.recording;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: dismissOnTapOutside ? _cancelDesktopVoiceSession : null,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              child: _DesktopVoicePopover(
                title: _desktopVoicePopoverTitle(overlayContext),
                subtitle: _desktopVoicePopoverSubtitle(overlayContext),
                primaryButtonLabel: _desktopVoicePrimaryButtonLabel(
                  overlayContext,
                ),
                secondaryButtonLabel: _desktopVoiceSecondaryButtonLabel(
                  overlayContext,
                ),
                primaryButtonKey:
                    _desktopVoiceState == _DesktopVoiceState.recording
                    ? const ValueKey('desktop_voice_stop_button')
                    : _desktopVoiceState == _DesktopVoiceState.confirm
                    ? const ValueKey('desktop_voice_send_button')
                    : null,
                secondaryButtonKey:
                    _desktopVoiceState == _DesktopVoiceState.confirm ||
                        _desktopVoiceState == _DesktopVoiceState.countdown
                    ? const ValueKey('desktop_voice_cancel_button')
                    : null,
                onPrimaryTap: _desktopVoicePrimaryAction(),
                onSecondaryTap: _desktopVoiceSecondaryAction(),
                accentColor: Theme.of(overlayContext).colorScheme.primary,
                state: _desktopVoiceState,
                busy: _voiceActionInFlight,
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_desktopVoiceOverlayEntry!);
  }

  void _removeDesktopVoiceOverlay() {
    _desktopVoiceOverlayEntry?.remove();
    _desktopVoiceOverlayEntry = null;
  }

  void _markDesktopVoiceOverlayNeedsBuild() {
    _desktopVoiceOverlayEntry?.markNeedsBuild();
  }

  Rect? _resolveDesktopVoiceAnchorRect() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final voiceBox =
        _voiceButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null || voiceBox == null) return null;
    if (!overlayBox.attached || !voiceBox.attached) return null;
    final topLeft = voiceBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      voiceBox.size.width,
      voiceBox.size.height,
    );
  }

  String _desktopVoicePopoverTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown =>
        l10n.chatInputBarDesktopVoiceCountdownLabel(_desktopVoiceCountdown),
      _DesktopVoiceState.recording =>
        l10n.chatInputBarDesktopVoiceRecordingLabel(
          formatVoiceRecordingDuration(_desktopVoiceElapsed),
        ),
      _DesktopVoiceState.confirm =>
        _desktopVoicePendingAttachment == null
            ? l10n.chatInputBarDesktopVoiceConfirmLabel
            : voiceRecordingDisplayLabel(
                l10n,
                _desktopVoicePendingAttachment!.fileName,
              ),
      _DesktopVoiceState.idle => '',
    };
  }

  String _desktopVoicePopoverSubtitle(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown =>
        l10n.chatInputBarDesktopVoiceCountdownHelp,
      _DesktopVoiceState.recording =>
        l10n.chatInputBarDesktopVoiceRecordingHelp(
          _desktopVoiceShortcutLabel(),
        ),
      _DesktopVoiceState.confirm => l10n.chatInputBarDesktopVoiceConfirmHelp,
      _DesktopVoiceState.idle => '',
    };
  }

  String? _desktopVoicePrimaryButtonLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown => null,
      _DesktopVoiceState.recording => l10n.chatInputBarDesktopVoiceStopButton,
      _DesktopVoiceState.confirm => l10n.chatInputBarDesktopVoiceSendButton,
      _DesktopVoiceState.idle => null,
    };
  }

  String? _desktopVoiceSecondaryButtonLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown => l10n.chatInputBarDesktopVoiceCancelButton,
      _DesktopVoiceState.recording => null,
      _DesktopVoiceState.confirm => l10n.chatInputBarDesktopVoiceCancelButton,
      _DesktopVoiceState.idle => null,
    };
  }

  VoidCallback? _desktopVoicePrimaryAction() {
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown => null,
      _DesktopVoiceState.recording => () {
        unawaited(_stopDesktopVoiceRecordingForConfirmation());
      },
      _DesktopVoiceState.confirm => _confirmDesktopVoiceSend,
      _DesktopVoiceState.idle => null,
    };
  }

  VoidCallback? _desktopVoiceSecondaryAction() {
    return switch (_desktopVoiceState) {
      _DesktopVoiceState.countdown => _cancelDesktopVoiceSession,
      _DesktopVoiceState.recording => null,
      _DesktopVoiceState.confirm => _cancelDesktopVoiceSession,
      _DesktopVoiceState.idle => null,
    };
  }

  _VoiceOverlayGeometry? _resolveVoiceOverlayGeometry() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final voiceBox =
        _voiceButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlayBox == null ||
        voiceBox == null ||
        !overlayBox.attached ||
        !voiceBox.attached) {
      return null;
    }
    final voiceTopLeft = voiceBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final center = voiceTopLeft + voiceBox.size.center(Offset.zero);
    final mediaQuery = MediaQuery.of(overlay.context);
    final bottomInset = math.max(
      mediaQuery.viewInsets.bottom,
      mediaQuery.padding.bottom,
    );
    final drawableRect = Rect.fromLTRB(
      mediaQuery.padding.left,
      mediaQuery.padding.top,
      overlayBox.size.width - mediaQuery.padding.right,
      overlayBox.size.height - bottomInset,
    );
    final radius = math.min(
      math.min(drawableRect.width * 0.3, _maxVoiceKeepZoneRadius),
      _maxDistanceToRectCorner(center, drawableRect) + 24,
    );
    return _VoiceOverlayGeometry(
      center: center,
      drawableRect: drawableRect,
      radius: radius,
    );
  }

  bool _isPointInVoiceKeepZone(
    Offset globalPosition,
    _VoiceOverlayGeometry geometry,
  ) {
    if (!geometry.drawableRect.contains(globalPosition)) return false;
    final dx = globalPosition.dx - geometry.center.dx;
    final dy = globalPosition.dy - geometry.center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > geometry.radius) return false;
    return true;
  }

  double _maxDistanceToRectCorner(Offset center, Rect rect) {
    final corners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    double maxDistance = 0;
    for (final corner in corners) {
      final dx = corner.dx - center.dx;
      final dy = corner.dy - center.dy;
      maxDistance = math.max(maxDistance, math.sqrt(dx * dx + dy * dy));
    }
    return maxDistance;
  }

  Widget _buildVoicePressButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isDesktopVoiceSupported) {
      final semanticLabel = _desktopVoiceState == _DesktopVoiceState.recording
          ? l10n.chatInputBarDesktopVoiceStopButton
          : l10n.chatInputBarVoiceInputTooltip;

      return Semantics(
        button: true,
        enabled: !_voiceActionInFlight && !widget.loading,
        label: semanticLabel,
        child: KeyedSubtree(
          key: const ValueKey('desktop_voice_trigger'),
          child: SizedBox(
            key: _voiceButtonKey,
            child: _CompactRoundActionButton(
              enabled:
                  !_voiceActionInFlight &&
                  !widget.loading &&
                  _desktopVoiceState != _DesktopVoiceState.confirm,
              active:
                  _desktopVoiceState == _DesktopVoiceState.countdown ||
                  _desktopVoiceState == _DesktopVoiceState.recording,
              color: Theme.of(context).colorScheme.primary,
              icon: _desktopVoiceState == _DesktopVoiceState.recording
                  ? Lucide.AudioLines
                  : Lucide.Mic,
              onTap: () {
                unawaited(_onDesktopVoiceButtonTap());
              },
            ),
          ),
        ),
      );
    }

    final semanticLabel = _voicePressActive
        ? l10n.chatInputBarVoiceRecordingTooltip
        : l10n.chatInputBarVoiceInputTooltip;

    return Semantics(
      button: true,
      enabled: !_voiceActionInFlight && !widget.loading,
      label: semanticLabel,
      child: Listener(
        key: _voiceButtonKey,
        behavior: HitTestBehavior.opaque,
        onPointerDown: _voiceActionInFlight || widget.loading
            ? null
            : (event) {
                _voicePointerHeld = true;
                unawaited(_startVoicePress(event.position));
              },
        onPointerMove: (event) {
          _updateVoiceDrag(event.position);
        },
        onPointerUp: (event) {
          _updateVoiceDrag(event.position);
          unawaited(_finishVoicePress());
        },
        onPointerCancel: (_) {
          unawaited(_finishVoicePress(forceCancel: true));
        },
        child: AnimatedScale(
          scale: _voicePressActive ? 2.0 : 1.0,
          duration: const Duration(milliseconds: 390),
          curve: Curves.elasticOut,
          child: _CompactRoundActionButton(
            enabled: !_voiceActionInFlight && !widget.loading,
            active: _voicePressActive,
            color: Theme.of(context).colorScheme.primary,
            icon: Lucide.Mic,
          ),
        ),
      ),
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

    // Other platforms: keep default behavior.
    final items = <ContextMenuButtonItem>[...state.contextMenuButtonItems];
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
    final isEscape = key == LogicalKeyboardKey.escape;
    final isArrow =
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight;
    final isPasteV = key == LogicalKeyboardKey.keyV;

    if (_isDesktopVoiceSupported && isDown) {
      if (_desktopVoiceState == _DesktopVoiceState.confirm && isEnter) {
        _confirmDesktopVoiceSend();
        return KeyEventResult.handled;
      }
      if ((_desktopVoiceState == _DesktopVoiceState.confirm ||
              _desktopVoiceState == _DesktopVoiceState.countdown) &&
          isEscape) {
        _cancelDesktopVoiceSession();
        return KeyEventResult.handled;
      }
    }

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
          _handleSend();
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
          _handleSend();
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

  Future<void> _handlePasteFromClipboard() async {
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

        // Helper: persist bytes as a file under upload directory
        Future<String?> saveImageBytes(String format, Uint8List bytes) async {
          try {
            final dir = await AppDirectories.getUploadDirectory();
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final ts = DateTime.now().millisecondsSinceEpoch;
            final ext = format.toLowerCase();
            final fileExt = ext == 'jpeg' ? 'jpg' : ext;
            String name = 'paste_$ts.$fileExt';
            String destPath = p.join(dir.path, name);
            if (await File(destPath).exists()) {
              name =
                  'paste_${ts}_${DateTime.now().microsecondsSinceEpoch}.$fileExt';
              destPath = p.join(dir.path, name);
            }
            await File(destPath).writeAsBytes(bytes, flush: true);
            return destPath;
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
          final savedPath = await saveImageBytes(fmt, bytes);
          if (savedPath != null) {
            _addImages([savedPath]);
            return;
          }
        }

        // If clipboard has plain text via super_clipboard, paste it
        if (reader.canProvide(Formats.plainText)) {
          try {
            final String? text = await reader.readValue(Formats.plainText);
            if (text != null && text.isNotEmpty) {
              final value = _controller.value;
              final sel = value.selection;
              if (!sel.isValid) {
                _controller.text = value.text + text;
                _controller.selection = TextSelection.collapsed(
                  offset: _controller.text.length,
                );
              } else {
                final start = sel.start;
                final end = sel.end;
                final newText = value.text.replaceRange(start, end, text);
                _controller.value = value.copyWith(
                  text: newText,
                  selection: TextSelection.collapsed(
                    offset: start + text.length,
                  ),
                  composing: TextRange.empty,
                );
              }
              setState(() {});
              return;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2) Fallback: legacy platform channel image handling
    final imageTempPaths = await ClipboardImages.getImagePaths();
    if (imageTempPaths.isNotEmpty) {
      final persisted = await _persistClipboardImages(imageTempPaths);
      if (persisted.isNotEmpty) {
        _addImages(persisted);
      }
      return;
    }

    // 3) Try files via platform channel on desktop (Finder/Explorer copies)
    bool handledFiles = false;
    try {
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final filePaths = await ClipboardImages.getFilePaths();
        if (filePaths.isNotEmpty) {
          final saved = await _copyFilesToUpload(filePaths);
          if (saved.images.isNotEmpty) _addImages(saved.images);
          if (saved.docs.isNotEmpty) _addFiles(saved.docs);
          handledFiles = saved.images.isNotEmpty || saved.docs.isNotEmpty;
        }
      }
    } catch (_) {}
    if (handledFiles) return;

    // 4) Last resort: paste text via Flutter Clipboard API
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      final value = _controller.value;
      final sel = value.selection;
      if (!sel.isValid) {
        _controller.text = value.text + text;
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      } else {
        final start = sel.start;
        final end = sel.end;
        final newText = value.text.replaceRange(start, end, text);
        _controller.value = value.copyWith(
          text: newText,
          selection: TextSelection.collapsed(offset: start + text.length),
          composing: TextRange.empty,
        );
      }
      setState(() {});
    } catch (_) {}
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
        final savedPath = await FileImportHelper.copyXFile(
          XFile(src),
          dir,
          context,
        );
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
              onTap: widget.onSelectModel,
              onLongPress: widget.onLongPressSelectModel,
              child: widget.modelIcon,
            ),
            menu: DesktopContextMenuItem(
              icon: Lucide.Boxes,
              label: l10n.chatInputBarSelectModelTooltip,
              onTap: widget.onSelectModel,
            ),
          ),
        );

        // Search button (stateful icon depending on provider config)
        final settings = context.watch<SettingsProvider>();
        final ap = context.watch<AssistantProvider>();
        final a = ap.currentAssistant;
        final currentProviderKey =
            a?.chatModelProvider ?? settings.currentModelProvider;
        final currentModelId = a?.chatModelId ?? settings.currentModelId;
        final cfg = (currentProviderKey != null)
            ? settings.getProviderConfig(currentProviderKey)
            : null;
        // Check built-in tools state using helper
        final toolsState = BuiltInToolsHelper.getActiveTools(
          cfg: cfg,
          modelId: currentModelId,
        );
        final builtinSearchActive = toolsState.searchActive;
        final appSearchEnabled = settings.searchEnabled;
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
                  onTap: widget.onOpenSearch,
                );
              }
              // Built-in search -> magnifier icon in theme color
              if (builtinSearchActive) {
                return _CompactIconButton(
                  tooltip: l10n.chatInputBarOnlineSearchTooltip,
                  icon: Lucide.Search,
                  active: true,
                  onTap: widget.onOpenSearch,
                );
              }
              // External provider search -> brand icon
              return _CompactIconButton(
                tooltip: l10n.chatInputBarOnlineSearchTooltip,
                icon: Lucide.Globe,
                active: true,
                onTap: widget.onOpenSearch,
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
                  onTap: widget.onOpenSearch,
                );
              }
              if (builtinSearchActive) {
                return DesktopContextMenuItem(
                  icon: Lucide.Search,
                  label: l10n.chatInputBarOnlineSearchTooltip,
                  onTap: widget.onOpenSearch,
                );
              }
              if (brandAsset != null && brandAsset.endsWith('.svg')) {
                return DesktopContextMenuItem(
                  svgAsset: brandAsset,
                  label: l10n.chatInputBarOnlineSearchTooltip,
                  onTap: widget.onOpenSearch,
                );
              }
              return DesktopContextMenuItem(
                icon: Lucide.Globe,
                label: l10n.chatInputBarOnlineSearchTooltip,
                onTap: widget.onOpenSearch,
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
                onTap: widget.onConfigureReasoning,
                childBuilder: (c) => SvgPicture.asset(
                  'assets/icons/deepthink.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
                ),
              ),
              menu: DesktopContextMenuItem(
                svgAsset: 'assets/icons/deepthink.svg',
                label: l10n.chatInputBarReasoningStrengthTooltip,
                onTap: widget.onConfigureReasoning,
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
                onTap: widget.onOpenMcp,
                onLongPress: widget.onLongPressMcp,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Hammer,
                label: l10n.chatInputBarMcpServersTooltip,
                onTap: widget.onOpenMcp,
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
                onTap: widget.onQuickPhrase,
                onLongPress: widget.onLongPressQuickPhrase,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Zap,
                label: l10n.chatInputBarQuickPhraseTooltip,
                onTap: widget.onQuickPhrase,
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
                onTap: widget.onPickCamera,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Camera,
                label: l10n.bottomToolsSheetCamera,
                onTap: widget.onPickCamera,
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
                onTap: widget.onPickPhotos,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Image,
                label: l10n.bottomToolsSheetPhotos,
                onTap: widget.onPickPhotos,
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
                onTap: widget.onUploadFiles,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Paperclip,
                label: l10n.bottomToolsSheetUpload,
                onTap: widget.onUploadFiles,
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
                onTap: widget.onToggleLearningMode,
                onLongPress: widget.onLongPressLearning,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Layers,
                label: l10n.instructionInjectionTitle,
                onTap: widget.onToggleLearningMode,
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
                onTap: widget.onOpenWorldBook,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.BookOpen,
                label: l10n.worldBookTitle,
                onTap: widget.onOpenWorldBook,
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
                    onTap: widget.onCompressContext,
                  ),
                DesktopContextMenuItem(
                  icon: Lucide.Eraser,
                  label: l10n.bottomToolsSheetClearContext,
                  onTap: widget.onClearContext,
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
                  onTap: showContextMenu,
                ),
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Eraser,
                label: l10n.contextManagement,
                onTap: showContextMenu,
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
                onTap: widget.onOpenMiniMap,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Map,
                label: l10n.miniMapTooltip,
                onTap: widget.onOpenMiniMap,
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
                onTap: widget.onToggleOcr,
              ),
              menu: DesktopContextMenuItem(
                icon: Lucide.Eye,
                label: l10n.chatInputBarOcrTooltip,
                onTap: widget.onToggleOcr,
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
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  Future<List<String>> _persistClipboardImages(List<String> srcPaths) async {
    try {
      final dir = await AppDirectories.getUploadDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final out = <String>[];
      int i = 0;
      for (var raw in srcPaths) {
        try {
          // Normalize path (strip file:// if present)
          final src = raw.startsWith('file://') ? raw.substring(7) : raw;
          // If already under upload directory, just keep it
          if (src.contains('/upload/') || src.contains('\\upload\\')) {
            out.add(src);
            continue;
          }
          final ext = p.extension(src).isNotEmpty ? p.extension(src) : '.png';
          final name =
              'paste_${DateTime.now().millisecondsSinceEpoch}_${i++}$ext';
          final destPath = p.join(dir.path, name);
          final from = File(src);
          if (await from.exists()) {
            await File(destPath).writeAsBytes(await from.readAsBytes());
            // Best-effort cleanup of the temporary source
            try {
              await from.delete();
            } catch (_) {}
            out.add(destPath);
          }
        } catch (_) {
          // skip single file errors
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImages = _images.isNotEmpty;
    final hasDocs = _docs.isNotEmpty;
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bool isMobileLayout = size.width < AppBreakpoints.tablet;
    final double visibleHeight = size.height - viewInsets.bottom;
    final double attachmentsHeight =
        (hasDocs ? 48 + AppSpacing.xs : 0) +
        (hasImages ? 64 + AppSpacing.xs : 0);
    const double baseChromeHeight = 120; // padding + action row + chrome buffer
    double maxInputHeight = double.infinity;
    if (isMobileLayout) {
      final double available =
          visibleHeight - attachmentsHeight - baseChromeHeight;
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
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File attachments (if any)
            if (hasDocs) ...[
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final d = _docs[idx];
                    final isVoice = isVoiceRecordingAttachment(d);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isDark ? [] : AppShadows.soft,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVoice
                                ? Lucide.AudioLines
                                : Icons.insert_drive_file,
                            size: 18,
                            color: isVoice ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              isVoice
                                  ? voiceRecordingDisplayLabel(l10n, d.fileName)
                                  : d.fileName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() => _docs.removeAt(idx));
                              // best-effort delete persisted attachment
                              try {
                                final f = File(d.path);
                                if (f.existsSync()) {
                                  f.deleteSync();
                                }
                              } catch (_) {}
                            },
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            // Image previews (if any)
            if (hasImages) ...[
              SizedBox(
                height: 64,
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final path = _images[idx];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(path),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: Colors.black12,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -6,
                          top: -6,
                          child: GestureDetector(
                            onTap: () => _removeImageAt(idx),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            // Main input container with iOS-like frosted glass effect
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    // Translucent background over blurred content
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(20),
                    // Use previous gray border for better contrast on white
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : theme.colorScheme.outline.withValues(alpha: 0.20),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
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
                                      behavior: HitTestBehavior.deferToChild,
                                      // onSecondaryTapDown: (details) {
                                      //   // _showDesktopContextMenu(details.globalPosition);
                                      // },
                                      child: TextField(
                                        controller: _controller,
                                        focusNode: widget.focusNode,
                                        onChanged: _onTextChanged,
                                        minLines: 1,
                                        maxLines: _isExpanded ? 25 : 5,
                                        // On mobile, optionally show "Send" on the return key and submit on tap.
                                        // Still keep multiline so pasted text preserves line breaks.
                                        keyboardType: TextInputType.multiline,
                                        textInputAction: enterToSend
                                            ? TextInputAction.send
                                            : TextInputAction.newline,
                                        onSubmitted: enterToSend
                                            ? (_) => _handleSend()
                                            : null,
                                        // Custom context menu: use instance method to avoid flickering
                                        // caused by recreating the callback on every build.
                                        // See: https://github.com/flutter/flutter/issues/150551
                                        contextMenuBuilder: _buildContextMenu,
                                        autofocus: false,
                                        decoration: InputDecoration(
                                          hintText: _hint(context),
                                          hintStyle: TextStyle(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.45),
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 2,
                                              ),
                                        ),
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface,
                                          fontSize:
                                              (Platform.isWindows ||
                                                  Platform.isLinux ||
                                                  Platform.isMacOS)
                                              ? 14
                                              : 15,
                                        ),
                                        cursorColor: theme.colorScheme.primary,
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
                                  setState(() => _isExpanded = !_isExpanded);
                                  _ensureCaretVisible();
                                },
                                child: Icon(
                                  _isExpanded
                                      ? Lucide.ChevronsDownUp
                                      : Lucide.ChevronsUpDown,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  ),
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Responsive left action bar that overflows into a + menu on desktop
                            Expanded(
                              child: _buildResponsiveLeftActions(context),
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
                                    onTap: widget.onMore,
                                    childBuilder: (c) => AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      transitionBuilder: (child, anim) =>
                                          RotationTransition(
                                            turns: Tween<double>(
                                              begin: 0.85,
                                              end: 1,
                                            ).animate(anim),
                                            child: FadeTransition(
                                              opacity: anim,
                                              child: child,
                                            ),
                                          ),
                                      child: Icon(
                                        widget.moreOpen
                                            ? Lucide.X
                                            : Lucide.Plus,
                                        key: ValueKey(
                                          widget.moreOpen ? 'close' : 'add',
                                        ),
                                        size: 20,
                                        color: c,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.showVoiceInputButton) ...[
                                  _buildVoicePressButton(context),
                                  const SizedBox(width: 8),
                                ],
                                _CompactSendButton(
                                  enabled:
                                      (hasText || hasImages || hasDocs) &&
                                      !widget.loading,
                                  loading: widget.loading,
                                  onSend: _handleSend,
                                  onStop: widget.loading ? widget.onStop : null,
                                  color: theme.colorScheme.primary,
                                  icon: Lucide.ArrowUp,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
        : (isDark ? Colors.white70 : Colors.black54);
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

class _CompactRoundActionButton extends StatelessWidget {
  const _CompactRoundActionButton({
    required this.enabled,
    required this.active,
    required this.color,
    required this.icon,
    this.child,
    this.onTap,
  });

  final bool enabled;
  final bool active;
  final Color color;
  final IconData icon;
  final Widget? child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = active
        ? color
        : (isDark
              ? Colors.white12
              : Colors.grey.shade300.withValues(alpha: 0.84));
    final fg = active
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white70 : Colors.grey.shade600);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: child ?? Icon(icon, size: 18, color: fg),
        ),
      ),
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
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = (enabled || loading)
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white70 : Colors.grey.shade600);

    return _CompactRoundActionButton(
      enabled: loading ? onStop != null : enabled,
      active: enabled || loading,
      color: color,
      icon: icon,
      onTap: loading ? onStop : onSend,
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
    );
  }
}

class _DesktopVoicePopover extends StatelessWidget {
  const _DesktopVoicePopover({
    required this.title,
    required this.subtitle,
    required this.primaryButtonLabel,
    required this.secondaryButtonLabel,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    required this.accentColor,
    required this.state,
    required this.busy,
    this.primaryButtonKey,
    this.secondaryButtonKey,
  });

  final String title;
  final String subtitle;
  final String? primaryButtonLabel;
  final String? secondaryButtonLabel;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final Color accentColor;
  final _DesktopVoiceState state;
  final bool busy;
  final Key? primaryButtonKey;
  final Key? secondaryButtonKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cs = theme.colorScheme;
    final icon = switch (state) {
      _DesktopVoiceState.countdown => Lucide.Mic,
      _DesktopVoiceState.recording => Lucide.AudioLines,
      _DesktopVoiceState.confirm => Lucide.ArrowUp,
      _DesktopVoiceState.idle => Lucide.Mic,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white).withValues(
              alpha: isDark ? 0.76 : 0.88,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: isDark ? 0.18 : 0.14),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.22 : 0.14,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 18, color: accentColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: cs.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (primaryButtonLabel != null ||
                      secondaryButtonLabel != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (secondaryButtonLabel != null)
                          Expanded(
                            child: _DesktopVoicePopoverButton(
                              key: secondaryButtonKey,
                              label: secondaryButtonLabel!,
                              onTap: busy ? null : onSecondaryTap,
                              filled: false,
                              accentColor: accentColor,
                            ),
                          ),
                        if (secondaryButtonLabel != null &&
                            primaryButtonLabel != null)
                          const SizedBox(width: 10),
                        if (primaryButtonLabel != null)
                          Expanded(
                            child: _DesktopVoicePopoverButton(
                              key: primaryButtonKey,
                              label: primaryButtonLabel!,
                              onTap: busy ? null : onPrimaryTap,
                              filled: true,
                              accentColor: accentColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopVoicePopoverButton extends StatelessWidget {
  const _DesktopVoicePopoverButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.filled,
    required this.accentColor,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = filled
        ? (isDark ? Colors.black : Colors.white)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.86);
    final bg = filled
        ? accentColor
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04));
    final borderColor = filled
        ? accentColor
        : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.24);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: filled ? 0 : 0.8),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceOverlayGeometry {
  const _VoiceOverlayGeometry({
    required this.center,
    required this.drawableRect,
    required this.radius,
  });

  final Offset center;
  final Rect drawableRect;
  final double radius;
}

class _VoiceKeepZonePainter extends CustomPainter {
  const _VoiceKeepZonePainter({
    required this.geometry,
    required this.cancelling,
  });

  final _VoiceOverlayGeometry geometry;
  final bool cancelling;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(geometry.drawableRect);

    final circleRect = Rect.fromCircle(
      center: geometry.center,
      radius: geometry.radius,
    );
    final path = Path()..addOval(circleRect);
    final baseColor = cancelling
        ? const Color(0xFFFF5D73)
        : const Color(0xFF8BC8FF);
    final solidFill = Paint()
      ..color = baseColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, solidFill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VoiceKeepZonePainter oldDelegate) {
    return geometry.center != oldDelegate.geometry.center ||
        geometry.drawableRect != oldDelegate.geometry.drawableRect ||
        geometry.radius != oldDelegate.geometry.radius ||
        cancelling != oldDelegate.cancelling;
  }
}

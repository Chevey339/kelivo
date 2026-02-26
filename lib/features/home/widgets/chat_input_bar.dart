import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../../../core/services/search/search_service.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';
import '../../../utils/app_directories.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../desktop/desktop_context_menu.dart';
import 'package:re_editor/re_editor.dart';

bool _isDesktopPlatform() {
  if (kIsWeb) return false;
  try {
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  } catch (_) {
    return false;
  }
}

bool _isIOSPlatform() {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS;
  } catch (_) {
    return false;
  }
}

class ChatInputBarController {
  _ChatInputBarState? _state;
  void _bind(_ChatInputBarState s) => _state = s;
  void _unbind(_ChatInputBarState s) { if (identical(_state, s)) _state = null; }

  void addImages(List<String> paths) => _state?._addImages(paths);
  void clearImages() => _state?._clearImages();
  void addFiles(List<DocumentAttachment> docs) => _state?._addFiles(docs);
  void clearFiles() => _state?._clearFiles();
}

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
    this.onToggleLearningMode,
    this.onOpenWorldBook,
    this.onClearContext,
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
  final CodeLineEditingController? controller;
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
  final VoidCallback? onToggleLearningMode;
  final VoidCallback? onOpenWorldBook;
  final VoidCallback? onClearContext;
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

class _ChatInputBarState extends State<ChatInputBar> with WidgetsBindingObserver {
  late CodeLineEditingController _controller;
  late final Map<Type, Action<Intent>> _shortcutOverrideActions;
  bool _isExpanded = false; // Track expand/collapse state for input field
  final List<String> _images = <String>[]; // local file paths
  final List<DocumentAttachment> _docs = <DocumentAttachment>[]; // files to upload
  final Map<LogicalKeyboardKey, Timer?> _repeatTimers = {};
  static const Duration _repeatInitialDelay = Duration(milliseconds: 300);
  static const Duration _repeatPeriod = Duration(milliseconds: 35);
  // Anchor for the responsive overflow menu on the left action bar
  final GlobalKey _leftOverflowAnchorKey = GlobalKey(debugLabel: 'left-overflow-anchor');
  String _lastText = '';


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
    try { final f = File(path); if (await f.exists()) { await f.delete(); } } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CodeLineEditingController();
    _lastText = _controller.text;
    _controller.addListener(_onControllerChanged);
    _shortcutOverrideActions = {
      CodeShortcutNewLineIntent: _ComposingAwareNewLineAction(
        isComposing: () => _controller.isComposing,
        onInvoke: _handleNewLineIntent,
      ),
    };
    widget.mediaController?._bind(this);
    WidgetsBinding.instance.addObserver(this);
  }

  // Listener for controller changes (replaces TextField's onChanged)
  void _onControllerChanged() {
    final text = _controller.text;
    if (text == _lastText) return;
    _lastText = text;
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes from background, suppress context menu briefly to avoid flickering
    if (state == AppLifecycleState.resumed) {
      // Also unfocus to reset any stuck toolbar state
      widget.focusNode?.unfocus();
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // When going to background, hide any open toolbar
      widget.focusNode?.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final t in _repeatTimers.values) {
      try {
        t?.cancel();
      } catch (_) {}
    }
    _repeatTimers.clear();
    widget.mediaController?._unbind(this);
    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldController = _controller;
      oldController.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        _controller = widget.controller!;
      } else {
        final fallback = CodeLineEditingController();
        fallback.value = oldController.value;
        _controller = fallback;
      }
      _lastText = _controller.text;
      _controller.addListener(_onControllerChanged);
      if (oldWidget.controller == null && oldController != _controller) {
        oldController.dispose();
      }
    }
  }

  String _hint(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return l10n.chatInputBarHint;
  }

  ({double height, int lineCount}) _measureInputMetrics({
    required BuildContext context,
    required String text,
    required double maxWidth,
    required double fontSize,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    required double fontHeight,
    required double verticalPadding,
    required int maxLines,
  }) {
    if (maxWidth.isInfinite || maxWidth <= 0) {
      final fallbackLineHeight = fontSize * fontHeight;
      return (height: fallbackLineHeight + verticalPadding, lineCount: 1);
    }

    const int wrapMeasureLimit = 4000;
    final limitedText = text.length > wrapMeasureLimit ? text.substring(0, wrapMeasureLimit) : text;
    final effectiveText = limitedText.isEmpty ? ' ' : limitedText;

    final painter = TextPainter(
      // IMPORTANT: CodeEditor builds its own TextStyle (doesn't merge DefaultTextStyle),
      // so our measurement must match that exactly; otherwise wrap thresholds will drift.
      text: TextSpan(
        text: effectiveText,
        style: TextStyle(
          fontSize: fontSize,
          height: fontHeight,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: maxLines,
    );
    try {
      painter.layout(maxWidth: maxWidth);

      final metrics = painter.computeLineMetrics();
      final lineCount = metrics.isEmpty ? 1 : metrics.length;
      final lineHeight = fontSize * fontHeight;
      final textHeight = math.max(painter.height, lineHeight);
      return (height: textHeight + verticalPadding, lineCount: lineCount);
    } finally {
      // TODO: Verify TextPainter.dispose() availability on our minimum Flutter SDK; remove if unsupported.
      painter.dispose();
    }
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty && _docs.isEmpty) return;
    widget.onSend?.call(ChatInputData(text: text, imagePaths: List.of(_images), documents: List.of(_docs)));
    _controller.value = const CodeLineEditingValue.empty(); // Clear + reset selection/composing
    _images.clear();
    _docs.clear();
    setState(() {});
    // Keep focus on desktop so user can continue typing
    if (_isDesktopPlatform()) {
      widget.focusNode?.requestFocus();
    }
  }

  void _insertNewlineAtCursor() {
    // CodeLineEditingController has a built-in method to insert newlines
    _controller.applyNewLine();
    _controller.makeCursorVisible();
  }

  Object? _handleNewLineIntent(CodeShortcutNewLineIntent intent) {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
    final meta = keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
    final ctrlOrMeta = ctrl || meta;

    final isDesktopOs = _isDesktopPlatform();
    if (isDesktopOs) {
      final sendShortcut = context.read<SettingsProvider>().desktopSendShortcut;
      if (sendShortcut == DesktopSendShortcut.ctrlEnter) {
        if (ctrlOrMeta) {
          _handleSend();
        } else {
          _insertNewlineAtCursor();
        }
      } else {
        if (shift || ctrlOrMeta) {
          _insertNewlineAtCursor();
        } else {
          _handleSend();
        }
      }
      return null;
    }

    final enterToSendOnMobile = context.read<SettingsProvider>().enterToSendOnMobile;
    if (shift || !enterToSendOnMobile) {
      _insertNewlineAtCursor();
    } else {
      _handleSend();
    }
    return null;
  }

  // Keep the caret visible after programmatic edits (e.g., Shift+Enter insert)
  void _ensureCaretVisible() {
    try {
      // CodeLineEditingController has built-in method to ensure cursor visibility
      _controller.makeCursorVisible();
    } catch (_) {}
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Enhance hardware keyboard behavior
    final nodeContext = node.context;
    if (nodeContext == null) return KeyEventResult.ignored;
    final w = MediaQuery.sizeOf(nodeContext).width;
    final isTabletOrDesktop = w >= AppBreakpoints.tablet;
    final isIosTablet = _isIOSPlatform() && isTabletOrDesktop;

    final key = event.logicalKey;
    final isArrow = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
    final isPasteV = key == LogicalKeyboardKey.keyV;

    // Paste handling for images on iOS/macOS (tablet/desktop)
    final isDown = event is KeyDownEvent;
    if (isDown && isPasteV) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final meta = keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight);
      final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);
      if (meta || ctrl) {
        _handlePasteFromClipboard();
        return KeyEventResult.handled;
      }
    }

    // Arrow repeat fix only needed on iOS tablets
    if (!isIosTablet || !isArrow) return KeyEventResult.ignored;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift = keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight);
    final alt = keys.contains(LogicalKeyboardKey.altLeft) || keys.contains(LogicalKeyboardKey.altRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight) ||
        keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);

    void moveOnce() {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveCaret(-1, extend: shift, byWord: alt);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _moveCaret(1, extend: shift, byWord: alt);
      }
    }

    if (isDown) {
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
    } else {
      // Key up -> cancel repeat
      final t = _repeatTimers.remove(key);
      try { t?.cancel(); } catch (_) {}
      return KeyEventResult.handled;
    }
  }

  Future<void> _handlePasteFromClipboard() async {
    // 1) Prefer reading via super_clipboard for better Windows support
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final reader = await clipboard.read();

        // Helper: read bytes for a given file format from DataReader (ClipboardReader or item)
        Future<Uint8List?> readFileBytes(DataReader dataReader, FileFormat format) async {
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
            String name = 'paste_$ts.${ext == 'jpeg' ? 'jpg' : ext}';
            String destPath = p.join(dir.path, name);
            if (await File(destPath).exists()) {
              name = 'paste_${ts}_${DateTime.now().microsecondsSinceEpoch}.${ext == 'jpeg' ? 'jpg' : ext}';
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
        bytes ??= reader.canProvide(Formats.jpeg) ? await readFileBytes(reader, Formats.jpeg) : null;
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
          if (!mounted) return;
          if (savedPath != null) {
            _addImages([savedPath]);
            return;
          }
        }

        // If clipboard has plain text via super_clipboard, paste it
        if (reader.canProvide(Formats.plainText)) {
          try {
            final String? text = await reader.readValue(Formats.plainText);
            if (!mounted) return;
            if (text != null && text.isNotEmpty) {
              // Use CodeLineEditingController's replaceSelection for pasting
              _controller.replaceSelection(text);
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
      if (!mounted) return;
      if (persisted.isNotEmpty) {
        _addImages(persisted);
      }
      return;
    }

    // 3) Try files via platform channel on desktop (Finder/Explorer copies)
    bool handledFiles = false;
    try {
      if (_isDesktopPlatform()) {
        final filePaths = await ClipboardImages.getFilePaths();
        if (filePaths.isNotEmpty) {
          final saved = await _copyFilesToUpload(filePaths);
          if (!mounted) return;
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
      if (!mounted) return;
      final text = data?.text ?? '';
      if (text.isEmpty) return;
      // Use CodeLineEditingController's replaceSelection for pasting
      _controller.replaceSelection(text);
      setState(() {});
    } catch (_) {}
  }

  // Copy arbitrary files to upload directory (without deleting the source),
  // split into images and document attachments.
  Future<({List<String> images, List<DocumentAttachment> docs})> _copyFilesToUpload(List<String> srcPaths) async {
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    try {
      final dir = await AppDirectories.getUploadDirectory();
      if (!mounted) return (images: images, docs: docs);
      for (final raw in srcPaths) {
        final src = raw.startsWith('file://') ? raw.substring(7) : raw;
        final savedPath = await FileImportHelper.copyXFile(XFile(src), dir, context);
        if (savedPath != null) {
          final savedName = p.basename(savedPath);
          if (_isImageExtension(savedName)) {
            images.add(savedPath);
          } else {
            final mime = _inferMimeByExtension(savedName);
            docs.add(DocumentAttachment(path: savedPath, fileName: savedName, mime: mime));
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
    const double modelButtonW = 30;  // 28 + padding(1*2)
    const double plusButtonW = 32;

    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final List<_OverflowAction> actions = [];

        // Model select (always present; can be hidden if overflow)
        actions.add(_OverflowAction(
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
        ));

        // Search button (stateful icon depending on provider config)
        final settings = context.watch<SettingsProvider>();
        final ap = context.watch<AssistantProvider>();
        final a = ap.currentAssistant;
        final currentProviderKey = a?.chatModelProvider ?? settings.currentModelProvider;
        final currentModelId = a?.chatModelId ?? settings.currentModelId;
        final cfg = (currentProviderKey != null)
            ? settings.getProviderConfig(currentProviderKey)
            : null;
        // Check built-in tools state using helper
        final toolsState = BuiltInToolsHelper.getActiveTools(cfg: cfg, modelId: currentModelId);
        final builtinSearchActive = toolsState.searchActive;
        final codeExecutionActive = toolsState.codeExecutionActive;
        // Only Gemini built-in tools conflict with MCP in the input bar UX.
        // OpenAI/Claude built-in search should not hide MCP tools.
        final kind = (cfg != null) ? ProviderConfig.classify(cfg.id, explicitType: cfg.providerType) : null;
        final anyBuiltInConflictsWithMcp = (kind == ProviderKind.google) && toolsState.anyMcpConflictingToolActive;
        final appSearchEnabled = settings.searchEnabled;
        final brandAsset = (() {
          if (!appSearchEnabled || builtinSearchActive) return null;
          final services = settings.searchServices;
          final sel = settings.searchServiceSelected.clamp(0, services.isNotEmpty ? services.length - 1 : 0);
          final options = services.isNotEmpty ? services[sel] : SearchServiceOptions.defaultOption;
          final svc = SearchService.getService(options);
          return BrandAssets.assetForName(svc.name);
        })();

        // Search button (hidden when code_execution is active)
        if (!codeExecutionActive) {
          actions.add(_OverflowAction(
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
                    return SvgPicture.asset(asset, width: 20, height: 20, colorFilter: ColorFilter.mode(c, BlendMode.srcIn));
                  } else {
                    return Image.asset(asset, width: 20, height: 20, color: c, colorBlendMode: BlendMode.srcIn);
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
              return DesktopContextMenuItem(icon: Lucide.Globe, label: l10n.chatInputBarOnlineSearchTooltip, onTap: widget.onOpenSearch);
            }
            if (builtinSearchActive) {
              return DesktopContextMenuItem(icon: Lucide.Search, label: l10n.chatInputBarOnlineSearchTooltip, onTap: widget.onOpenSearch);
            }
            if (brandAsset != null && brandAsset.endsWith('.svg')) {
              return DesktopContextMenuItem(svgAsset: brandAsset, label: l10n.chatInputBarOnlineSearchTooltip, onTap: widget.onOpenSearch);
            }
            return DesktopContextMenuItem(icon: Lucide.Globe, label: l10n.chatInputBarOnlineSearchTooltip, onTap: widget.onOpenSearch);
          }(),
        ));
        }

        if (widget.supportsReasoning) {
          actions.add(_OverflowAction(
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
          ));
        }

        // MCP button (hidden only when conflicting Gemini built-in tools are active)
        if (widget.showMcpButton && !anyBuiltInConflictsWithMcp) {
          actions.add(_OverflowAction(
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
          ));
        }

        if (widget.showQuickPhraseButton && widget.onQuickPhrase != null) {
          actions.add(_OverflowAction(
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
          ));
        }

        if (widget.onPickCamera != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.bottomToolsSheetCamera,
              icon: Lucide.Camera,
              onTap: widget.onPickCamera,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Camera, label: l10n.bottomToolsSheetCamera, onTap: widget.onPickCamera),
          ));
        }

        if (widget.onPickPhotos != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.bottomToolsSheetPhotos,
              icon: Lucide.Image,
              onTap: widget.onPickPhotos,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Image, label: l10n.bottomToolsSheetPhotos, onTap: widget.onPickPhotos),
          ));
        }

        if (widget.onUploadFiles != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.bottomToolsSheetUpload,
              icon: Lucide.Paperclip,
              onTap: widget.onUploadFiles,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Paperclip, label: l10n.bottomToolsSheetUpload, onTap: widget.onUploadFiles),
          ));
        }

        if (widget.onToggleLearningMode != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.instructionInjectionTitle,
              icon: Lucide.Layers,
              active: widget.learningModeActive,
              onTap: widget.onToggleLearningMode,
              onLongPress: widget.onLongPressLearning,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Layers, label: l10n.instructionInjectionTitle, onTap: widget.onToggleLearningMode),
          ));
        }

        if (widget.onOpenWorldBook != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.worldBookTitle,
              icon: Lucide.BookOpen,
              active: widget.worldBookActive,
              onTap: widget.onOpenWorldBook,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.BookOpen, label: l10n.worldBookTitle, onTap: widget.onOpenWorldBook),
          ));
        }

        if (widget.onClearContext != null) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.bottomToolsSheetClearContext,
              icon: Lucide.Eraser,
              onTap: widget.onClearContext,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Eraser, label: l10n.bottomToolsSheetClearContext, onTap: widget.onClearContext),
          ));
        }

        if (widget.showMiniMapButton) {
          actions.add(_OverflowAction(
            width: normalButtonW,
            builder: () => _CompactIconButton(
              tooltip: l10n.miniMapTooltip,
              icon: Lucide.Map,
              onTap: widget.onOpenMiniMap,
            ),
            menu: DesktopContextMenuItem(icon: Lucide.Map, label: l10n.miniMapTooltip, onTap: widget.onOpenMiniMap),
          ));
        }

        if (widget.showOcrButton && widget.onToggleOcr != null) {
          actions.add(_OverflowAction(
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
          ));
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
          final menuItems = overflowItems.map((e) => e.menu).toList(growable: false);
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
    final lower = name.toLowerCase();
    // Video
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mpeg') || lower.endsWith('.mpg')) return 'video/mpeg';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    if (lower.endsWith('.wmv')) return 'video/x-ms-wmv';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.3gp') || lower.endsWith('.3gpp')) return 'video/3gpp';
    // Documents / text
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.txt') || lower.endsWith('.md') || lower.endsWith('.markdown') || lower.endsWith('.mdx')) return 'text/plain';
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.yml') || lower.endsWith('.yaml')) return 'application/x-yaml';
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
          final name = 'paste_${DateTime.now().millisecondsSinceEpoch}_${i++}$ext';
          final destPath = p.join(dir.path, name);
          final from = File(src);
          if (await from.exists()) {
            await File(destPath).writeAsBytes(await from.readAsBytes());
            // Best-effort cleanup of the temporary source
            try { await from.delete(); } catch (_) {}
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
    // Use CodeLineEditingController's built-in methods for cursor movement
    if (_controller.text.isEmpty) return;
    
    if (byWord) {
      if (extend) {
        // Extend selection to word boundary
        if (dir < 0) {
          _controller.extendSelectionToWordBoundaryBackward();
        } else {
          _controller.extendSelectionToWordBoundaryForward();
        }
      } else {
        // Move cursor to word boundary
        if (dir < 0) {
          _controller.moveCursorToWordBoundaryBackward();
        } else {
          _controller.moveCursorToWordBoundaryForward();
        }
      }
    } else {
      final direction = dir < 0 ? AxisDirection.left : AxisDirection.right;
      if (extend) {
        _controller.extendSelection(direction);
      } else {
        _controller.moveCursor(direction);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImages = _images.isNotEmpty;
    final hasDocs = _docs.isNotEmpty;
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final bool isMobileLayout = size.width < AppBreakpoints.tablet;
    final double visibleHeight = size.height - viewInsets.bottom;
    final double attachmentsHeight =
        (hasDocs ? 48 + AppSpacing.xs : 0) + (hasImages ? 64 + AppSpacing.xs : 0);
    const double baseChromeHeight = 120; // padding + action row + chrome buffer
    double maxInputHeight = double.infinity;
    // Double insurance (same spirit as old TextField behavior):
    // - Outer cap: keep the whole input bar above keyboard + attachments even when expanded (incl. desktop narrow windows).
    // - Inner cap: editor itself will still have its own "max lines" viewport and scroll internally.
    final bool shouldCapInputHeight = isMobileLayout || _isExpanded;
    if (shouldCapInputHeight) {
      final double available = visibleHeight - attachmentsHeight - baseChromeHeight;
      // Allow a bit more room on larger layouts, but still keep context visible.
      final double softCap = visibleHeight * (isMobileLayout ? 0.45 : 0.60);
      if (available > 0) {
        maxInputHeight = math.min(softCap, available);
        maxInputHeight = math.min(available, math.max(80.0, maxInputHeight));
      } else {
        maxInputHeight = math.max(80.0, softCap);
      }
    }
    final BoxConstraints textFieldConstraints =
        (maxInputHeight.isFinite && maxInputHeight > 0) ? BoxConstraints(maxHeight: maxInputHeight) : const BoxConstraints();

    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm, AppSpacing.sm),
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
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isDark ? [] : AppShadows.soft,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insert_drive_file, size: 18),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              d.fileName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() => _docs.removeAt(idx));
                              // best-effort delete persisted attachment
                              try { final f = File(d.path); if (f.existsSync()) { f.deleteSync(); } } catch (_) {}
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
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
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
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.07),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.xs),
                    child: ConstrainedBox(
                      constraints: textFieldConstraints,
                      child: LayoutBuilder(
                        builder: (ctx, constraints) {
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

                          // enterToSend setting is checked but CodeEditor handles Enter differently.
                          // Keep watching to rebuild when the setting changes.
                          // ignore: unused_local_variable
                          final enterToSendOnMobile = context.watch<SettingsProvider>().enterToSendOnMobile;
                          final fontSize = _isDesktopPlatform() ? 14.0 : 15.0;
                          final fontHeight = 1.4;
                          final baseFont = theme.textTheme.bodyLarge;
                          final fontFamily = baseFont?.fontFamily;
                          final fontFamilyFallback = baseFont?.fontFamilyFallback;
                          final maxLinesLimit = _isExpanded ? 25 : 5;
                          final verticalPadding = 8.0;
                          const double overlayGutter = 28.0;
                          // Match CodeEditor's own padding so measurement width equals real content width.
                          // (Otherwise the wrap threshold will drift.)
                          // Slightly more top padding so placeholder "输入消息与AI聊天" sits lower visually.
                          final contentPadding = EdgeInsets.fromLTRB(
                            0,
                            verticalPadding,
                            overlayGutter,
                            verticalPadding / 2,
                          );

                          final metrics = _measureInputMetrics(
                            context: ctx,
                            text: _controller.text,
                            maxWidth: math.max(0, constraints.maxWidth - contentPadding.horizontal),
                            fontSize: fontSize,
                            fontFamily: fontFamily,
                            fontFamilyFallback: fontFamilyFallback,
                            fontHeight: fontHeight,
                            verticalPadding: contentPadding.vertical,
                            maxLines: maxLinesLimit,
                          );

                          final minHeight = fontSize * fontHeight + contentPadding.vertical;
                          final height = constraints.maxHeight.isFinite
                              ? math.max(minHeight, math.min(metrics.height, constraints.maxHeight))
                              : math.max(minHeight, metrics.height);
                          final showExpandButton = metrics.lineCount >= 3;

                          return Stack(
                            children: [
                              Focus(
                                onKeyEvent: _handleKeyEvent,
                                child: SizedBox(
                                  height: height,
                                  child: PlainTextCodeEditor(
                                    controller: _controller,
                                    focusNode: widget.focusNode,
                                    wordWrap: true,
                                    autofocus: false,
                                    shortcutsActivatorsBuilder: const _ChatInputShortcutsActivatorsBuilder(),
                                    shortcutOverrideActions: _shortcutOverrideActions,
                                    // Make wrapping behavior stable by ensuring we always use the same padding.
                                    hint: _hint(context),
                                    padding: contentPadding,
                                    fontSize: fontSize,
                                    fontFamily: fontFamily,
                                    fontFamilyFallback: fontFamilyFallback,
                                    fontHeight: fontHeight,
                                    hintAlpha: 0.45,
                                  ),
                                ),
                              ),
                              // Expand/Collapse icon button (only shown when 3+ lines)
                              if (showExpandButton)
                                Positioned(
                                  top: 10,
                                  right: 12,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _isExpanded = !_isExpanded);
                                      _ensureCaretVisible();
                                    },
                                    child: Icon(
                                      _isExpanded ? Lucide.ChevronsDownUp : Lucide.ChevronsUpDown,
                                      size: 16,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // Bottom buttons row (no divider)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, AppSpacing.xs, AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Responsive left action bar that overflows into a + menu on desktop
                        Expanded(child: _buildResponsiveLeftActions(context)),
                        Row(
                          children: [
                            if (widget.showMoreButton) ...[
                              _CompactIconButton(
                                tooltip: AppLocalizations.of(context)!.chatInputBarMoreTooltip,
                                icon: Lucide.Plus,
                                active: widget.moreOpen,
                                onTap: widget.onMore,
                                childBuilder: (c) => AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) => RotationTransition(
                                    turns: Tween<double>(begin: 0.85, end: 1).animate(anim),
                                    child: FadeTransition(opacity: anim, child: child),
                                  ),
                                  child: Icon(
                                    widget.moreOpen ? Lucide.X : Lucide.Plus,
                                    key: ValueKey(widget.moreOpen ? 'close' : 'add'),
                                    size: 20,
                                    color: c,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            _CompactSendButton(
                              enabled: (hasText || hasImages || hasDocs) && !widget.loading,
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
  const _OverflowAction({required this.width, required this.builder, required this.menu});
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
    final fgColor = active ? theme.colorScheme.primary : (isDark ? Colors.white70 : Colors.black54);
    final bool isDesktop = _isDesktopPlatform();

    // Keep overall button size constant. For model icon with child, enlarge child slightly
    // and reduce padding so (2*padding + childSize) stays unchanged.
    final bool isModelChild = modelIcon && child != null;
    final double iconSize = 20.0; // default glyph size
    final double childSize = isModelChild ? 28.0 : iconSize; // enlarge circle a bit more
    final double padding = isModelChild ? 1.0 : 6.0; // keep total ~30px (2*1 + 28)

    final button = IosIconButton(
      size: isModelChild ? childSize : 20,
      padding: EdgeInsets.all(padding),
      onTap: onTap,
      // Disable long press on desktop platforms
      onLongPress: isDesktop ? null : onLongPress,
      color: fgColor,
      builder: childBuilder != null
          ? (c) => SizedBox(width: childSize, height: childSize, child: childBuilder!(c))
          : (child != null
              ? (_) => SizedBox(width: childSize, height: childSize, child: child)
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
    final bg = (enabled || loading) ? color : (isDark ? Colors.white12 : Colors.grey.shade300.withValues(alpha: 0.84));
    final fg = (enabled || loading) ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.grey.shade600);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? onStop : (enabled ? onSend : null),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
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
  }
}

class _ComposingAwareNewLineAction extends Action<CodeShortcutNewLineIntent> {
  _ComposingAwareNewLineAction({
    required this.isComposing,
    required this.onInvoke,
  });

  final bool Function() isComposing;
  final Object? Function(CodeShortcutNewLineIntent) onInvoke;

  @override
  Object? invoke(CodeShortcutNewLineIntent intent) {
    if (isComposing()) {
      return null;
    }
    return onInvoke(intent);
  }
}

class _ChatInputShortcutsActivatorsBuilder extends CodeShortcutsActivatorsBuilder {
  const _ChatInputShortcutsActivatorsBuilder();

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) {
    if (type == CodeShortcutType.newLine) {
      final activators = <ShortcutActivator>[
        SingleActivator(LogicalKeyboardKey.enter),
        SingleActivator(LogicalKeyboardKey.enter, shift: true),
      ];
      if (_isDesktopPlatform()) {
        activators.addAll(const [
          SingleActivator(LogicalKeyboardKey.enter, control: true),
          SingleActivator(LogicalKeyboardKey.enter, meta: true),
        ]);
      }
      return activators;
    }
    return const DefaultCodeShortcutsActivatorsBuilder().build(type);
  }
}

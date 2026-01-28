import 'package:flutter/material.dart';
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
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../shared/responsive/breakpoints.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import '../../../core/models/chat_input_data.dart';
import '../../../utils/clipboard_images.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/services/search/search_service.dart';
import '../../../core/services/api/builtin_tools.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../utils/app_directories.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../desktop/desktop_context_menu.dart';

// Desktop context menu actions for right-click on the input field
enum _DesktopTextMenuAction { paste, cut, copy, selectAll }

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
    this.onClearContext,
    this.onLongPressLearning,
    this.learningModeActive = false,
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
  final VoidCallback? onToggleLearningMode;
  final VoidCallback? onClearContext;
  final VoidCallback? onLongPressLearning;
  final bool learningModeActive;
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
  late TextEditingController _controller;
  bool _searchEnabled = false;
  bool _isExpanded = false; // Track expand/collapse state for input field
  final List<String> _images = <String>[]; // local file paths
  final List<DocumentAttachment> _docs = <DocumentAttachment>[]; // files to upload
  final Map<LogicalKeyboardKey, Timer?> _repeatTimers = {};
  static const Duration _repeatInitialDelay = Duration(milliseconds: 300);
  static const Duration _repeatPeriod = Duration(milliseconds: 35);
  // Anchor for the responsive overflow menu on the left action bar
  final GlobalKey _leftOverflowAnchorKey = GlobalKey(debugLabel: 'left-overflow-anchor');
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
    try { final f = File(path); if (await f.exists()) { await f.delete(); } } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    widget.mediaController?._bind(this);
    _searchEnabled = widget.searchEnabled;
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
    } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      // When going to background, hide any open toolbar
      _suppressContextMenu = true;
      widget.focusNode?.unfocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _repeatTimers.values.forEach((t) { try { t?.cancel(); } catch (_) {} });
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
    if (oldWidget.searchEnabled != widget.searchEnabled) {
      _searchEnabled = widget.searchEnabled;
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

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty && _docs.isEmpty) return;
    widget.onSend?.call(ChatInputData(text: text, imagePaths: List.of(_images), documents: List.of(_docs)));
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

  void _insertNewlineAtCursor() {
    final value = _controller.value;
    final selection = value.selection;
    final text = value.text;
    if (!selection.isValid) {
      _controller.text = text + '\n';
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
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
      final editable = focusContext.findAncestorStateOfType<EditableTextState>();
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
    final items = <ContextMenuButtonItem>[
      ...state.contextMenuButtonItems,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: items,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    // Enhance hardware keyboard behavior
    final w = MediaQuery.sizeOf(node.context!).width;
    final isTabletOrDesktop = w >= AppBreakpoints.tablet;
    final isIosTablet = Platform.isIOS && isTabletOrDesktop;

    final isDown = event is RawKeyDownEvent;
    final key = event.logicalKey;
    final isEnter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    final isArrow = key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight;
    final isPasteV = key == LogicalKeyboardKey.keyV;

    // Enter handling on tablet/desktop: configurable shortcut
    if (isEnter && isTabletOrDesktop) {
      if (!isDown) return KeyEventResult.handled; // ignore key up
      // Respect IME composition (e.g., Chinese Pinyin). If composing, let IME handle Enter.
      final composing = _controller.value.composing;
      final composingActive = composing.isValid && !composing.isCollapsed;
      if (composingActive) return KeyEventResult.ignored;
      final keys = RawKeyboard.instance.keysPressed;
      final shift = keys.contains(LogicalKeyboardKey.shiftLeft) || keys.contains(LogicalKeyboardKey.shiftRight);
      final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);
      final meta = keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight);
      final ctrlOrMeta = ctrl || meta;
      // Get send shortcut setting
      final sendShortcut = Provider.of<SettingsProvider>(node.context!, listen: false).desktopSendShortcut;
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
      final keys = RawKeyboard.instance.keysPressed;
      final meta = keys.contains(LogicalKeyboardKey.metaLeft) || keys.contains(LogicalKeyboardKey.metaRight);
      final ctrl = keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight);
      if (meta || ctrl) {
        _handlePasteFromClipboard();
        return KeyEventResult.handled;
      }
    }

    // Arrow repeat fix only needed on iOS tablets
    if (!isIosTablet || !isArrow) return KeyEventResult.ignored;

    final keys = RawKeyboard.instance.keysPressed;
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
        Future<Uint8List?> _readFileBytes(DataReader dataReader, FileFormat format) async {
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
        Future<String?> _saveImageBytes(String format, Uint8List bytes) async {
          try {
            final dir = await AppDirectories.getUploadDirectory();
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final ts = DateTime.now().millisecondsSinceEpoch;
            final ext = format.toLowerCase();
            String name = 'paste_${ts}.${ext == 'jpeg' ? 'jpg' : ext}';
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
          bytes = await _readFileBytes(reader, Formats.png);
          fmt = 'png';
        }
        bytes ??= reader.canProvide(Formats.jpeg) ? await _readFileBytes(reader, Formats.jpeg) : null;
        fmt = (bytes != null && fmt == null) ? 'jpeg' : fmt;
        if (bytes == null && reader.canProvide(Formats.gif)) {
          bytes = await _readFileBytes(reader, Formats.gif);
          fmt = 'gif';
        }
        if (bytes == null && reader.canProvide(Formats.webp)) {
          bytes = await _readFileBytes(reader, Formats.webp);
          fmt = 'webp';
        }

        if (bytes == null) {
          // Try per-item formats
          for (final item in reader.items) {
            if (bytes == null && item.canProvide(Formats.png)) {
              bytes = await _readFileBytes(item, Formats.png);
              fmt = 'png';
            }
            if (bytes == null && item.canProvide(Formats.jpeg)) {
              bytes = await _readFileBytes(item, Formats.jpeg);
              fmt = 'jpeg';
            }
            if (bytes == null && item.canProvide(Formats.gif)) {
              bytes = await _readFileBytes(item, Formats.gif);
              fmt = 'gif';
            }
            if (bytes == null && item.canProvide(Formats.webp)) {
              bytes = await _readFileBytes(item, Formats.webp);
              fmt = 'webp';
            }
            if (bytes != null) break;
          }
        }

        if (bytes != null && bytes.isNotEmpty && fmt != null) {
          final savedPath = await _saveImageBytes(fmt, bytes);
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
                _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
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
        _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
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
  Future<({List<String> images, List<DocumentAttachment> docs})> _copyFilesToUpload(List<String> srcPaths) async {
    final images = <String>[];
    final docs = <DocumentAttachment>[];
    try {
      final dir = await AppDirectories.getUploadDirectory();
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
            child: widget.modelIcon,
            modelIcon: true,
            onTap: widget.onSelectModel,
            onLongPress: widget.onLongPressSelectModel,
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
        while (i > 0 && text[i - 1].trim().isEmpty) i--;
        while (i > 0 && text[i - 1].trim().isNotEmpty) i--;
      } else {
        // Move right
        while (i < text.length && text[i].trim().isEmpty) i++;
        while (i < text.length && text[i].trim().isNotEmpty) i++;
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
    if (isMobileLayout) {
      final double available = visibleHeight - attachmentsHeight - baseChromeHeight;
      final double softCap = visibleHeight * 0.45;
      if (available > 0) {
        maxInputHeight = math.min(softCap, available);
        maxInputHeight = math.min(available, math.max(80.0, maxInputHeight));
      } else {
        maxInputHeight = math.max(80.0, softCap);
      }
    }
    // Cap text field height on mobile so expanded input stays above the keyboard.
    final BoxConstraints textFieldConstraints = (isMobileLayout && maxInputHeight.isFinite && maxInputHeight > 0)
        ? BoxConstraints(maxHeight: maxInputHeight)
        : const BoxConstraints();

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
                                color: Colors.black.withOpacity(0.6),
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
                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    // Use previous gray border for better contrast on white
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.10)
                          : theme.colorScheme.outline.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                  // Input field with expand/collapse button
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.xs),
                        child: ConstrainedBox(
                          constraints: textFieldConstraints,
                          child: Focus(
                            onKey: (node, event) => _handleKeyEvent(node, event),
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

                            final enterToSend = context.watch<SettingsProvider>().enterToSendOnMobile;
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
                                textInputAction: enterToSend ? TextInputAction.send : TextInputAction.newline,
                                onSubmitted: enterToSend ? (_) => _handleSend() : null,
                                // Custom context menu: use instance method to avoid flickering
                                // caused by recreating the callback on every build.
                                // See: https://github.com/flutter/flutter/issues/150551
                                contextMenuBuilder: _buildContextMenu,
                                autofocus: false,
                                decoration: InputDecoration(
                                  hintText: _hint(context),
                                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.45)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                                ),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: (Platform.isWindows || Platform.isLinux || Platform.isMacOS) ? 14 : 15,
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
                              _isExpanded ? Lucide.ChevronsDownUp : Lucide.ChevronsUpDown,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.45),
                            ),
                          ),
                        ),
                    ],
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
    final bool isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

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

// Keep original button for compatibility if needed elsewhere
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.tooltip,
    this.active = false,
    this.child,
    this.padding,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;
  final Widget? child;
  final double? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = active ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent;
    final fgColor = active ? theme.colorScheme.primary : (isDark ? Colors.white : Colors.black87);

    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: const ShapeDecoration(shape: CircleBorder()),
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding ?? 10),
            child: child ?? Icon(icon, size: 22, color: fgColor),
          ),
        ),
      ),
    );

    // Avoid Material Tooltip's ticker conflicts on some platforms; use semantics-only tooltip
    return tooltip == null ? button : Semantics(tooltip: tooltip!, child: button);
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
    final bg = (enabled || loading) ? color : (isDark ? Colors.white12 : Colors.grey.shade300.withOpacity(0.84));
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

// Keep original button for compatibility if needed elsewhere
class _SendButton extends StatelessWidget {
  const _SendButton({
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
    final bg = (enabled || loading) ? color : (isDark ? Colors.white12 : Colors.grey.shade300);
    final fg = (enabled || loading) ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white70 : Colors.grey.shade600);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? onStop : (enabled ? onSend : null),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
            child: loading
                ? SvgPicture.asset(
                    key: const ValueKey('stop'),
                    'assets/icons/stop.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(fg, BlendMode.srcIn),
                  )
                : Icon(icon, key: const ValueKey('send'), size: 22, color: fg),
          ),
        ),
      ),
    );
  }
}

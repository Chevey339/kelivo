import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/mermaid_bridge.dart';
import 'package:Kelivo/shared/widgets/mermaid_image_cache.dart';
import 'package:Kelivo/shared/widgets/export_capture_scope.dart';
import 'package:Kelivo/shared/widgets/diagram_exporter.dart';
import 'highlight_adapter.dart';
import 'diagram_chrome.dart';

enum MermaidBitmapRenderStatus { success, failed, unsupported }

class MermaidBitmapRenderResult {
  const MermaidBitmapRenderResult._(this.status, [this.bytes]);

  factory MermaidBitmapRenderResult.success(Uint8List bytes) {
    return MermaidBitmapRenderResult._(
      MermaidBitmapRenderStatus.success,
      bytes,
    );
  }

  factory MermaidBitmapRenderResult.failed() {
    return const MermaidBitmapRenderResult._(MermaidBitmapRenderStatus.failed);
  }

  factory MermaidBitmapRenderResult.unsupported() {
    return const MermaidBitmapRenderResult._(
      MermaidBitmapRenderStatus.unsupported,
    );
  }

  final MermaidBitmapRenderStatus status;
  final Uint8List? bytes;
}

typedef MermaidBitmapRenderOverride =
    Future<MermaidBitmapRenderResult> Function(
      String code,
      bool isDark,
      Map<String, String> themeVars,
    );

@visibleForTesting
MermaidBitmapRenderOverride? debugMermaidBitmapRenderOverride;

class KelivoDiagramBlock extends StatefulWidget {
  final CodeBlockNode node;
  final MarkstreamTheme theme;
  String get code => node.code;
  final bool streaming;
  final bool isSvg;
  const KelivoDiagramBlock({
    super.key,
    required this.node,
    required this.theme,
    required this.streaming,
    this.isSvg = false,
  });

  @override
  State<KelivoDiagramBlock> createState() => KelivoDiagramBlockState();
}

enum _MermaidTab { image, code }

class KelivoDiagramBlockState extends State<KelivoDiagramBlock> {
  static const Duration _streamingBitmapRenderDelay = Duration(
    milliseconds: 360,
  );
  static const Duration _settledBitmapRenderDelay = Duration(milliseconds: 220);
  static const double _previewHeight = 406;

  _MermaidTab _selectedTab = _MermaidTab.image;
  late final ScrollController _vMermaidScrollController;
  OverlayEntry? _renderOverlayEntry;
  bool _renderQueued = false;
  bool _renderingBitmap = false;
  String? _renderKey;
  Uint8List? _lastRenderedBytes;
  Timer? _streamingRenderDebounce;
  bool _bitmapRenderingUnsupported = false;
  bool _suppressBitmapLoading = false;
  final Set<String> _failedBitmapRenderKeys = <String>{};

  String _cacheKey(String code, bool dark, Map<String, String> vars) =>
      diagramImageCacheKey(code, dark, vars, isSvg: widget.isSvg);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final mermaidColors = widget.theme.colors;

    final themeVars = buildThemeVarsFromColorScheme(cs);

    final exporting = ExportCaptureScope.of(context);
    final cacheKey = _cacheKey(widget.code, isDark, themeVars);
    final themedCachedBytes = MermaidImageCache.get(cacheKey);
    final legacyCachedBytes = widget.isSvg
        ? null
        : MermaidImageCache.get(widget.code);
    final prefixCachedBytes = widget.streaming && !widget.isSvg
        ? _findCachedStreamingMermaidPrefix(
            widget.code,
            isDark: isDark,
            themeVars: themeVars,
          )
        : null;
    final exactCachedBytes = themedCachedBytes ?? legacyCachedBytes;
    final cachedBytes = exactCachedBytes ?? prefixCachedBytes;
    final displayBytes =
        cachedBytes ?? (widget.streaming ? _lastRenderedBytes : null);
    final actionBytes = cachedBytes ?? displayBytes;
    final renderFailedForCurrentCode = _failedBitmapRenderKeys.contains(
      cacheKey,
    );
    final hasRenderableCode = widget.code.trim().isNotEmpty;
    if (!exporting &&
        hasRenderableCode &&
        exactCachedBytes == null &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode) {
      _scheduleBitmapRender(
        isDark: isDark,
        themeVars: themeVars,
        delay: widget.streaming
            ? _streamingBitmapRenderDelay
            : _settledBitmapRenderDelay,
      );
    }
    final hasImage = displayBytes != null && displayBytes.isNotEmpty;
    if (exporting && !hasImage) {
      return MarkstreamCodeBlock(
        node: widget.node,
        theme: widget.theme,
        extensions: const MarkstreamExtensions.empty(),
        options: const CodeBlockOptions(),
        labels: MarkstreamLabels(unnamedCode: l10n.markdownCodeLabel),
        highlighter: KelivoCodeHighlighter.forTheme(widget.theme),
        exporting: true,
      );
    }
    final showLoading =
        !hasImage &&
        !_suppressBitmapLoading &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode &&
        (widget.streaming || _renderQueued || _renderingBitmap);
    final showError =
        !hasImage &&
        !_bitmapRenderingUnsupported &&
        renderFailedForCurrentCode &&
        _selectedTab == _MermaidTab.image;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: mermaidColors.fillBlock,
        borderRadius: BorderRadius.circular(widget.theme.code.radius),
      ),
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.theme.code.radius),
        border: Border.all(color: mermaidColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DiagramChrome(
            theme: widget.theme,
            imageSelected: _selectedTab == _MermaidTab.image,
            onImage: () => setState(() => _selectedTab = _MermaidTab.image),
            onCode: () => setState(() => _selectedTab = _MermaidTab.code),
            actions: exporting
                ? const []
                : [
                    DiagramAction(
                      theme: widget.theme,
                      icon: Lucide.Copy,
                      label: l10n.shareProviderSheetCopyButton,
                      onTap: () => _copyMermaidCode(context),
                    ),
                    DiagramAction(
                      theme: widget.theme,
                      icon: Lucide.Download,
                      label: l10n.mermaidExportPng,
                      enabled: actionBytes != null && actionBytes.isNotEmpty,
                      onTap: actionBytes == null || actionBytes.isEmpty
                          ? null
                          : () => _saveMermaidBytes(context, actionBytes),
                    ),
                    DiagramAction(
                      theme: widget.theme,
                      icon: Lucide.Maximize2,
                      label: l10n.mermaidFullScreen,
                      enabled: actionBytes != null && actionBytes.isNotEmpty,
                      onTap: actionBytes == null || actionBytes.isEmpty
                          ? null
                          : () => _openMermaidImageViewer(context, actionBytes),
                    ),
                  ],
          ),
          SizedBox(
            key: const ValueKey('mermaid-preview-body'),
            width: double.infinity,
            height: _previewHeight,
            child: ColoredBox(
              // The enclosing surface already paints this tint once.
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return currentChild ?? const SizedBox.shrink();
                },
                child: _buildMermaidBody(
                  context: context,
                  isDark: isDark,
                  colors: mermaidColors,
                  displayBytes: displayBytes,
                  cacheKey: cacheKey,
                  showLoading: showLoading,
                  showError: showError,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMermaidBody({
    required BuildContext context,
    required bool isDark,
    required MarkstreamColors colors,
    required Uint8List? displayBytes,
    required String cacheKey,
    required bool showLoading,
    required bool showError,
  }) {
    if (_selectedTab == _MermaidTab.code ||
        _bitmapRenderingUnsupported ||
        widget.code.trim().isEmpty) {
      return _buildMermaidCodeView(context, isDark);
    }

    if (displayBytes != null && displayBytes.isNotEmpty) {
      return Padding(
        key: ValueKey<String>('mermaid-image-$cacheKey'),
        padding: const EdgeInsets.all(12),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openMermaidImageViewer(context, displayBytes),
            child: Image(image: MemoryImage(displayBytes), fit: BoxFit.contain),
          ),
        ),
      );
    }

    if (showLoading) {
      return _MermaidLoadingView(
        key: const ValueKey('mermaid-loading-body'),
        colors: colors,
      );
    }

    if (showError) {
      return _MermaidErrorView(
        key: const ValueKey('mermaid-error-body'),
        colors: colors,
      );
    }

    return _buildMermaidCodeView(context, isDark);
  }

  Widget _buildMermaidCodeView(BuildContext context, bool isDark) {
    final codeView = MarkstreamCodeContent(
      node: widget.node,
      theme: widget.theme,
      highlighter: KelivoCodeHighlighter.forTheme(widget.theme),
      streaming: widget.streaming,
      wrap: false,
    );

    return Padding(
      key: const ValueKey('mermaid-code-body'),
      padding: const EdgeInsets.all(12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.stylus,
            ui.PointerDeviceKind.unknown,
          },
        ),
        child: Scrollbar(
          controller: _vMermaidScrollController,
          thumbVisibility: true,
          interactive: true,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: _vMermaidScrollController,
            child: codeView,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _vMermaidScrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant KelivoDiagramBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code ||
        oldWidget.streaming != widget.streaming) {
      _suppressBitmapLoading = false;
      if (!widget.streaming || oldWidget.streaming != widget.streaming) {
        _streamingRenderDebounce?.cancel();
        _renderQueued = false;
        _renderingBitmap = false;
        _removeRenderOverlay();
        _renderKey = null;
      }
    }
    if (widget.code.trim().isEmpty) {
      _lastRenderedBytes = null;
      _suppressBitmapLoading = false;
      _bitmapRenderingUnsupported = false;
      _failedBitmapRenderKeys.clear();
    }
  }

  @override
  void dispose() {
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    _vMermaidScrollController.dispose();
    super.dispose();
  }

  void _scheduleBitmapRender({
    required bool isDark,
    required Map<String, String> themeVars,
    required Duration delay,
  }) {
    if (_renderQueued || _renderingBitmap) return;
    _renderQueued = true;
    _streamingRenderDebounce?.cancel();
    _streamingRenderDebounce = Timer(delay, () {
      _renderQueued = false;
      if (!mounted) return;
      _renderBitmap(isDark: isDark, themeVars: themeVars);
    });
  }

  Future<void> _renderBitmap({
    required bool isDark,
    required Map<String, String> themeVars,
  }) async {
    final code = widget.code;
    final cacheKey = _cacheKey(code, isDark, themeVars);
    if (MermaidImageCache.get(cacheKey) != null) return;
    final renderOverride = debugMermaidBitmapRenderOverride;
    final overlay = renderOverride == null ? Overlay.maybeOf(context) : null;
    if (renderOverride == null && overlay == null) {
      _markBitmapRenderingUnsupported(cacheKey);
      return;
    }
    setState(() {
      _renderKey = cacheKey;
      _renderingBitmap = true;
    });

    MermaidBitmapRenderResult result = MermaidBitmapRenderResult.failed();
    try {
      result = renderOverride == null
          ? await _renderMermaidBitmapWithOverlay(
              overlay!,
              code,
              isDark,
              themeVars,
            )
          : await renderOverride(code, isDark, themeVars);
      if (!mounted || _renderKey != cacheKey) return;
      final bytes = result.bytes;
      if (result.status == MermaidBitmapRenderStatus.success &&
          bytes != null &&
          bytes.isNotEmpty) {
        MermaidImageCache.put(cacheKey, bytes);
        _failedBitmapRenderKeys.remove(cacheKey);
      }
    } catch (_) {
      // The existing failed-result state presents the localized error view.
    } finally {
      if (mounted && _renderKey == cacheKey) {
        _removeRenderOverlay();
        setState(() {
          if (result.status == MermaidBitmapRenderStatus.success &&
              result.bytes != null &&
              result.bytes!.isNotEmpty) {
            _lastRenderedBytes = result.bytes;
          } else if (result.status == MermaidBitmapRenderStatus.unsupported) {
            _bitmapRenderingUnsupported = true;
            _suppressBitmapLoading = true;
          } else {
            _failedBitmapRenderKeys.add(cacheKey);
            _suppressBitmapLoading = true;
          }
          _renderingBitmap = false;
        });
      }
    }
  }

  Future<MermaidBitmapRenderResult> _renderMermaidBitmapWithOverlay(
    OverlayState overlay,
    String code,
    bool isDark,
    Map<String, String> themeVars,
  ) async {
    _removeRenderOverlay();
    final renderKey = GlobalKey();
    final handle = createMermaidView(
      code,
      isDark,
      themeVars: themeVars,
      viewKey: renderKey,
      isSvg: widget.isSvg,
    );
    if (handle == null) return MermaidBitmapRenderResult.unsupported();

    _renderOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: -10000,
        child: ConstrainedBox(
          constraints: const BoxConstraints.tightFor(width: 720, height: 600),
          child: Material(color: Colors.transparent, child: handle.widget),
        ),
      ),
    );
    overlay.insert(_renderOverlayEntry!);

    return _captureMermaidBitmap(handle);
  }

  void _markBitmapRenderingUnsupported(String cacheKey) {
    if (!mounted) return;
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    setState(() {
      if (_renderKey == null || _renderKey == cacheKey) {
        _renderKey = null;
        _renderQueued = false;
        _renderingBitmap = false;
      }
      _bitmapRenderingUnsupported = true;
    });
  }

  Uint8List? _findCachedStreamingMermaidPrefix(
    String code, {
    required bool isDark,
    required Map<String, String> themeVars,
  }) {
    final lines = code.split('\n');
    for (var end = lines.length - 1; end >= 1; end--) {
      final candidate = lines.take(end).join('\n').trimRight();
      if (candidate.isEmpty) continue;
      final themed = MermaidImageCache.get(
        _cacheKey(candidate, isDark, themeVars),
      );
      final legacy = MermaidImageCache.get(candidate);
      final bytes = themed ?? legacy;
      if (bytes != null && bytes.isNotEmpty) {
        _lastRenderedBytes = bytes;
        return bytes;
      }
    }
    return null;
  }

  Future<MermaidBitmapRenderResult> _captureMermaidBitmap(
    MermaidViewHandle handle,
  ) async {
    final exportBytes = handle.exportPngBytes;
    if (exportBytes == null) return MermaidBitmapRenderResult.unsupported();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (var i = 0; i < 4; i++) {
      try {
        final bytes = await exportBytes().timeout(
          const Duration(milliseconds: 900),
          onTimeout: () => null,
        );
        if (bytes != null && bytes.isNotEmpty) {
          return MermaidBitmapRenderResult.success(bytes);
        }
      } catch (e) {
        if (e is UnsupportedError) {
          return MermaidBitmapRenderResult.unsupported();
        }
        // Mermaid/WebView can report readiness before pixel capture is available.
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return MermaidBitmapRenderResult.failed();
  }

  Future<void> _copyMermaidCode(BuildContext context) async {
    final copiedMessage = AppLocalizations.of(
      context,
    )!.chatMessageWidgetCopiedToClipboard;
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: copiedMessage,
      type: NotificationType.success,
    );
  }

  Future<void> _saveMermaidBytes(BuildContext context, Uint8List bytes) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await _saveCachedMermaidPng(bytes);
    if (!context.mounted) return;
    if (!ok) {
      showAppSnackBar(
        context,
        message: l10n.mermaidExportFailed,
        type: NotificationType.error,
      );
    } else if (Platform.isAndroid || Platform.isIOS) {
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveSuccess,
        type: NotificationType.success,
      );
    }
  }

  void _openMermaidImageViewer(BuildContext context, Uint8List bytes) {
    final src = 'data:image/png;base64,${base64Encode(bytes)}';
    final provider = MemoryImage(bytes);
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ImageViewerPage(images: [src], imageProviders: {src: provider}),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        transitionsBuilder: (context, anim, sec, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
  }

  void _removeRenderOverlay() {
    try {
      _renderOverlayEntry?.remove();
    } catch (_) {}
    _renderOverlayEntry = null;
  }

  Future<bool> _saveCachedMermaidPng(Uint8List bytes) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final prefix = widget.isSvg ? 'svg' : 'mermaid';
      final suggested =
          '${prefix}_${DateTime.now().millisecondsSinceEpoch}.png';
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: l10n.backupPageExportToFile,
          fileName: suggested,
          type: FileType.custom,
          allowedExtensions: const ['png'],
        );
        if (savePath == null || savePath.isEmpty) return false;
        await File(savePath).parent.create(recursive: true);
        await File(savePath).writeAsBytes(bytes);
        return true;
      }
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'kelivo-$prefix-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (result is Map) {
        final isSuccess =
            result['isSuccess'] == true || result['isSuccess'] == 1;
        final filePath = result['filePath'] ?? result['file_path'];
        return isSuccess || (filePath is String && filePath.isNotEmpty);
      }
    } catch (_) {}
    return false;
  }
}

class _MermaidLoadingView extends StatefulWidget {
  const _MermaidLoadingView({super.key, required this.colors});

  final MarkstreamColors colors;

  @override
  State<_MermaidLoadingView> createState() => _MermaidLoadingViewState();
}

class _MermaidLoadingViewState extends State<_MermaidLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RotationTransition(
            turns: _controller,
            child: Icon(Lucide.Loader, size: 24, color: widget.colors.ink2),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.mermaidGeneratingImage,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: widget.colors.ink2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MermaidErrorView extends StatelessWidget {
  const _MermaidErrorView({super.key, required this.colors});

  final MarkstreamColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.ImageOff, size: 48, color: colors.ink3),
          const SizedBox(height: 8),
          Text(
            l10n.mermaidGenerationFailedHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.35, color: colors.ink2),
          ),
        ],
      ),
    );
  }
}

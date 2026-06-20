import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import '../../features/chat/pages/image_viewer_page.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import 'export_capture_scope.dart';
import 'mermaid_bridge.dart';
import 'mermaid_image_cache.dart';
import 'snackbar.dart';
import 'tabbed_preview_block.dart';

// ---------------------------------------------------------------------------
// Cache key
// ---------------------------------------------------------------------------

String _mermaidCacheKey(
  String code,
  bool isDark,
  Map<String, String> themeVars,
) {
  final entries = themeVars.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final themeSig = entries.map((e) => '${e.key}=${e.value}').join('&');
  return '${isDark ? 'dark' : 'light'}|$themeSig|$code';
}

// ---------------------------------------------------------------------------
// Bitmap render result
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// MermaidBlock widget
// ---------------------------------------------------------------------------

class MermaidBlock extends TabbedPreviewBlock {
  const MermaidBlock({super.key, required super.code, this.streaming = false});

  final bool streaming;

  @override
  State<MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends TabbedPreviewBlockState<MermaidBlock> {
  static const Duration _streamingBitmapRenderDelay = Duration(
    milliseconds: 360,
  );
  static const Duration _settledBitmapRenderDelay = Duration(milliseconds: 220);

  OverlayEntry? _renderOverlayEntry;
  bool _renderQueued = false;
  bool _renderingBitmap = false;
  String? _renderKey;
  Uint8List? _lastRenderedBytes;
  Timer? _streamingRenderDebounce;
  bool _bitmapRenderingUnsupported = false;
  bool _suppressBitmapLoading = false;
  final Set<String> _failedBitmapRenderKeys = <String>{};

  // -----------------------------------------------------------------------
  // Overrides
  // -----------------------------------------------------------------------

  @override
  void onCodeChanged() {
    _suppressBitmapLoading = false;
    if (!widget.streaming) {
      _streamingRenderDebounce?.cancel();
      _renderQueued = false;
      _renderingBitmap = false;
      _removeRenderOverlay();
      _renderKey = null;
    }
    if (widget.code.trim().isEmpty) {
      _lastRenderedBytes = null;
      _suppressBitmapLoading = false;
      _bitmapRenderingUnsupported = false;
      _failedBitmapRenderKeys.clear();
    }
  }

  @override
  void didUpdateWidget(covariant MermaidBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streaming != widget.streaming) {
      _suppressBitmapLoading = false;
      _streamingRenderDebounce?.cancel();
      _renderQueued = false;
      _renderingBitmap = false;
      _removeRenderOverlay();
      _renderKey = null;
    }
  }

  @override
  void dispose() {
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Schedule bitmap render regardless of selected tab so the image
    // is ready when the user switches to the image view.
    _scheduleRenderIfNeeded(context);
    return super.build(context);
  }

  @override
  Widget buildImageContent(BuildContext context, PreviewBlockColors colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final themeVars = _buildThemeVars(cs);
    final cacheKey = _mermaidCacheKey(widget.code, isDark, themeVars);
    final themedCachedBytes = MermaidImageCache.get(cacheKey);
    final legacyCachedBytes = MermaidImageCache.get(widget.code);
    final prefixCachedBytes = widget.streaming
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
    final renderFailedForCurrentCode = _failedBitmapRenderKeys.contains(
      cacheKey,
    );
    final hasImage = displayBytes != null && displayBytes.isNotEmpty;
    final showLoading =
        !hasImage &&
        !_suppressBitmapLoading &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode &&
        (widget.streaming || _renderQueued || _renderingBitmap);
    final showError =
        !hasImage && !_bitmapRenderingUnsupported && renderFailedForCurrentCode;

    if (widget.code.trim().isEmpty) {
      return _buildCodeFallback(context, isDark, colors);
    }

    if (hasImage) {
      return Padding(
        key: ValueKey<String>('mermaid-image-$cacheKey'),
        padding: const EdgeInsets.all(8),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openImageViewer(context, displayBytes),
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

    return _buildCodeFallback(context, isDark, colors);
  }

  @override
  List<Widget> buildExtraActions(
    BuildContext context,
    PreviewBlockColors colors,
    bool exporting,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final themeVars = _buildThemeVars(cs);
    final cacheKey = _mermaidCacheKey(widget.code, isDark, themeVars);
    final themedCachedBytes = MermaidImageCache.get(cacheKey);
    final legacyCachedBytes = MermaidImageCache.get(widget.code);
    final prefixCachedBytes = widget.streaming
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
    final hasBytes = actionBytes != null && actionBytes.isNotEmpty;

    return [
      PreviewTextAction(
        icon: Lucide.Download,
        label: l10n.mermaidExportPng,
        colors: colors,
        enabled: hasBytes,
        onTap: hasBytes ? () => _saveMermaidBytes(context, actionBytes) : null,
      ),
      const SizedBox(width: 4),
      PreviewTextAction(
        icon: Lucide.Maximize2,
        label: l10n.mermaidFullScreen,
        colors: colors,
        enabled: hasBytes,
        onTap: hasBytes ? () => _openImageViewer(context, actionBytes) : null,
      ),
    ];
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  Map<String, String> _buildThemeVars(ColorScheme cs) {
    String hex(Color c) {
      final v = c.toARGB32();
      final r = (v >> 16) & 0xFF;
      final g = (v >> 8) & 0xFF;
      final b = v & 0xFF;
      return '#'
              '${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
    }

    return <String, String>{
      'primaryColor': hex(cs.primary),
      'primaryTextColor': hex(cs.onPrimary),
      'primaryBorderColor': hex(cs.primary),
      'secondaryColor': hex(cs.secondary),
      'secondaryTextColor': hex(cs.onSecondary),
      'secondaryBorderColor': hex(cs.secondary),
      'tertiaryColor': hex(cs.tertiary),
      'tertiaryTextColor': hex(cs.onTertiary),
      'tertiaryBorderColor': hex(cs.tertiary),
      'background': hex(cs.surface),
      'mainBkg': hex(cs.primaryContainer),
      'secondBkg': hex(cs.secondaryContainer),
      'lineColor': hex(cs.onSurface),
      'textColor': hex(cs.onSurface),
      'nodeBkg': hex(cs.surface),
      'nodeBorder': hex(cs.primary),
      'clusterBkg': hex(cs.surface),
      'clusterBorder': hex(cs.primary),
      'actorBorder': hex(cs.primary),
      'actorBkg': hex(cs.surface),
      'actorTextColor': hex(cs.onSurface),
      'actorLineColor': hex(cs.primary),
      'taskBorderColor': hex(cs.primary),
      'taskBkgColor': hex(cs.primary),
      'taskTextLightColor': hex(cs.onPrimary),
      'taskTextDarkColor': hex(cs.onSurface),
      'labelColor': hex(cs.onSurface),
      'errorBkgColor': hex(cs.error),
      'errorTextColor': hex(cs.onError),
    };
  }

  void _scheduleRenderIfNeeded(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final themeVars = _buildThemeVars(cs);
    final cacheKey = _mermaidCacheKey(widget.code, isDark, themeVars);
    final themedCachedBytes = MermaidImageCache.get(cacheKey);
    final legacyCachedBytes = MermaidImageCache.get(widget.code);
    final exactCachedBytes = themedCachedBytes ?? legacyCachedBytes;
    final renderFailedForCurrentCode = _failedBitmapRenderKeys.contains(
      cacheKey,
    );
    final hasRenderableCode = widget.code.trim().isNotEmpty;

    final shouldRender =
        !ExportCaptureScope.of(context) &&
        hasRenderableCode &&
        exactCachedBytes == null &&
        !_bitmapRenderingUnsupported &&
        !renderFailedForCurrentCode;

    if (shouldRender) {
      _scheduleBitmapRender(
        isDark: isDark,
        themeVars: themeVars,
        delay: widget.streaming
            ? _streamingBitmapRenderDelay
            : _settledBitmapRenderDelay,
      );
    }
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
    final cacheKey = _mermaidCacheKey(code, isDark, themeVars);
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
    } catch (e, st) {
      debugPrint('Mermaid bitmap render failed: $e\n$st');
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
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return MermaidBitmapRenderResult.failed();
  }

  void _markBitmapRenderingUnsupported(String cacheKey) {
    if (!mounted) return;
    _streamingRenderDebounce?.cancel();
    _removeRenderOverlay();
    setState(() {
      _bitmapRenderingUnsupported = true;
      _suppressBitmapLoading = true;
      _failedBitmapRenderKeys.add(cacheKey);
      _renderingBitmap = false;
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
        _mermaidCacheKey(candidate, isDark, themeVars),
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

  void _removeRenderOverlay() {
    try {
      _renderOverlayEntry?.remove();
    } catch (_) {}
    _renderOverlayEntry = null;
  }

  Widget _buildCodeFallback(
    BuildContext context,
    bool isDark,
    PreviewBlockColors colors,
  ) {
    // When bitmap rendering is unsupported, code is empty, or the
    // render failed, fall back to the base code view.
    return Container(
      key: const ValueKey('mermaid-code-fallback'),
      padding: const EdgeInsets.all(12),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.unknown,
          },
        ),
        child: Scrollbar(
          controller: codeScrollController,
          thumbVisibility: true,
          interactive: true,
          notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
          child: SingleChildScrollView(
            controller: codeScrollController,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.code,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, Uint8List bytes) {
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

  Future<bool> _saveCachedMermaidPng(Uint8List bytes) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final suggested = 'mermaid_${DateTime.now().millisecondsSinceEpoch}.png';
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
        name: 'kelivo-mermaid-${DateTime.now().millisecondsSinceEpoch}',
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

// ---------------------------------------------------------------------------
// Mermaid-specific loading / error views
// ---------------------------------------------------------------------------

class _MermaidLoadingView extends StatefulWidget {
  const _MermaidLoadingView({super.key, required this.colors});

  final PreviewBlockColors colors;

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
            child: Icon(
              Lucide.Loader,
              size: 24,
              color: widget.colors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.mermaidGeneratingImage,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: widget.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MermaidErrorView extends StatelessWidget {
  const _MermaidErrorView({super.key, required this.colors});

  final PreviewBlockColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Lucide.ImageOff, size: 48, color: colors.textTertiary),
          const SizedBox(height: 8),
          Text(
            l10n.mermaidGenerationFailedHint,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

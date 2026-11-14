import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import '../../../core/models/image_upload_quality.dart';
import '../models/image_viewer_draft_mode.dart';
import 'dart:convert';
import 'package:Kelivo/utils/svg_image_provider.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../core/services/native_file_save.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/safe_resize_image.dart';
import '../../../utils/clipboard_images.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

@visibleForTesting
const int kMaxViewerDecodeEdge = 4096;
@visibleForTesting
const int kMaxViewerDecodePixels = 12 * 1024 * 1024;

@visibleForTesting
({int width, int height}) computeViewerDecodePixels({
  required double logicalWidth,
  required double logicalHeight,
  required double devicePixelRatio,
}) {
  final dpr = devicePixelRatio <= 0 ? 1.0 : devicePixelRatio;
  return clampDecodedPixelSize(
    width: math.max(1.0, logicalWidth * dpr),
    height: math.max(1.0, logicalHeight * dpr),
    maxEdge: kMaxViewerDecodeEdge,
    maxPixels: kMaxViewerDecodePixels,
  );
}

@visibleForTesting
const List<int> kViewerDecodeSizeBuckets = <int>[
  512,
  768,
  1024,
  1536,
  2048,
  2304,
  2560,
  3072,
  3584,
  4096,
];

@visibleForTesting
({int width, int height}) quantizeViewerDecodePixels({
  required int width,
  required int height,
}) {
  return computeViewerDecodePixels(
    logicalWidth: _snapViewerDecodeBucket(width).toDouble(),
    logicalHeight: _snapViewerDecodeBucket(height).toDouble(),
    devicePixelRatio: 1,
  );
}

@visibleForTesting
bool canReuseViewerDisplayPixels({
  required int cachedWidth,
  required int cachedHeight,
  required int targetWidth,
  required int targetHeight,
}) {
  if (cachedWidth != cachedHeight &&
      targetWidth != targetHeight &&
      (cachedWidth > cachedHeight) != (targetWidth > targetHeight)) {
    return false;
  }
  return targetWidth <= (cachedWidth * 1.2).ceil() &&
      targetHeight <= (cachedHeight * 1.2).ceil();
}

int _snapViewerDecodeBucket(int value) {
  final size = math.max(1, value);
  for (final candidate in kViewerDecodeSizeBuckets) {
    if (candidate >= size) return candidate;
  }
  return math.min(size, kMaxViewerDecodeEdge);
}

@visibleForTesting
int debugClipboardImageCodecCalls = 0;

@visibleForTesting
({int width, int height})? debugLastClipboardDecodeTarget;

@visibleForTesting
String detectClipboardImageFormat({required List<int> bytes}) {
  return _formatFromMagicBytes(bytes);
}

@visibleForTesting
String inferClipboardImageFormatHint(String hint) {
  final raw = hint.trim().toLowerCase();
  if (raw.isEmpty) return '';
  final media = raw.split(';').first.trim();
  if (media.contains('/')) {
    final parts = media.split('/');
    if (parts.length != 2 || parts[0] != 'image') return '';
    return switch (parts[1]) {
      'png' => 'png',
      'jpeg' || 'jpg' || 'pjpeg' => 'jpeg',
      'gif' => 'gif',
      'webp' => 'webp',
      _ => '',
    };
  }
  var name = raw;
  final slash = math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
  if (slash >= 0) name = name.substring(slash + 1);
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) return '';
  return switch (name.substring(dot + 1)) {
    'png' => 'png',
    'jpg' || 'jpeg' => 'jpeg',
    'gif' => 'gif',
    'webp' => 'webp',
    _ => '',
  };
}

@visibleForTesting
String? resolveClipboardFallbackSourcePath({
  required String? sourcePath,
  required bool converted,
}) {
  return converted ? null : sourcePath;
}

bool _isSupportedClipboardFormat(String format) {
  return format == 'png' ||
      format == 'jpeg' ||
      format == 'gif' ||
      format == 'webp';
}

Size? _readPngSizeFromBytes(List<int> bytes) {
  if (bytes.length < 24 || _formatFromMagicBytes(bytes) != 'png') return null;
  final view = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  // IHDR is the first chunk: length (8..11) + 'IHDR' (12..15) + w/h (16..23).
  if (view[12] != 0x49 ||
      view[13] != 0x48 ||
      view[14] != 0x44 ||
      view[15] != 0x52) {
    return null;
  }
  final data = ByteData.sublistView(view);
  final width = data.getUint32(16);
  final height = data.getUint32(20);
  if (width == 0 || height == 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

String _formatFromMagicBytes(List<int> bytes) {
  if (bytes.isEmpty) return '';
  final view = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  return switch (sniffClipboardImageMime(view)) {
    'image/png' => 'png',
    'image/jpeg' => 'jpeg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => '',
  };
}

/// Strict signatures for clipboard passthrough. Does not change
/// [sniffMimeFromBytes], which other MIME callers still use.
@visibleForTesting
String? sniffClipboardImageMime(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38 &&
      (bytes[4] == 0x37 || bytes[4] == 0x39) &&
      bytes[5] == 0x61) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

@visibleForTesting
Future<({Uint8List bytes, String format, bool converted})?>
prepareClipboardImageBytes({required Uint8List bytes}) async {
  final magic = _formatFromMagicBytes(bytes);
  if (_isSupportedClipboardFormat(magic)) {
    return (bytes: bytes, format: magic, converted: false);
  }

  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    debugClipboardImageCodecCalls += 1;
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final decode = computeViewerDecodePixels(
      logicalWidth: descriptor.width.toDouble(),
      logicalHeight: descriptor.height.toDouble(),
      devicePixelRatio: 1,
    );
    debugLastClipboardDecodeTarget = decode;
    codec = await descriptor.instantiateCodec(
      targetWidth: decode.width,
      targetHeight: decode.height,
    );
    final frame = await codec.getNextFrame();
    image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return (bytes: data.buffer.asUint8List(), format: 'png', converted: true);
  } catch (_) {
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

class _DisplayProviderEntry {
  const _DisplayProviderEntry({
    required this.width,
    required this.height,
    required this.provider,
  });

  final int width;
  final int height;
  final ImageProvider provider;
}

@visibleForTesting
int imageViewerDebugSizeListenerCount(State<ImageViewerPage> state) {
  return (state as _ImageViewerPageState).debugLiveImageSizeListenerCount;
}

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.draft,
    this.imageProviders = const <String, ImageProvider>{},
  });

  final List<String> images; // local paths, http urls, or data urls
  final int initialIndex;
  final ImageViewerDraftMode? draft;
  final Map<String, ImageProvider> imageProviders;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage>
    with TickerProviderStateMixin {
  late final PageController _controller;
  late int _index;
  late final AnimationController _restoreCtrl;
  late final List<TransformationController> _zoomCtrls;
  late final List<String> _images = List.of(widget.images);
  final Set<String> _failedImages = {};
  final Map<String, int> _reloadVersions = {};
  final Set<int> _qualityBusy = {};
  final Map<int, int> _qualityVersions = {};
  final Map<int, ImageUploadQuality> _pendingQuality = {};
  final Map<int, int> _pendingCustom = {};
  final Map<String, int> _fileSizes = {};
  bool _qualityPanelOpen = false;
  bool _openingEditor = false;
  Timer? _zoomBadgeTimer;
  bool _zoomBadgeVisible = false;
  bool get _currentFailed =>
      !_hasImages || _failedImages.contains(_images[_index]);
  late final List<GlobalKey> _imageFrameKeys;
  late final AnimationController _zoomCtrl;
  VoidCallback? _zoomTick;
  final Map<String, Size> _imageNaturalSizes = <String, Size>{};
  final Map<String, ImageStream> _imageSizeStreams = <String, ImageStream>{};
  final Map<String, ImageStreamListener> _imageSizeListeners =
      <String, ImageStreamListener>{};

  double _dragDy = 0.0; // current vertical drag offset
  double _bgOpacity = 1.0; // background dim opacity (0..1)
  bool _dragActive = false; // only when zoom ~ 1.0
  double _animFrom = 0.0; // for restore animation
  Offset? _lastDoubleTapPos; // focal point for double-tap zoom
  Offset? _lastTapPos; // local tap point for desktop image/background split
  bool _saving = false; // saving to gallery state
  bool _sharing = false; // sharing state
  bool _copying = false; // copying to clipboard state
  bool _chromeVisible = true;
  bool _currentImageZoomed = false;
  late final FocusNode _focusNode;
  final GlobalKey _viewerKey = GlobalKey();

  final Map<String, ImageProvider> _baseProviderCache =
      <String, ImageProvider>{};
  final Map<String, _DisplayProviderEntry> _displayProviderCache =
      <String, _DisplayProviderEntry>{};
  Color? _svgCurrentColor;

  @visibleForTesting
  int get debugLiveImageSizeListenerCount => _imageSizeListeners.length;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get _hasImages => _images.isNotEmpty;
  bool get _hasMultipleImages => _images.length > 1;
  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < _images.length - 1;
  TransformationController? get _currentZoomCtrl =>
      _hasImages && _index >= 0 && _index < _zoomCtrls.length
      ? _zoomCtrls[_index]
      : null;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(
      0,
      _images.isEmpty ? 0 : _images.length - 1,
    );
    _controller = PageController(initialPage: _index);
    _zoomCtrls = List<TransformationController>.generate(_images.length, (_) {
      final ctrl = TransformationController();
      ctrl.addListener(_handleZoomChanged);
      return ctrl;
    }, growable: false);
    _imageFrameKeys = List<GlobalKey>.generate(
      _images.length,
      (_) => GlobalKey(),
      growable: false,
    );
    _restoreCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          final t = Curves.easeOutCubic.transform(_restoreCtrl.value);
          setState(() {
            _dragDy = _animFrom * (1 - t);
            _bgOpacity = 1.0 - math.min(_dragDy / 300.0, 0.7);
          });
        });
    _zoomCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 230),
    );
    _focusNode = FocusNode(debugLabel: 'ImageViewerPage');
    _baseProviderCache.addAll(widget.imageProviders);
    if (widget.draft != null && _hasImages) unawaited(_readSize(_index));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = Theme.of(context).colorScheme.onSurface;
    if (_svgCurrentColor == color) return;
    _svgCurrentColor = color;
    // This also refreshes providers supplied by Markdown when opening a gallery.
    for (final source in _baseProviderCache.keys.toList()) {
      final provider = _baseProviderCache[source];
      if (provider is! SvgImageProvider || provider.currentColor == color) {
        continue;
      }
      _baseProviderCache[source] = SvgImageProvider(
        provider.source,
        currentColor: color,
      );
      _displayProviderCache.remove(source);
      final listener = _imageSizeListeners.remove(source);
      final stream = _imageSizeStreams.remove(source);
      if (listener != null) stream?.removeListener(listener);
    }
  }

  @override
  void dispose() {
    _zoomBadgeTimer?.cancel();
    if (!_isDesktop) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _controller.dispose();
    for (final c in _zoomCtrls) {
      c.removeListener(_handleZoomChanged);
      c.dispose();
    }
    for (final entry in _imageSizeListeners.entries) {
      _imageSizeStreams[entry.key]?.removeListener(entry.value);
    }
    _imageSizeListeners.clear();
    _imageSizeStreams.clear();
    _restoreCtrl.dispose();
    _zoomCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _animateZoomTo(
    TransformationController ctrl, {
    required double toScale,
    required double toTx,
    required double toTy,
  }) {
    _zoomCtrl.stop();
    if (_zoomTick != null) {
      _zoomCtrl.removeListener(_zoomTick!);
      _zoomTick = null;
    }
    final m = ctrl.value.clone();
    final fromScale = m.getMaxScaleOnAxis();
    final storage = m.storage;
    final fromTx = storage[12];
    final fromTy = storage[13];
    final curve = CurvedAnimation(
      parent: _zoomCtrl,
      curve: Curves.easeOutCubic,
    );
    _zoomTick = () {
      final t = curve.value;
      final s = fromScale + (toScale - fromScale) * t;
      final x = fromTx + (toTx - fromTx) * t;
      final y = fromTy + (toTy - fromTy) * t;
      ctrl.value = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..scaleByDouble(s, s, s, 1);
    };
    _zoomCtrl.addListener(_zoomTick!);
    _zoomCtrl.forward(from: 0);
  }

  void _toggleZoomAt(TransformationController ctrl, Offset focal) {
    final current = ctrl.value;
    final currentScale = current.getMaxScaleOnAxis();
    if (currentScale > 1.01) {
      _animateZoomTo(ctrl, toScale: 1.0, toTx: 0.0, toTy: 0.0);
      return;
    }

    final focalPoint = MatrixUtils.transformPoint(
      Matrix4.inverted(current),
      focal,
    );
    const targetScale = 2.35;
    final tx = focal.dx - targetScale * focalPoint.dx;
    final ty = focal.dy - targetScale * focalPoint.dy;
    _animateZoomTo(ctrl, toScale: targetScale, toTx: tx, toTy: ty);
  }

  void _toggleChrome() {
    if (_qualityPanelOpen) {
      setState(() => _qualityPanelOpen = false);
      return;
    }
    setState(() => _chromeVisible = !_chromeVisible);
    _syncSystemChrome();
  }

  void _syncSystemChrome() {
    if (!_isDesktop) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(
          _chromeVisible
              ? SystemUiMode.edgeToEdge
              : SystemUiMode.immersiveSticky,
        ),
      );
    }
  }

  bool _isZoomed(TransformationController ctrl) =>
      ctrl.value.getMaxScaleOnAxis() > 1.01;

  void _handleZoomChanged() {
    final ctrl = _currentZoomCtrl;
    if (ctrl == null) return;
    final zoomed = _isZoomed(ctrl);
    if (!mounted) return;
    setState(() {
      _currentImageZoomed = zoomed;
      if (zoomed) _chromeVisible = false;
      _zoomBadgeVisible = _isDesktop;
    });
    _syncSystemChrome();
    _zoomBadgeTimer?.cancel();
    _zoomBadgeTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _zoomBadgeVisible = false);
    });
  }

  void _markImageSizeChanged() {
    if (!mounted) return;
    switch (SchedulerBinding.instance.schedulerPhase) {
      case SchedulerPhase.idle:
      case SchedulerPhase.postFrameCallbacks:
        setState(() {});
        return;
      case SchedulerPhase.transientCallbacks:
      case SchedulerPhase.midFrameMicrotasks:
      case SchedulerPhase.persistentCallbacks:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return;
    }
  }

  void _rememberImageNaturalSize(String src, Size size, {bool notify = true}) {
    if (size.width <= 0 || size.height <= 0) return;
    final current = _imageNaturalSizes[src];
    if (current != null &&
        current.width == size.width &&
        current.height == size.height) {
      return;
    }
    _imageNaturalSizes[src] = size;
    if (notify) {
      _markImageSizeChanged();
    }
  }

  Size? _readImageSizeFromBytes(Uint8List bytes) =>
      _readPngSizeFromBytes(bytes);

  void _removeImageSizeListener(String src, ImageStreamListener listener) {
    if (!identical(_imageSizeListeners[src], listener)) return;
    _imageSizeStreams[src]?.removeListener(listener);
    _imageSizeStreams.remove(src);
    _imageSizeListeners.remove(src);
  }

  void _ensureImageNaturalSize(
    String src,
    ImageProvider provider, {
    ImageConfiguration configuration = ImageConfiguration.empty,
  }) {
    if (_imageNaturalSizes.containsKey(src) ||
        _imageSizeListeners.containsKey(src)) {
      return;
    }

    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        try {
          _rememberImageNaturalSize(
            src,
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
        } finally {
          info.dispose();
          _removeImageSizeListener(src, listener);
        }
      },
      onError: (_, _) {
        _removeImageSizeListener(src, listener);
      },
    );
    _imageSizeListeners[src] = listener;

    void attach() {
      if (!mounted) return;
      if (!identical(_imageSizeListeners[src], listener)) return;
      if (_imageNaturalSizes.containsKey(src)) {
        _imageSizeListeners.remove(src);
        return;
      }
      final stream = provider.resolve(configuration);
      _imageSizeStreams[src] = stream;
      stream.addListener(listener);
    }

    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => attach());
    } else {
      attach();
    }
  }

  Rect _imageTapRect({
    required int index,
    required String src,
    required Size pageSize,
    required EdgeInsets padding,
  }) {
    Rect fitInto({
      required Size outerSize,
      required Offset outerTopLeft,
      required Size sourceSize,
    }) {
      final fittedSource = sourceSize;
      final fitted = applyBoxFit(BoxFit.contain, fittedSource, outerSize);
      final outputSize = fitted.destination;
      return Rect.fromLTWH(
        outerTopLeft.dx + (outerSize.width - outputSize.width) / 2,
        outerTopLeft.dy + (outerSize.height - outputSize.height) / 2,
        outputSize.width,
        outputSize.height,
      );
    }

    Rect centeredSquare(Size outerSize, Offset outerTopLeft) {
      final side = math.min(outerSize.width, outerSize.height);
      return Rect.fromLTWH(
        outerTopLeft.dx + (outerSize.width - side) / 2,
        outerTopLeft.dy + (outerSize.height - side) / 2,
        side,
        side,
      );
    }

    final naturalSize = _imageNaturalSizes[src];
    final imageContext = _imageFrameKeys[index].currentContext;
    final viewerContext = _viewerKey.currentContext;
    final imageBox = imageContext?.findRenderObject();
    final viewerBox = viewerContext?.findRenderObject();
    if (imageBox is RenderBox &&
        imageBox.hasSize &&
        viewerBox is RenderBox &&
        viewerBox.hasSize) {
      final globalTopLeft = imageBox.localToGlobal(Offset.zero);
      final localTopLeft = viewerBox.globalToLocal(globalTopLeft);
      return localTopLeft & imageBox.size;
    }

    final contentSize = Size(
      math.max(0.0, pageSize.width - padding.horizontal),
      math.max(0.0, pageSize.height - padding.vertical),
    );
    final contentRect = padding.topLeft & contentSize;
    if (naturalSize == null) {
      return centeredSquare(contentSize, contentRect.topLeft);
    }

    return fitInto(
      outerSize: contentSize,
      outerTopLeft: contentRect.topLeft,
      sourceSize: naturalSize,
    );
  }

  Size _displaySizeFor({
    required int index,
    required String src,
    required Size availableSize,
  }) {
    if (availableSize.width <= 0 || availableSize.height <= 0) {
      return Size.zero;
    }

    final naturalSize = _imageNaturalSizes[src];
    if (naturalSize == null) {
      final side = math.min(availableSize.width, availableSize.height);
      return Size.square(side);
    }

    final fittedSource = naturalSize;
    return applyBoxFit(BoxFit.contain, fittedSource, availableSize).destination;
  }

  void _handleImageTap({
    required int index,
    required String src,
    required Size pageSize,
    required EdgeInsets padding,
  }) {
    if (_qualityPanelOpen || !_isDesktop) {
      _toggleChrome();
      return;
    }

    final tapPos = _lastTapPos;
    _lastTapPos = null;
    if (tapPos != null &&
        !_imageTapRect(
          index: index,
          src: src,
          pageSize: pageSize,
          padding: padding,
        ).contains(tapPos)) {
      Navigator.of(context).maybePop();
      return;
    }

    _toggleChrome();
  }

  void _resetDragState() {
    _dragDy = 0.0;
    _bgOpacity = 1.0;
    _dragActive = false;
  }

  void _goToIndex(int target) {
    if (!_hasImages) return;
    setState(() => _qualityPanelOpen = false);
    final next = target < 0
        ? 0
        : target >= _images.length
        ? _images.length - 1
        : target;
    if (next == _index) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _showPrevious() => _goToIndex(_index - 1);
  void _showNext() => _goToIndex(_index + 1);

  void _resetZoom() {
    final ctrl = _currentZoomCtrl;
    if (ctrl == null) return;
    _animateZoomTo(ctrl, toScale: 1.0, toTx: 0.0, toTy: 0.0);
  }

  void _zoomBy(double factor, {Offset? focal}) {
    final ctrl = _currentZoomCtrl;
    final viewerContext = _viewerKey.currentContext;
    if (ctrl == null || viewerContext == null) return;
    final size = viewerContext.size;
    if (size == null) return;

    final current = ctrl.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 5.0).toDouble();
    final viewportCenter = focal ?? size.center(Offset.zero);
    final focalPoint = MatrixUtils.transformPoint(
      Matrix4.inverted(current),
      viewportCenter,
    );
    final tx = viewportCenter.dx - targetScale * focalPoint.dx;
    final ty = viewportCenter.dy - targetScale * focalPoint.dy;
    _animateZoomTo(ctrl, toScale: targetScale, toTx: tx, toTy: ty);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        if (_qualityPanelOpen) {
          setState(() => _qualityPanelOpen = false);
          return KeyEventResult.handled;
        }
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _showPrevious();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        _showNext();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.numpadAdd:
        _zoomBy(1.25);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        _zoomBy(0.8);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        _resetZoom();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  ImageProvider _baseProviderFor(String src) {
    final cached = _baseProviderCache[src];
    if (cached != null) return cached;

    final provider = _createProviderFor(src);
    _baseProviderCache[src] = provider;
    return provider;
  }

  ImageProvider _displayProviderFor(
    String src, {
    required double logicalWidth,
    required double logicalHeight,
    required double devicePixelRatio,
  }) {
    final exact = computeViewerDecodePixels(
      logicalWidth: logicalWidth,
      logicalHeight: logicalHeight,
      devicePixelRatio: devicePixelRatio,
    );
    final cached = _displayProviderCache[src];
    if (cached != null &&
        canReuseViewerDisplayPixels(
          cachedWidth: cached.width,
          cachedHeight: cached.height,
          targetWidth: exact.width,
          targetHeight: exact.height,
        )) {
      return cached.provider;
    }
    final decode = quantizeViewerDecodePixels(
      width: exact.width,
      height: exact.height,
    );
    final provider = SafeResizeImage.display(
      _baseProviderFor(src),
      width: decode.width,
      height: decode.height,
      fit: SafeResizeFit.contain,
      allowUpscaling: false,
      maxEdge: kMaxViewerDecodeEdge,
      maxPixels: kMaxViewerDecodePixels,
    );
    _displayProviderCache[src] = _DisplayProviderEntry(
      width: decode.width,
      height: decode.height,
      provider: provider,
    );
    return provider;
  }

  ImageProvider _createProviderFor(String src) {
    if (isSvgImageSource(src)) {
      return SvgImageProvider(
        src,
        currentColor: Theme.of(context).colorScheme.onSurface,
      );
    }
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('data:')) {
      try {
        final base64Marker = 'base64,';
        final idx = src.indexOf(base64Marker);
        if (idx != -1) {
          final bytes = base64Decode(src.substring(idx + base64Marker.length));
          final size = _readImageSizeFromBytes(bytes);
          if (size != null) {
            _rememberImageNaturalSize(src, size, notify: false);
          }
          return MemoryImage(bytes);
        }
      } catch (_) {}
    }
    final fixed = SandboxPathResolver.fix(src);
    // Use a FileImage with a unique key per path so Hero tags remain stable
    return FileImage(File(fixed));
  }

  Future<Uint8List> _svgPngBytes(String src) {
    final provider = _baseProviderFor(src);
    return (provider is SvgImageProvider ? provider : SvgImageProvider(src))
        .pngBytes();
  }

  bool _canDragDismiss() {
    if (_index < 0 || _index >= _zoomCtrls.length) return true;
    final m = _zoomCtrls[_index].value;
    final s = m.getMaxScaleOnAxis();
    // Only allow when scale ~ 1 (not zooming)
    return (s >= 0.98 && s <= 1.02);
  }

  void _handleVerticalDragStart(DragStartDetails d) {
    _dragActive = _canDragDismiss();
    if (!_dragActive) return;
    _restoreCtrl.stop();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails d) {
    if (!_dragActive) return;
    final dy = d.delta.dy;
    if (dy <= 0 && _dragDy <= 0) return; // only handle downward
    setState(() {
      _dragDy = math.max(0.0, _dragDy + dy);
      _bgOpacity = 1.0 - math.min(_dragDy / 300.0, 0.7);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails d) {
    if (!_dragActive) return;
    _dragActive = false;
    final v = d.primaryVelocity ?? 0.0; // positive when swiping down
    const double dismissDistance = 140.0;
    const double dismissVelocity = 900.0;
    if (_dragDy > dismissDistance || v > dismissVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    // animate back
    _animFrom = _dragDy;
    _restoreCtrl
      ..reset()
      ..forward();
  }

  Future<void> _saveCurrent() async {
    if (_isDesktop) {
      await _saveCurrentDesktop();
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final src = _images[_index];
      Uint8List? bytes;

      if (isSvgImageSource(src)) {
        bytes = await _svgPngBytes(src);
      } else if (src.startsWith('data:')) {
        final marker = 'base64,';
        final idx = src.indexOf(marker);
        if (idx != -1) {
          bytes = base64Decode(src.substring(idx + marker.length));
        }
      } else if (src.startsWith('http://') || src.startsWith('https://')) {
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          bytes = resp.bodyBytes;
        } else {
          if (!mounted) return;
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageSaveFailed('HTTP ${resp.statusCode}'),
            type: NotificationType.error,
          );
          return;
        }
      } else {
        final local = SandboxPathResolver.fix(src);
        final file = File(local);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else {
          if (!mounted) return;
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageSaveFailed('file-missing'),
            type: NotificationType.error,
          );
          return;
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveFailed('empty-bytes'),
          type: NotificationType.error,
        );
        return;
      }

      final name = 'kelivo-${DateTime.now().millisecondsSinceEpoch}';
      final dynamic result;
      if (_formatFromMagicBytes(bytes) == 'gif') {
        // saveImage re-encodes as JPEG on Android and iOS, losing animation.
        final temp = await getTemporaryDirectory();
        final directory = await temp.createTemp('kelivo-image-save-');
        try {
          final file = File(p.join(directory.path, '$name.gif'));
          await file.writeAsBytes(bytes);
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            result = {
              'isSuccess': await NativeFileSave.saveImageToGallery(
                sourcePath: file.path,
              ),
            };
          } else {
            result = await ImageGallerySaverPlus.saveFile(
              file.path,
              name: name,
            );
          }
        } finally {
          await directory.delete(recursive: true);
        }
      } else {
        result = await ImageGallerySaverPlus.saveImage(
          bytes,
          quality: 100,
          name: name,
        );
      }
      bool success = false;
      if (result is Map) {
        final isSuccess =
            result['isSuccess'] == true || result['isSuccess'] == 1;
        final filePath = result['filePath'] ?? result['file_path'];
        success = isSuccess || (filePath is String && filePath.isNotEmpty);
      }

      if (!mounted) return;
      if (success) {
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveSuccess,
          type: NotificationType.success,
        );
      } else {
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveFailed('unknown'),
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveFailed(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareCurrent() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      // iPad requires a non-zero popover source rect within overlay coordinates
      Rect anchor;
      try {
        final overlay = Overlay.of(context);
        final ro = overlay.context.findRenderObject();
        if (ro is RenderBox && ro.hasSize) {
          final center = ro.size.center(Offset.zero);
          final global = ro.localToGlobal(center);
          anchor = Rect.fromCenter(center: global, width: 1, height: 1);
        } else {
          final size = MediaQuery.sizeOf(context);
          anchor = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 1,
            height: 1,
          );
        }
      } catch (_) {
        final size = MediaQuery.sizeOf(context);
        anchor = Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: 1,
          height: 1,
        );
      }
      final src = _images[_index];
      String? pathToSave;
      File? temp;
      if (isSvgImageSource(src)) {
        final bytes = await _svgPngBytes(src);
        final tmp = await getTemporaryDirectory();
        temp = await File(
          p.join(
            tmp.path,
            'kelivo_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        ).create(recursive: true);
        await temp.writeAsBytes(bytes);
        pathToSave = temp.path;
      } else if (src.startsWith('data:')) {
        final i = src.indexOf('base64,');
        if (i != -1) {
          final bytes = base64Decode(src.substring(i + 7));
          final tmp = await getTemporaryDirectory();
          temp = await File(
            p.join(
              tmp.path,
              'kelivo_${DateTime.now().millisecondsSinceEpoch}.png',
            ),
          ).create(recursive: true);
          await temp.writeAsBytes(bytes);
          pathToSave = temp.path;
        }
      } else if (src.startsWith('http')) {
        // Try download and share
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final tmp = await getTemporaryDirectory();
          final ext = p.extension(Uri.parse(src).path);
          temp = await File(
            p.join(
              tmp.path,
              'kelivo_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? ext : '.jpg'}',
            ),
          ).create(recursive: true);
          await temp.writeAsBytes(resp.bodyBytes);
          pathToSave = temp.path;
        } else {
          if (!mounted) return;
          // fallback to sharing url as text
          await SharePlus.instance.share(
            ShareParams(text: src, sharePositionOrigin: anchor),
          );
          return;
        }
      } else {
        final local = SandboxPathResolver.fix(src);
        final f = File(local);
        if (await f.exists()) {
          pathToSave = f.path;
        }
      }
      if (pathToSave == null) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageShareFailed('empty-source'),
          type: NotificationType.error,
        );
        return;
      }
      try {
        await SharePlus.instance.share(
          ShareParams(files: [XFile(pathToSave)], sharePositionOrigin: anchor),
        );
      } on MissingPluginException catch (_) {
        // Fallback: open system chooser by opening file
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageShareFailedOpenFile(res.message),
            type: NotificationType.error,
          );
        }
      } on PlatformException catch (_) {
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageShareFailedOpenFile(res.message),
            type: NotificationType.error,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageShareFailed(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _normalizeSuggestedName(String? name, String format) {
    final ext = format == 'jpeg' ? '.jpg' : '.$format';
    final fallback = 'image$ext';
    if (name == null || name.trim().isEmpty) return fallback;
    final trimmed = name.trim();
    if (p.extension(trimmed).toLowerCase() != ext) {
      return p.setExtension(trimmed, ext);
    }
    return trimmed;
  }

  Future<_CopyPayload?> _loadCopyPayload(
    void Function(String reason) setError,
  ) async {
    final src = _images[_index];
    Uint8List? bytes;
    String suggestedName = '';
    String? sourcePath;

    try {
      if (isSvgImageSource(src)) {
        bytes = await _svgPngBytes(src);
        suggestedName = 'image.png';
      } else if (src.startsWith('data:')) {
        final marker = 'base64,';
        final idx = src.indexOf(marker);
        if (idx != -1) {
          bytes = base64Decode(src.substring(idx + marker.length));
        }
        final format = detectClipboardImageFormat(
          bytes: bytes ?? const <int>[],
        );
        if (format.isNotEmpty) {
          suggestedName = 'image.${format == 'jpeg' ? 'jpg' : format}';
        }
      } else if (src.startsWith('http://') || src.startsWith('https://')) {
        final uri = Uri.parse(src);
        final resp = await http.get(uri);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          bytes = resp.bodyBytes;
          suggestedName = uri.pathSegments.isNotEmpty
              ? uri.pathSegments.last
              : '';
        } else {
          setError('http-${resp.statusCode}');
          return null;
        }
      } else {
        final local = SandboxPathResolver.fix(src);
        final file = File(local);
        if (await file.exists()) {
          sourcePath = file.path;
          bytes = await file.readAsBytes();
          suggestedName = p.basename(file.path);
        } else {
          setError('file-missing');
          return null;
        }
      }
    } catch (_) {
      setError('read-error');
      return null;
    }

    if (bytes == null || bytes.isEmpty) {
      setError('empty-bytes');
      return null;
    }

    final prepared = await prepareClipboardImageBytes(bytes: bytes);
    if (prepared == null || !_isSupportedClipboardFormat(prepared.format)) {
      setError('unsupported-format');
      return null;
    }

    suggestedName = _normalizeSuggestedName(suggestedName, prepared.format);

    return _CopyPayload(
      bytes: prepared.bytes,
      format: prepared.format,
      suggestedName: suggestedName,
      sourcePath: resolveClipboardFallbackSourcePath(
        sourcePath: sourcePath,
        converted: prepared.converted,
      ),
    );
  }

  Future<bool> _writeClipboardPayload(_CopyPayload payload) async {
    bool ok = false;
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard != null) {
        final item = DataWriterItem(suggestedName: payload.suggestedName);
        switch (payload.format) {
          case 'png':
            item.add(Formats.png(payload.bytes));
            break;
          case 'jpeg':
            item.add(Formats.jpeg(payload.bytes));
            break;
          case 'gif':
            item.add(Formats.gif(payload.bytes));
            break;
          case 'webp':
            item.add(Formats.webp(payload.bytes));
            break;
        }
        await clipboard.write([item]);
        ok = true;
      }
    } catch (_) {
      ok = false;
    }

    if (!ok) {
      try {
        String? path = payload.sourcePath;
        if (path == null) {
          final dir = await getTemporaryDirectory();
          final ext = payload.format == 'jpeg' ? '.jpg' : '.${payload.format}';
          path = p.join(
            dir.path,
            'kelivo_clip_${DateTime.now().millisecondsSinceEpoch}$ext',
          );
          await File(path).writeAsBytes(payload.bytes);
        }
        ok = await ClipboardImages.setImagePath(path);
      } catch (_) {
        ok = false;
      }
    }
    return ok;
  }

  Future<void> _copyCurrent() async {
    if (_copying) return;
    setState(() => _copying = true);
    final l10n = AppLocalizations.of(context)!;
    String failureReason = 'copy-failed';
    bool ok = false;

    try {
      final payload = await _loadCopyPayload(
        (reason) => failureReason = reason,
      );
      if (payload == null) {
        if (mounted) {
          showAppSnackBar(
            context,
            message: l10n.messageExportSheetExportFailed(failureReason),
            type: NotificationType.error,
          );
        }
        return;
      }

      if (_isDesktop) {
        ok = await _writeClipboardPayload(payload);
        if (!ok) {
          failureReason = 'clipboard-unavailable';
        }
      } else {
        failureReason = 'unsupported-platform';
      }
    } finally {
      if (mounted) setState(() => _copying = false);
    }

    if (!mounted) return;
    if (ok) {
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCopiedToClipboard,
        type: NotificationType.success,
      );
    } else {
      showAppSnackBar(
        context,
        message: l10n.messageExportSheetExportFailed(failureReason),
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.of(context);
    final size = media.size;
    final compact = size.width < 700;
    final topInset =
        media.padding.top + (_isDesktop && Platform.isMacOS ? 22 : 0);
    final chromeOpacity = _chromeVisible ? _bgOpacity.clamp(0.0, 1.0) : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: _bgOpacity),
                  ),
                ),
              ),
              if (_hasImages) _buildPagedImageStage(context),
              if (_zoomBadgeVisible)
                Positioned(
                  top: topInset + 14,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '${((_currentZoomCtrl?.value.getMaxScaleOnAxis() ?? 1) * 100).round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              _buildTopBar(
                context,
                topInset: topInset,
                opacity: chromeOpacity,
                counterLabel: l10n.imageViewerPageCounter(
                  _index + 1,
                  _images.length,
                ),
              ),
              if (_hasMultipleImages && !compact)
                _buildDesktopPageArrows(context, opacity: chromeOpacity),
              _buildActionChrome(
                context,
                compact: compact,
                bottomInset: media.padding.bottom,
                opacity: chromeOpacity,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagedImageStage(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: _currentImageZoomed
          ? null
          : _handleVerticalDragStart,
      onVerticalDragUpdate: _currentImageZoomed
          ? null
          : _handleVerticalDragUpdate,
      onVerticalDragEnd: _currentImageZoomed ? null : _handleVerticalDragEnd,
      child: PageView.builder(
        key: const ValueKey('image-viewer-page-view'),
        controller: _controller,
        physics: _currentImageZoomed
            ? const NeverScrollableScrollPhysics()
            : const PageScrollPhysics(),
        itemCount: _images.length,
        onPageChanged: (i) {
          setState(() {
            _index = i;
            _qualityPanelOpen = false;
            if (widget.draft != null) unawaited(_readSize(i));
            _chromeVisible = true;
            _currentImageZoomed = _isZoomed(_zoomCtrls[i]);
            _resetDragState();
          });
        },
        itemBuilder: _buildImagePage,
      ),
    );
  }

  Widget _buildImagePage(BuildContext context, int i) {
    final l10n = AppLocalizations.of(context)!;
    final src = _images[i];
    final translateY = (i == _index) ? _dragDy : 0.0;
    final pageScale = (i == _index)
        ? (1.0 - math.min(_dragDy / 800.0, 0.15))
        : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final pageSize = Size(constraints.maxWidth, constraints.maxHeight);
        final compact = constraints.maxWidth < 700;
        final padding = compact
            ? const EdgeInsets.symmetric(vertical: 82)
            : const EdgeInsets.fromLTRB(92, 82, 92, 106);
        final availableSize = Size(
          math.max(0.0, pageSize.width - padding.horizontal),
          math.max(0.0, pageSize.height - padding.vertical),
        );
        var logicalWidth = availableSize.width > 0
            ? availableSize.width
            : pageSize.width;
        var logicalHeight = availableSize.height > 0
            ? availableSize.height
            : pageSize.height;
        final provider = _displayProviderFor(
          src,
          logicalWidth: logicalWidth,
          logicalHeight: logicalHeight,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        _ensureImageNaturalSize(
          src,
          provider,
          configuration: createLocalImageConfiguration(context),
        );
        final image = Image(
          key: ValueKey((src, _reloadVersions[src] ?? 0)),
          image: provider,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  value: loadingProgress.expectedTotalBytes == null
                      ? null
                      : loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) {
            if (_failedImages.add(src)) _markImageSizeChanged();
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0x14ffffff),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Lucide.ImageOff,
                      color: Colors.white54,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.imageViewerPageImageLoadFailed,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  _GlassPillButton(
                    label: l10n.imageEditorRetry,
                    onTap: () => _retryImage(src),
                  ),
                ],
              ),
            );
          },
        );
        final displaySize = _displaySizeFor(
          index: i,
          src: src,
          availableSize: availableSize,
        );

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: pageScale,
            child: AnimatedBuilder(
              animation: _zoomCtrls[i],
              builder: (context, _) {
                final scale = _zoomCtrls[i].value.getMaxScaleOnAxis();
                final canPan = scale > 1.01;
                return Listener(
                  onPointerSignal: (event) {
                    if (_isDesktop && event is PointerScrollEvent) {
                      GestureBinding.instance.pointerSignalResolver.register(
                        event,
                        (_) => _zoomBy(
                          math.exp(-event.scrollDelta.dy / 400),
                          focal: event.localPosition,
                        ),
                      );
                    }
                  },
                  child: InteractiveViewer(
                    key: i == _index ? _viewerKey : null,
                    transformationController: _zoomCtrls[i],
                    minScale: 1.0,
                    maxScale: 5.0,
                    panEnabled: canPan,
                    scaleEnabled: true,
                    clipBehavior: compact ? Clip.hardEdge : Clip.none,
                    boundaryMargin: compact
                        ? EdgeInsets.zero
                        : canPan
                        ? const EdgeInsets.all(80)
                        : EdgeInsets.zero,
                    child: SizedBox.expand(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) =>
                            _lastTapPos = details.localPosition,
                        onTapCancel: () => _lastTapPos = null,
                        onDoubleTapDown: _failedImages.contains(src)
                            ? null
                            : (details) =>
                                  _lastDoubleTapPos = details.localPosition,
                        onTap: _failedImages.contains(src)
                            ? null
                            : () => _handleImageTap(
                                index: i,
                                src: src,
                                pageSize: pageSize,
                                padding: padding,
                              ),
                        onDoubleTap: _failedImages.contains(src)
                            ? null
                            : () {
                                final focal =
                                    _lastDoubleTapPos ??
                                    pageSize.center(Offset.zero);
                                _toggleZoomAt(_zoomCtrls[i], focal);
                                _lastDoubleTapPos = null;
                              },
                        child: Padding(
                          padding: padding,
                          child: Center(
                            child: SizedBox(
                              key: _imageFrameKeys[i],
                              width: displaySize.width,
                              height: displaySize.height,
                              child: Hero(
                                tag: widget.draft == null
                                    ? 'img:$src'
                                    : ('draft-image', i),
                                child: SizedBox.expand(
                                  child: Semantics(
                                    image: true,
                                    label: l10n.imageViewerPageImageLabel(
                                      i + 1,
                                      _images.length,
                                    ),
                                    child: Center(
                                      child: SizedBox(
                                        width: displaySize.width,
                                        height: displaySize.height,
                                        child: isSvgImageSource(src)
                                            ? ColoredBox(
                                                key: ValueKey(
                                                  'image-viewer-svg-surface-$i',
                                                ),
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.surface,
                                                child: image,
                                              )
                                            : image,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar(
    BuildContext context, {
    required double topInset,
    required double opacity,
    required String counterLabel,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      left: 16,
      right: 16,
      top: topInset + 10,
      child: IgnorePointer(
        ignoring: opacity <= 0.01,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          opacity: opacity.toDouble(),
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_hasMultipleImages)
                  Text(
                    counterLabel,
                    key: const ValueKey('image-viewer-counter'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .78),
                      fontSize: 13,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                Align(
                  alignment: _isDesktop
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDesktop && widget.draft != null) ...[
                        _editButton(),
                        const SizedBox(width: 10),
                      ],
                      _GlassCircleButton(
                        label: l10n.imageViewerPageCloseButton,
                        icon: Lucide.X,
                        size: 40,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
                if (!_isDesktop && widget.draft != null)
                  Align(alignment: Alignment.centerRight, child: _editButton()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPageArrows(
    BuildContext context, {
    required double opacity,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return IgnorePointer(
      ignoring: opacity <= 0.01,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        opacity: opacity.toDouble(),
        child: Stack(
          children: [
            Positioned(
              left: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GlassCircleButton(
                  label: l10n.imageViewerPagePreviousButton,
                  icon: Lucide.ChevronLeft,
                  onTap: _canGoPrevious ? _showPrevious : null,
                  size: 52,
                ),
              ),
            ),
            Positioned(
              right: 24,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GlassCircleButton(
                  label: l10n.imageViewerPageNextButton,
                  icon: Lucide.ChevronRight,
                  onTap: _canGoNext ? _showNext : null,
                  size: 52,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editButton() => _GlassPillButton(
    label: AppLocalizations.of(context)!.imageViewerPageEditButton,
    onTap: _openingEditor || _currentFailed || _qualityBusy.contains(_index)
        ? null
        : () async {
            setState(() => _openingEditor = true);
            try {
              final completed = await widget.draft!.onEdit(_index);
              if (completed && mounted) Navigator.of(context).pop();
            } finally {
              if (mounted) setState(() => _openingEditor = false);
            }
          },
  );

  Future<void> _readSize(int index) async {
    final src = _images[index];
    try {
      final size = await File(src).length();
      if (mounted) setState(() => _fileSizes[src] = size);
    } catch (_) {}
  }

  Future<void> _retryImage(String src) async {
    final provider = _displayProviderCache.remove(src)?.provider;
    final base = _baseProviderCache.remove(src);
    final listener = _imageSizeListeners.remove(src);
    final stream = _imageSizeStreams.remove(src);
    if (listener != null) stream?.removeListener(listener);
    _imageNaturalSizes.remove(src);
    await provider?.evict();
    await base?.evict();
    if (mounted) {
      setState(() {
        _failedImages.remove(src);
        _reloadVersions[src] = (_reloadVersions[src] ?? 0) + 1;
      });
    }
  }

  Future<void> _changeQuality(ImageUploadQuality quality, [int? custom]) async {
    final index = _index;
    final version = (_qualityVersions[index] ?? 0) + 1;
    _qualityVersions[index] = version;
    setState(() {
      _qualityBusy.add(index);
      _pendingQuality[index] = quality;
      if (custom != null) _pendingCustom[index] = custom;
    });
    try {
      final path = await widget.draft!.onQualityChanged(index, quality, custom);
      if (!mounted || _qualityVersions[index] != version) return;
      setState(() {
        final previousSize = _imageNaturalSizes[_images[index]];
        if (previousSize != null) _imageNaturalSizes[path] = previousSize;
        _images[index] = path;
        _zoomCtrls[index].value = Matrix4.identity();
      });
      await _readSize(index);
    } catch (_) {
      if (mounted && _qualityVersions[index] == version) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.imageEditorProcessFailed,
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted && _qualityVersions[index] == version) {
        setState(() {
          _qualityBusy.remove(index);
          _pendingQuality.remove(index);
          _pendingCustom.remove(index);
        });
      }
    }
  }

  String _sizeLabel() {
    final size = _fileSizes[_images[_index]];
    if (size == null) return '—';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).round()} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _filmstrip() => _hasMultipleImages
      ? SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _images.length; i++)
                GestureDetector(
                  onTap: () => _goToIndex(i),
                  child: Semantics(
                    button: true,
                    selected: i == _index,
                    label: AppLocalizations.of(
                      context,
                    )!.imageViewerPageImageLabel(i + 1, _images.length),
                    child: AnimatedContainer(
                      key: ValueKey('image-viewer-thumbnail-$i'),
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      width: i == _index ? 54 : 22,
                      height: 36,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: i == _index ? 1 : .55,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: _ViewerThumbnail(
                            key: ValueKey((
                              _images[i],
                              _reloadVersions[_images[i]] ?? 0,
                            )),
                            provider: SafeResizeImage.display(
                              _baseProviderFor(_images[i]),
                              width: 108,
                              height: 72,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        )
      : const SizedBox.shrink();

  Widget _qualityPanel() {
    final draft = widget.draft!, l = AppLocalizations.of(context)!;
    final selected = _pendingQuality[_index] ?? draft.qualityOf(_index);
    final custom = _pendingCustom[_index] ?? draft.customQualityOf(_index);
    final labels = [
      l.imageSettingsPageQualityOriginal,
      l.imageSettingsPageQualityHigh,
      l.imageSettingsPageQualityBalanced,
      l.imageSettingsPageQualitySaver,
      l.imageSettingsPageQualityCustom,
    ];
    final subtitles = [
      l.imageSettingsPageQualityOriginalSubtitle,
      l.imageSettingsPageQualityHighSubtitle,
      l.imageSettingsPageQualityBalancedSubtitle,
      l.imageSettingsPageQualitySaverSubtitle,
      '',
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _QualityChip(
                    label: labels[i],
                    selected: selected.index == i,
                    onTap: i == 0 && !draft.originalAvailable(_index)
                        ? null
                        : () => _changeQuality(
                            ImageUploadQuality.values[i],
                            custom,
                          ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: selected == ImageUploadQuality.custom
              ? SizedBox(
                  width: 260,
                  child: SfSliderTheme(
                    data: const SfSliderThemeData(
                      thumbRadius: 8,
                      activeTrackHeight: 2,
                      inactiveTrackHeight: 2,
                    ),
                    child: SfSlider(
                      min: 10.0,
                      max: 100.0,
                      stepSize: 5,
                      value: custom.toDouble(),
                      activeColor: const Color(0xff9aa8f0),
                      inactiveColor: Colors.white24,
                      onChanged: (value) => _changeQuality(
                        ImageUploadQuality.custom,
                        (value as double).round(),
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    subtitles[selected.index],
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildActionChrome(
    BuildContext context, {
    required bool compact,
    required double bottomInset,
    required double opacity,
  }) {
    if (!_hasImages) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final disabled = _currentFailed || _qualityBusy.contains(_index);
    Widget save() => _GlassCircleButton(
      size: 44,
      label: l.imageViewerPageSaveButton,
      icon: Lucide.Download,
      loading: _saving,
      onTap: disabled || _saving ? null : _saveCurrent,
    );
    Widget copy() => _GlassCircleButton(
      size: 44,
      label: l.imageViewerPageCopyButton,
      icon: Lucide.Copy,
      loading: _copying,
      onTap: disabled || _copying ? null : _copyCurrent,
    );
    Widget share() => _GlassCircleButton(
      size: 44,
      label: l.imageViewerPageShareButton,
      icon: Lucide.Share2,
      loading: _sharing,
      onTap: disabled || _sharing ? null : _shareCurrent,
    );
    final slot = AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: _qualityPanelOpen ? _qualityPanel() : _filmstrip(),
    );
    final size = Tooltip(
      message: l.imageViewerPageFileSize,
      child: _GlassPillButton(
        label: _sizeLabel(),
        small: true,
        loading: _qualityBusy.contains(_index),
        onTap: () => setState(() => _qualityPanelOpen = !_qualityPanelOpen),
      ),
    );
    return Positioned(
      left: 22,
      right: 22,
      bottom: math.max(bottomInset, 12),
      child: IgnorePointer(
        ignoring: opacity <= .01,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: opacity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (compact && widget.draft != null) ...[
                size,
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: compact ? 76 : 62,
                child: compact
                    ? Row(
                        children: [
                          if (!_qualityPanelOpen) save(),
                          Expanded(child: Center(child: slot)),
                          if (!_qualityPanelOpen && _isDesktop) ...[
                            copy(),
                            const SizedBox(width: 6),
                          ],
                          if (!_qualityPanelOpen) share(),
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 182,
                            ),
                            child: slot,
                          ),
                          if (widget.draft != null)
                            Align(alignment: Alignment.centerLeft, child: size),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _GlassPanel(
                              padding: const EdgeInsets.all(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  save(),
                                  const SizedBox(width: 8),
                                  if (_isDesktop) ...[
                                    copy(),
                                    const SizedBox(width: 8),
                                  ],
                                  share(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Desktop save: choose a location via file picker
  Future<void> _saveCurrentDesktop() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final src = _images[_index];
      Uint8List? bytes;
      String ext = '.jpg';

      if (isSvgImageSource(src)) {
        bytes = await _svgPngBytes(src);
        ext = '.png';
      } else if (src.startsWith('data:')) {
        final marker = 'base64,';
        final idx = src.indexOf(marker);
        if (idx != -1) {
          bytes = base64Decode(src.substring(idx + marker.length));
        }
        final mimeEnd = src.indexOf(';');
        if (mimeEnd != -1) {
          final mime = src.substring(5, mimeEnd);
          if (mime.contains('png')) {
            ext = '.png';
          } else if (mime.contains('jpeg') || mime.contains('jpg')) {
            ext = '.jpg';
          } else if (mime.contains('gif')) {
            ext = '.gif';
          } else if (mime.contains('webp')) {
            ext = '.webp';
          }
        }
      } else if (src.startsWith('http://') || src.startsWith('https://')) {
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          bytes = resp.bodyBytes;
          final urlExt = p.extension(Uri.parse(src).path);
          if (urlExt.isNotEmpty) ext = urlExt;
        } else {
          if (!mounted) return;
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageSaveFailed('HTTP ${resp.statusCode}'),
            type: NotificationType.error,
          );
          return;
        }
      } else {
        final local = SandboxPathResolver.fix(src);
        final file = File(local);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
          final pathExt = p.extension(local);
          if (pathExt.isNotEmpty) ext = pathExt;
        } else {
          if (!mounted) return;
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageSaveFailed('file-missing'),
            type: NotificationType.error,
          );
          return;
        }
      }

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveFailed('empty-bytes'),
          type: NotificationType.error,
        );
        return;
      }

      final defaultName = 'kelivo-${DateTime.now().millisecondsSinceEpoch}$ext';
      final allowed = [ext.replaceFirst('.', '').toLowerCase()];
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.imageViewerPageSaveButton,
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: allowed,
      );
      if (savePath == null) {
        // user cancelled
        return;
      }
      try {
        await File(savePath).parent.create(recursive: true);
        await File(savePath).writeAsBytes(bytes);
      } catch (e) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          message: l10n.imageViewerPageSaveFailed(e.toString()),
          type: NotificationType.error,
        );
        return;
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveSuccess,
        type: NotificationType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: l10n.imageViewerPageSaveFailed(e.toString()),
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CopyPayload {
  _CopyPayload({
    required this.bytes,
    required this.format,
    required this.suggestedName,
    this.sourcePath,
  });

  final Uint8List bytes;
  final String format; // png/jpeg/gif/webp
  final String suggestedName;
  final String? sourcePath;
}

class _GlassCircleButton extends StatefulWidget {
  const _GlassCircleButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
    this.size = 48,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final double size;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onTap == null;
    final Color baseFill = Colors.white.withValues(
      alpha: disabled ? 0.09 : 0.16,
    );
    final Color border = Colors.white.withValues(alpha: disabled ? 0.18 : 0.30);
    final double overlay = disabled
        ? 0
        : _pressed
        ? 0.10
        : _hovered
        ? 0.06
        : 0;
    final Color fill = Color.lerp(
      baseFill,
      Colors.white,
      overlay,
    )!.withValues(alpha: baseFill.a + overlay);
    final content = widget.loading
        ? SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2.1,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withValues(alpha: disabled ? 0.52 : 0.92),
              ),
            ),
          )
        : Icon(
            widget.icon,
            color: Colors.white.withValues(alpha: disabled ? 0.48 : 0.92),
            size: 20,
          );

    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        enabled: !disabled,
        label: widget.label,
        child: MouseRegion(
          cursor: disabled ? MouseCursor.defer : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) {
            setState(() {
              _hovered = false;
              _pressed = false;
            });
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: disabled ? null : (_) => _setPressed(true),
            onTapUp: disabled ? null : (_) => _setPressed(false),
            onTapCancel: disabled ? null : () => _setPressed(false),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              scale: _pressed ? 0.94 : 1.0,
              child: ClipOval(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(color: border, width: 0.7),
                    ),
                    child: Center(child: content),
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.26),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 0.7,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({
    required this.label,
    this.onTap,
    this.small = false,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool small, loading;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: label,
    child: MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: small ? 30 : 40,
              padding: EdgeInsets.symmetric(horizontal: small ? 12 : 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .16),
                border: Border.all(color: Colors.white30, width: .7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  Text(
                    label,
                    style: TextStyle(
                      color: onTap == null ? Colors.white38 : Colors.white,
                      fontSize: small ? 13 : 15,
                      fontWeight: AppFontWeights.semibold,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  if (small)
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(
                        Lucide.ChevronDown,
                        color: Colors.white54,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _QualityChip extends StatelessWidget {
  const _QualityChip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: onTap == null
                ? Colors.white24
                : selected
                ? Colors.black
                : Colors.white70,
          ),
        ),
      ),
    ),
  );
}

/// A filmstrip must not pin the full-resolution image streams in memory.
/// Rasterize one frame at thumbnail size and release the provider listener.
class _ViewerThumbnail extends StatefulWidget {
  const _ViewerThumbnail({super.key, required this.provider});
  final ImageProvider provider;
  @override
  State<_ViewerThumbnail> createState() => _ViewerThumbnailState();
}

class _ViewerThumbnailState extends State<_ViewerThumbnail> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  int _generation = 0;
  bool _failed = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ViewerThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) _load();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _listener = null;
    _stream = null;
  }

  void _load() {
    _detach();
    final generation = ++_generation;
    _stream = widget.provider.resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) async {
        _detach();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final source = info.image;
        final size = applyBoxFit(
          BoxFit.cover,
          Size(source.width.toDouble(), source.height.toDouble()),
          const Size(108, 72),
        );
        canvas.drawImageRect(
          source,
          Alignment.center.inscribe(
            size.source,
            Rect.fromLTWH(
              0,
              0,
              source.width.toDouble(),
              source.height.toDouble(),
            ),
          ),
          const Rect.fromLTWH(0, 0, 108, 72),
          Paint()..filterQuality = FilterQuality.low,
        );
        final picture = recorder.endRecording();
        ui.Image? result;
        try {
          result = await picture.toImage(108, 72);
        } finally {
          picture.dispose();
          info.dispose();
        }
        if (!mounted || generation != _generation) {
          result.dispose();
          return;
        }
        final previous = _image;
        setState(() {
          _image = result;
          _failed = false;
        });
        previous?.dispose();
      },
      onError: (_, _) {
        _detach();
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _generation++;
    _detach();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _failed
      ? const Icon(Lucide.ImageOff, color: Colors.white54, size: 18)
      : RawImage(image: _image, fit: BoxFit.cover);
}

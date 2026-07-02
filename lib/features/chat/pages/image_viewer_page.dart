import 'dart:convert';
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
import '../../../icons/lucide_adapter.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/clipboard_images.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../l10n/app_localizations.dart';
import 'package:Cuplivo/theme/app_font_weights.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.imageProviders = const <String, ImageProvider>{},
  });

  final List<String> images; // local paths, http urls, or data urls
  final int initialIndex;
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
  late final List<_ImageDisplayTransform> _displayTransforms;
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

  final Map<String, ImageProvider> _imageProviderCache =
      <String, ImageProvider>{};

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  bool get _hasImages => widget.images.isNotEmpty;
  bool get _hasMultipleImages => widget.images.length > 1;
  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < widget.images.length - 1;
  TransformationController? get _currentZoomCtrl =>
      _hasImages && _index >= 0 && _index < _zoomCtrls.length
      ? _zoomCtrls[_index]
      : null;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(
      0,
      widget.images.isEmpty ? 0 : widget.images.length - 1,
    );
    _controller = PageController(initialPage: _index);
    _zoomCtrls = List<TransformationController>.generate(widget.images.length, (
      _,
    ) {
      final ctrl = TransformationController();
      ctrl.addListener(_handleZoomChanged);
      return ctrl;
    }, growable: false);
    _displayTransforms = List<_ImageDisplayTransform>.generate(
      widget.images.length,
      (_) => const _ImageDisplayTransform(),
      growable: false,
    );
    _imageFrameKeys = List<GlobalKey>.generate(
      widget.images.length,
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
    _imageProviderCache.addAll(widget.imageProviders);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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
    setState(() => _chromeVisible = !_chromeVisible);
  }

  void _updateCurrentDisplayTransform(
    _ImageDisplayTransform Function(_ImageDisplayTransform current) update,
  ) {
    if (!_hasImages || _index < 0 || _index >= _displayTransforms.length) {
      return;
    }
    setState(() {
      _displayTransforms[_index] = update(_displayTransforms[_index]);
    });
  }

  void _flipCurrentHorizontally() {
    _updateCurrentDisplayTransform(
      (current) => current.copyWith(flipX: !current.flipX),
    );
  }

  void _flipCurrentVertically() {
    _updateCurrentDisplayTransform(
      (current) => current.copyWith(flipY: !current.flipY),
    );
  }

  void _rotateCurrentLeft() {
    _updateCurrentDisplayTransform(
      (current) => current.copyWith(quarterTurns: current.quarterTurns - 1),
    );
  }

  void _rotateCurrentRight() {
    _updateCurrentDisplayTransform(
      (current) => current.copyWith(quarterTurns: current.quarterTurns + 1),
    );
  }

  bool _isZoomed(TransformationController ctrl) =>
      ctrl.value.getMaxScaleOnAxis() > 1.01;

  void _handleZoomChanged() {
    final ctrl = _currentZoomCtrl;
    if (ctrl == null) return;
    final zoomed = _isZoomed(ctrl);
    if (zoomed == _currentImageZoomed) return;
    if (!mounted) {
      _currentImageZoomed = zoomed;
      return;
    }
    setState(() => _currentImageZoomed = zoomed);
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

  Size? _readImageSizeFromBytes(Uint8List bytes) {
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      final data = ByteData.sublistView(bytes);
      return Size(data.getUint32(16).toDouble(), data.getUint32(20).toDouble());
    }
    return null;
  }

  void _ensureImageNaturalSize(String src, ImageProvider provider) {
    if (_imageNaturalSizes.containsKey(src) ||
        _imageSizeListeners.containsKey(src)) {
      return;
    }

    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        _rememberImageNaturalSize(
          src,
          Size(info.image.width.toDouble(), info.image.height.toDouble()),
        );
      },
      onError: (_, _) {
        stream.removeListener(listener);
        _imageSizeStreams.remove(src);
        _imageSizeListeners.remove(src);
      },
    );
    _imageSizeStreams[src] = stream;
    _imageSizeListeners[src] = listener;
    stream.addListener(listener);
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
      final transform = _displayTransforms[index];
      final fittedSource = transform.quarterTurns.isOdd
          ? Size(sourceSize.height, sourceSize.width)
          : sourceSize;
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

    final transform = _displayTransforms[index];
    final fittedSource = transform.isOddQuarterTurn
        ? Size(naturalSize.height, naturalSize.width)
        : naturalSize;
    return applyBoxFit(BoxFit.contain, fittedSource, availableSize).destination;
  }

  Size _imageBoxSizeFor({required int index, required Size displaySize}) {
    if (_displayTransforms[index].isOddQuarterTurn) {
      return Size(displaySize.height, displaySize.width);
    }
    return displaySize;
  }

  void _handleImageTap({
    required int index,
    required String src,
    required Size pageSize,
    required EdgeInsets padding,
  }) {
    if (!_isDesktop) {
      Navigator.of(context).maybePop();
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
    final next = target < 0
        ? 0
        : target >= widget.images.length
        ? widget.images.length - 1
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

  void _zoomBy(double factor) {
    final ctrl = _currentZoomCtrl;
    final viewerContext = _viewerKey.currentContext;
    if (ctrl == null || viewerContext == null) return;
    final size = viewerContext.size;
    if (size == null) return;

    final current = ctrl.value.clone();
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(1.0, 5.0).toDouble();
    final viewportCenter = size.center(Offset.zero);
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

  ImageProvider _providerFor(String src) {
    final cached = _imageProviderCache[src];
    if (cached != null) return cached;

    final provider = _createProviderFor(src);
    _imageProviderCache[src] = provider;
    return provider;
  }

  ImageProvider _createProviderFor(String src) {
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
      final src = widget.images[_index];
      Uint8List? bytes;

      if (src.startsWith('data:')) {
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
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
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
      final src = widget.images[_index];
      String? pathToSave;
      File? temp;
      if (src.startsWith('data:')) {
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

  String _inferFormatFromHint(String hint) {
    final lower = hint.toLowerCase();
    if (lower.contains('png')) return 'png';
    if (lower.contains('jpeg') || lower.contains('jpg')) return 'jpeg';
    if (lower.contains('gif')) return 'gif';
    if (lower.contains('webp')) return 'webp';
    return '';
  }

  bool _isSupportedClipboardFormat(String format) {
    return format == 'png' ||
        format == 'jpeg' ||
        format == 'gif' ||
        format == 'webp';
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
    final src = widget.images[_index];
    Uint8List? bytes;
    String format = '';
    String suggestedName = '';
    String? sourcePath;

    try {
      if (src.startsWith('data:')) {
        final marker = 'base64,';
        final idx = src.indexOf(marker);
        if (idx != -1) {
          bytes = base64Decode(src.substring(idx + marker.length));
        }
        final mimeEnd = src.indexOf(';');
        if (mimeEnd != -1) {
          final mime = src.substring(5, mimeEnd);
          final fmt = _inferFormatFromHint(mime);
          if (fmt.isNotEmpty) format = fmt;
        }
        if (format.isNotEmpty) {
          suggestedName = 'image.${format == 'jpeg' ? 'jpg' : format}';
        }
      } else if (src.startsWith('http://') || src.startsWith('https://')) {
        final uri = Uri.parse(src);
        final resp = await http.get(uri);
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          bytes = resp.bodyBytes;
          final urlExt = p.extension(uri.path);
          final fmt = _inferFormatFromHint(urlExt);
          if (fmt.isNotEmpty) format = fmt;
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
          final ext = p.extension(file.path);
          final fmt = _inferFormatFromHint(ext);
          if (fmt.isNotEmpty) format = fmt;
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

    Uint8List safeBytes = bytes;

    if (!_isSupportedClipboardFormat(format)) {
      try {
        final codec = await ui.instantiateImageCodec(safeBytes);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data != null) {
          safeBytes = data.buffer.asUint8List();
          format = 'png';
        }
      } catch (_) {}
      if (!_isSupportedClipboardFormat(format)) {
        setError('unsupported-format');
        return null;
      }
    }

    suggestedName = _normalizeSuggestedName(suggestedName, format);

    return _CopyPayload(
      bytes: safeBytes,
      format: format,
      suggestedName: suggestedName,
      sourcePath: sourcePath,
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
              _buildTopBar(
                context,
                topInset: topInset,
                opacity: chromeOpacity,
                counterLabel: l10n.imageViewerPageCounter(
                  _index + 1,
                  widget.images.length,
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
        itemCount: widget.images.length,
        onPageChanged: (i) {
          setState(() {
            _index = i;
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
    final src = widget.images[i];
    final provider = _providerFor(src);
    _ensureImageNaturalSize(src, provider);
    final image = Image(
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
      errorBuilder: (_, __, ___) => Semantics(
        image: true,
        label: l10n.imageViewerPageImageLoadFailed,
        child: Icon(
          Lucide.ImageOff,
          color: Colors.white.withValues(alpha: 0.72),
          size: 64,
        ),
      ),
    );
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
        final displaySize = _displaySizeFor(
          index: i,
          src: src,
          availableSize: availableSize,
        );
        final imageBoxSize = _imageBoxSizeFor(
          index: i,
          displaySize: displaySize,
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
                return InteractiveViewer(
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
                      onDoubleTapDown: (details) =>
                          _lastDoubleTapPos = details.localPosition,
                      onTap: () => _handleImageTap(
                        index: i,
                        src: src,
                        pageSize: pageSize,
                        padding: padding,
                      ),
                      onDoubleTap: () {
                        final focal =
                            _lastDoubleTapPos ?? pageSize.center(Offset.zero);
                        _toggleZoomAt(_zoomCtrls[i], focal);
                        _lastDoubleTapPos = null;
                        if (!_chromeVisible) {
                          setState(() => _chromeVisible = true);
                        }
                      },
                      child: Padding(
                        padding: padding,
                        child: Center(
                          child: SizedBox(
                            key: _imageFrameKeys[i],
                            width: displaySize.width,
                            height: displaySize.height,
                            child: Hero(
                              tag: 'img:$src',
                              child: SizedBox.expand(
                                child: Semantics(
                                  image: true,
                                  label: l10n.imageViewerPageImageLabel(
                                    i + 1,
                                    widget.images.length,
                                  ),
                                  child: Center(
                                    child: _AnimatedImageDisplayTransform(
                                      transformKey: ValueKey(
                                        'image-viewer-display-transform-$i',
                                      ),
                                      transform: _displayTransforms[i],
                                      child: SizedBox(
                                        width: imageBoxSize.width,
                                        height: imageBoxSize.height,
                                        child: image,
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
          child: Row(
            children: [
              _GlassCircleButton(
                label: l10n.imageViewerPageCloseButton,
                icon: Lucide.X,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const Spacer(),
              if (_hasImages)
                _GlassLabel(
                  key: const ValueKey('image-viewer-counter'),
                  label: counterLabel,
                ),
            ],
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

  Widget _buildActionChrome(
    BuildContext context, {
    required bool compact,
    required double bottomInset,
    required double opacity,
  }) {
    if (!_hasImages) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final actions = <Widget>[
      _GlassCircleButton(
        label: l10n.imageViewerPageSaveButton,
        icon: Lucide.Download,
        loading: _saving,
        onTap: _saving ? null : _saveCurrent,
      ),
      if (_isDesktop)
        _GlassCircleButton(
          label: l10n.imageViewerPageCopyButton,
          icon: Lucide.Copy,
          loading: _copying,
          onTap: _copying ? null : _copyCurrent,
        ),
      _GlassCircleButton(
        label: l10n.imageViewerPageShareButton,
        icon: Lucide.Share2,
        loading: _sharing,
        onTap: _sharing ? null : _shareCurrent,
      ),
      const _GlassDivider(),
      _GlassCircleButton(
        label: l10n.imageViewerPageFlipHorizontalButton,
        icon: Lucide.FlipHorizontal2,
        onTap: _flipCurrentHorizontally,
      ),
      _GlassCircleButton(
        label: l10n.imageViewerPageFlipVerticalButton,
        icon: Lucide.FlipVertical2,
        onTap: _flipCurrentVertically,
      ),
      _GlassCircleButton(
        label: l10n.imageViewerPageRotateLeftButton,
        icon: Lucide.RotateCcw,
        onTap: _rotateCurrentLeft,
      ),
      _GlassCircleButton(
        label: l10n.imageViewerPageRotateRightButton,
        icon: Lucide.RotateCw,
        onTap: _rotateCurrentRight,
      ),
      if (!compact) ...[
        const _GlassDivider(),
        _GlassCircleButton(
          label: l10n.imageViewerPageZoomOutButton,
          icon: Lucide.ZoomOut,
          onTap: () => _zoomBy(0.8),
        ),
        _GlassCircleButton(
          label: l10n.imageViewerPageResetZoomButton,
          icon: Lucide.RotateCcw,
          onTap: _resetZoom,
        ),
        _GlassCircleButton(
          label: l10n.imageViewerPageZoomInButton,
          icon: Lucide.ZoomIn,
          onTap: () => _zoomBy(1.25),
        ),
      ],
    ];

    return Positioned(
      left: 16,
      right: 16,
      bottom: math.max(bottomInset, 12) + (compact ? 10 : 18),
      child: IgnorePointer(
        ignoring: opacity <= 0.01,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          opacity: opacity.toDouble(),
          child: Center(
            child: _GlassPanel(
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: compact
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions
                      .expand((child) sync* {
                        if (child != actions.first) {
                          yield SizedBox(width: compact ? 8 : 10);
                        }
                        yield child;
                      })
                      .toList(growable: false),
                ),
              ),
            ),
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
      final src = widget.images[_index];
      Uint8List? bytes;
      String ext = '.jpg';

      if (src.startsWith('data:')) {
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

class _ImageDisplayTransform {
  const _ImageDisplayTransform({
    this.flipX = false,
    this.flipY = false,
    this.quarterTurns = 0,
  });

  final bool flipX;
  final bool flipY;
  final int quarterTurns;

  bool get isOddQuarterTurn => quarterTurns.isOdd;

  _ImageDisplayTransform copyWith({
    bool? flipX,
    bool? flipY,
    int? quarterTurns,
  }) {
    return _ImageDisplayTransform(
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      quarterTurns: quarterTurns ?? this.quarterTurns,
    );
  }

  Matrix4 toMatrix() {
    return toPoseNear(0).toMatrix();
  }

  _ImageDisplayPose toPoseNear(double angle) {
    final baseAngle = (quarterTurns % 4) * math.pi / 2;
    final nearestFullTurns = ((angle - baseAngle) / (math.pi * 2)).round();
    return _ImageDisplayPose(
      angle: baseAngle + nearestFullTurns * math.pi * 2,
      scaleX: flipX ? -1.0 : 1.0,
      scaleY: flipY ? -1.0 : 1.0,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _ImageDisplayTransform &&
        other.flipX == flipX &&
        other.flipY == flipY &&
        other.quarterTurns == quarterTurns;
  }

  @override
  int get hashCode => Object.hash(flipX, flipY, quarterTurns);
}

class _ImageDisplayPose {
  const _ImageDisplayPose({
    required this.angle,
    required this.scaleX,
    required this.scaleY,
  });

  final double angle;
  final double scaleX;
  final double scaleY;

  Matrix4 toMatrix() {
    return Matrix4.identity()
      ..rotateZ(angle)
      ..scaleByDouble(scaleX, scaleY, 1.0, 1.0);
  }
}

class _AnimatedImageDisplayTransform extends StatefulWidget {
  const _AnimatedImageDisplayTransform({
    required this.transformKey,
    required this.transform,
    required this.child,
  });

  final Key transformKey;
  final _ImageDisplayTransform transform;
  final Widget child;

  @override
  State<_AnimatedImageDisplayTransform> createState() =>
      _AnimatedImageDisplayTransformState();
}

class _AnimatedImageDisplayTransformState
    extends State<_AnimatedImageDisplayTransform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _angle;
  late Animation<double> _scaleX;
  late Animation<double> _scaleY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    final pose = widget.transform.toPoseNear(0);
    _setAnimations(pose, pose);
  }

  @override
  void didUpdateWidget(covariant _AnimatedImageDisplayTransform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transform == widget.transform) return;
    final current = _currentPose;
    final target = widget.transform.toPoseNear(current.angle);
    _setAnimations(current, target);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _ImageDisplayPose get _currentPose {
    return _ImageDisplayPose(
      angle: _angle.value,
      scaleX: _scaleX.value,
      scaleY: _scaleY.value,
    );
  }

  Animation<double> _animateDouble(double begin, double end) {
    return Tween<double>(
      begin: begin,
      end: end,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller);
  }

  void _setAnimations(_ImageDisplayPose begin, _ImageDisplayPose end) {
    _angle = _animateDouble(begin.angle, end.angle);
    _scaleX = _animateDouble(begin.scaleX, end.scaleX);
    _scaleY = _animateDouble(begin.scaleY, end.scaleY);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    final reduceMotion =
        (media?.disableAnimations ?? false) ||
        (media?.accessibleNavigation ?? false);
    if (reduceMotion) {
      return Transform(
        key: widget.transformKey,
        alignment: Alignment.center,
        transform: widget.transform.toPoseNear(_angle.value).toMatrix(),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return Transform(
          key: widget.transformKey,
          alignment: Alignment.center,
          transform: _currentPose.toMatrix(),
          child: child,
        );
      },
    );
  }
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

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.86),
          fontSize: 13,
          fontWeight: AppFontWeights.semibold,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 24,
      child: ColoredBox(color: Colors.white.withValues(alpha: 0.16)),
    );
  }
}

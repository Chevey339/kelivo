import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/clipboard_images.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../l10n/app_localizations.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({super.key, required this.images, this.initialIndex = 0});

  final List<String> images; // local paths, http urls, or data urls
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> with TickerProviderStateMixin {
  late final PageController _controller;
  late int _index;
  late final AnimationController _restoreCtrl;
  late final List<TransformationController> _zoomCtrls;
  late final AnimationController _zoomCtrl;
  VoidCallback? _zoomTick;

  double _dragDy = 0.0; // current vertical drag offset
  double _bgOpacity = 1.0; // background dim opacity (0..1)
  bool _dragActive = false; // only when zoom ~ 1.0
  double _animFrom = 0.0; // for restore animation
  Offset? _lastDoubleTapPos; // focal point for double-tap zoom
  bool _saving = false; // saving to gallery state
  bool _copying = false; // copying to clipboard state
  final GlobalKey _viewerKey = GlobalKey();
  final GlobalKey _saveBtnKey = GlobalKey();
  final GlobalKey _shareBtnKey = GlobalKey();
  final GlobalKey _copyBtnKey = GlobalKey();

  final Map<String, _SampledImage> _samples = <String, _SampledImage>{};

  bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.isEmpty ? 0 : widget.images.length - 1);
    _controller = PageController(initialPage: _index);
    _zoomCtrls = List<TransformationController>.generate(
      widget.images.length,
      (_) => TransformationController(),
      growable: false,
    );
    _restoreCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_restoreCtrl.value);
        setState(() {
          _dragDy = _animFrom * (1 - t);
          _bgOpacity = 1.0 - math.min(_dragDy / 300.0, 0.7);
        });
      });
    _zoomCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 230));

    // prepare sample for initial image
    _prepareSampleForIndex(_index);
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final c in _zoomCtrls) { c.dispose(); }
    _restoreCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  void _animateZoomTo(TransformationController ctrl, {
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
    final curve = CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeOutCubic);
    _zoomTick = () {
      final t = curve.value;
      final s = fromScale + (toScale - fromScale) * t;
      final x = fromTx + (toTx - fromTx) * t;
      final y = fromTy + (toTy - fromTy) * t;
      ctrl.value = Matrix4.identity()
        ..translate(x, y)
        ..scale(s);
    };
    _zoomCtrl.addListener(_zoomTick!);
    _zoomCtrl.forward(from: 0);
  }

  ImageProvider _providerFor(String src) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('data:')) {
      try {
        final base64Marker = 'base64,';
        final idx = src.indexOf(base64Marker);
        if (idx != -1) {
          final b64 = src.substring(idx + base64Marker.length);
          return MemoryImage(base64Decode(b64));
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

  void _goToPreviousImage() {
    if (_index > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextImage() {
    if (_index < widget.images.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
      final result = await ImageGallerySaverPlus.saveImage(bytes, quality: 100, name: name);
      bool success = false;
      if (result is Map) {
        final isSuccess = result['isSuccess'] == true || result['isSuccess'] == 1;
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
    final l10n = AppLocalizations.of(context)!;
    try {
      // iPad requires a non-zero popover source rect within overlay coordinates
      Rect anchor;
      try {
        final overlay = Overlay.of(context);
        final ro = overlay?.context.findRenderObject();
        if (ro is RenderBox && ro.hasSize) {
          final center = ro.size.center(Offset.zero);
          final global = ro.localToGlobal(center);
          anchor = Rect.fromCenter(center: global, width: 1, height: 1);
        } else {
          final size = MediaQuery.sizeOf(context);
          anchor = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
        }
      } catch (_) {
        final size = MediaQuery.sizeOf(context);
        anchor = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
      }
      final src = widget.images[_index];
      String? pathToSave;
      File? temp;
      if (src.startsWith('data:')) {
        final i = src.indexOf('base64,');
        if (i != -1) {
          final bytes = base64Decode(src.substring(i + 7));
          final tmp = await getTemporaryDirectory();
          temp = await File(p.join(tmp.path, 'kelivo_${DateTime.now().millisecondsSinceEpoch}.png')).create(recursive: true);
          await temp.writeAsBytes(bytes);
          pathToSave = temp.path;
        }
      } else if (src.startsWith('http')) {
        // Try download and share
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final tmp = await getTemporaryDirectory();
          final ext = p.extension(Uri.parse(src).path);
          temp = await File(p.join(tmp.path, 'kelivo_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? ext : '.jpg'}')).create(recursive: true);
          await temp.writeAsBytes(resp.bodyBytes);
          pathToSave = temp.path;
        } else {
          if (!mounted) return;
          // fallback to sharing url as text
          await Share.share(src, sharePositionOrigin: anchor);
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
        await Share.share('', sharePositionOrigin: anchor);
        return;
      }
      try {
        await Share.shareXFiles([XFile(pathToSave)], sharePositionOrigin: anchor);
      } on MissingPluginException catch (_) {
        // Fallback: open system chooser by opening file
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageShareFailedOpenFile(res.message ?? res.type.name),
            type: NotificationType.error,
          );
        }
      } on PlatformException catch (_) {
        final res = await OpenFilex.open(pathToSave);
        if (!mounted) return;
        if (res.type != ResultType.done) {
          showAppSnackBar(
            context,
            message: l10n.imageViewerPageShareFailedOpenFile(res.message ?? res.type.name),
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
    return format == 'png' || format == 'jpeg' || format == 'gif' || format == 'webp';
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

  Future<_CopyPayload?> _loadCopyPayload(void Function(String reason) setError) async {
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
          suggestedName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
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
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
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
          path = p.join(dir.path, 'kelivo_clip_${DateTime.now().millisecondsSinceEpoch}$ext');
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
      final payload = await _loadCopyPayload((reason) => failureReason = reason);
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPreviousImage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNextImage,
      },
      child: Focus(
        autofocus: true,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
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
        body: Stack(
          children: [
            // Dim background behind image; becomes transparent while dragging down
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(_bgOpacity)),
            ),
            // Drag-to-dismiss gesture layered over the PageView
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: _handleVerticalDragStart,
              onVerticalDragUpdate: _handleVerticalDragUpdate,
              onVerticalDragEnd: _handleVerticalDragEnd,
              onTap: () => Navigator.of(context).maybePop(),
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (i) {
                  setState(() {
                    _index = i;
                    _dragDy = 0.0;
                    _bgOpacity = 1.0;
                  });
                  _prepareSampleForIndex(i);
                },
                itemBuilder: (context, i) {
                  final src = widget.images[i];
                  final img = Image(
                    image: _providerFor(src),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white70, size: 64),
                  );
                  // Only transform the current page while dragging
                  final translateY = (i == _index) ? _dragDy : 0.0;
                  final scale = (i == _index) ? (1.0 - math.min(_dragDy / 800.0, 0.15)) : 1.0;
                  return Container(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: scale,
                        child: Hero(
                          tag: 'img:$src',
                          child: SizedBox.expand(
                            child: GestureDetector(
                              onDoubleTapDown: (d) => _lastDoubleTapPos = d.localPosition,
                              onDoubleTap: () {
                                final ctrl = _zoomCtrls[i];
                                final current = ctrl.value;
                                final double currentScale = current.getMaxScaleOnAxis();
                                // Toggle zoom
                                if (currentScale > 1.01) {
                                  _animateZoomTo(ctrl, toScale: 1.0, toTx: 0.0, toTy: 0.0);
                                } else {
                                  final focal = _lastDoubleTapPos ?? (context.size == null
                                      ? const Offset(0, 0)
                                      : Offset(context.size!.width / 2, context.size!.height / 2));
                                  // Convert focal from viewport to child coordinates
                                  final inv = Matrix4.inverted(current);
                                  final focalVector = inv.transform3(Vector3(focal.dx, focal.dy, 0));
                                  final double targetScale = 2; // 放大倍率
                                  final double tx = focal.dx - targetScale * focalVector.x;
                                  final double ty = focal.dy - targetScale * focalVector.y;
                                  _animateZoomTo(ctrl, toScale: targetScale, toTx: tx, toTy: ty);
                                }
                                _lastDoubleTapPos = null;
                              },
                              child: AnimatedBuilder(
                                animation: _zoomCtrls[i],
                                builder: (context, _) {
                                  final scale = _zoomCtrls[i].value.getMaxScaleOnAxis();
                                  final canPan = scale > 1.01;
                                  return InteractiveViewer(
                                    key: i == _index ? _viewerKey : null,
                                    transformationController: _zoomCtrls[i],
                                    minScale: 1.0,
                                    maxScale: 5,
                                    panEnabled: canPan,
                                    scaleEnabled: true,
                                    clipBehavior: Clip.none,
                                    boundaryMargin: canPan ? const EdgeInsets.all(80) : EdgeInsets.zero,
                                    child: img,
                                  );
                                },
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
          // Top bar
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(top: Platform.isMacOS ? 28.0 : 0.0),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '${_index + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
              ),
            ),
          ),
          // Bottom action buttons (save + copy + share)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _zoomCtrls[_index],
                    builder: (context, _) {
                      final leftColor = _smartIconColorForKey(context, _saveBtnKey);
                      final rightColor = _smartIconColorForKey(context, _shareBtnKey);
                      final showCopy = _isDesktop;
                      final Color? copyColor = showCopy ? _smartIconColorForKey(context, _copyBtnKey) : null;
                      final children = <Widget>[
                        _GlassCircleButton(
                          key: _saveBtnKey,
                          onTap: _saving ? null : _saveCurrent,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: _saving
                                ? SizedBox(
                                    key: const ValueKey('saving'),
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation(leftColor),
                                    ),
                                  )
                                : Icon(Icons.download, color: leftColor, size: 20, key: const ValueKey('ready')),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ];
                      if (showCopy) {
                        children.addAll([
                          _GlassCircleButton(
                            key: _copyBtnKey,
                            onTap: _copying ? null : _copyCurrent,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                              child: _copying
                                  ? SizedBox(
                                      key: const ValueKey('copying'),
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: AlwaysStoppedAnimation(copyColor ?? _fallbackIconColor(context)),
                                      ),
                                    )
                                  : Icon(Icons.copy, color: copyColor ?? _fallbackIconColor(context), size: 20, key: const ValueKey('copy-ready')),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ]);
                      }
                      children.add(
                        _GlassCircleButton(
                          key: _shareBtnKey,
                          onTap: _shareCurrent,
                          child: Icon(Icons.share, color: rightColor, size: 20),
                        ),
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: children,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Left navigation arrow (only show when not at first image and multiple images)
          if (widget.images.length > 1 && _index > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GlassCircleButton(
                  onTap: _goToPreviousImage,
                  child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                ),
              ),
            ),
          // Right navigation arrow (only show when not at last image and multiple images)
          if (widget.images.length > 1 && _index < widget.images.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GlassCircleButton(
                  onTap: _goToNextImage,
                  child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                ),
              ),
            ),
        ],
        ),
      ),
    ),
      ),
    );
  }

  // Dynamic icon color for glass buttons
  Color _fallbackIconColor(BuildContext context) {
    if (_bgOpacity >= 0.5) return Colors.white;
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? Colors.white : Colors.black;
  }

  double _currentScale() {
    if (_index < 0 || _index >= _zoomCtrls.length) return 1.0;
    return _zoomCtrls[_index].value.getMaxScaleOnAxis();
  }

  Color _smartIconColorForKey(BuildContext context, GlobalKey key) {
    final src = (_index >= 0 && _index < widget.images.length) ? widget.images[_index] : null;
    if (src == null) return _fallbackIconColor(context);
    final sample = _samples[src];
    final viewerCtx = _viewerKey.currentContext;
    final btnCtx = key.currentContext;
    if (sample == null || viewerCtx == null || btnCtx == null) return _fallbackIconColor(context);
    final viewerBox = viewerCtx.findRenderObject();
    final btnBox = btnCtx.findRenderObject();
    if (viewerBox is! RenderBox || btnBox is! RenderBox || !viewerBox.hasSize) return _fallbackIconColor(context);

    try {
      final btnCenterGlobal = btnBox.localToGlobal(btnBox.size.center(Offset.zero));
      final viewerLocal = viewerBox.globalToLocal(btnCenterGlobal);

      // Invert InteractiveViewer transform to get child-space point
      final m = _zoomCtrls[_index].value;
      final inv = Matrix4.inverted(m);
      final p = inv.transform3(Vector3(viewerLocal.dx, viewerLocal.dy, 0));
      final childPt = Offset(p.x, p.y);

      final childSize = viewerBox.size;
      final imgSize = Size(sample.w.toDouble(), sample.h.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, imgSize, childSize);
      final dest = Size(fitted.destination.width, fitted.destination.height);
      final dx = (childSize.width - dest.width) / 2.0;
      final dy = (childSize.height - dest.height) / 2.0;
      final destRect = Rect.fromLTWH(dx, dy, dest.width, dest.height);
      if (!destRect.contains(childPt)) {
        return _fallbackIconColor(context);
      }

      final u = ((childPt.dx - destRect.left) / destRect.width).clamp(0.0, 1.0);
      final v = ((childPt.dy - destRect.top) / destRect.height).clamp(0.0, 1.0);
      final sx = (u * (sample.w - 1)).round();
      final sy = (v * (sample.h - 1)).round();
      final avgLum = sample.avgLuminance(sx, sy, radius: 4);
      // Choose color: light bg -> black icon; dark bg -> white icon
      return avgLum >= 0.58 ? Colors.black : Colors.white;
    } catch (_) {
      return _fallbackIconColor(context);
    }
  }

  Future<void> _prepareSampleForIndex(int i) async {
    if (i < 0 || i >= widget.images.length) return;
    final src = widget.images[i];
    if (_samples.containsKey(src)) return;
    try {
      Uint8List? bytes;
      if (src.startsWith('data:')) {
        final idx = src.indexOf('base64,');
        if (idx != -1) {
          bytes = base64Decode(src.substring(idx + 7));
        }
      } else if (src.startsWith('http://') || src.startsWith('https://')) {
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          bytes = resp.bodyBytes;
        }
      } else {
        final local = SandboxPathResolver.fix(src);
        final f = File(local);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null) return;
      // Downscale decode for sampling
      const int targetW = 96;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetW);
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final w = img.width;
      final h = img.height;
      final lum = Uint8List(w * h);
      final bd = data.buffer.asUint8List();
      for (int y = 0; y < h; y++) {
        int row = y * w;
        for (int x = 0; x < w; x++) {
          final idx4 = (row + x) * 4;
          final r = bd[idx4 + 0];
          final g = bd[idx4 + 1];
          final b = bd[idx4 + 2];
          final yv = (0.299 * r + 0.587 * g + 0.114 * b).clamp(0, 255).toInt();
          lum[row + x] = yv;
        }
      }
      _samples[src] = _SampledImage(w, h, lum);
      if (mounted) setState(() {});
    } catch (_) {
      // ignore sampling failures
    }
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
          if (mime.contains('png')) ext = '.png';
          else if (mime.contains('jpeg') || mime.contains('jpg')) ext = '.jpg';
          else if (mime.contains('gif')) ext = '.gif';
          else if (mime.contains('webp')) ext = '.webp';
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

Route _buildFancyRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, anim, sec, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(curved), child: child),
      );
    },
  );
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
    super.key,
    required this.child,
    this.onTap,
    this.size = 48,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double size;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.onTap == null;
    final Color baseFill = Colors.white.withOpacity(disabled ? 0.10 : 0.18);
    final Color border = Colors.white.withOpacity(disabled ? 0.20 : 0.35);
    final Color fill = _pressed ? Colors.white.withOpacity(disabled ? 0.12 : 0.24) : baseFill;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.94 : 1.0,
        child: ClipOval(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: fill,
                shape: BoxShape.circle,
                border: Border.all(color: border, width: 0.6),
              ),
              child: Center(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

class _SampledImage {
  final int w;
  final int h;
  final Uint8List lum; // 0..255 luminance
  _SampledImage(this.w, this.h, this.lum);

  double avgLuminance(int cx, int cy, {int radius = 3}) {
    if (w == 0 || h == 0) return 0.0;
    int x0 = (cx - radius).clamp(0, w - 1);
    int x1 = (cx + radius).clamp(0, w - 1);
    int y0 = (cy - radius).clamp(0, h - 1);
    int y1 = (cy + radius).clamp(0, h - 1);
    int sum = 0;
    int count = 0;
    for (int y = y0; y <= y1; y++) {
      int row = y * w;
      for (int x = x0; x <= x1; x++) {
        sum += lum[row + x];
        count++;
      }
    }
    if (count == 0) return 0.0;
    return (sum / count) / 255.0;
  }
}

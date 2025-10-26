import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import '../../../utils/sandbox_path_resolver.dart';
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
    if (kIsWeb) {
      // On web, local file paths are not supported
      return const AssetImage('assets/placeholder.png'); // or return null if you prefer
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
          final size = MediaQuery.of(context).size;
          anchor = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: 1, height: 1);
        }
      } catch (_) {
        final size = MediaQuery.of(context).size;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
          // Bottom share button (no gradient background)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    ),
                    onPressed: _shareCurrent,
                    icon: const Icon(Icons.share),
                    label: Text(l10n.imageViewerPageShareButton),
                  ),
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

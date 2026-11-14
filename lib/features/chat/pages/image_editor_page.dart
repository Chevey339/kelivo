import '../../../utils/platform_utils.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/models/image_edit_document.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../utils/image_edit_renderer.dart';

class EditorImage {
  const EditorImage({
    required this.id,
    required this.path,
    this.sourcePath,
    this.document = const ImageEditDocument(),
    this.failed = false,
  });
  final int id;
  final String path;
  final String? sourcePath;
  final ImageEditDocument document;
  final bool failed;
}

enum _Tool { crop, draw, text, mosaic }

enum _Pen { pen, arrow, eraser }

const _accent = Color(0xff9aa8f0);
const _colors = [
  0xffffffff,
  0xff111111,
  0xffff453a,
  0xffffd60a,
  0xff32d74b,
  0xff0a84ff,
];

class ImageEditorPage extends StatefulWidget {
  const ImageEditorPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
    required this.onSave,
    required this.onRetry,
    required this.onRemove,
  });
  final List<EditorImage> images;
  final int initialIndex;
  final Future<void> Function(Map<int, ImageEditDocument>) onSave;
  final Future<EditorImage?> Function(int id) onRetry;
  final void Function(int id) onRemove;
  @override
  State<ImageEditorPage> createState() => _ImageEditorPageState();
}

class _ImageEditorPageState extends State<ImageEditorPage> {
  late final List<EditorImage> _images = List.of(widget.images);
  late final Map<int, ImageEditDocument> _docs = {
    for (final i in _images) i.id: i.document,
  };
  late final Map<int, ImageEditDocument> _initial;
  final List<Map<int, ImageEditDocument>> _undo = [], _redo = [];
  final Map<int, ui.Image> _decoded = {}, _pixels = {}, _previews = {};
  final Map<int, int> _previewVersions = {};
  final Set<int> _failed = {}, _loading = {};
  final _zoom = TransformationController();
  final _focus = FocusNode(debugLabel: 'ImageEditor');
  final _textFocus = FocusNode(debugLabel: 'ImageAnnotation');
  final _textController = TextEditingController();
  late int _index = widget.initialIndex.clamp(
    0,
    math.max(0, _images.length - 1),
  );
  _Tool? _tool;
  _Pen _pen = _Pen.pen;
  bool _boxMosaic = false,
      _saving = false,
      _confirming = false,
      _allowPop = false;
  int _color = _colors[2];
  double _width = 8, _textSize = 42, _mosaicWidth = 50;
  ImageTextStyle _textStyle = ImageTextStyle.plain;
  TextAlign _align = TextAlign.center;
  int? _selectedText, _editingText, _previousTextSelection;
  Map<int, ImageEditDocument>? _pinchBefore;
  double _pinchTextSize = 42;
  Map<int, ImageEditDocument>? _textBefore, _gestureBefore, _sizeBefore;
  List<Offset> _points = [];
  Offset? _start, _hover;
  Rect? _startCrop;
  int _cropHandle = -1;
  double? _aspect;
  Size _viewport = Size.zero;
  Rect _fit = Rect.zero;
  final Set<int> _pointers = {};
  bool _dragging = false;
  bool _keyboardFramed = false;
  EditorImage get _image => _images[_index];
  ImageEditDocument get _doc => _docs[_image.id]!;
  ui.Image? get _source => _decoded[_image.id];
  bool get _unavailable => _source == null || _failed.contains(_image.id);
  bool get _dirty =>
      _docs.entries.any((e) => !_initial[e.key]!.sameValue(e.value));
  AppLocalizations get _l => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _initial = Map.of(_docs);
    _failed.addAll(_images.where((i) => i.failed).map((i) => i.id));
    _textController.addListener(_updateText);
    if (_images.isNotEmpty) unawaited(_load(_image));
  }

  @override
  void dispose() {
    _zoom.dispose();
    _focus.dispose();
    _textFocus.dispose();
    _textController.dispose();
    for (final image in [
      ..._decoded.values,
      ..._pixels.values,
      ..._previews.values,
    ]) {
      image.dispose();
    }
    super.dispose();
  }

  Future<void> _load(EditorImage image) async {
    if (_decoded.containsKey(image.id) ||
        _failed.contains(image.id) ||
        !_loading.add(image.id)) {
      return;
    }
    ui.Image? decoded, pixels;
    try {
      decoded = await ImageEditRenderer.decode(
        image.sourcePath ?? image.path,
        maxEdge: 2048,
      );
      pixels = await ImageEditRenderer.pixelate(decoded);
      if (!mounted || !_docs.containsKey(image.id)) {
        decoded.dispose();
        pixels.dispose();
        return;
      }
      setState(() {
        _decoded[image.id] = decoded!;
        _pixels[image.id] = pixels!;
      });
      while (_decoded.length > 3) {
        final id = _decoded.keys.firstWhere((id) => id != _image.id);
        unawaited(_makePreview(id));
        _decoded.remove(id)?.dispose();
        _pixels.remove(id)?.dispose();
      }
    } catch (_) {
      decoded?.dispose();
      pixels?.dispose();
      if (mounted) setState(() => _failed.add(image.id));
    } finally {
      _loading.remove(image.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _makePreview(int id) async {
    final source = _decoded[id]?.clone();
    if (source == null) return;
    final pixels = _pixels[id]?.clone();
    final doc = _docs[id]!;
    final version = (_previewVersions[id] ?? 0) + 1;
    _previewVersions[id] = version;
    ui.Picture? picture;
    try {
      final geometry = ImageEditGeometry(
        Size(source.width.toDouble(), source.height.toDouble()),
        doc,
      );
      final scale = 88 / math.max(geometry.size.width, geometry.size.height);
      final size = Size(
        math.max(1, (geometry.size.width * scale).round()).toDouble(),
        math.max(1, (geometry.size.height * scale).round()).toDouble(),
      );
      final recorder = ui.PictureRecorder();
      ImageEditPainter(
        source: source,
        pixels: pixels,
        document: doc,
      ).paint(Canvas(recorder), size);
      picture = recorder.endRecording();
      final preview = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      if (!mounted ||
          _previewVersions[id] != version ||
          !_docs.containsKey(id)) {
        preview.dispose();
        return;
      }
      final old = _previews[id];
      setState(() => _previews[id] = preview);
      old?.dispose();
    } catch (_) {
      // The existing thumbnail remains usable if its replacement cannot render.
    } finally {
      source.dispose();
      pixels?.dispose();
      picture?.dispose();
    }
  }

  void _record(Map<int, ImageEditDocument> before) {
    if (!before.keys.any(
      (id) => _docs.containsKey(id) && !before[id]!.sameValue(_docs[id]!),
    )) {
      return;
    }
    _undo.add(before);
    _redo.clear();
  }

  void _change(ImageEditDocument doc) {
    final before = Map<int, ImageEditDocument>.of(_docs);
    setState(() {
      _docs[_image.id] = doc;
      _record(before);
    });
  }

  void _undoStep({bool redo = false}) {
    _finishText();
    final from = redo ? _redo : _undo, to = redo ? _undo : _redo;
    if (from.isEmpty) return;
    setState(() {
      to.add(Map.of(_docs));
      final next = from.removeLast();
      final changed = _docs.keys
          .where(
            (id) => next.containsKey(id) && !_docs[id]!.sameValue(next[id]!),
          )
          .firstOrNull;
      if (changed != null) {
        _index = _images.indexWhere((image) => image.id == changed);
      }
      for (final id in _docs.keys.toList()) {
        if (next.containsKey(id)) _docs[id] = next[id]!;
      }
      _selectedText = null;
      _zoom.value = Matrix4.identity();
    });
    unawaited(_load(_image));
  }

  void _select(int index) {
    if (index < 0 || index >= _images.length || index == _index || _saving) {
      return;
    }
    _finishText();
    unawaited(_makePreview(_image.id));
    setState(() {
      _index = index;
      _selectedText = null;
      _tool = null;
      _zoom.value = Matrix4.identity();
    });
    unawaited(_load(_image));
  }

  void _selectTool(_Tool tool) {
    _finishText();
    setState(() {
      _tool = _tool == tool ? null : tool;
      _selectedText = null;
      _zoom.value = Matrix4.identity();
    });
  }

  Future<void> _cancel() async {
    if (_saving || _confirming) return;
    _finishText();
    if (_dirty) {
      _confirming = true;
      final desktop =
          (ResponsiveHelper.isDesktop(context) ||
          PlatformUtils.isDesktopTarget);
      final confirmed = desktop
          ? await showDialog<bool>(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.transparent,
                child: _discardCard(ctx, false),
              ),
            )
          : await showModalBottomSheet<bool>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (ctx) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _discardCard(ctx, true),
                ),
              ),
            );
      _confirming = false;
      if (confirmed != true || !mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  Widget _discardCard(BuildContext ctx, bool mobile) => Container(
    width: mobile ? double.infinity : 288,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xff1f2027),
      borderRadius: BorderRadius.circular(mobile ? 22 : 18),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _l.imageEditorDiscardTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        _button(
          _l.imageEditorDiscard,
          () => Navigator.pop(ctx, true),
          color: const Color(0xffff8a80),
          fill: const Color(0x29ff6363),
        ),
        const SizedBox(height: 8),
        _button(_l.imageEditorKeepEditing, () => Navigator.pop(ctx, false)),
      ],
    ),
  );
  Future<void> _save() async {
    if (_saving) return;
    _finishText();
    setState(() => _saving = true);
    try {
      await widget.onSave({
        for (final e in _docs.entries)
          if (!_initial[e.key]!.sameValue(e.value)) e.key: e.value,
      });
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: _l.imageEditorProcessFailed,
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retry() async {
    if (_loading.contains(_image.id)) return;
    final id = _image.id;
    setState(() => _loading.add(id));
    try {
      final replacement = await widget.onRetry(id);
      if (!mounted || replacement == null) return;
      final at = _images.indexWhere((i) => i.id == id);
      if (at < 0) return;
      _images[at] = replacement;
      _failed.remove(id);
      _loading.remove(id);
      await _load(replacement);
    } catch (_) {
      if (mounted) setState(() => _failed.add(id));
    } finally {
      _loading.remove(id);
      if (mounted) setState(() {});
    }
  }

  void _remove() {
    final id = _image.id;
    widget.onRemove(id);
    setState(() {
      _images.removeAt(_index);
      _docs.remove(id);
      _initial.remove(id);
      for (final history in [..._undo, ..._redo]) {
        history.remove(id);
      }
      _index = _index.clamp(0, math.max(0, _images.length - 1));
    });
    if (_images.isEmpty) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      unawaited(_load(_image));
    }
  }

  ImageEditGeometry get _geometry => ImageEditGeometry(
    Size(_source!.width.toDouble(), _source!.height.toDouble()),
    _doc,
    full: _tool == _Tool.crop,
  );
  Offset _sourcePoint(Offset local) {
    final scene = _zoom.toScene(local);
    final point = (scene - _fit.topLeft) / (_fit.width / _geometry.size.width);
    final source = _geometry.toSource(point);
    // Mosaic strokes and rectangles use the unflipped photo's coordinates.
    final x = _tool == _Tool.mosaic && _doc.flipX
        ? 1000 - source.dx
        : source.dx;
    return Offset(
      x.clamp(0, 1000),
      source.dy.clamp(0, _geometry.sourceSize.height),
    );
  }

  int? _hitText(Offset point) {
    for (var i = _doc.texts.length - 1; i >= 0; i--) {
      final t = _doc.texts[i], p = imageEditTextPainter(_doc.texts[i]);
      final rect = Rect.fromCenter(
        center: t.center,
        width: p.width + 24,
        height: p.height + 24,
      );
      p.dispose();
      if (rect.contains(point)) return i;
    }
    return null;
  }

  void _pointerDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    if (_pointers.length > 1) {
      if (_gestureBefore != null) {
        setState(() {
          _docs.addAll(_gestureBefore!);
          _gestureBefore = null;
          _start = null;
        });
      }
      return;
    }
    if (_unavailable || _tool == null || _editingText != null || _saving) {
      return;
    }
    if (!_fit.contains(_zoom.toScene(e.localPosition))) return;
    _start = _sourcePoint(e.localPosition);
    _points = [_start!];
    _dragging = false;
    _gestureBefore = Map.of(_docs);
    if (_tool == _Tool.text) {
      _previousTextSelection = _selectedText;
      _selectedText = _hitText(_start!);
    }
    if (_tool == _Tool.crop) {
      _startCrop = _doc.crop ?? const Rect.fromLTWH(0, 0, 1, 1);
      final size = _geometry.sourceSize;
      final point = Offset(_start!.dx / 1000, _start!.dy / size.height);
      final r = _startCrop!;
      final handles = [
        r.topLeft,
        r.topCenter,
        r.topRight,
        r.centerRight,
        r.bottomRight,
        r.bottomCenter,
        r.bottomLeft,
        r.centerLeft,
      ];
      var nearest = 24.0;
      _cropHandle = -1;
      for (var i = 0; i < handles.length; i++) {
        final sourcePoint = Offset(
          handles[i].dx * 1000,
          handles[i].dy * size.height,
        );
        final output = MatrixUtils.transformPoint(
          _geometry.transform,
          sourcePoint,
        );
        final viewportPoint =
            _fit.topLeft + output * (_fit.width / _geometry.size.width);
        final screenPoint = MatrixUtils.transformPoint(
          _zoom.value,
          viewportPoint,
        );
        final distance = (screenPoint - e.localPosition).distance;
        if (distance <= nearest) {
          nearest = distance;
          _cropHandle = i;
        }
      }
      if (_cropHandle == -1 && !r.contains(point)) {
        _start = null;
        _gestureBefore = null;
      }
    }
    setState(() {});
  }

  void _pointerMove(PointerMoveEvent e) {
    if (_pointers.length != 1 ||
        _start == null ||
        _gestureBefore == null ||
        _unavailable) {
      return;
    }
    final point = _sourcePoint(e.localPosition);
    if ((point - _start!).distance > 3) _dragging = true;
    final initial = _gestureBefore![_image.id]!;
    setState(() {
      switch (_tool) {
        case _Tool.draw:
          if (_pen == _Pen.eraser) {
            _docs[_image.id] = _doc.copyWith(
              strokes: _doc.strokes
                  .where((s) => !_strokeHit(s, point))
                  .toList(),
            );
          } else {
            _points.add(point);
            _docs[_image.id] = initial.copyWith(
              strokes: [
                ...initial.strokes,
                ImageEditStroke(
                  points: List.of(_points),
                  width: _width,
                  color: _color,
                  kind: _pen == _Pen.arrow
                      ? ImageStrokeKind.arrow
                      : ImageStrokeKind.pen,
                ),
              ],
            );
          }
        case _Tool.mosaic:
          _points.add(point);
          _docs[_image.id] = initial.copyWith(
            mosaic: [
              ...initial.mosaic,
              ImageMosaicOp(
                points: _boxMosaic ? const [] : List.of(_points),
                width: _mosaicWidth,
                rect: _boxMosaic ? Rect.fromPoints(_start!, point) : null,
              ),
            ],
          );
        case _Tool.text:
          if (_selectedText != null) {
            final list = List<ImageEditText>.of(initial.texts);
            final t = list[_selectedText!];
            list[_selectedText!] = t.copyWith(
              center: t.center + point - _start!,
            );
            _docs[_image.id] = initial.copyWith(texts: list);
          }
        case _Tool.crop:
          _dragCrop(point);
        case null:
          break;
      }
    });
  }

  bool _strokeHit(ImageEditStroke s, Offset point) {
    final points = s.kind == ImageStrokeKind.arrow && s.points.length > 1
        ? [s.points.first, s.points.last]
        : s.points;
    if (points.length == 1) {
      return (points.first - point).distance < 22 + s.width / 2;
    }
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], v = points[i] - a;
      final length = v.dx * v.dx + v.dy * v.dy;
      final t = length == 0
          ? 0.0
          : (((point - a).dx * v.dx + (point - a).dy * v.dy) / length).clamp(
              0.0,
              1.0,
            );
      if ((a + v * t - point).distance < 22 + s.width / 2) return true;
    }
    return false;
  }

  void _pointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    final before = _gestureBefore;
    if (before == null || _start == null || _unavailable) return;
    if (e is PointerCancelEvent) {
      setState(() => _docs.addAll(before));
    } else if (_tool == _Tool.text && !_dragging) {
      final hit = _hitText(_start!);
      if (hit == null || hit == _previousTextSelection) {
        _beginText(hit, _start!);
      } else {
        final text = _doc.texts[hit];
        _textSize = text.size;
        _color = text.color;
        _textStyle = text.style;
        _align = text.align;
      }
    } else {
      if (!_dragging && (_tool == _Tool.draw || _tool == _Tool.mosaic)) {
        final point = _start!;
        if (_tool == _Tool.draw && _pen != _Pen.eraser) {
          _docs[_image.id] = _doc.copyWith(
            strokes: [
              ..._doc.strokes,
              ImageEditStroke(points: [point], width: _width, color: _color),
            ],
          );
        }
        if (_tool == _Tool.mosaic && !_boxMosaic) {
          _docs[_image.id] = _doc.copyWith(
            mosaic: [
              ..._doc.mosaic,
              ImageMosaicOp(points: [point], width: _mosaicWidth),
            ],
          );
        }
      }
      _record(before);
    }
    _gestureBefore = null;
    _start = null;
    if (mounted) setState(() {});
  }

  void _dragCrop(Offset point) {
    final h = _geometry.sourceSize.height;
    final delta = Offset(
      (point.dx - _start!.dx) / 1000,
      (point.dy - _start!.dy) / h,
    );
    final r = _startCrop!;
    final minWidth = math.min(.04, r.width / 2);
    final minHeight = math.min(.04, r.height / 2);
    double l = r.left, t = r.top, right = r.right, bottom = r.bottom;
    if (_cropHandle == -1) {
      l = (l + delta.dx).clamp(0, 1 - r.width);
      t = (t + delta.dy).clamp(0, 1 - r.height);
      right = l + r.width;
      bottom = t + r.height;
    } else {
      if ([0, 6, 7].contains(_cropHandle)) {
        l = (l + delta.dx).clamp(0, right - minWidth);
      }
      if ([0, 1, 2].contains(_cropHandle)) {
        t = (t + delta.dy).clamp(0, bottom - minHeight);
      }
      if ([2, 3, 4].contains(_cropHandle)) {
        right = (right + delta.dx).clamp(l + minWidth, 1);
      }
      if ([4, 5, 6].contains(_cropHandle)) {
        bottom = (bottom + delta.dy).clamp(t + minHeight, 1);
      }
      if (_aspect != null) {
        final ratio =
            (_doc.quarterTurns.isOdd ? 1 / _aspect! : _aspect!) * h / 1000;
        if (_cropHandle.isOdd) {
          // Keep the opposite edge fixed and grow both orthogonal edges
          // symmetrically around the original center.
          if (_cropHandle == 1 || _cropHandle == 5) {
            final maxWidth = 2 * math.min(r.center.dx, 1 - r.center.dx);
            final height = math.min(bottom - t, maxWidth / ratio);
            final width = height * ratio;
            l = r.center.dx - width / 2;
            right = r.center.dx + width / 2;
            if (_cropHandle == 1) {
              t = bottom - height;
            } else {
              bottom = t + height;
            }
          } else {
            final maxHeight = 2 * math.min(r.center.dy, 1 - r.center.dy);
            final width = math.min(right - l, maxHeight * ratio);
            final height = width / ratio;
            t = r.center.dy - height / 2;
            bottom = r.center.dy + height / 2;
            if (_cropHandle == 7) {
              l = right - width;
            } else {
              right = l + width;
            }
          }
        } else {
          final width = math.min(right - l, (bottom - t) * ratio);
          final height = width / ratio;
          if (_cropHandle == 0 || _cropHandle == 6) {
            l = right - width;
          } else {
            right = l + width;
          }
          if (_cropHandle == 0 || _cropHandle == 2) {
            t = bottom - height;
          } else {
            bottom = t + height;
          }
        }
      }
    }
    _docs[_image.id] = _doc.copyWith(crop: Rect.fromLTRB(l, t, right, bottom));
  }

  void _setAspect(double? aspect) {
    _aspect = aspect;
    if (aspect == null) return;
    final size = _geometry.sourceSize;
    final ratio =
        (_doc.quarterTurns.isOdd ? 1 / aspect : aspect) *
        size.height /
        size.width;
    final w = math.min(1.0, ratio), h = math.min(1.0, 1 / ratio);
    _change(
      _doc.copyWith(
        crop: Rect.fromCenter(
          center: const Offset(.5, .5),
          width: w,
          height: h,
        ),
      ),
    );
  }

  void _beginText(int? index, Offset point) {
    _textBefore = Map.of(_docs);
    if (index == null) {
      final list = [
        ..._doc.texts,
        ImageEditText(
          text: '',
          center: point,
          size: _textSize,
          color: _color,
          style: _textStyle,
          align: _align,
        ),
      ];
      _docs[_image.id] = _doc.copyWith(texts: list);
      index = list.length - 1;
    }
    _editingText = index;
    _selectedText = index;
    final t = _doc.texts[index];
    _textSize = t.size;
    _color = t.color;
    _textStyle = t.style;
    _align = t.align;
    _textController.value = TextEditingValue(
      text: t.text,
      selection: TextSelection.collapsed(offset: t.text.length),
    );
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _updateText() {
    if (_editingText == null || _images.isEmpty) return;
    final list = List<ImageEditText>.of(_doc.texts);
    list[_editingText!] = list[_editingText!].copyWith(
      text: _textController.text,
    );
    setState(() {
      _docs[_image.id] = _doc.copyWith(texts: list);
      _keyboardFramed = false;
    });
  }

  void _finishText() {
    if (_editingText == null) return;
    if (_doc.texts[_editingText!].text.trim().isEmpty) {
      final list = List<ImageEditText>.of(_doc.texts)..removeAt(_editingText!);
      _docs[_image.id] = _doc.copyWith(texts: list);
      _selectedText = null;
    }
    _editingText = null;
    _textFocus.unfocus();
    if (_textBefore != null) _record(_textBefore!);
    _textBefore = null;
    _keyboardFramed = false;
    _zoom.value = Matrix4.identity();
    if (mounted) {
      setState(() {});
      _focus.requestFocus();
    }
  }

  void _styleText({
    ImageTextStyle? style,
    int? color,
    TextAlign? align,
    double? size,
    bool record = true,
  }) {
    setState(() {
      if (style != null) _textStyle = style;
      if (color != null) _color = color;
      if (align != null) _align = align;
      if (size != null) _textSize = size;
      if (_selectedText != null) {
        final before = Map<int, ImageEditDocument>.of(_docs);
        final list = List<ImageEditText>.of(_doc.texts);
        list[_selectedText!] = list[_selectedText!].copyWith(
          style: style,
          color: color,
          align: align,
          size: size,
        );
        _docs[_image.id] = _doc.copyWith(texts: list);
        if (record && _editingText == null) _record(before);
      }
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _saving) return KeyEventResult.ignored;
    final key = event.logicalKey, keys = HardwareKeyboard.instance;
    if (_editingText != null) {
      if (key == LogicalKeyboardKey.escape ||
          (key == LogicalKeyboardKey.enter && !keys.isShiftPressed)) {
        _finishText();
        if (key == LogicalKeyboardKey.escape) unawaited(_cancel());
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.escape) {
      unawaited(_cancel());
    } else if (key == LogicalKeyboardKey.enter) {
      unawaited(_save());
    } else if (key == LogicalKeyboardKey.keyZ &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      _undoStep(redo: keys.isShiftPressed);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _select(_index - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _select(_index + 1);
    } else if ((key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) &&
        _selectedText != null) {
      _change(
        _doc.copyWith(texts: List.of(_doc.texts)..removeAt(_selectedText!)),
      );
      setState(() => _selectedText = null);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) return const SizedBox.shrink();
    final desktop =
        (ResponsiveHelper.isDesktop(context) || PlatformUtils.isDesktopTarget);
    final typing =
        !desktop &&
        _editingText != null &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_cancel());
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: Colors.black,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          body: Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _key,
            child: SafeArea(
              child: desktop ? _desktopLayout() : _mobileLayout(typing),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopLayout() => Column(
    children: [
      _topBar(true),
      Expanded(child: _stage(false)),
      SizedBox(height: 60, child: _bottomSlot()),
      Padding(padding: const EdgeInsets.only(bottom: 16), child: _rail(true)),
    ],
  );
  Widget _mobileLayout(bool typing) => Column(
    children: [
      SizedBox(
        height: 56,
        child: typing ? const SizedBox.shrink() : _topBar(false),
      ),
      Expanded(child: _stage(typing)),
      SizedBox(height: 60, child: _bottomSlot()),
      if (!typing) SizedBox(height: 64, child: _rail(false)),
    ],
  );
  Widget _topBar(bool desktop) => SizedBox(
    height: desktop ? 58 : 56,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: desktop && Platform.isMacOS ? 84 : 0,
                ),
                child: _button(_l.imageEditorCancel, _saving ? null : _cancel),
              ),
            ),
          ),
          _icon(
            LucideIcons.undo2,
            _l.imageEditorUndo,
            _undo.isEmpty || _saving ? null : () => _undoStep(),
          ),
          _icon(
            LucideIcons.redo2,
            _l.imageEditorRedo,
            _redo.isEmpty || _saving ? null : () => _undoStep(redo: true),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_doc.isEmpty && !_unavailable)
                    Flexible(
                      child: _button(
                        _l.imageEditorRestore,
                        _saving
                            ? null
                            : () {
                                _finishText();
                                _change(const ImageEditDocument());
                                _selectedText = null;
                                _zoom.value = Matrix4.identity();
                              },
                      ),
                    ),
                  Flexible(
                    child: _button(
                      _l.imageEditorDone,
                      _saving ? null : _save,
                      color: const Color(0xff1d2550),
                      fill: _accent,
                      busy: _saving,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _stage(bool typing) {
    if (_failed.contains(_image.id)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.imageOff, color: Colors.white54, size: 40),
            const SizedBox(height: 16),
            Text(
              _l.imageEditorProcessFailed,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(_l.imageEditorRemove, _remove),
                const SizedBox(width: 12),
                _button(
                  _l.imageEditorRetry,
                  _loading.contains(_image.id) ? null : _retry,
                  fill: const Color(0x29ffffff),
                  busy: _loading.contains(_image.id),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (_source == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final geometry = _geometry;
        final desktop =
            (ResponsiveHelper.isDesktop(context) ||
            PlatformUtils.isDesktopTarget);
        final available = Size(
          math.max(1, _viewport.width - (desktop ? 184 : 24)),
          math.max(1, _viewport.height - 20),
        );
        final fitted = applyBoxFit(
          BoxFit.contain,
          geometry.size,
          available,
        ).destination;
        _fit = Rect.fromCenter(
          center: _viewport.center(Offset.zero),
          width: fitted.width,
          height: fitted.height,
        );
        if (typing && !_keyboardFramed && _editingText != null) {
          _keyboardFramed = true;
          final text = _doc.texts[_editingText!];
          final painter = imageEditTextPainter(text);
          final caret = painter.getOffsetForCaret(
            TextPosition(
              offset: _textController.selection.extentOffset.clamp(
                0,
                text.text.length,
              ),
            ),
            Rect.zero,
          );
          final activeLine =
              text.center -
              Offset(painter.width / 2, painter.height / 2) +
              caret +
              Offset(0, text.size * .6);
          painter.dispose();
          final point =
              MatrixUtils.transformPoint(geometry.transform, activeLine) *
                  (fitted.width / geometry.size.width) +
              _fit.topLeft;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _editingText == null) return;
            _zoom.value = Matrix4.identity()
              ..translateByDouble(
                (_viewport.width / 2 - point.dx * 1.7).clamp(
                  math.min(
                    _viewport.width - _fit.right * 1.7,
                    -_fit.left * 1.7,
                  ),
                  math.max(
                    _viewport.width - _fit.right * 1.7,
                    -_fit.left * 1.7,
                  ),
                ),
                _viewport.height / 2 - point.dy * 1.7,
                0,
                1,
              )
              ..scaleByDouble(1.7, 1.7, 1, 1);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: MouseRegion(
                onHover: (e) {
                  if (_tool == _Tool.mosaic) {
                    setState(() => _hover = e.localPosition);
                  }
                },
                onExit: (_) => setState(() => _hover = null),
                child: Listener(
                  key: const ValueKey('image-editor-stage'),
                  onPointerDown: _pointerDown,
                  onPointerMove: _pointerMove,
                  onPointerUp: _pointerUp,
                  onPointerCancel: _pointerUp,
                  child: InteractiveViewer(
                    transformationController: _zoom,
                    minScale: 1,
                    maxScale: 5,
                    scaleEnabled:
                        !(_tool == _Tool.text &&
                            _selectedText != null &&
                            _editingText == null),
                    onInteractionStart: (_) {
                      if (_tool == _Tool.text &&
                          _selectedText != null &&
                          _editingText == null) {
                        _pinchBefore = Map.of(_docs);
                        _pinchTextSize = _doc.texts[_selectedText!].size;
                      }
                    },
                    onInteractionUpdate: (details) {
                      if (_pinchBefore != null &&
                          _pointers.length > 1 &&
                          _selectedText != null) {
                        final texts = List<ImageEditText>.of(_doc.texts);
                        _textSize = (_pinchTextSize * details.scale).clamp(
                          18,
                          96,
                        );
                        texts[_selectedText!] = texts[_selectedText!].copyWith(
                          size: _textSize,
                        );
                        setState(
                          () => _docs[_image.id] = _doc.copyWith(texts: texts),
                        );
                      }
                    },
                    onInteractionEnd: (_) {
                      if (_pinchBefore != null) {
                        setState(() => _record(_pinchBefore!));
                        _pinchBefore = null;
                      }
                    },
                    panEnabled: _tool == null || _pointers.length > 1,
                    child: SizedBox(
                      width: _viewport.width,
                      height: _viewport.height,
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: _fit,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: ImageEditPainter(
                                      source: _source!,
                                      pixels: _pixels[_image.id],
                                      document: _doc,
                                      full: _tool == _Tool.crop,
                                      selectedText: _editingText == null
                                          ? _selectedText
                                          : null,
                                      editingText: _editingText,
                                    ),
                                  ),
                                ),
                                if (typing)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: ColoredBox(
                                        color: Colors.black.withValues(
                                          alpha: .34,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_editingText != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: ImageEditPainter(
                                          source: _source!,
                                          pixels: _pixels[_image.id],
                                          document: _doc,
                                          textOnly: _editingText,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_tool == _Tool.crop)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: CustomPaint(
                                        painter: _CropPainter(
                                          geometry,
                                          _doc.crop ??
                                              const Rect.fromLTWH(0, 0, 1, 1),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_editingText != null)
                                  _editable(geometry, fitted),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_tool == _Tool.mosaic &&
                _hover != null &&
                !_boxMosaic &&
                desktop)
              Positioned(
                left:
                    _hover!.dx -
                    _mosaicWidth * fitted.width / geometry.size.width / 2,
                top:
                    _hover!.dy -
                    _mosaicWidth * fitted.width / geometry.size.width / 2,
                child: IgnorePointer(
                  child: Container(
                    width: _mosaicWidth * fitted.width / geometry.size.width,
                    height: _mosaicWidth * fitted.width / geometry.size.width,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            if (_tool != null && _tool != _Tool.crop)
              Positioned(
                left: desktop ? 16 : 8,
                top: _viewport.height * .3,
                child: _SizeWedge(
                  onStart: () => _sizeBefore = Map.of(_docs),
                  onEnd: () {
                    if (_sizeBefore != null && _editingText == null) {
                      setState(() => _record(_sizeBefore!));
                    }
                    _sizeBefore = null;
                  },
                  value: _tool == _Tool.draw
                      ? (_width - 2) / 28
                      : _tool == _Tool.text
                      ? (_textSize - 18) / 78
                      : (_mosaicWidth - 20) / 100,
                  onChanged: (value) {
                    if (_tool == _Tool.text) {
                      _styleText(size: 18 + value * 78, record: false);
                    } else {
                      setState(() {
                        if (_tool == _Tool.draw) {
                          _width = 2 + value * 28;
                        } else {
                          _mosaicWidth = 20 + value * 100;
                        }
                      });
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _editable(ImageEditGeometry geometry, Size fitted) {
    final text = _doc.texts[_editingText!];
    final painter = imageEditTextPainter(
      text.copyWith(text: text.text.isEmpty ? ' ' : text.text),
    );
    final width = math.max(text.size, painter.width);
    final height = painter.height;
    painter.dispose();
    final scale = fitted.width / geometry.size.width;
    final matrix = Matrix4.diagonal3Values(scale, scale, 1)
      ..multiply(geometry.transform);
    return Positioned(
      key: const ValueKey('image-editor-editable-layer'),
      left: 0,
      top: 0,
      child: Transform(
        alignment: Alignment.topLeft,
        transform: matrix,
        child: Transform.translate(
          offset: text.center - Offset(width / 2, height / 2),
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(text.size * .34),
              ),
              child: EditableText(
                key: const ValueKey('image-editor-text-input'),
                controller: _textController,
                focusNode: _textFocus,
                style: imageEditTextStyle(
                  text,
                ).copyWith(color: Colors.transparent, shadows: const []),
                cursorColor: Colors.white,
                backgroundCursorColor: Colors.white24,
                textAlign: text.align,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _finishText(),
                selectionColor: _accent.withValues(alpha: .4),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomSlot() => Center(
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: _tool == null || _unavailable
          ? _filmstrip()
          : IgnorePointer(
              ignoring: _unavailable || _saving,
              child: Opacity(
                opacity: _unavailable ? .35 : 1,
                child: _contextBar(),
              ),
            ),
    ),
  );
  Widget _filmstrip() => SingleChildScrollView(
    key: const ValueKey('image-editor-filmstrip'),
    scrollDirection: Axis.horizontal,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _images.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _select(i),
              child: Container(
                key: ValueKey('image-editor-thumbnail-$i'),
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: i == _index ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: _thumbnail(_images[i]),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _thumbnail(EditorImage image) {
    final source = _decoded[image.id];
    if (source != null) {
      final doc = _docs[image.id]!;
      final geometry = ImageEditGeometry(
        Size(source.width.toDouble(), source.height.toDouble()),
        doc,
      );
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: geometry.size.width,
          height: geometry.size.height,
          child: CustomPaint(
            painter: ImageEditPainter(
              source: source,
              pixels: _pixels[image.id],
              document: doc,
            ),
          ),
        ),
      );
    }
    final preview = _previews[image.id];
    if (preview != null) return RawImage(image: preview, fit: BoxFit.cover);
    return Image.file(
      File(image.path),
      fit: BoxFit.cover,
      cacheWidth: 88,
      errorBuilder: (_, __, ___) =>
          const Icon(LucideIcons.imageOff, color: Colors.white54, size: 20),
    );
  }

  Widget _rail(bool desktop) {
    final entries = [
      (LucideIcons.crop, _l.imageEditorToolCrop),
      (LucideIcons.brush, _l.imageEditorToolDraw),
      (LucideIcons.type, _l.imageEditorToolText),
      (LucideIcons.grid3x3, _l.imageEditorToolMosaic),
    ];
    final row = Row(
      mainAxisSize: desktop ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < entries.length; i++)
          _toolButton(_Tool.values[i], entries[i].$1, entries[i].$2, desktop),
      ],
    );
    return desktop ? _panel(row, padding: const EdgeInsets.all(5)) : row;
  }

  Widget _toolButton(_Tool tool, IconData icon, String label, bool desktop) {
    final active = _tool == tool;
    final content = [
      Icon(icon, size: 23, color: active ? _accent : Colors.white),
      SizedBox(width: desktop ? 8 : 0, height: desktop ? 0 : 4),
      Text(
        label,
        style: TextStyle(
          fontSize: desktop ? 13 : 11.5,
          color: active ? _accent : Colors.white,
        ),
      ),
    ];
    return IosCardPress(
      key: ValueKey('image-editor-tool-${tool.name}'),
      onTap: _unavailable || _saving ? null : () => _selectTool(tool),
      baseColor: active ? _accent.withValues(alpha: .18) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      padding: EdgeInsets.symmetric(horizontal: desktop ? 14 : 16, vertical: 8),
      child: Opacity(
        opacity: _unavailable ? .35 : 1,
        child: desktop
            ? Row(children: content)
            : Column(mainAxisSize: MainAxisSize.min, children: content),
      ),
    );
  }

  Widget _contextBar() {
    final children = <Widget>[];
    switch (_tool) {
      case _Tool.crop:
        children.add(
          _icon(LucideIcons.rotateCcw, _l.imageEditorRotate, () {
            _change(_doc.copyWith(quarterTurns: _doc.quarterTurns - 1));
            _zoom.value = Matrix4.identity();
          }),
        );
        for (final choice in [
          (null, _l.imageEditorAspectFree),
          (_source!.width / _source!.height, _l.imageEditorAspectOriginal),
          (1.0, '1:1'),
          (4 / 3, '4:3'),
          (16 / 9, '16:9'),
        ]) {
          children.add(
            _chip(choice.$2, _aspect == choice.$1, () {
              setState(() => _setAspect(choice.$1));
            }),
          );
        }
        children.add(
          _icon(
            LucideIcons.flipHorizontal2,
            _l.imageEditorFlip,
            () => _change(_doc.copyWith(flipX: !_doc.flipX)),
          ),
        );
      case _Tool.draw:
        for (final p in [
          (_Pen.pen, LucideIcons.penLine, _l.imageEditorPen),
          (_Pen.arrow, LucideIcons.moveUpRight, _l.imageEditorArrow),
          (_Pen.eraser, LucideIcons.eraser, _l.imageEditorEraser),
        ]) {
          children.add(
            _icon(
              p.$2,
              p.$3,
              () => setState(() => _pen = p.$1),
              selected: _pen == p.$1,
            ),
          );
        }
        children.addAll(_colorButtons());
      case _Tool.text:
        for (final s in [
          (ImageTextStyle.plain, _l.imageEditorTextPlain),
          (ImageTextStyle.outline, _l.imageEditorTextOutline),
          (ImageTextStyle.fill, _l.imageEditorTextFill),
        ]) {
          children.add(_textStyleChoice(s.$1, s.$2));
        }
        children.addAll(_colorButtons());
        children.add(
          _icon(
            _align == TextAlign.left
                ? LucideIcons.alignLeft
                : _align == TextAlign.right
                ? LucideIcons.alignRight
                : LucideIcons.alignCenter,
            _l.imageEditorAlign,
            () => _styleText(
              align: _align == TextAlign.left
                  ? TextAlign.center
                  : _align == TextAlign.center
                  ? TextAlign.right
                  : TextAlign.left,
            ),
          ),
        );
        if (_editingText != null) {
          children.add(
            Tooltip(
              message: _l.imageEditorDone,
              child: IosCardPress(
                onTap: _finishText,
                baseColor: _accent,
                borderRadius: BorderRadius.circular(18),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  LucideIcons.check,
                  size: 20,
                  color: Color(0xff1d2550),
                ),
              ),
            ),
          );
        }
      case _Tool.mosaic:
        children.add(
          _chip(
            _l.imageEditorMosaicBrush,
            !_boxMosaic,
            () => setState(() => _boxMosaic = false),
          ),
        );
        children.add(
          _chip(
            _l.imageEditorMosaicRect,
            _boxMosaic,
            () => setState(() => _boxMosaic = true),
          ),
        );
      case null:
        break;
    }
    return Padding(
      key: ValueKey(_tool),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: _panel(Row(mainAxisSize: MainAxisSize.min, children: children)),
      ),
    );
  }

  Widget _textStyleChoice(ImageTextStyle style, String label) {
    final selected = _textStyle == style;
    const text = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );
    Widget glyph = const Text('A', style: text);
    if (style == ImageTextStyle.outline) {
      glyph = Stack(
        children: [
          Text(
            'A',
            style: text.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = Colors.white,
              color: null,
            ),
          ),
          const Text(
            'A',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      );
    } else if (style == ImageTextStyle.fill) {
      glyph = Container(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'A',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      );
    }
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: IosCardPress(
          onTap: () => _styleText(style: style),
          baseColor: selected ? const Color(0x29ffffff) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          borderRadius: BorderRadius.circular(12),
          child: glyph,
        ),
      ),
    );
  }

  List<Widget> _colorButtons() => [
    const SizedBox(width: 8),
    for (final c in _colors)
      Semantics(
        label: _l.imageEditorColor(c.toRadixString(16).substring(2)),
        selected: c == _color,
        button: true,
        child: GestureDetector(
          onTap: () {
            if (_tool == _Tool.text) {
              _styleText(color: c);
            } else {
              setState(() => _color = c);
            }
          },
          child: Container(
            width: 26,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: c == _color
                  ? Border.all(color: Colors.white, width: 1.5)
                  : null,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(c),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
            ),
          ),
        ),
      ),
  ];
  Widget _panel(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0x14ffffff),
      border: Border.all(color: const Color(0x1affffff), width: .7),
      borderRadius: BorderRadius.circular(22),
    ),
    child: child,
  );
  Widget _chip(String text, bool selected, VoidCallback onTap) => IosCardPress(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    borderRadius: BorderRadius.circular(16),
    baseColor: selected ? Colors.white : Colors.transparent,
    child: Text(
      text,
      style: TextStyle(
        color: selected ? Colors.black : Colors.white70,
        fontSize: 12,
      ),
    ),
  );
  Widget _icon(
    IconData icon,
    String label,
    VoidCallback? action, {
    bool selected = false,
  }) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      enabled: action != null,
      child: IosCardPress(
        onTap: action,
        padding: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(11),
        baseColor: selected ? const Color(0x29ffffff) : Colors.transparent,
        child: Icon(
          icon,
          size: 19,
          color: action == null ? Colors.white24 : Colors.white,
        ),
      ),
    ),
  );
  Widget _button(
    String label,
    VoidCallback? action, {
    Color color = Colors.white,
    Color fill = Colors.transparent,
    bool busy = false,
  }) => IosCardPress(
    onTap: action,
    padding: EdgeInsets.symmetric(
      horizontal: fill == _accent ? 18 : 8,
      vertical: 8,
    ),
    borderRadius: BorderRadius.circular(20),
    baseColor: fill,
    child: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: action == null ? color.withValues(alpha: .4) : color,
              fontSize: 15,
              fontWeight: fill == _accent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
  );
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.geometry, this.crop);
  final ImageEditGeometry geometry;
  final Rect crop;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / geometry.size.width);
    c.transform(geometry.transform.storage);
    final source = geometry.sourceSize;
    final r = Rect.fromLTRB(
      crop.left * source.width,
      crop.top * source.height,
      crop.right * source.width,
      crop.bottom * source.height,
    );
    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & source)
      ..addRect(r);
    c.drawPath(shade, Paint()..color = const Color(0x94000000));
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * geometry.size.width / size.width;
    c.drawRect(r, line);
    for (var i = 1; i < 3; i++) {
      c.drawLine(
        Offset(r.left + r.width * i / 3, r.top),
        Offset(r.left + r.width * i / 3, r.bottom),
        line..color = Colors.white38,
      );
      c.drawLine(
        Offset(r.left, r.top + r.height * i / 3),
        Offset(r.right, r.top + r.height * i / 3),
        line,
      );
    }
    for (final point in [
      r.topLeft,
      r.topCenter,
      r.topRight,
      r.centerRight,
      r.bottomRight,
      r.bottomCenter,
      r.bottomLeft,
      r.centerLeft,
    ]) {
      c.drawCircle(
        point,
        4 * geometry.size.width / size.width,
        Paint()..color = Colors.white,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) =>
      crop != old.crop || geometry != old.geometry;
}

class _SizeWedge extends StatelessWidget {
  const _SizeWedge({
    required this.value,
    required this.onChanged,
    required this.onStart,
    required this.onEnd,
  });
  final VoidCallback onStart, onEnd;
  final double value;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onPanDown: (d) {
      onStart();
      onChanged((1 - d.localPosition.dy / 180).clamp(0, 1));
    },
    onPanEnd: (_) => onEnd(),
    onPanCancel: onEnd,
    onTapUp: (_) => onEnd(),
    onPanUpdate: (d) => onChanged((1 - d.localPosition.dy / 180).clamp(0, 1)),
    child: SizedBox(
      width: 24,
      height: 180,
      child: CustomPaint(painter: _WedgePainter(value.clamp(0, 1))),
    ),
  ).animate().fadeIn(duration: 160.ms);
}

class _WedgePainter extends CustomPainter {
  _WedgePainter(this.value);
  final double value;
  @override
  void paint(Canvas c, Size size) {
    final path = Path()
      ..moveTo(3, 8)
      ..quadraticBezierTo(12, 0, 21, 8)
      ..lineTo(13, 177)
      ..quadraticBezierTo(12, 181, 11, 177)
      ..close();
    c.drawPath(path, Paint()..color = Colors.white24);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white38,
    );
    c.drawCircle(
      Offset(12, 8 + (1 - value) * 164),
      10,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _WedgePainter old) => old.value != value;
}

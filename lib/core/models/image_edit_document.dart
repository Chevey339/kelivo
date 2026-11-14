import 'dart:convert';
import 'dart:ui';

enum ImageStrokeKind { pen, arrow }

enum ImageTextStyle { plain, outline, fill }

/// Geometry uses the uncropped source's width as 1000 units. Cropping never
/// rebases annotations, so changing the crop does not destroy hidden marks.
class ImageEditDocument {
  const ImageEditDocument({
    this.crop,
    this.quarterTurns = 0,
    this.flipX = false,
    this.strokes = const [],
    this.mosaic = const [],
    this.texts = const [],
  });
  final Rect? crop;
  final int quarterTurns;
  final bool flipX;
  final List<ImageEditStroke> strokes;
  final List<ImageMosaicOp> mosaic;
  final List<ImageEditText> texts;

  bool get isEmpty =>
      (crop == null || crop == const Rect.fromLTWH(0, 0, 1, 1)) &&
      quarterTurns % 4 == 0 &&
      !flipX &&
      strokes.isEmpty &&
      mosaic.isEmpty &&
      texts.isEmpty;

  ImageEditDocument copyWith({
    Rect? crop,
    bool clearCrop = false,
    int? quarterTurns,
    bool? flipX,
    List<ImageEditStroke>? strokes,
    List<ImageMosaicOp>? mosaic,
    List<ImageEditText>? texts,
  }) => ImageEditDocument(
    crop: clearCrop ? null : crop ?? this.crop,
    quarterTurns: (quarterTurns ?? this.quarterTurns) % 4,
    flipX: flipX ?? this.flipX,
    strokes: List.unmodifiable(strokes ?? this.strokes),
    mosaic: List.unmodifiable(mosaic ?? this.mosaic),
    texts: List.unmodifiable(texts ?? this.texts),
  );

  bool sameValue(ImageEditDocument other) =>
      identical(this, other) ||
      (isEmpty && other.isEmpty) ||
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  Map<String, dynamic> toJson() => {
    'crop': crop == null ? null : _rectJson(crop!),
    'quarterTurns': quarterTurns,
    'flipX': flipX,
    'strokes': strokes.map((s) => s.toJson()).toList(),
    'mosaic': mosaic.map((m) => m.toJson()).toList(),
    'texts': texts.map((t) => t.toJson()).toList(),
  };
  factory ImageEditDocument.fromJson(Map<String, dynamic> json) =>
      ImageEditDocument(
        crop: json['crop'] == null ? null : _rect(json['crop']),
        quarterTurns: (json['quarterTurns'] as int) % 4,
        flipX: json['flipX'] as bool,
        strokes: [
          for (final s in json['strokes'] as List)
            ImageEditStroke.fromJson(Map<String, dynamic>.from(s as Map)),
        ],
        mosaic: [
          for (final m in json['mosaic'] as List)
            ImageMosaicOp.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
        texts: [
          for (final t in json['texts'] as List)
            ImageEditText.fromJson(Map<String, dynamic>.from(t as Map)),
        ],
      );
}

class ImageEditStroke {
  const ImageEditStroke({
    required this.points,
    required this.width,
    required this.color,
    this.kind = ImageStrokeKind.pen,
  });
  final List<Offset> points;
  final double width;
  final int color;
  final ImageStrokeKind kind;
  Map<String, dynamic> toJson() => {
    'points': _pointsJson(points),
    'width': width,
    'color': color,
    'kind': kind.name,
  };
  factory ImageEditStroke.fromJson(Map<String, dynamic> j) => ImageEditStroke(
    points: _points(j['points']),
    width: (j['width'] as num).toDouble(),
    color: j['color'] as int,
    kind: ImageStrokeKind.values.byName(j['kind'] as String),
  );
}

class ImageMosaicOp {
  const ImageMosaicOp({this.points = const [], this.width = 40, this.rect});
  final List<Offset> points;
  final double width;
  final Rect? rect;
  Map<String, dynamic> toJson() => {
    'points': _pointsJson(points),
    'width': width,
    'rect': rect == null ? null : _rectJson(rect!),
  };
  factory ImageMosaicOp.fromJson(Map<String, dynamic> j) => ImageMosaicOp(
    points: _points(j['points']),
    width: (j['width'] as num).toDouble(),
    rect: j['rect'] == null ? null : _rect(j['rect']),
  );
}

class ImageEditText {
  const ImageEditText({
    required this.text,
    required this.center,
    this.size = 42,
    this.color = 0xffff453a,
    this.style = ImageTextStyle.plain,
    this.align = TextAlign.center,
  });
  final String text;
  final Offset center;
  final double size;
  final int color;
  final ImageTextStyle style;
  final TextAlign align;
  ImageEditText copyWith({
    String? text,
    Offset? center,
    double? size,
    int? color,
    ImageTextStyle? style,
    TextAlign? align,
  }) => ImageEditText(
    text: text ?? this.text,
    center: center ?? this.center,
    size: size ?? this.size,
    color: color ?? this.color,
    style: style ?? this.style,
    align: align ?? this.align,
  );
  Map<String, dynamic> toJson() => {
    'text': text,
    'center': [center.dx, center.dy],
    'size': size,
    'color': color,
    'style': style.name,
    'align': align.name,
  };
  factory ImageEditText.fromJson(Map<String, dynamic> j) => ImageEditText(
    text: j['text'] as String,
    center: _offset(j['center']),
    size: (j['size'] as num).toDouble(),
    color: j['color'] as int,
    style: ImageTextStyle.values.byName(j['style'] as String),
    align: TextAlign.values.byName(j['align'] as String),
  );
}

List<List<double>> _pointsJson(List<Offset> p) => [
  for (final o in p) [o.dx, o.dy],
];
List<Offset> _points(dynamic p) => [for (final o in p as List) _offset(o)];
Offset _offset(dynamic p) =>
    Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
List<double> _rectJson(Rect r) => [r.left, r.top, r.right, r.bottom];
Rect _rect(dynamic r) => Rect.fromLTRB(
  (r[0] as num).toDouble(),
  (r[1] as num).toDouble(),
  (r[2] as num).toDouble(),
  (r[3] as num).toDouble(),
);

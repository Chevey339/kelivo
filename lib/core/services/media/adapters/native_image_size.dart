import 'dart:math' as math;

const standardImageRatios = [
  'auto',
  '1:1',
  '3:2',
  '2:3',
  '4:3',
  '3:4',
  '16:9',
  '9:16',
  '21:9',
];

({int width, int height}) imageDimensions(
  String ratio,
  int squareSide, {
  int multiple = 32,
}) {
  final parts = ratio.split(':');
  final width = parts.length == 2 ? double.tryParse(parts.first) : null;
  final height = parts.length == 2 ? double.tryParse(parts.last) : null;
  final scale = width != null && height != null && width > 0 && height > 0
      ? math.sqrt(width / height)
      : 1.0;
  return (
    width: (squareSide * scale / multiple).round() * multiple,
    height: (squareSide / scale / multiple).round() * multiple,
  );
}

const imageFormats = ['png', 'jpeg', 'webp'];

String imageMime(Object? format) => switch (format) {
  'jpeg' || 'jpg' => 'image/jpeg',
  'webp' => 'image/webp',
  _ => 'image/png',
};

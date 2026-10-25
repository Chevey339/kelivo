import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;

/// Encoded capture tiles remain small and can also be used by the preview.
class ExportImageTile {
  const ExportImageTile({
    required this.bytes,
    required this.width,
    required this.height,
  });
  final Uint8List bytes;
  final int width;
  final int height;
}

class ExportImagePreview {
  const ExportImagePreview({
    required this.width,
    required this.height,
    required this.tiles,
  });
  final int width;
  final int height;
  final List<ExportImageTile> tiles;
}

class ProcessedExportImage {
  const ProcessedExportImage(this.pngBytes, this.preview);
  final Uint8List pngBytes;
  final ExportImagePreview? preview;
}

class ExportImageProcessingRequest {
  const ExportImageProcessingRequest({
    this.singlePngBytes,
    this.outputWidth = 0,
    this.outputHeight = 0,
    this.slices = const [],
    this.preservePadding = 48,
    this.preparePreview = false,
  });
  final Uint8List? singlePngBytes;
  final int outputWidth;
  final int outputHeight;
  final List<({Uint8List bytes, int y})> slices;
  final int preservePadding;
  final bool preparePreview;
}

ProcessedExportImage processExportImage(ExportImageProcessingRequest request) {
  final single = request.singlePngBytes;
  final image = single == null
      ? stitchExportImage(
          request.outputWidth,
          request.outputHeight,
          request.slices,
        )
      : _decode(single);
  final trimmed = _trimExportImageBlankPadding(
    image,
    preservePadding: request.preservePadding,
  );
  final png = single != null && identical(image, trimmed)
      ? single
      : image_lib.encodePng(trimmed);
  ExportImagePreview? preview;
  if (request.preparePreview) {
    final originals = single == null ? request.slices : [(bytes: single, y: 0)];
    var nextY = 0;
    final tiles = <ExportImageTile>[];
    // Uncropped, contiguous native captures need neither decoding nor encoding
    // again for preview. Only read the PNG dimensions from its header.
    if (identical(image, trimmed)) {
      for (final slice in originals) {
        final header = ByteData.sublistView(slice.bytes);
        final w = header.getUint32(16);
        final h = header.getUint32(20);
        if (slice.y != nextY ||
            w != image.width ||
            h > 4096 ||
            nextY + h > image.height) {
          tiles.clear();
          break;
        }
        tiles.add(ExportImageTile(bytes: slice.bytes, width: w, height: h));
        nextY += h;
      }
      if (nextY != image.height) tiles.clear();
    }
    if (tiles.isEmpty) {
      for (var y = 0; y < trimmed.height; y += 4096) {
        final tile = image_lib.copyCrop(
          trimmed,
          x: 0,
          y: y,
          width: trimmed.width,
          height: math.min(4096, trimmed.height - y),
        );
        tiles.add(
          ExportImageTile(
            bytes: image_lib.encodePng(tile),
            width: tile.width,
            height: tile.height,
          ),
        );
      }
    }
    preview = ExportImagePreview(
      width: trimmed.width,
      height: trimmed.height,
      tiles: tiles,
    );
  }
  return ProcessedExportImage(png, preview);
}

image_lib.Image _decode(Uint8List bytes) {
  final image = image_lib.decodePng(bytes);
  if (image == null) throw const FormatException('Invalid export PNG');
  return image;
}

image_lib.Image stitchExportImage(
  int width,
  int height,
  List<({Uint8List bytes, int y})> slices,
) {
  // iOS wide-gamut snapshots may be 16-bit PNGs. Directly assigning their
  // channel values to Uint8List truncates them, including antialiased alpha.
  // Preserve all source precision; mixed 8/16-bit inputs are promoted to 16.
  final format = slices.any((s) => s.bytes.length > 24 && s.bytes[24] == 16)
      ? image_lib.Format.uint16
      : image_lib.Format.uint8;
  final stitched = image_lib.Image(
    width: width,
    height: height,
    format: format,
    numChannels: 4,
  );
  final target = stitched.toUint8List();
  final bytesPerPixel = format == image_lib.Format.uint16 ? 8 : 4;
  for (final slice in slices) {
    var decoded = _decode(slice.bytes);
    stitched.iccProfile ??= decoded.iccProfile;
    if (decoded.format != format ||
        decoded.numChannels != 4 ||
        decoded.hasPalette) {
      decoded = decoded.convert(format: format, numChannels: 4);
    }
    final dstY = math.max(slice.y, 0);
    final srcY = math.max(-slice.y, 0);
    final copyHeight = math.min(decoded.height - srcY, height - dstY);
    final copyWidth = math.min(decoded.width, width);
    if (copyWidth <= 0 || copyHeight <= 0) continue;
    final source = decoded.toUint8List();
    for (var y = 0; y < copyHeight; y++) {
      final dest = (dstY + y) * stitched.rowStride;
      target.setRange(
        dest,
        dest + copyWidth * bytesPerPixel,
        source,
        (srcY + y) * decoded.rowStride,
      );
    }
  }
  return stitched;
}

image_lib.Image _trimExportImageBlankPadding(
  image_lib.Image decoded, {
  required int preservePadding,
}) {
  final background = _exportImageBlankReferencePixel(decoded);
  final width = decoded.width;
  final height = decoded.height;

  int? top;
  for (var y = 0; y < height; y += 1) {
    if (_exportImageRowHasContent(decoded, y, background)) {
      top = y;
      break;
    }
  }
  if (top == null) return decoded;

  var bottom = height - 1;
  for (var y = height - 1; y >= top; y -= 1) {
    if (_exportImageRowHasContent(decoded, y, background)) {
      bottom = y;
      break;
    }
  }

  var left = 0;
  for (var x = 0; x < width; x += 1) {
    if (_exportImageColumnHasContent(decoded, x, top, bottom, background)) {
      left = x;
      break;
    }
  }

  var right = width - 1;
  for (var x = width - 1; x >= left; x -= 1) {
    if (_exportImageColumnHasContent(decoded, x, top, bottom, background)) {
      right = x;
      break;
    }
  }

  final padding = math.max(preservePadding, 0);
  final cropLeft = math.max(left - padding, 0);
  final cropTop = math.max(top - padding, 0);
  final cropRight = math.min(right + padding, width - 1);
  final cropBottom = math.min(bottom + padding, height - 1);

  if (cropLeft == 0 &&
      cropTop == 0 &&
      cropRight == width - 1 &&
      cropBottom == height - 1) {
    return decoded;
  }

  return image_lib.copyCrop(
    decoded,
    x: cropLeft,
    y: cropTop,
    width: cropRight - cropLeft + 1,
    height: cropBottom - cropTop + 1,
  );
}

image_lib.Pixel _exportImageBlankReferencePixel(image_lib.Image image) {
  final corners = [
    image.getPixel(0, 0),
    image.getPixel(image.width - 1, 0),
    image.getPixel(0, image.height - 1),
    image.getPixel(image.width - 1, image.height - 1),
  ];
  for (final pixel in corners) {
    if (pixel.aNormalized * 255 <= 8) return pixel;
  }
  return corners.first;
}

bool _exportImageRowHasContent(
  image_lib.Image image,
  int y,
  image_lib.Pixel background,
) {
  for (var x = 0; x < image.width; x += 1) {
    if (!_exportImageIsBlankPixel(image.getPixel(x, y), background)) {
      return true;
    }
  }
  return false;
}

bool _exportImageColumnHasContent(
  image_lib.Image image,
  int x,
  int top,
  int bottom,
  image_lib.Pixel background,
) {
  for (var y = top; y <= bottom; y += 1) {
    if (!_exportImageIsBlankPixel(image.getPixel(x, y), background)) {
      return true;
    }
  }
  return false;
}

bool _exportImageIsBlankPixel(
  image_lib.Pixel pixel,
  image_lib.Pixel background,
) {
  if (pixel.aNormalized * 255 <= 8) return true;
  if (background.aNormalized * 255 <= 8) return false;
  return _exportImageChannelNear(
        pixel.rNormalized * 255,
        background.rNormalized * 255,
      ) &&
      _exportImageChannelNear(
        pixel.gNormalized * 255,
        background.gNormalized * 255,
      ) &&
      _exportImageChannelNear(
        pixel.bNormalized * 255,
        background.bNormalized * 255,
      ) &&
      _exportImageChannelNear(
        pixel.aNormalized * 255,
        background.aNormalized * 255,
      );
}

bool _exportImageChannelNear(num a, num b) {
  return (a - b).abs() <= 3;
}

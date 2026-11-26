import 'dart:ui' as ui;

typedef ImageDecodeMetadata = ({int width, int height, bool animated});

/// Reads native dimensions and frame count without decoding a frame.
/// Takes ownership of the encoded [buffer].
Future<ImageDecodeMetadata> readImageDecodeMetadata(
  ui.ImmutableBuffer buffer,
) async {
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec(targetWidth: 1, targetHeight: 1);
    return (
      width: descriptor.width,
      height: descriptor.height,
      animated: codec.frameCount > 1,
    );
  } finally {
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

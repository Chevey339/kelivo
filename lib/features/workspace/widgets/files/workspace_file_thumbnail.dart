import 'dart:io';
import 'dart:ui' as ui;

import 'package:Kelivo/features/chat/widgets/workspace_tool_ui.dart'
    show workspaceFileTypeIcon;
import 'package:Kelivo/features/workspace/widgets/files/file_browser_ops.dart';
import 'package:Kelivo/features/workspace/widgets/preview/preview_file_type.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// A cached, static thumbnail loaded only when its file row is built.
class WorkspaceFileThumbnail extends StatelessWidget {
  const WorkspaceFileThumbnail({
    super.key,
    required this.entry,
    required this.iconColor,
    this.size = 32,
    this.iconSize = 20,
  });

  // Bound output pixels, intrinsic pixels and encoded input independently.
  // PNG/GIF decoders may allocate the full source before resizing to the output.
  static const int maxDecodeEdge = 128;
  static const int maxSourcePixels = 16 * 1024 * 1024;
  static const int maxSourceBytes = 64 * 1024 * 1024;

  final FileBrowserEntry entry;
  final Color iconColor;
  final double size;
  final double iconSize;

  static bool supports(FileBrowserEntry entry) =>
      !entry.isDirectory &&
      kPreviewImageExtensions.contains(p.extension(entry.name).toLowerCase());

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Icon(
        workspaceFileTypeIcon(entry.name),
        size: iconSize,
        color: iconColor,
      ),
    );
    final edge = (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      1,
      maxDecodeEdge,
    );
    return SizedBox.square(
      dimension: size,
      child: entry.size <= 0 || entry.size > maxSourceBytes
          ? fallback
          : ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image(
                image: SafeResizeImage.wrap(
                  _ThumbnailFileImage(entry),
                  width: edge,
                  height: edge,
                  fit: SafeResizeFit.cover,
                  maxEdge: maxDecodeEdge,
                  maxPixels: maxDecodeEdge * maxDecodeEdge,
                ),
                width: size,
                height: size,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                excludeFromSemantics: true,
                frameBuilder: (_, child, frame, _) =>
                    frame == null ? fallback : child,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

/// Include the listing's revision in the cache key so overwriting an image and
/// refreshing the directory cannot reuse the previous thumbnail. Only decode
/// the first frame of GIF/WebP files; file lists do not run image animations.
class _ThumbnailFileImage extends FileImage {
  _ThumbnailFileImage(FileBrowserEntry entry)
    : modified = entry.modified.microsecondsSinceEpoch,
      sourceBytes = entry.size,
      super(File(entry.hostPath));

  final int modified;
  final int sourceBytes;

  // Serialize thumbnail decoding, including source buffers, so a newly visible
  // page of images cannot multiply the per-image intermediate memory budget.
  static Future<void>? _pendingDecode;

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) {
    final previous = _pendingDecode;
    final frame = previous == null
        ? _firstFrame(decode)
        : previous.then((_) => _firstFrame(decode));
    late final Future<void> pending;
    void release() {
      if (identical(_pendingDecode, pending)) _pendingDecode = null;
    }

    pending = frame.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _pendingDecode = pending;
    return OneFrameImageStreamCompleter(frame);
  }

  Future<ImageInfo> _firstFrame(ImageDecoderCallback decode) async {
    final length = await file.length();
    if (length <= 0 || length > WorkspaceFileThumbnail.maxSourceBytes) {
      throw StateError('Image is outside the thumbnail input size limit');
    }
    final buffer = await ui.ImmutableBuffer.fromFilePath(file.path);
    try {
      // Read metadata only: creating a codec can already start pixel decoding.
      // Check the same immutable bytes that will be handed to the decoder.
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width <= 0 ||
            descriptor.height <= 0 ||
            descriptor.width * descriptor.height >
                WorkspaceFileThumbnail.maxSourcePixels) {
          throw StateError('Image exceeds the thumbnail source pixel limit');
        }
      } finally {
        descriptor.dispose();
      }
    } catch (_) {
      buffer.dispose();
      rethrow;
    }
    // After validation, SafeResizeImage supplies the output target and its
    // decoder takes ownership of the buffer. Only the codec remains ours.
    final codec = await decode(buffer);
    try {
      final frame = await codec.getNextFrame();
      return ImageInfo(image: frame.image);
    } finally {
      codec.dispose();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is _ThumbnailFileImage &&
      other.file.path == file.path &&
      other.modified == modified &&
      other.sourceBytes == sourceBytes;

  @override
  int get hashCode => Object.hash(file.path, modified, sourceBytes);
}

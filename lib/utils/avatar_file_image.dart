import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'image_decode_metadata.dart';
import 'safe_resize_image.dart';

typedef _AnimationSize = ({int width, int height});

typedef _FileInfo = ({
  DateTime modified,
  int length,
  _AnimationSize? animation,
});

/// Native animated codecs ignore resize targets. Give every presentation of
/// an animated avatar one image stream, while static photos keep their targets.
class AvatarFileImage extends SafeResizeImage {
  AvatarFileImage(
    File file, {
    required int pixels,
    super.fit = SafeResizeFit.cover,
    super.cacheRevision,
  }) : super(FileImage(file), width: pixels, height: pixels);

  // Keep only small metadata records. The decoded pixels belong to ImageCache.
  static final _known = <(String, int?), _FileInfo>{};
  static final _pending = <(String, int?), Future<_FileInfo?>>{};
  late final Future<SafeResizeImageKey> _key = _resolveKey();

  @override
  Future<SafeResizeImageKey> obtainKey(ImageConfiguration configuration) =>
      _key;

  SafeResizeImageKey _keyFor(_AnimationSize? animation) => SafeResizeImageKey(
    providerCacheKey: imageProvider,
    width: animation?.width ?? width,
    height: animation?.height ?? height,
    fit: animation == null ? fit : SafeResizeFit.contain,
    allowUpscaling: false,
    maxEdge: null,
    maxPixels: null,
    cacheRevision: cacheRevision,
  );

  Future<SafeResizeImageKey> _resolveKey() {
    final file = (imageProvider as FileImage).file;
    final id = (file.path, cacheRevision);
    final known = _known.remove(id);
    if (known != null) {
      _known[id] = known;
      final key = _keyFor(known.animation);
      // Match FileImage's synchronous first paint when the frame is cached.
      if (cacheRevision != null ||
          PaintingBinding.instance.imageCache.statusForKey(key).tracked) {
        return SynchronousFuture(key);
      }
    }
    final probe = _pending.putIfAbsent(id, () async {
      try {
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) return null;
        if (known != null &&
            known.modified == stat.modified &&
            known.length == stat.size) {
          return known;
        }
        final result = (
          modified: stat.modified,
          length: stat.size,
          animation: await _animationSize(file),
        );
        _known[id] = result;
        if (_known.length > 128) _known.remove(_known.keys.first);
        return result;
      } catch (_) {
        // FileImage reports missing, unsupported or unreadable sources.
        return null;
      } finally {
        _pending.remove(id);
      }
    });
    return probe.then((info) => _keyFor(info?.animation));
  }

  static Future<_AnimationSize?> _animationSize(File file) async {
    // Large camera JPEGs need only their signature checked.
    final header = await file.openRead(0, 3).first;
    if (header.length == 3 &&
        header[0] == 0xff &&
        header[1] == 0xd8 &&
        header[2] == 0xff) {
      return null;
    }
    final info = await readImageDecodeMetadata(
      await ui.ImmutableBuffer.fromFilePath(file.path),
    );
    return info.animated ? (width: info.width, height: info.height) : null;
  }
}

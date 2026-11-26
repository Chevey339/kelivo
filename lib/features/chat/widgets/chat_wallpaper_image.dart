import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../../utils/image_decode_metadata.dart';
import '../../../utils/safe_resize_image.dart';

/// The base wallpaper and pinned overlays share the source and decoded frames.
class ChatWallpaperImage extends StatefulWidget {
  ChatWallpaperImage({required this.source, this.tint})
    : super(key: ValueKey(source));

  final ImageProvider source;
  final Color? tint;

  @override
  State<ChatWallpaperImage> createState() => _ChatWallpaperImageState();
}

class _ChatWallpaperImageState extends State<ChatWallpaperImage> {
  late final _WallpaperSource _source;
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _source = _WallpaperSource.acquire(widget.source);
  }

  @override
  void dispose() {
    _source.release(_image);
    _source.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    int pixels(double extent) => math.max(1, (extent * dpr / 128).ceil()) * 128;
    final width = pixels(size.width);
    final height = pixels(size.height);
    return FutureBuilder(
      future: _source.loaded,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final info = data.info;
        final target = computeSafeResizeTarget(
          intrinsicWidth: info.width,
          intrinsicHeight: info.height,
          boxWidth: width,
          boxHeight: height,
          fit: SafeResizeFit.cover,
          maxPixels: math.min(2 * width * height, 3840 * 2160),
        );
        final next =
            info.animated ||
                (target.width == info.width && target.height == info.height)
            ? data.image
            : ResizeImage(
                data.image,
                width: target.width,
                height: target.height,
              );
        if (next != _image) {
          _source.release(_image);
          _source.retain(next);
          _image = next;
        }
        return Image(
          image: next,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          color: widget.tint,
          colorBlendMode: widget.tint == null ? null : BlendMode.srcATop,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      },
    );
  }
}

typedef _WallpaperData = ({ImageProvider image, ImageDecodeMetadata info});

class _WallpaperSource {
  _WallpaperSource(this.source);

  static final _active = <ImageProvider, _WallpaperSource>{};
  final ImageProvider source;
  final _sizesInUse = <ImageProvider, int>{};
  Future<_WallpaperData>? _data;
  var _users = 0;
  var _loading = false;

  static _WallpaperSource acquire(ImageProvider source) {
    final entry = _active.putIfAbsent(source, () => _WallpaperSource(source));
    entry._users++;
    return entry;
  }

  void detach() {
    _users--;
    _discardIfUnused();
  }

  void _discardIfUnused() {
    if (_users == 0 && !_loading) _active.remove(source);
  }

  Future<_WallpaperData> get loaded => _data ??= _load();

  Future<_WallpaperData> _load() async {
    _loading = true;
    try {
      return await _read(source);
    } catch (_) {
      // A new mount or rebuild can retry after the network becomes available.
      _data = null;
      rethrow;
    } finally {
      _loading = false;
      _discardIfUnused();
    }
  }

  static Future<_WallpaperData> _read(ImageProvider source) async {
    final ui.ImmutableBuffer buffer;
    if (source is NetworkImage) {
      // Re-decode the same encoded bytes when the window grows or moves to a
      // denser display, even if the connection has since gone offline.
      final bytes = await http.readBytes(Uri.parse(source.url));
      source = MemoryImage(bytes);
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    } else {
      buffer = await ui.ImmutableBuffer.fromFilePath(
        (source as FileImage).file.path,
      );
    }
    return (image: source, info: await readImageDecodeMetadata(buffer));
  }

  void retain(ImageProvider image) =>
      _sizesInUse.update(image, (count) => count + 1, ifAbsent: () => 1);

  void release(ImageProvider? image) {
    if (image == null) return;
    final remaining = _sizesInUse[image]! - 1;
    if (remaining > 0) {
      _sizesInUse[image] = remaining;
      return;
    }
    _sizesInUse.remove(image);
    // Wait until all layers have rebuilt before dropping an obsolete cache
    // entry. Image keeps painting the previous frame while the next one loads.
    scheduleMicrotask(() async {
      final key = await image.obtainKey(ImageConfiguration.empty);
      if (_active[source]?._sizesInUse.containsKey(image) != true) {
        PaintingBinding.instance.imageCache.evict(key, includeLive: false);
      }
    });
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../../utils/avatar_cache.dart';
import '../../utils/safe_resize_image.dart';
import '../../utils/sandbox_path_resolver.dart';

/// A display-sized avatar with one path lookup per source/cache revision.
class AvatarImage extends StatefulWidget {
  const AvatarImage({
    super.key,
    required this.source,
    required this.size,
    required this.fallback,
    this.isNetwork = false,
  });

  final String source;
  final double size;
  final Widget fallback;
  final bool isNetwork;

  @override
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  late Future<String?> _path;
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    _path = _resolve();
    AvatarCache.changes.addListener(_cacheChanged);
  }

  Future<String?> _resolve() => widget.isNetwork
      ? AvatarCache.getPath(widget.source)
      : Future.value(SandboxPathResolver.fix(widget.source));

  void _cacheChanged() {
    if (!widget.isNetwork) return;
    final evicted = _image?.evict();
    // Evict the decoded image as well, even when the downloaded file will have
    // the same name. FutureBuilder ignores results from superseded requests.
    setState(() {
      _path = () async {
        await evicted;
        if (!mounted) return null;
        return _resolve();
      }();
    });
  }

  @override
  void didUpdateWidget(AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.isNetwork != widget.isNetwork) {
      _path = _resolve();
    }
  }

  @override
  void dispose() {
    AvatarCache.changes.removeListener(_cacheChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _path,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return widget.fallback;
      }
      final path = snapshot.data;
      if (path == null && !widget.isNetwork) return widget.fallback;
      final pixels = (widget.size * MediaQuery.devicePixelRatioOf(context))
          .ceil();
      _image = SafeResizeImage.display(
        path == null ? NetworkImage(widget.source) : FileImage(File(path)),
        width: pixels,
        height: pixels,
        fit: SafeResizeFit.cover,
        cacheRevision: widget.isNetwork ? AvatarCache.revision : null,
      );
      return ClipOval(
        child: Image(
          image: _image!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => widget.fallback,
        ),
      );
    },
  );
}

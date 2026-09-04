import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

import 'preview_states.dart';

/// Workspace image preview: zoomable [FileImage] under caller chrome.
///
/// Decodes at native size (no [SafeResizeImage] target). Images larger than
/// the viewport scale down. Images are never upscaled except the tiny-pixel
/// exception: both sides ≤ 16 px render in a 128 px box with
/// [FilterQuality.none].
class ImageFilePreview extends StatefulWidget {
  const ImageFilePreview({super.key, required this.file, this.autoLoad = true});

  static const Key imageKey = ValueKey<String>('file-preview-image');
  static const double minBox = 128;
  static const int tinyMaxEdge = 16;

  final File file;
  final bool autoLoad;

  @override
  ImageFilePreviewState createState() => ImageFilePreviewState();
}

class ImageFilePreviewState extends State<ImageFilePreview> {
  Uint8List? _bytes;
  int _width = 0;
  int _height = 0;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(load());
      });
    }
  }

  @override
  void didUpdateWidget(covariant ImageFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      setState(() {
        _bytes = null;
        _width = 0;
        _height = 0;
        _error = null;
        _loading = true;
      });
      if (widget.autoLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(load());
        });
      }
    }
  }

  @visibleForTesting
  Future<void> load() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _width = width;
        _height = height;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _tiny {
    return _width > 0 &&
        _height > 0 &&
        _width <= ImageFilePreview.tinyMaxEdge &&
        _height <= ImageFilePreview.tinyMaxEdge;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return PreviewError(onRetry: () => unawaited(load()));
    }
    if (_loading || _bytes == null) {
      return const PreviewLoading();
    }
    final l10n = AppLocalizations.of(context)!;
    final bytes = _bytes!;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_tiny) {
          final scale =
              ImageFilePreview.minBox /
              math.max(_width.toDouble(), _height.toDouble());
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 8,
            child: Center(
              child: SizedBox(
                width: _width * scale,
                height: _height * scale,
                child: Image.memory(
                  bytes,
                  key: ImageFilePreview.imageKey,
                  width: _width * scale,
                  height: _height * scale,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _loadFailedIcon(context, l10n),
                ),
              ),
            ),
          );
        }

        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Image.memory(
                  bytes,
                  key: ImageFilePreview.imageKey,
                  scale: 1,
                  width: _width.toDouble(),
                  height: _height.toDouble(),
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => _loadFailedIcon(context, l10n),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _loadFailedIcon(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Icon(
        Lucide.ImageOff,
        size: 48,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        semanticLabel: l10n.imageViewerPageImageLoadFailed,
      ),
    );
  }
}

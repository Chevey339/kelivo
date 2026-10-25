import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/models/mcp_presentation.dart';
import '../../../core/services/mcp/mcp_icon_cache.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../utils/brand_assets.dart';

class McpResolvedIcon extends StatefulWidget {
  const McpResolvedIcon({
    super.key,
    required this.icon,
    required this.sources,
    required this.size,
    required this.color,
    required this.fallback,
    this.inset = true,
  });
  final McpServerIcon? icon;
  final List<String> sources;
  final double size;
  final Color color;
  final Widget fallback;

  /// Avatar tiles leave an inset; bare tool icons fill the whole icon slot.
  final bool inset;

  @override
  State<McpResolvedIcon> createState() => _McpResolvedIconState();
}

class _McpResolvedIconState extends State<McpResolvedIcon> {
  late Future<String?> _path;
  String? _cached;
  final _failedPaths = <String>{};
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(McpResolvedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icon?.type != widget.icon?.type ||
        oldWidget.icon?.value != widget.icon?.value ||
        !listEquals(oldWidget.sources, widget.sources)) {
      _failedPaths.clear();
      _resolve();
    }
  }

  void _resolve() {
    final icon = widget.icon;
    final sources = [...widget.sources];
    _cached = null;
    if (icon?.type == McpIconType.url) sources.insert(0, icon!.value);
    if (icon?.type == McpIconType.lobehub &&
        RegExp(r'^[a-z0-9][a-z0-9-]*$').hasMatch(icon!.value.toLowerCase())) {
      final name = icon.value.toLowerCase();
      sources.insertAll(0, [
        if (!name.endsWith('-color') && !name.endsWith('-text'))
          BrandAssets.lobehubIconUrl('$name-color'),
        BrandAssets.lobehubIconUrl(name),
      ]);
    }
    if (icon?.type == McpIconType.emoji && icon!.value.isNotEmpty ||
        icon?.type == McpIconType.asset &&
            BrandAssets.selectableAssetOrNull(icon!.value) != null) {
      _path = Future.value(null);
      return;
    }
    // A lower-priority cached source must not bypass a custom/declared icon.
    if (icon?.type != McpIconType.file && sources.isNotEmpty) {
      final cached = McpIconCache.peek(sources.first);
      if (!_failedPaths.contains(cached)) _cached = cached;
    }
    _path = () async {
      if (icon?.type == McpIconType.file) {
        final file = await McpIconCache.localPath(icon!.value);
        if (file != null && !_failedPaths.contains(file)) return file;
      }
      for (final source in sources) {
        final file = await McpIconCache.getPath(source);
        if (file != null && !_failedPaths.contains(file)) return file;
      }
      return null;
    }();
  }

  Widget _decodeFailed(String path) {
    if (_failedPaths.add(path)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(_resolve);
      });
    }
    return widget.fallback;
  }

  Color? get _imageTint => widget.color.a < 1
      ? Colors.white.withValues(alpha: widget.color.a)
      : null;

  @override
  Widget build(BuildContext context) {
    final icon = widget.icon;
    final decodeSize = (widget.size * MediaQuery.devicePixelRatioOf(context))
        .ceil();
    if (icon?.type == McpIconType.emoji && icon!.value.isNotEmpty) {
      return DefaultTextStyle.merge(
        style: TextStyle(color: widget.color),
        child: EmojiText(
          icon.value.characters.first,
          fontSize: widget.size * (widget.inset ? .5 : 1),
        ),
      );
    }
    if (icon?.type == McpIconType.asset) {
      final asset = BrandAssets.selectableAssetOrNull(icon!.value);
      if (asset != null) {
        final mono = BrandAssets.assetNeedsDarkInvert(asset);
        return asset.endsWith('.svg')
            ? SvgPicture.asset(
                asset,
                width: widget.size * (widget.inset ? .65 : 1),
                height: widget.size * (widget.inset ? .65 : 1),
                colorFilter: mono
                    ? ColorFilter.mode(widget.color, BlendMode.srcIn)
                    : _imageTint == null
                    ? null
                    : ColorFilter.mode(_imageTint!, BlendMode.modulate),
                clipBehavior: Clip.none,
              )
            : Image.asset(
                asset,
                width: widget.size * (widget.inset ? .65 : 1),
                height: widget.size * (widget.inset ? .65 : 1),
                fit: BoxFit.contain,
                cacheWidth: decodeSize,
                cacheHeight: decodeSize,
                color: _imageTint,
                colorBlendMode: BlendMode.modulate,
              );
      }
    }
    return FutureBuilder<String?>(
      future: _path,
      builder: (context, snapshot) {
        final path = snapshot.data ?? _cached;
        if (path == null) return widget.fallback;
        return path.endsWith('.svg')
            ? SvgPicture.file(
                File(path),
                width: widget.size * (widget.inset ? .65 : 1),
                height: widget.size * (widget.inset ? .65 : 1),
                theme: SvgTheme(
                  currentColor: widget.color.withValues(alpha: 1),
                ),
                colorFilter: _imageTint == null
                    ? null
                    : ColorFilter.mode(_imageTint!, BlendMode.modulate),
                clipBehavior: Clip.none,
                errorBuilder: (_, _, _) => _decodeFailed(path),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(widget.size * .2),
                child: Image.file(
                  File(path),
                  width: widget.size * (widget.inset ? .75 : 1),
                  height: widget.size * (widget.inset ? .75 : 1),
                  fit: BoxFit.cover,
                  cacheWidth: decodeSize,
                  cacheHeight: decodeSize,
                  color: _imageTint,
                  colorBlendMode: BlendMode.modulate,
                  errorBuilder: (_, _, _) => _decodeFailed(path),
                ),
              );
      },
    );
  }
}

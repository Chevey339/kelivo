import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/avatar_config.dart';
import '../../theme/app_font_weights.dart';
import '../../utils/avatar_cache.dart';
import '../../utils/brand_assets.dart';
import '../../utils/sandbox_path_resolver.dart';
import 'emoji_text.dart';

/// Shared image rendering for provider and model avatars.
class ConfigurableAvatar extends StatelessWidget {
  const ConfigurableAvatar({
    super.key,
    this.avatar,
    required this.name,
    this.fallbackAsset,
    this.size = 28,
    this.iconScale = .7,
    this.withBackground = true,
    this.backgroundColor,
  });

  final AvatarConfig? avatar;
  final String name;
  final String? fallbackAsset;
  final double size;
  final double iconScale;
  final bool withBackground;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fallback = _fallback(context);
    final config = avatar;
    Widget content = fallback;
    if (config != null) {
      switch (config.type) {
        case AvatarType.emoji:
          content = EmojiText(
            config.value.characters.first,
            fontSize: size * .5,
            optimizeEmojiAlign: true,
          );
        case AvatarType.icon:
          final asset = BrandAssets.selectableAssetOrNull(config.value);
          if (asset != null) content = _asset(context, asset);
        case AvatarType.file:
          final file = File(SandboxPathResolver.fix(config.value));
          if (file.existsSync()) content = _file(context, file.path, fallback);
        case AvatarType.url:
        case AvatarType.lobehub:
          content = _RemoteAvatar(
            avatar: config,
            builder: (path) => path == null
                ? fallback
                : _file(
                    context,
                    path,
                    fallback,
                    brand: config.type == AvatarType.lobehub,
                    monochrome: config.monochrome,
                  ),
          );
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: withBackground
            ? (backgroundColor ?? cs.primary.withValues(alpha: dark ? .18 : .1))
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: content,
    );
  }

  Widget _fallback(BuildContext context) {
    final asset = fallbackAsset ?? BrandAssets.assetForName(name);
    if (asset != null) return _asset(context, asset);
    return Text(
      name.isEmpty ? '?' : name.characters.first.toUpperCase(),
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: AppFontWeights.emphasis,
        fontSize: size * .43,
      ),
    );
  }

  Widget _asset(BuildContext context, String asset) {
    final tint =
        Theme.of(context).brightness == Brightness.dark &&
        BrandAssets.assetNeedsDarkInvert(asset);
    final color = Theme.of(context).colorScheme.onSurface;
    return asset.endsWith('.svg')
        ? SvgPicture.asset(
            asset,
            width: size * iconScale,
            height: size * iconScale,
            colorFilter: tint ? ColorFilter.mode(color, BlendMode.srcIn) : null,
          )
        : Image.asset(
            asset,
            width: size * iconScale,
            height: size * iconScale,
            fit: BoxFit.contain,
            color: tint ? color : null,
            colorBlendMode: tint ? BlendMode.srcIn : null,
          );
  }

  Widget _file(
    BuildContext context,
    String path,
    Widget fallback, {
    bool brand = false,
    bool monochrome = false,
  }) {
    final dimension = brand ? size * iconScale : size;
    if (path.toLowerCase().endsWith('.svg')) {
      final color = Theme.of(context).colorScheme.onSurface;
      return SvgPicture.file(
        File(path),
        width: dimension,
        height: dimension,
        fit: BoxFit.contain,
        theme: SvgTheme(currentColor: color),
        colorFilter: brand && monochrome
            ? ColorFilter.mode(color, BlendMode.srcIn)
            : null,
        errorBuilder: (_, __, ___) => fallback,
      );
    }
    return Image.file(
      File(path),
      width: dimension,
      height: dimension,
      fit: brand ? BoxFit.contain : BoxFit.cover,
      // Crop photo frames without clipping brand artwork or error fallbacks.
      frameBuilder: brand ? null : (_, child, _, _) => ClipOval(child: child),
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _RemoteAvatar extends StatefulWidget {
  const _RemoteAvatar({required this.avatar, required this.builder});
  final AvatarConfig avatar;
  final Widget Function(String?) builder;

  @override
  State<_RemoteAvatar> createState() => _RemoteAvatarState();
}

class _RemoteAvatarState extends State<_RemoteAvatar> {
  late Future<String?> _path;

  List<String> get _urls => widget.avatar.type == AvatarType.lobehub
      ? BrandAssets.lobehubIconUrls(
          widget.avatar.value,
          monochrome: widget.avatar.monochrome,
        )
      : [widget.avatar.value];

  Future<String?> _load({bool retryFailed = false}) async {
    for (final url in _urls) {
      final path =
          AvatarCache.peek(url) ??
          await AvatarCache.getPath(url, retryFailed: retryFailed);
      if (path != null) return path;
    }
    return null;
  }

  void _reload() => setState(() => _path = _load());

  @override
  void initState() {
    super.initState();
    _path = _load(retryFailed: true);
    AvatarCache.changes.addListener(_reload);
  }

  @override
  void didUpdateWidget(_RemoteAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatar != widget.avatar) _path = _load(retryFailed: true);
  }

  @override
  void dispose() {
    AvatarCache.changes.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      key: ValueKey(widget.avatar),
      future: _path,
      initialData: _urls.map(AvatarCache.peek).whereType<String>().firstOrNull,
      builder: (_, snapshot) => widget.builder(snapshot.data),
    );
  }
}

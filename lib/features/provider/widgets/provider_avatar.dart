import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../utils/avatar_cache.dart';
import '../../../utils/sandbox_path_resolver.dart';
import '../../../utils/brand_assets.dart';
import '../../../shared/widgets/emoji_text.dart';
import '../../../theme/app_font_weights.dart';

class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.providerKey,
    required this.displayName,
    this.size = 28,
    this.onTap,
  });

  final String providerKey;
  final String displayName;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cfg = context.watch<SettingsProvider>().getProviderConfig(
      providerKey,
      defaultName: displayName,
    );

    Widget avatar;
    final type = cfg.avatarType;
    final value = cfg.avatarValue;

    if (type == 'emoji' && value != null && value.isNotEmpty) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: EmojiText(
          value.characters.take(1).toString(),
          fontSize: size * 0.5,
          optimizeEmojiAlign: true,
        ),
      );
    } else if (type == 'url' && value != null && value.isNotEmpty) {
      avatar = FutureBuilder<String?>(
        future: AvatarCache.getPath(value),
        builder: (ctx, snap) {
          final p = snap.data;
          if (p != null && File(p).existsSync()) {
            return ClipOval(
              child: Image(
                image: FileImage(File(p)),
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            );
          }
          return ClipOval(
            child: Image.network(
              value,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _brandOrInitial(
                context,
                cfg.name.isNotEmpty ? cfg.name : displayName,
              ),
            ),
          );
        },
      );
    } else if (type == 'file' && value != null && value.isNotEmpty) {
      final fixed = SandboxPathResolver.fix(value);
      final f = File(fixed);
      if (f.existsSync()) {
        avatar = ClipOval(
          child: Image(
            image: FileImage(f),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } else {
        avatar = _brandOrInitial(
          context,
          cfg.name.isNotEmpty ? cfg.name : displayName,
        );
      }
    } else if (type == 'icon' && value != null && value.isNotEmpty) {
      // 校验资源在白名单中，防止非法值
      final asset = BrandAssets.selectableAssetOrNull(value);
      if (asset == null) {
        avatar = _brandOrInitial(
          context,
          cfg.name.isNotEmpty ? cfg.name : displayName,
        );
      } else {
        avatar = _assetAvatar(context, asset);
      }
    } else if (type == 'lobehub' && value != null && value.isNotEmpty) {
      avatar = _lobehubAvatar(
        context,
        value,
        cfg.name.isNotEmpty ? cfg.name : displayName,
      );
    } else {
      avatar = _brandOrInitial(
        context,
        cfg.name.isNotEmpty ? cfg.name : displayName,
      );
    }

    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 0.5,
        ),
      ),
      child: avatar,
    );

    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }

  Widget _brandOrInitial(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    if (asset == null) {
      return Container(
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
          style: TextStyle(
            color: cs.primary,
            fontWeight: AppFontWeights.emphasis,
            fontSize: size * 0.42,
          ),
        ),
      );
    }
    final mono = isDark && BrandAssets.assetNeedsDarkInvert(asset);
    return CircleAvatar(
      backgroundColor: isDark
          ? Colors.white10
          : cs.primary.withValues(alpha: 0.1),
      child: asset.endsWith('.svg')
          ? SvgPicture.asset(
              asset,
              width: size * 0.7,
              height: size * 0.7,
              colorFilter: mono
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : null,
            )
          : Image.asset(
              asset,
              width: size * 0.7,
              height: size * 0.7,
              fit: BoxFit.contain,
              color: mono ? Colors.white : null,
              colorBlendMode: mono ? BlendMode.srcIn : null,
            ),
    );
  }

  // 优先彩色版本（{name}-color.svg），不存在则回退单色（{name}.svg）。
  // 用户已显式指定 -color/-text 变体时按原样请求。
  Future<String?> _resolveLobehubPath(String iconName) async {
    final n = iconName.trim().toLowerCase();
    if (n.isEmpty) return null;
    if (!n.endsWith('-color') && !n.endsWith('-text')) {
      final colored = await AvatarCache.getPath(
        BrandAssets.lobehubIconUrl('$n-color'),
      );
      if (colored != null) return colored;
    }
    return AvatarCache.getPath(BrandAssets.lobehubIconUrl(n));
  }

  // 同步命中已缓存的 LobeHub 图标路径，命中则可直接渲染、避免 FutureBuilder 闪烁。
  // 镜像 _resolveLobehubPath 的彩色优先/单色回退顺序。
  String? _peekLobehubPath(String iconName) {
    final n = iconName.trim().toLowerCase();
    if (n.isEmpty) return null;
    if (!n.endsWith('-color') && !n.endsWith('-text')) {
      final colored = AvatarCache.peek(BrandAssets.lobehubIconUrl('$n-color'));
      if (colored != null) return colored;
    }
    return AvatarCache.peek(BrandAssets.lobehubIconUrl(n));
  }

  Widget _lobehubAvatar(
    BuildContext context,
    String iconName,
    String fallbackName,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white10 : cs.primary.withValues(alpha: 0.1);
    // 缓存命中时同步渲染，避免每次 rebuild 都经历 FutureBuilder 的 loading 态。
    final cached = _peekLobehubPath(iconName);
    if (cached != null) {
      return _lobehubTile(context, cached, bg);
    }
    return FutureBuilder<String?>(
      // 优先彩色版本，回退单色；复用头像缓存（下载并缓存 SVG，失败返回 null）
      future: _resolveLobehubPath(iconName),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return CircleAvatar(backgroundColor: bg);
        }
        final p = snap.data;
        if (p == null || !File(p).existsSync()) {
          return _brandOrInitial(context, fallbackName);
        }
        return _lobehubTile(context, p, bg);
      },
    );
  }

  Widget _lobehubTile(BuildContext context, String path, Color bg) {
    final cs = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: bg,
      child: SvgPicture.file(
        File(path),
        width: size * 0.7,
        height: size * 0.7,
        fit: BoxFit.contain,
        // LobeHub 单色图标用 fill="currentColor"，注入前景色以适配明暗；
        // 带 -color 的彩色图标有固定填充，不受影响
        theme: SvgTheme(currentColor: cs.onSurface),
        placeholderBuilder: (_) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _assetAvatar(BuildContext context, String asset) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSvg = asset.endsWith('.svg');
    final needsMono = isDark && BrandAssets.assetNeedsDarkInvert(asset);
    return CircleAvatar(
      backgroundColor: isDark
          ? Colors.white10
          : cs.primary.withValues(alpha: 0.1),
      child: isSvg
          ? SvgPicture.asset(
              asset,
              width: size * 0.7,
              height: size * 0.7,
              colorFilter: needsMono
                  ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                  : null,
            )
          : Image.asset(
              asset,
              width: size * 0.7,
              height: size * 0.7,
              fit: BoxFit.contain,
              color: needsMono ? Colors.white : null,
              colorBlendMode: needsMono ? BlendMode.srcIn : null,
            ),
    );
  }
}

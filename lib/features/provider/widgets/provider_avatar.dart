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

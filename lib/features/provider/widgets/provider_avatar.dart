import '../../../theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/configurable_avatar.dart';

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

    final avatar = ConfigurableAvatar(
      avatar: cfg.avatar,
      name: cfg.name.isNotEmpty ? cfg.name : displayName,
      size: size,
    );

    final portrait = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.onSurface.withValues(alpha: isDark ? 0.24 : 0.12),
          width: 0.5,
        ),
      ),
      child: avatar,
    );

    final child = cfg.isOAuth
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              portrait,
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: size < 30 ? 7 : 10,
                  height: size < 30 ? 7 : 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        cfg.oauthCredentials == null ||
                            cfg.oauthCredentials!.requiresLogin
                        ? cs.error
                        : context.appColors.success,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          )
        : portrait;
    if (onTap == null) return child;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: child,
    );
  }
}

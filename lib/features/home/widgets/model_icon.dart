import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../shared/widgets/configurable_avatar.dart';
import '../../../utils/brand_assets.dart';

/// Widget that displays the current model's icon.
///
/// Prefers the model's custom avatar, then its recognized brand, then the
/// provider's custom/brand avatar, and finally the model's initial.
class CurrentModelIcon extends StatelessWidget {
  const CurrentModelIcon({
    super.key,
    required this.providerKey,
    required this.modelId,
    this.size = 28,
    this.withBackground = true,
    this.iconScale = .5,
    this.backgroundColor,
  });

  final String? providerKey;
  final String? modelId;
  final double iconScale;
  final double size; // outer diameter
  final bool withBackground; // whether to draw circular background
  final Color? backgroundColor; // override background color if provided

  @override
  Widget build(BuildContext context) {
    if (providerKey == null || modelId == null) return const SizedBox.shrink();
    final cfg = context.select<SettingsProvider?, ProviderConfig?>(
      (settings) => settings?.providerConfigs[providerKey],
    );
    final upstreamId = cfg == null
        ? modelId!
        : ModelSpecResolver.instance.spec(cfg, modelId!).upstreamId;
    final modelAsset = BrandAssets.assetForName(upstreamId);
    return ConfigurableAvatar(
      avatar:
          cfg?.modelAvatar(modelId!) ??
          (modelAsset == null ? cfg?.avatar : null),
      name: modelId!,
      fallbackAsset:
          modelAsset ??
          BrandAssets.assetForName(cfg?.name ?? '') ??
          BrandAssets.assetForName(providerKey!),
      size: size,
      iconScale: iconScale,
      withBackground: withBackground,
      backgroundColor: backgroundColor,
    );
  }
}

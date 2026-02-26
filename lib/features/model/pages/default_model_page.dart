import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/settings_provider.dart';
import '../widgets/model_select_sheet.dart';
import '../widgets/ocr_prompt_sheet.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/services/haptics.dart';

class DefaultModelPage extends StatelessWidget {
  const DefaultModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    String displayText({String? providerKey, String? modelId, String? fbProvider, String? fbModel}) {
      // If not explicitly set, use current model text
      if (providerKey == null || modelId == null) return l10n.defaultModelPageUseCurrentModel;
      try {
        final cfg = settings.getProviderConfig(providerKey);
        final ov = cfg.modelOverrides[modelId] as Map?;
        if (ov != null) {
          final overrideName = (ov['name'] as String?)?.trim();
          if (overrideName != null && overrideName.isNotEmpty) return overrideName;
          final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
          if (apiId != null && apiId.isNotEmpty) return apiId;
        }
        return modelId;
      } catch (_) {
        return fbModel ?? providerKey;
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.defaultModelPageBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.defaultModelPageTitle),
        actions: const [SizedBox(width: 12)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _ModelCard(
            icon: Lucide.MessageCircle,
            title: l10n.defaultModelPageChatModelTitle,
            subtitle: l10n.defaultModelPageChatModelSubtitle,
            modelProvider: settings.currentModelProvider,
            modelId: settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetCurrentModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setCurrentModel(sel.providerKey, sel.modelId);
              }
            },
          ),
          const SizedBox(height: 16),
          _ModelCard(
            icon: Lucide.NotebookTabs,
            title: l10n.defaultModelPageTitleModelTitle,
            subtitle: l10n.defaultModelPageTitleModelSubtitle,
            modelProvider: settings.titleModelProvider,
            modelId: settings.titleModelId,
            fallbackProvider: settings.currentModelProvider,
            fallbackModelId: settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetTitleModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setTitleModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => _showTitlePromptSheet(context),
          ),
          const SizedBox(height: 16),
          _ModelCard(
            icon: Lucide.FileText,
            title: l10n.defaultModelPageSummaryModelTitle,
            subtitle: l10n.defaultModelPageSummaryModelSubtitle,
            modelProvider: settings.summaryModelProvider,
            modelId: settings.summaryModelId,
            fallbackProvider: settings.titleModelProvider ?? settings.currentModelProvider,
            fallbackModelId: settings.titleModelId ?? settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetSummaryModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setSummaryModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => _showSummaryPromptSheet(context),
          ),
          const SizedBox(height: 16),
          _ModelCard(
            icon: Lucide.package2,
            title: l10n.defaultModelPageCompressModelTitle,
            subtitle: l10n.defaultModelPageCompressModelSubtitle,
            modelProvider: settings.compressModelProvider,
            modelId: settings.compressModelId,
            fallbackProvider: settings.summaryModelProvider ?? settings.titleModelProvider ?? settings.currentModelProvider,
            fallbackModelId: settings.summaryModelId ?? settings.titleModelId ?? settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetCompressModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setCompressModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => _showCompressPromptSheet(context),
          ),
          const SizedBox(height: 16),
          _ModelCard(
            icon: Lucide.Languages,
            title: l10n.defaultModelPageTranslateModelTitle,
            subtitle: l10n.defaultModelPageTranslateModelSubtitle,
            modelProvider: settings.translateModelProvider,
            modelId: settings.translateModelId,
            fallbackProvider: settings.currentModelProvider,
            fallbackModelId: settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetTranslateModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setTranslateModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => _showTranslatePromptSheet(context),
          ),
          const SizedBox(height: 16),
          _ModelCard(
            icon: Lucide.Eye,
            title: l10n.defaultModelPageOcrModelTitle,
            subtitle: l10n.defaultModelPageOcrModelSubtitle,
            modelProvider: settings.ocrModelProvider,
            modelId: settings.ocrModelId,
            fallbackProvider: settings.currentModelProvider,
            fallbackModelId: settings.currentModelId,
            onReset: () async {
              await context.read<SettingsProvider>().resetOcrModel();
            },
            onPick: () async {
              final sel = await showModelSelector(context);
              if (sel != null) {
                await context.read<SettingsProvider>().setOcrModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => showOcrPromptSheet(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showTitlePromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.titlePrompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.defaultModelPageTitlePromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await settings.resetTitlePrompt();
                        controller.text = settings.titlePrompt;
                      },
                      child: Text(l10n.defaultModelPageResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await settings.setTitlePrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.defaultModelPageSave),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l10n.defaultModelPageTitleVars('{content}', '{locale}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTranslatePromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.translatePrompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.defaultModelPageTranslatePromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await settings.resetTranslatePrompt();
                        controller.text = settings.translatePrompt;
                      },
                      child: Text(l10n.defaultModelPageResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await settings.setTranslatePrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.defaultModelPageSave),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l10n.defaultModelPageTranslateVars('{source_text}', '{target_lang}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSummaryPromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.summaryPrompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.defaultModelPageSummaryPromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await settings.resetSummaryPrompt();
                        controller.text = settings.summaryPrompt;
                      },
                      child: Text(l10n.defaultModelPageResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await settings.setSummaryPrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.defaultModelPageSave),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l10n.defaultModelPageSummaryVars('{previous_summary}', '{user_messages}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCompressPromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settings.compressPrompt);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(
                    hintText: l10n.defaultModelPageCompressPromptHint,
                    filled: true,
                    fillColor: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.5))),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await settings.resetCompressPrompt();
                        controller.text = settings.compressPrompt;
                      },
                      child: Text(l10n.defaultModelPageResetDefault),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () async {
                        await settings.setCompressPrompt(controller.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      child: Text(l10n.defaultModelPageSave),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l10n.defaultModelPageCompressVars('{content}', '{locale}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.modelProvider,
    required this.modelId,
    required this.onPick,
    this.onReset,
    this.fallbackProvider,
    this.fallbackModelId,
    this.configAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? modelProvider;
  final String? modelId;
  final String? fallbackProvider;
  final String? fallbackModelId;
  final VoidCallback onPick;
  final VoidCallback? onReset;
  final VoidCallback? configAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    // Check if using fallback (not explicitly set)
    final usingFallback = modelProvider == null || modelId == null;

    // Use fallback values if needed
    final effectiveProvider = modelProvider ?? fallbackProvider;
    final effectiveModelId = modelId ?? fallbackModelId;

    String? providerName;
    String? modelDisplay;
    if (effectiveProvider != null && effectiveModelId != null) {
      final cfg = settings.getProviderConfig(effectiveProvider);
      providerName = cfg.name.isNotEmpty ? cfg.name : effectiveProvider;
      final ov = cfg.modelOverrides[effectiveModelId] as Map?;
      if (ov != null) {
        final overrideName = (ov['name'] as String?)?.trim();
        if (overrideName != null && overrideName.isNotEmpty) {
          modelDisplay = overrideName;
        } else {
          final apiId = (ov['apiModelId'] ?? ov['api_model_id'])?.toString().trim();
          modelDisplay = (apiId != null && apiId.isNotEmpty) ? apiId : effectiveModelId;
        }
      } else {
        modelDisplay = effectiveModelId;
      }
    }

    // Override display text if using fallback
    if (usingFallback) {
      modelDisplay = l10n.defaultModelPageUseCurrentModel;
    }
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (onReset != null && !usingFallback)
                  Tooltip(
                    message: l10n.defaultModelPageResetDefault,
                    child: _TactileIconButton(
                      icon: Lucide.RotateCcw,
                      color: cs.onSurface,
                      size: 20,
                      onTap: onReset!,
                    ),
                  ),
                if (configAction != null)
                  _TactileIconButton(
                    icon: Lucide.Settings,
                    color: cs.onSurface,
                    size: 20,
                    onTap: configAction!,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // description under title
            Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            _TactileRow(
              onTap: onPick,
              builder: (pressed) {
                final bg = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
                final pressedBg = Color.alphaBlend(overlay, bg);
                return AnimatedScale(
                  scale: pressed ? 0.98 : 1.0,
                  duration: const Duration(milliseconds: 110),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: pressed ? pressedBg : bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _BrandAvatar(name: modelDisplay ?? (providerName ?? '?'), size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            modelDisplay ?? (providerName ?? '-'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({required this.name, this.size = 20});
  final String name;
  final double size;



  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    Widget inner;
    if (asset != null) {
      if (asset.endsWith('.svg')) {
        final isColorful = asset.contains('color');
        final dark = Theme.of(context).brightness == Brightness.dark;
        final ColorFilter? tint = (dark && !isColorful)
            ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
            : null;
        inner = SvgPicture.asset(
          asset,
          width: size * 0.62,
          height: size * 0.62,
          colorFilter: tint,
        );
      } else {
        inner = Image.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
      }
    } else {
      inner = Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: size * 0.42));
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : cs.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

// --- iOS-style helpers ---

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 6, thickness: 0.6, indent: 54, endIndent: 12, color: cs.outlineVariant.withOpacity(0.18));
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.onLongPress, this.semanticLabel, this.size = 22, this.haptics = true});
  final IconData icon; final Color color; final VoidCallback onTap; final VoidCallback? onLongPress; final String? semanticLabel; final double size; final bool haptics;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withOpacity(0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base, semanticLabel: widget.semanticLabel);
    return Semantics(
      button: true, label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { if (widget.haptics) Haptics.light(); widget.onTap(); },
        onLongPress: widget.onLongPress == null ? null : () { if (widget.haptics) Haptics.light(); widget.onLongPress!.call(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}

Widget _iosNavRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  String? detailText,
  Widget? accessory,
  VoidCallback? onTap,
}) {
  final cs = Theme.of(context).colorScheme; final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap, haptics: true,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.8);
      return _AnimatedPressColor(
        pressed: pressed, base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(children: [
              SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (detailText != null) Padding(padding: const EdgeInsets.only(right: 6), child: Text(detailText, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (accessory != null) accessory,
              if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
            ]),
          );
        },
      );
    },
  );
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap, this.haptics = true});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final bool haptics;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _setPressed(bool v) { if (_pressed != v) setState(() => _pressed = v); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
      onTapUp: widget.onTap == null
          ? null
          : (_) async {
              // Keep pressed state for a short moment to avoid flicker
              await Future.delayed(const Duration(milliseconds: 60));
              if (mounted) _setPressed(false);
            },
      onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
      onTap: widget.onTap == null ? null : () {
        if (widget.haptics && context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: widget.builder(_pressed),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:re_editor/re_editor.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../core/providers/settings_provider.dart';
import '../widgets/model_select_sheet.dart';
import '../widgets/ocr_prompt_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/brand_assets.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/input_height_constraints.dart';
import '../../../shared/widgets/plain_text_code_editor.dart';

class DefaultModelPage extends StatelessWidget {
  const DefaultModelPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

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
              if (!context.mounted) return;
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
              if (!context.mounted) return;
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
              if (!context.mounted) return;
              if (sel != null) {
                await context.read<SettingsProvider>().setSummaryModel(sel.providerKey, sel.modelId);
              }
            },
            configAction: () => _showSummaryPromptSheet(context),
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
              if (!context.mounted) return;
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
              if (!context.mounted) return;
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
    final controller = CodeLineEditingController.fromText(settings.titlePrompt);
    try {
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
                      decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (innerCtx) {
                      final rawMaxPromptHeight = computeInputMaxHeight(
                        context: innerCtx,
                        reservedHeight: 220,
                        softCapFraction: 0.45,
                        minHeight: 120,
                      );
                      // TODO: computeInputMaxHeight already enforces minHeight; remove this redundant clamp and consider extracting the repeated Builder/ConstrainedBox/TextField pattern.
                      final maxPromptHeight = rawMaxPromptHeight < 120 ? 120.0 : rawMaxPromptHeight;
                      return ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 120, maxHeight: maxPromptHeight),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PlainTextCodeEditor(
                            controller: controller,
                            autofocus: false,
                            hint: l10n.defaultModelPageTitlePromptHint,
                            padding: const EdgeInsets.all(12),
                            fontSize: 14,
                            fontHeight: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if resetTitlePrompt fails.
                          await settings.resetTitlePrompt();
                          controller.text = settings.titlePrompt;
                        },
                        child: Text(l10n.defaultModelPageResetDefault),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if setTitlePrompt fails.
                          await settings.setTitlePrompt(controller.text.trim());
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.defaultModelPageSave),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.defaultModelPageTitleVars('{content}', '{locale}'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showTranslatePromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = CodeLineEditingController.fromText(settings.translatePrompt);
    try {
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
                      decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (innerCtx) {
                      final rawMaxPromptHeight = computeInputMaxHeight(
                        context: innerCtx,
                        reservedHeight: 220,
                        softCapFraction: 0.45,
                        minHeight: 120,
                      );
                      // TODO: computeInputMaxHeight already enforces minHeight; remove this redundant clamp and consider extracting the repeated Builder/ConstrainedBox/TextField pattern.
                      final maxPromptHeight = rawMaxPromptHeight < 120 ? 120.0 : rawMaxPromptHeight;
                      return ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 120, maxHeight: maxPromptHeight),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PlainTextCodeEditor(
                            controller: controller,
                            autofocus: false,
                            hint: l10n.defaultModelPageTranslatePromptHint,
                            padding: const EdgeInsets.all(12),
                            fontSize: 14,
                            fontHeight: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if resetTranslatePrompt fails.
                          await settings.resetTranslatePrompt();
                          controller.text = settings.translatePrompt;
                        },
                        child: Text(l10n.defaultModelPageResetDefault),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if setTranslatePrompt fails.
                          await settings.setTranslatePrompt(controller.text.trim());
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.defaultModelPageSave),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.defaultModelPageTranslateVars('{source_text}', '{target_lang}'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showSummaryPromptSheet(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.read<SettingsProvider>();
    final controller = CodeLineEditingController.fromText(settings.summaryPrompt);
    try {
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
                      decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (innerCtx) {
                      final rawMaxPromptHeight = computeInputMaxHeight(
                        context: innerCtx,
                        reservedHeight: 220,
                        softCapFraction: 0.45,
                        minHeight: 120,
                      );
                      // TODO: computeInputMaxHeight already enforces minHeight; remove this redundant clamp and consider extracting the repeated Builder/ConstrainedBox/TextField pattern.
                      final maxPromptHeight = rawMaxPromptHeight < 120 ? 120.0 : rawMaxPromptHeight;
                      return ConstrainedBox(
                        constraints: BoxConstraints(minHeight: 120, maxHeight: maxPromptHeight),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF2F3F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: PlainTextCodeEditor(
                            controller: controller,
                            autofocus: false,
                            hint: l10n.defaultModelPageSummaryPromptHint,
                            padding: const EdgeInsets.all(12),
                            fontSize: 14,
                            fontHeight: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if resetSummaryPrompt fails.
                          await settings.resetSummaryPrompt();
                          controller.text = settings.summaryPrompt;
                        },
                        child: Text(l10n.defaultModelPageResetDefault),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          // TODO: Add try/catch and user feedback if setSummaryPrompt fails.
                          await settings.setSummaryPrompt(controller.text.trim());
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.defaultModelPageSave),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.defaultModelPageSummaryVars('{previous_summary}', '{user_messages}'), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      controller.dispose();
    }
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
    final baseBg = isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96);
    return Container(
      decoration: BoxDecoration(
        color: baseBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06), width: 0.6),
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
            Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 4),
            const SizedBox(height: 8),
            _TactileRow(
              onTap: onPick,
              builder: (pressed) {
                final bg = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
                final overlay = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05);
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
        color: isDark ? Colors.white10 : cs.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.size = 22});
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color; final pressColor = base.withValues(alpha: 0.7);
    final icon = Icon(widget.icon, size: widget.size, color: _pressed ? pressColor : base);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () { Haptics.light(); widget.onTap(); },
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), child: icon),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
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
        if (context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
        widget.onTap!.call();
      },
      child: widget.builder(_pressed),
    );
  }
}

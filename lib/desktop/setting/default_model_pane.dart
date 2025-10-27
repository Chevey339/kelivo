import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../features/model/widgets/model_select_sheet.dart';
import '../../utils/brand_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:characters/characters.dart';

class DesktopDefaultModelPane extends StatelessWidget {
  const DesktopDefaultModelPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.defaultModelPageTitle,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              _ModelCard(
                icon: lucide.Lucide.MessageCircle,
                title: l10n.defaultModelPageChatModelTitle,
                subtitle: l10n.defaultModelPageChatModelSubtitle,
                modelProvider: settings.currentModelProvider,
                modelId: settings.currentModelId,
                onPick: () async {
                  final sel = await showModelSelector(context);
                  if (sel != null) {
                    await context.read<SettingsProvider>().setCurrentModel(sel.providerKey, sel.modelId);
                  }
                },
              ),

              const SizedBox(height: 16),
              _ModelCard(
                icon: lucide.Lucide.NotebookTabs,
                title: l10n.defaultModelPageTitleModelTitle,
                subtitle: l10n.defaultModelPageTitleModelSubtitle,
                modelProvider: settings.titleModelProvider,
                modelId: settings.titleModelId,
                fallbackProvider: settings.currentModelProvider,
                fallbackModelId: settings.currentModelId,
                onPick: () async {
                  final sel = await showModelSelector(context);
                  if (sel != null) {
                    await context.read<SettingsProvider>().setTitleModel(sel.providerKey, sel.modelId);
                  }
                },
                configAction: () => _showTitlePromptDialog(context),
              ),

              const SizedBox(height: 16),
              _ModelCard(
                icon: lucide.Lucide.Languages,
                title: l10n.defaultModelPageTranslateModelTitle,
                subtitle: l10n.defaultModelPageTranslateModelSubtitle,
                modelProvider: settings.translateModelProvider,
                modelId: settings.translateModelId,
                fallbackProvider: settings.currentModelProvider,
                fallbackModelId: settings.currentModelId,
                onPick: () async {
                  final sel = await showModelSelector(context);
                  if (sel != null) {
                    await context.read<SettingsProvider>().setTranslateModel(sel.providerKey, sel.modelId);
                  }
                },
                configAction: () => _showTranslatePromptDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTitlePromptDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: sp.titlePrompt);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                      _SmallIconBtn(icon: lucide.Lucide.X, onTap: () => Navigator.of(ctx).maybePop()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 160),
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      minLines: 8,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(ctx).copyWith(hintText: l10n.defaultModelPageTitlePromptHint),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DeskIosButton(label: l10n.defaultModelPageResetDefault, filled: false, dense: true, onTap: () async {
                        await sp.resetTitlePrompt();
                        ctrl.text = sp.titlePrompt;
                      }),
                      const Spacer(),
                      _DeskIosButton(label: l10n.defaultModelPageSave, filled: true, dense: true, onTap: () async {
                        await sp.setTitlePrompt(ctrl.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).maybePop();
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.defaultModelPageTitleVars('{content}', '{locale}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTranslatePromptDialog(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final sp = context.read<SettingsProvider>();
    final ctrl = TextEditingController(text: sp.translatePrompt);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(l10n.defaultModelPagePromptLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                      _SmallIconBtn(icon: lucide.Lucide.X, onTap: () => Navigator.of(ctx).maybePop()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 160),
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      minLines: 8,
                      style: const TextStyle(fontSize: 14),
                      decoration: _deskInputDecoration(ctx).copyWith(hintText: l10n.defaultModelPageTranslatePromptHint),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DeskIosButton(label: l10n.defaultModelPageResetDefault, filled: false, dense: true, onTap: () async {
                        await sp.resetTranslatePrompt();
                        ctrl.text = sp.translatePrompt;
                      }),
                      const Spacer(),
                      _DeskIosButton(label: l10n.defaultModelPageSave, filled: true, dense: true, onTap: () async {
                        await sp.setTranslatePrompt(ctrl.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).maybePop();
                      }),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.defaultModelPageTranslateVars('{source_text}', '{target_lang}'), style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModelCard extends StatefulWidget {
  const _ModelCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.modelProvider,
    required this.modelId,
    required this.onPick,
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
  final VoidCallback? configAction;

  @override
  State<_ModelCard> createState() => _ModelCardState();
}

class _ModelCardState extends State<_ModelCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.read<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    final usingFallback = widget.modelProvider == null || widget.modelId == null;
    final effectiveProvider = widget.modelProvider ?? widget.fallbackProvider;
    final effectiveModelId = widget.modelId ?? widget.fallbackModelId;

    String? providerName;
    String? modelDisplay;
    if (effectiveProvider != null && effectiveModelId != null) {
      final cfg = settings.getProviderConfig(effectiveProvider);
      providerName = cfg.name.isNotEmpty ? cfg.name : effectiveProvider;
      final ov = cfg.modelOverrides[effectiveModelId] as Map?;
      modelDisplay = (ov != null && (ov['name'] as String?)?.isNotEmpty == true) ? (ov['name'] as String) : effectiveModelId;
    }
    if (usingFallback) {
      modelDisplay = l10n.defaultModelPageUseCurrentModel;
    }

    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06);
    final rowBase = isDark ? Colors.white10 : const Color(0xFFF2F3F5);
    final hoverOverlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);

    return Container(
      decoration: BoxDecoration(color: baseBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor, width: 0.6)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 18, color: cs.onSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (widget.configAction != null) _SmallIconBtn(icon: lucide.Lucide.Settings, onTap: widget.configAction!),
              ],
            ),
            const SizedBox(height: 6),
            Text(widget.subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),

            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hover = true),
              onExit: (_) => setState(() => _hover = false),
              child: GestureDetector(
                onTap: widget.onPick,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _hover ? Color.alphaBlend(hoverOverlay, rowBase) : rowBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _BrandCircle(name: modelDisplay ?? (providerName ?? '?'), size: 24),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({required this.label, required this.filled, required this.dense, required this.onTap});
  final String label; final bool filled; final bool dense; final VoidCallback onTap;
  @override State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false; bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.filled ? cs.primary : cs.onSurface.withOpacity(0.8);
    final textColor = widget.filled ? Colors.white : baseColor;
    final bg = widget.filled
        ? (_hover ? cs.primary.withOpacity(0.92) : cs.primary)
        : (_hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent);
    final borderColor = widget.filled ? Colors.transparent : cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: widget.dense ? 8 : 12, horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Text(widget.label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: widget.dense ? 13 : 14)),
          ),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;
  @override State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover ? (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)) : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _BrandCircle extends StatelessWidget {
  const _BrandCircle({required this.name, this.size = 22});
  final String name; final double size;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme; final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = BrandAssets.assetForName(name);
    Widget inner;
    if (asset == null) {
      inner = Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w800, fontSize: size * 0.45));
    } else if (asset.endsWith('.svg')) {
      inner = SvgPicture.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
    } else {
      inner = Image.asset(asset, width: size * 0.62, height: size * 0.62, fit: BoxFit.contain);
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: isDark ? Colors.white10 : cs.primary.withOpacity(0.10), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: inner,
    );
  }
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2), width: 0.8),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.2), width: 0.8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary.withOpacity(0.45), width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

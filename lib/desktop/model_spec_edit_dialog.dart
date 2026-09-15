import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/models/model_spec.dart';
import '../core/providers/settings_provider.dart';
import '../features/model/widgets/model_spec_form/advanced_section.dart';
import '../features/model/widgets/model_spec_form/basic_section.dart';
import '../features/model/widgets/model_spec_form/builtin_tools_section.dart';
import '../features/model/widgets/model_spec_form/limits_pricing_section.dart';
import '../features/model/widgets/model_spec_form/modality_ability_section.dart';
import '../features/model/widgets/model_spec_form/model_spec_form_controller.dart';
import '../features/model/widgets/model_spec_form/reasoning_section.dart';
import '../features/model/widgets/model_spec_form/strategy_section.dart';
import '../icons/lucide_adapter.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/ios_tactile.dart';
import '../shared/widgets/section_card.dart';
import '../shared/widgets/snackbar.dart';
import '../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

Future<bool?> showDesktopModelSpecEditDialog(
  BuildContext context, {
  required String providerKey,
  required String modelKey,
}) {
  return _openDialog(
    context,
    providerKey: providerKey,
    modelKey: modelKey,
    isNew: false,
  );
}

Future<bool?> showDesktopCreateModelSpecDialog(
  BuildContext context, {
  required String providerKey,
}) {
  return _openDialog(
    context,
    providerKey: providerKey,
    modelKey: '',
    isNew: true,
  );
}

Future<bool?> _openDialog(
  BuildContext context, {
  required String providerKey,
  required String modelKey,
  required bool isNew,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
    barrierLabel: 'model-spec-edit-dialog',
    pageBuilder: (ctx, _, __) => _ModelSpecEditDialogBody(
      providerKey: providerKey,
      modelKey: modelKey,
      isNew: isNew,
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum _SpecSection {
  basic,
  modalities,
  reasoning,
  strategy,
  limits,
  advanced,
  tools,
}

class _ModelSpecEditDialogBody extends StatefulWidget {
  const _ModelSpecEditDialogBody({
    required this.providerKey,
    required this.modelKey,
    required this.isNew,
  });

  final String providerKey;
  final String modelKey;
  final bool isNew;

  @override
  State<_ModelSpecEditDialogBody> createState() =>
      _ModelSpecEditDialogBodyState();
}

class _ModelSpecEditDialogBodyState extends State<_ModelSpecEditDialogBody> {
  late final ModelSpecFormController _controller;
  _SpecSection _section = _SpecSection.basic;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = ModelSpecFormController(
      config: settings.getProviderConfig(widget.providerKey),
      modelKey: widget.modelKey,
      isNew: widget.isNew,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final error = _controller.validate(l10n);
    if (error != null) {
      showAppSnackBar(context, message: error, type: NotificationType.error);
      return;
    }
    final settings = context.read<SettingsProvider>();
    final ok = await _controller.save(settings);
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(
        context,
        message: l10n.modelDetailSheetSaveFailedMessage,
        type: NotificationType.error,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final media = MediaQuery.sizeOf(context);
    final width = math.min(760.0, math.max(0.0, media.width - 48));
    final height = math.min(640.0, math.max(0.0, media.height - 48));

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop(false);
        },
      },
      child: Focus(
        autofocus: true,
        child: Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Material(
              color: context.overlaySurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? cs.onSurface.withValues(alpha: 0.08)
                      : cs.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final spec = _controller.spec;
                    final showTools =
                        spec.type == ModelType.chat &&
                        ModelBuiltInToolTiles.forConfig(
                          cfg: _controller.config,
                          l10n: l10n,
                        ).isNotEmpty;
                    final sections = _visibleSections(spec, showTools);
                    var section = _section;
                    if (!sections.contains(section) ||
                        !_sectionEnabled(section, spec)) {
                      section = _SpecSection.basic;
                      if (_section != section) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _section = section);
                        });
                      }
                    }
                    return Column(
                      key: const ValueKey('model-spec-edit-dialog'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(cs, l10n),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 180,
                                child: ColoredBox(
                                  color: context.appColors.surfaceFill,
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      8,
                                      8,
                                      8,
                                      12,
                                    ),
                                    children: [
                                      for (final item in sections)
                                        _NavItem(
                                          key: ValueKey(
                                            'model-spec-nav-${item.name}',
                                          ),
                                          label: _sectionLabel(l10n, item),
                                          subtitle: _sectionSubtitle(
                                            l10n,
                                            item,
                                            spec,
                                          ),
                                          selected: item == section,
                                          enabled: _sectionEnabled(item, spec),
                                          onTap: () =>
                                              setState(() => _section = item),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: cs.outlineVariant.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                              Expanded(
                                child: ColoredBox(
                                  color: context.overlaySurface,
                                  child: ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      16,
                                    ),
                                    children: [
                                      SectionCard(child: _sectionBody(section)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _footer(l10n),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs, AppLocalizations l10n) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.isNew
                    ? l10n.modelDetailSheetAddModel
                    : l10n.modelDetailSheetEditModel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: AppFontWeights.emphasis,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IosIconButton(
              icon: Lucide.X,
              size: 20,
              minSize: 36,
              tooltip: l10n.mcpPageClose,
              semanticLabel: l10n.mcpPageClose,
              color: cs.onSurface.withValues(alpha: 0.9),
              onTap: () => Navigator.of(context).maybePop(false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          const Spacer(),
          _DeskTextButton(
            label: l10n.modelDetailSheetCancelButton,
            onTap: () => Navigator.of(context).maybePop(false),
          ),
          const SizedBox(width: 8),
          _PrimaryDeskButton(
            key: const ValueKey('model-spec-confirm'),
            icon: widget.isNew ? Lucide.Plus : Lucide.Check,
            label: widget.isNew
                ? l10n.modelDetailSheetAddButton
                : l10n.modelDetailSheetConfirmButton,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  Widget _sectionBody(_SpecSection section) {
    return switch (section) {
      _SpecSection.basic => BasicSection(controller: _controller),
      _SpecSection.modalities => ModalityAbilitySection(
        controller: _controller,
      ),
      _SpecSection.reasoning => ReasoningSection(controller: _controller),
      _SpecSection.strategy => StrategySection(controller: _controller),
      _SpecSection.limits => LimitsPricingSection(controller: _controller),
      _SpecSection.advanced => AdvancedSection(controller: _controller),
      _SpecSection.tools => BuiltinToolsSection(controller: _controller),
    };
  }

  List<_SpecSection> _visibleSections(ModelSpec spec, bool showTools) {
    return [
      _SpecSection.basic,
      _SpecSection.modalities,
      if (spec.type != ModelType.embedding) ...[
        _SpecSection.reasoning,
        _SpecSection.strategy,
      ],
      _SpecSection.limits,
      _SpecSection.advanced,
      if (showTools) _SpecSection.tools,
    ];
  }

  bool _sectionEnabled(_SpecSection section, ModelSpec spec) {
    return switch (section) {
      _SpecSection.reasoning || _SpecSection.strategy => spec.supportsReasoning,
      _ => true,
    };
  }

  String _sectionLabel(AppLocalizations l10n, _SpecSection section) {
    return switch (section) {
      _SpecSection.basic => l10n.modelDetailSheetBasicTab,
      _SpecSection.modalities => l10n.modelSpecFormModalitiesSection,
      _SpecSection.reasoning => l10n.modelSpecFormReasoningSection,
      _SpecSection.strategy => l10n.modelSpecFormStrategySection,
      _SpecSection.limits => l10n.modelSpecFormLimitsPricingSection,
      _SpecSection.advanced => l10n.modelDetailSheetAdvancedTab,
      _SpecSection.tools => l10n.modelDetailSheetBuiltinToolsTab,
    };
  }

  String? _sectionSubtitle(
    AppLocalizations l10n,
    _SpecSection section,
    ModelSpec spec,
  ) {
    if ((section == _SpecSection.reasoning ||
            section == _SpecSection.strategy) &&
        !spec.supportsReasoning) {
      return l10n.reasoningLevelNoReasoning;
    }
    return null;
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.selected && widget.enabled;
    final bg = selected
        ? cs.primary.withValues(alpha: 0.14)
        : (_hover && widget.enabled
              ? cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04)
              : Colors.transparent);
    final fg = selected
        ? cs.primary
        : cs.onSurface.withValues(alpha: widget.enabled ? 0.88 : 0.45);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected
                        ? AppFontWeights.semibold
                        : AppFontWeights.medium,
                    color: fg,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeskTextButton extends StatefulWidget {
  const _DeskTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_DeskTextButton> createState() => _DeskTextButtonState();
}

class _DeskTextButtonState extends State<_DeskTextButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed
        ? cs.onSurface.withValues(alpha: 0.08)
        : (_hover ? cs.onSurface.withValues(alpha: 0.05) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.82),
              fontWeight: AppFontWeights.semibold,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryDeskButton extends StatefulWidget {
  const _PrimaryDeskButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_PrimaryDeskButton> createState() => _PrimaryDeskButtonState();
}

class _PrimaryDeskButtonState extends State<_PrimaryDeskButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = _pressed
        ? cs.primary.withValues(alpha: 0.85)
        : (_hover ? cs.primary.withValues(alpha: 0.92) : cs.primary);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: cs.onPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

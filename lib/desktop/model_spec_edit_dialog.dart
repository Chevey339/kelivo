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
import '../shared/widgets/snackbar.dart';
import 'widgets/desktop_form_dialog.dart';

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

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).maybePop(false);
        },
      },
      child: Focus(
        autofocus: true,
        child: DesktopFormDialog(
          key: const ValueKey('model-spec-edit-dialog'),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DesktopFormDialogHeader(
                    title: widget.isNew
                        ? l10n.modelDetailSheetAddModel
                        : l10n.modelDetailSheetEditModel,
                    closeTooltip: l10n.mcpPageClose,
                    closeSemanticLabel: l10n.mcpPageClose,
                    onClose: () => Navigator.of(context).maybePop(false),
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 188,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            children: [
                              for (final item in sections)
                                DesktopFormDialogNavItem(
                                  key: ValueKey('model-spec-nav-${item.name}'),
                                  label: _sectionLabel(l10n, item),
                                  subtitle: _sectionSubtitle(l10n, item, spec),
                                  selected: item == section,
                                  enabled: _sectionEnabled(item, spec),
                                  onTap: () => setState(() => _section = item),
                                ),
                            ],
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 0.5,
                          color: cs.outlineVariant.withValues(alpha: 0.12),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            children: [_sectionBody(section)],
                          ),
                        ),
                      ],
                    ),
                  ),
                  DesktopFormDialogFooter(
                    secondaryLabel: l10n.modelDetailSheetCancelButton,
                    onSecondary: () => Navigator.of(context).maybePop(false),
                    primaryKey: const ValueKey('model-spec-confirm'),
                    primaryIcon: widget.isNew ? Lucide.Plus : Lucide.Check,
                    primaryLabel: widget.isNew
                        ? l10n.modelDetailSheetAddButton
                        : l10n.modelDetailSheetConfirmButton,
                    onPrimary: _save,
                  ),
                ],
              );
            },
          ),
        ),
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

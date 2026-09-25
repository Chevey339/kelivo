import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/model_spec.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/snackbar.dart';
import '../widgets/model_spec_form/advanced_section.dart';
import '../widgets/model_spec_form/basic_section.dart';
import '../widgets/model_spec_form/builtin_tools_section.dart';
import '../widgets/model_spec_form/limits_pricing_section.dart';
import '../widgets/model_spec_form/modality_ability_section.dart';
import '../widgets/model_spec_form/model_spec_form_controller.dart';
import '../widgets/model_spec_form/reasoning_section.dart';
import '../widgets/model_spec_form/strategy_section.dart';

Future<bool?> showModelSpecEditPage(
  BuildContext context, {
  required String providerKey,
  required String modelKey,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ModelSpecEditPage(
        providerKey: providerKey,
        modelKey: modelKey,
        isNew: false,
      ),
    ),
  );
}

Future<bool?> showCreateModelSpecPage(
  BuildContext context, {
  required String providerKey,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => ModelSpecEditPage(
        providerKey: providerKey,
        modelKey: '',
        isNew: true,
      ),
    ),
  );
}

class ModelSpecEditPage extends StatefulWidget {
  const ModelSpecEditPage({
    super.key,
    required this.providerKey,
    required this.modelKey,
    required this.isNew,
  });

  final String providerKey;
  final String modelKey;
  final bool isNew;

  @override
  State<ModelSpecEditPage> createState() => _ModelSpecEditPageState();
}

class _ModelSpecEditPageState extends State<ModelSpecEditPage> {
  late final ModelSpecFormController _controller;
  int _tab = 0;

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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            size: 22,
            semanticLabel: l10n.settingsPageBackButton,
            minSize: 44,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          widget.isNew
              ? l10n.modelDetailSheetAddModel
              : l10n.modelDetailSheetEditModel,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IosIconButton(
            key: const ValueKey('model-spec-save'),
            icon: widget.isNew ? Lucide.Plus : Lucide.Check,
            size: 22,
            minSize: 44,
            tooltip: widget.isNew
                ? l10n.modelDetailSheetAddButton
                : l10n.modelDetailSheetConfirmButton,
            semanticLabel: widget.isNew
                ? l10n.modelDetailSheetAddButton
                : l10n.modelDetailSheetConfirmButton,
            onTap: _save,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SegmentedTabs(
                  tabs: [
                    SegmentedTab(label: l10n.modelDetailSheetBasicTab),
                    SegmentedTab(label: l10n.reasoningLevelSheetTitle),
                    SegmentedTab(label: l10n.modelDetailSheetAdvancedTab),
                  ],
                  index: _tab,
                  onChanged: (index) => setState(() => _tab = index),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  children: _tabChildren(l10n),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _tabChildren(AppLocalizations l10n) {
    switch (_tab) {
      case 1:
        return _reasoningTab(l10n);
      case 2:
        return _advancedTab(l10n);
      default:
        return _basicTab(l10n);
    }
  }

  List<Widget> _basicTab(AppLocalizations l10n) {
    return [
      IosSectionHeader(text: l10n.modelDetailSheetBasicTab, first: true),
      SectionCard(child: BasicSection(controller: _controller)),
      IosSectionHeader(text: l10n.modelDetailSheetInputModesLabel),
      SectionCard(child: ModalityAbilitySection(controller: _controller)),
      IosSectionHeader(text: l10n.modelSpecFormLimitsSection),
      SectionCard(child: LimitsPricingSection(controller: _controller)),
    ];
  }

  List<Widget> _reasoningTab(AppLocalizations l10n) {
    if (!_controller.spec.supportsReasoning) {
      return [
        IosSectionHeader(text: l10n.reasoningLevelSheetTitle, first: true),
        SectionCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Text(l10n.reasoningLevelNoReasoning),
          ),
        ),
      ];
    }
    return [
      IosSectionHeader(text: l10n.modelSpecFormReasoningSection, first: true),
      SectionCard(child: ReasoningSection(controller: _controller)),
      IosSectionHeader(text: l10n.modelSpecFormStrategySection),
      SectionCard(child: StrategySection(controller: _controller)),
    ];
  }

  List<Widget> _advancedTab(AppLocalizations l10n) {
    return [
      IosSectionHeader(text: l10n.modelSpecFormAdvancedSection, first: true),
      SectionCard(child: AdvancedSection(controller: _controller)),
      if (_controller.spec.type == ModelType.chat) ...[
        IosSectionHeader(text: l10n.modelDetailSheetBuiltinToolsTab),
        SectionCard(child: BuiltinToolsSection(controller: _controller)),
      ],
    ];
  }
}

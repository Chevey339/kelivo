import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/models/model_spec.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/api/builtin_tools.dart';
import '../../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ios_switch.dart';
import '../../../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'model_spec_form_controller.dart';
import 'spec_field_header.dart';

/// One built-in tool switch on a model's tools tab.
class ModelBuiltInToolTile {
  const ModelBuiltInToolTile({
    required this.name,
    required this.title,
    required this.desc,
    this.available = true,
  });

  final String name;
  final String title;
  final String desc;

  /// False for a tool the provider's current API mode cannot run: the switch
  /// stays visible but reads off and locked.
  final bool available;
}

class ModelBuiltInToolTiles {
  /// Switches for [cfg]'s tools tab, in display order. Kept in step with
  /// [BuiltInToolsHelper.modelSettingsToolNames], which decides whether the tab
  /// shows at all.
  static List<ModelBuiltInToolTile> forConfig({
    required ProviderConfig cfg,
    required AppLocalizations l10n,
  }) {
    final kind = ProviderConfig.classify(
      cfg.id,
      explicitType: cfg.providerType,
    );
    final responses = cfg.useResponseApi == true;
    switch (kind) {
      case ProviderKind.google:
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.urlContext,
            title: l10n.modelDetailSheetUrlContextTool,
            desc: l10n.modelDetailSheetUrlContextToolDescription,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeExecution,
            title: l10n.modelDetailSheetCodeExecutionTool,
            desc: l10n.modelDetailSheetCodeExecutionToolDescription,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.youtube,
            title: l10n.modelDetailSheetYoutubeTool,
            desc: l10n.modelDetailSheetYoutubeToolDescription,
          ),
        ];
      case ProviderKind.claude:
        // Anthropic hosts these tools itself, so only its own endpoint can run
        // them; a Claude-compatible relay is offered the switch but locked out.
        final official = BuiltInToolsHelper.isOfficialAnthropicEndpoint(cfg);
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.webFetch,
            title: l10n.modelDetailSheetWebFetchTool,
            desc: l10n.modelDetailSheetClaudeWebFetchToolDescription,
            available: official,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeExecution,
            title: l10n.modelDetailSheetCodeExecutionTool,
            desc: l10n.modelDetailSheetClaudeCodeExecutionToolDescription,
            available: official,
          ),
        ];
      case ProviderKind.openai:
        if (BuiltInToolsHelper.isOpenRouterProvider(cfg)) {
          return <ModelBuiltInToolTile>[
            ModelBuiltInToolTile(
              name: BuiltInToolNames.codeInterpreter,
              title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
              desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
              available: responses,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.webFetch,
              title: l10n.modelDetailSheetWebFetchTool,
              desc: l10n.modelDetailSheetOpenrouterWebFetchToolDescription,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.imageGeneration,
              title: l10n.modelDetailSheetOpenaiImageGenerationTool,
              desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
            ),
            ModelBuiltInToolTile(
              name: BuiltInToolNames.shell,
              title: l10n.modelDetailSheetOpenrouterShellTool,
              desc: l10n.modelDetailSheetOpenrouterShellToolDescription,
              available: responses,
            ),
          ];
        }
        return <ModelBuiltInToolTile>[
          ModelBuiltInToolTile(
            name: BuiltInToolNames.codeInterpreter,
            title: l10n.modelDetailSheetOpenaiCodeInterpreterTool,
            desc: l10n.modelDetailSheetOpenaiCodeInterpreterToolDescription,
            available: responses,
          ),
          ModelBuiltInToolTile(
            name: BuiltInToolNames.imageGeneration,
            title: l10n.modelDetailSheetOpenaiImageGenerationTool,
            desc: l10n.modelDetailSheetOpenaiImageGenerationToolDescription,
            available: responses,
          ),
        ];
    }
  }
}

class BuiltinToolsSection extends StatelessWidget {
  const BuiltinToolsSection({super.key, required this.controller});

  final ModelSpecFormController controller;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final cfg = settings.getProviderConfig(controller.providerId);
    final l10n = AppLocalizations.of(context)!;
    final tiles = ModelBuiltInToolTiles.forConfig(cfg: cfg, l10n: l10n);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (tiles.isEmpty || controller.spec.type != ModelType.chat) {
          return const SizedBox.shrink();
        }
        final cs = Theme.of(context).colorScheme;
        final kind = ProviderConfig.classify(
          cfg.id,
          explicitType: cfg.providerType,
        );
        final isOpenRouter = BuiltInToolsHelper.isOpenRouterProvider(cfg);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SpecFieldHeader(
              label: l10n.modelDetailSheetBuiltinToolsTab,
              source: controller.isBuiltInToolsOverridden
                  ? SpecSource.override
                  : SpecSource.fallback,
              overridden: controller.isBuiltInToolsOverridden,
              onReset: controller.resetBuiltInTools,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                l10n.modelDetailSheetBuiltinToolsDescription,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ),
            if (kind == ProviderKind.openai &&
                !isOpenRouter &&
                cfg.useResponseApi != true)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  l10n.modelDetailSheetOpenaiBuiltinToolsResponsesOnlyHint,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            for (final tool in tiles)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: _ToolTile(
                  title: tool.title,
                  desc: tool.desc,
                  value:
                      tool.available && controller.isBuiltInToolOn(tool.name),
                  onChanged: tool.available
                      ? (on) => controller.toggleBuiltInTool(tool.name, on)
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final disabled = onChanged == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: context.appColors.surfaceFill,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFontWeights.semibold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IosSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

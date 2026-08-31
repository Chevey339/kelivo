import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/tool_schema_override.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/tools/built_in_tool_catalog.dart';
import '../../../features/home/services/local_tools_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import 'tool_schema_editor_page.dart';

class ToolSchemaSettingsPage extends StatefulWidget {
  const ToolSchemaSettingsPage({super.key});

  @override
  State<ToolSchemaSettingsPage> createState() => _ToolSchemaSettingsPageState();
}

class _ToolSchemaSettingsPageState extends State<ToolSchemaSettingsPage> {
  @override
  void initState() {
    super.initState();
    DeviceLocalTools.prefetchIosCapabilities().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    final catalog = BuiltInToolCatalog.entries(
      lang: settings.resolvedMemoryPromptLang,
      legacyMemoryMode: settings.legacyMemoryMode,
    );

    Future<void> confirmResetAll() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.toolSchemaSettingsResetAllTitle),
          content: Text(l10n.toolSchemaSettingsResetAllMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.toolSchemaSettingsCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: cs.error),
              child: Text(l10n.toolSchemaSettingsResetAllConfirm),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await context.read<SettingsProvider>().resetAllToolSchemaOverrides();
      }
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.toolSchemaSettingsPageTitle),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Lucide.MoreVertical, color: cs.onSurface),
            onSelected: (value) {
              if (value == 'resetAll') confirmResetAll();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'resetAll',
                child: Text(l10n.toolSchemaSettingsResetAll),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          for (final group in BuiltInToolGroup.values)
            ..._groupSection(
              context,
              group: group,
              entries: catalog.where((e) => e.group == group).toList(),
              overrides: settings.toolSchemaOverrides,
            ),
        ],
      ),
    );
  }

  List<Widget> _groupSection(
    BuildContext context, {
    required BuiltInToolGroup group,
    required List<BuiltInToolCatalogEntry> entries,
    required Map<String, ToolSchemaOverride> overrides,
  }) {
    if (entries.isEmpty) return const [];
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final title = switch (group) {
      BuiltInToolGroup.search => l10n.toolSchemaSettingsGroupSearch,
      BuiltInToolGroup.memory => l10n.toolSchemaSettingsGroupMemory,
      BuiltInToolGroup.local => l10n.toolSchemaSettingsGroupLocal,
    };
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      if (group == BuiltInToolGroup.memory)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            l10n.toolSchemaSettingsMemoryLangNote,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      SectionCard(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.6,
                color: cs.outlineVariant.withValues(alpha: 0.18),
              ),
            _ToolRow(
              entry: entries[i],
              schemaOverride: overrides[entries[i].name],
            ),
          ],
        ],
      ),
      const SizedBox(height: 12),
    ];
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.entry, this.schemaOverride});

  final BuiltInToolCatalogEntry entry;
  final ToolSchemaOverride? schemaOverride;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final modified = schemaOverride != null && !schemaOverride!.isEmpty;
    final effective = modified
        ? (schemaOverride!.description?.trim().isNotEmpty == true
              ? schemaOverride!.description!
              : entry.defaultDescription ?? '')
        : (entry.defaultDescription ?? '');
    final summary = _firstLine(effective);

    return IosCardPress(
      borderRadius: BorderRadius.zero,
      onTap: () async {
        final result = await Navigator.of(context).push<ToolSchemaOverride?>(
          MaterialPageRoute(
            builder: (_) => ToolSchemaEditorPage(
              toolName: entry.name,
              defaultDefinition: entry.defaultDefinition,
              initialOverride: schemaOverride,
            ),
          ),
        );
        if (result == null || !context.mounted) return;
        await context.read<SettingsProvider>().setToolSchemaOverride(
          entry.name,
          result,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                            fontWeight: AppFontWeights.medium,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (modified) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.toolSchemaSettingsModified,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: AppFontWeights.medium,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Lucide.ChevronRight,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

String _firstLine(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\r?\n')).first;
}

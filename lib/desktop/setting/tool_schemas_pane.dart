import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/tool_schema_override.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/tools/built_in_tool_catalog.dart';
import '../../features/home/services/local_tools_service.dart';
import '../../features/settings/widgets/tool_schema_editor_form.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

class DesktopToolSchemasPane extends StatefulWidget {
  const DesktopToolSchemasPane({super.key});

  @override
  State<DesktopToolSchemasPane> createState() => _DesktopToolSchemasPaneState();
}

class _DesktopToolSchemasPaneState extends State<DesktopToolSchemasPane> {
  String? _selectedName;
  int _formEpoch = 0;
  SettingsProvider? _settings;

  @override
  void initState() {
    super.initState();
    DeviceLocalTools.prefetchIosCapabilities().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings = context.read<SettingsProvider>();
  }

  @override
  void dispose() {
    unawaited(_settings?.flushPendingToolSchemaOverridePersist());
    super.dispose();
  }

  Future<void> _confirmResetAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
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
      if (mounted) setState(() => _formEpoch++);
    }
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
    if (catalog.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedName = catalog.any((e) => e.name == _selectedName)
        ? _selectedName!
        : catalog.first.name;
    final selected = catalog.firstWhere((e) => e.name == selectedName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.toolSchemaSettingsPageTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.regular,
                      color: cs.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmResetAll(context),
                  child: Text(l10n.toolSchemaSettingsResetAll),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 280,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.only(right: 12),
                      children: [
                        for (final group in BuiltInToolGroup.values)
                          ..._groupTiles(
                            context,
                            group: group,
                            entries: catalog
                                .where((e) => e.group == group)
                                .toList(),
                            selectedName: selectedName,
                            overrides: settings.toolSchemaOverrides,
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 16),
                    child: ToolSchemaEditorForm(
                      key: ValueKey('${selected.name}:$_formEpoch'),
                      defaultDefinition: selected.defaultDefinition,
                      initialOverride:
                          settings.toolSchemaOverrides[selected.name],
                      onChanged: (value) {
                        settings.setToolSchemaOverrideLive(
                          selected.name,
                          value,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _groupTiles(
    BuildContext context, {
    required BuiltInToolGroup group,
    required List<BuiltInToolCatalogEntry> entries,
    required String selectedName,
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
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: AppFontWeights.semibold,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
      if (group == BuiltInToolGroup.memory)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Text(
            l10n.toolSchemaSettingsMemoryLangNote,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      for (final entry in entries)
        _ToolTile(
          entry: entry,
          selected: entry.name == selectedName,
          modified:
              overrides[entry.name] != null && !overrides[entry.name]!.isEmpty,
          onTap: () {
            unawaited(_settings?.flushPendingToolSchemaOverridePersist());
            setState(() => _selectedName = entry.name);
          },
        ),
    ];
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.entry,
    required this.selected,
    required this.modified,
    required this.onTap,
  });

  final BuiltInToolCatalogEntry entry;
  final bool selected;
  final bool modified;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? cs.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: selected
                          ? AppFontWeights.semibold
                          : AppFontWeights.medium,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (modified)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

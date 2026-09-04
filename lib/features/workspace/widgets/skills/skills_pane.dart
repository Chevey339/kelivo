import 'dart:async';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_detail.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_settings_rows.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

/// Embeddable skills list for the Skills page and desktop settings.
///
/// When [showHeader] is false the pane renders the list only — no ＋ row.
class SkillsPane extends StatefulWidget {
  const SkillsPane({super.key, this.padding, this.showHeader = true});

  final EdgeInsetsGeometry? padding;
  final bool showHeader;

  static const Key emptyKey = SkillsKeys.empty;
  static const Key listKey = SkillsKeys.list;
  static const Key searchKey = SkillsKeys.search;
  static const Key importKey = SkillsKeys.import;
  static const Key importPasteKey = SkillsKeys.importPaste;
  static const Key importFileKey = SkillsKeys.importFile;
  static const Key importGitHubKey = SkillsKeys.importGitHub;
  static const Key importSubmitKey = SkillsKeys.importSubmit;
  static const Key importErrorKey = SkillsKeys.importError;
  static const Key deleteKey = SkillsKeys.delete;
  static const Key emptyCtasKey = SkillsKeys.emptyCtas;

  static Key itemKey(String id) => SkillsKeys.item(id);

  static Key enableKey(String id) => SkillsKeys.enable(id);

  @override
  State<SkillsPane> createState() => SkillsPaneState();
}

class SkillsPaneState extends State<SkillsPane> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Skill> _filtered(List<Skill> skills) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return skills;
    return [
      for (final skill in skills)
        if (skill.name.toLowerCase().contains(query) ||
            skill.description.toLowerCase().contains(query))
          skill,
    ];
  }

  Widget _emptyState(AppLocalizations l10n, ColorScheme cs) {
    final child = Center(
      key: SkillsPane.emptyKey,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Lucide.Sparkles,
                size: 44,
                color: cs.onSurface.withValues(alpha: 0.26),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.skillsEmptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.skillsEmptyHint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.52),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: context.appColors.surfaceFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.skillsEmptyFormat,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                    color: cs.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                key: SkillsKeys.emptyCtas,
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IosTileButton(
                      key: SkillsKeys.importPaste,
                      icon: Lucide.ClipboardPaste,
                      label: l10n.skillsImportPaste,
                      onTap: () => unawaited(showSkillPasteImport(context)),
                    ),
                    const SizedBox(height: 8),
                    IosTileButton(
                      key: SkillsKeys.importFile,
                      icon: Lucide.FileUp,
                      label: l10n.skillsImportFile,
                      onTap: () => unawaited(importSkillFromFile(context)),
                    ),
                    const SizedBox(height: 8),
                    IosTileButton(
                      key: SkillsKeys.importGitHub,
                      leading: const GitHubGlyph(),
                      label: l10n.skillsImportGitHub,
                      onTap: () => unawaited(showSkillGitHubImport(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return child.animate().fadeIn(duration: 200.ms);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final skills = context.watch<SkillsService>().skills;
    final filtered = _filtered(skills);
    final showSearch = skills.length > 8;

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.skillsTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.emphasis,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SkillsImportPlusButton(key: SkillsKeys.import),
                ],
              ),
            ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkillsSearchField(
                controller: _searchController,
                onChanged: () => setState(() {}),
              ),
            ),
          Expanded(
            child: skills.isEmpty
                ? _emptyState(l10n, cs)
                : ListView(
                    key: SkillsPane.listKey,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                    children: [
                      SectionCard(
                        children: [
                          for (var i = 0; i < filtered.length; i++) ...[
                            if (i > 0) const IosRowDivider(),
                            _SkillTile(skill: filtered[i]),
                          ],
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SkillsSearchField extends StatelessWidget {
  const _SkillsSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasText = controller.text.isNotEmpty;
    return TextField(
      key: SkillsPane.searchKey,
      controller: controller,
      onChanged: (_) => onChanged(),
      cursorColor: cs.primary,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: l10n.skillsSearchHint,
        prefixIcon: Icon(
          Lucide.Search,
          size: 18,
          color: cs.onSurface.withValues(alpha: 0.6),
        ),
        suffixIcon: hasText
            ? Tooltip(
                message: l10n.skillsSearchClear,
                child: IosIconButton(
                  icon: Lucide.X,
                  size: 16,
                  semanticLabel: l10n.skillsSearchClear,
                  onTap: () {
                    Haptics.light();
                    controller.clear();
                    onChanged();
                  },
                ),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: context.appColors.surfaceFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final description = skill.description.trim();
    return IosNavRow(
      key: SkillsPane.itemKey(skill.record.id),
      icon: Lucide.Sparkles,
      label: skill.name,
      labelWeight: AppFontWeights.medium,
      subtitle: description.isEmpty ? null : description,
      caption: l10n.skillsUsedCount(skill.record.useCount),
      onTap: () =>
          unawaited(showSkillDetail(context, skillId: skill.record.id)),
      trailing: IosSwitch(
        key: SkillsPane.enableKey(skill.record.id),
        value: skill.record.enabled,
        semanticLabel: l10n.skillsEnabled,
        onChanged: (value) {
          unawaited(
            context.read<SkillsService>().setEnabled(skill.record.id, value),
          );
        },
      ),
    );
  }
}

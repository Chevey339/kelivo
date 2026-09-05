import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/desktop/menu_anchor.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/widgets/files/file_browser.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/features/workspace/workspace_layout.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/markdown_with_highlight.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

String skillModelPath(Skill skill, String hostPath) {
  final rel = p.relative(hostPath, from: skill.dir).replaceAll('\\', '/');
  if (rel == '.' || rel == './') return '/skills/${skill.record.id}';
  return '/skills/${skill.record.id}/$rel';
}

Future<void> showSkillDetail(BuildContext context, {required String skillId}) {
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 720,
      child: SizedBox(
        height: height,
        child: SkillDetailView(skillId: skillId, dialog: true),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => SkillDetailPage(skillId: skillId)),
  );
}

Future<void> editSkillBody(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  var initial = '';
  try {
    initial = File(skill.skillMdPath).readAsStringSync();
  } catch (_) {}
  await showSkillTextImport(
    context: context,
    title: l10n.skillsEditTitle,
    label: l10n.skillsImportPasteLabel,
    hint: l10n.skillsImportPasteHint,
    confirmLabel: l10n.skillsSave,
    minLines: 8,
    maxLines: 16,
    initial: initial,
    onSubmit: (markdown) async {
      await context.read<SkillsService>().updateBody(skill.record.id, markdown);
    },
  );
}

Future<void> exportSkill(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  final service = context.read<SkillsService>();
  try {
    final outDir = await Directory.systemTemp.createTemp(
      'kelivo_skill_export_',
    );
    final zip = await service.exportZip(skill.record.id, outDir);
    if (!context.mounted) return;
    final desktop = useDesktopWorkspaceLayout(context);
    if (desktop) {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.skillsExport,
        fileName: '${skill.record.id}.zip',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (savePath == null) return;
      await File(savePath).parent.create(recursive: true);
      await zip.copy(savePath);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(zip.path, name: '${skill.record.id}.zip')],
        sharePositionOrigin: _shareAnchor(context),
      ),
    );
  } catch (error) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: skillErrorMessage(error),
      type: NotificationType.error,
    );
  }
}

Future<void> deleteSkill(
  BuildContext context,
  Skill skill, {
  bool popAfter = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showWorkspaceConfirm(
    context: context,
    title: l10n.skillsDeleteTitle,
    message: l10n.skillsDeleteMessage(skill.name),
    confirmLabel: l10n.skillsDelete,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  await context.read<SkillsService>().delete(skill.record.id);
  if (popAfter && context.mounted) Navigator.of(context).maybePop();
}

Future<void> showSkillItemActions(
  BuildContext context,
  Skill skill, {
  Offset? anchor,
  bool popAfterDelete = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAdaptiveActionMenu(
    context,
    anchor: anchor ?? DesktopMenuAnchor.positionOrCenter(context),
    items: [
      ActionSheetItem(
        icon: Lucide.FolderOpen,
        label: l10n.skillsBrowseFiles,
        onTap: () => unawaited(browseSkillFiles(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Pencil,
        label: l10n.skillsEdit,
        onTap: () => unawaited(editSkillBody(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Share2,
        label: l10n.skillsExport,
        onTap: () => unawaited(exportSkill(context, skill)),
      ),
      ActionSheetItem(
        icon: Lucide.Trash2,
        label: l10n.skillsDelete,
        destructive: true,
        onTap: () =>
            unawaited(deleteSkill(context, skill, popAfter: popAfterDelete)),
      ),
    ],
  );
}

class SkillDetailPage extends StatelessWidget {
  const SkillDetailPage({super.key, required this.skillId});

  final String skillId;

  @override
  Widget build(BuildContext context) {
    return SkillDetailView(skillId: skillId);
  }
}

class SkillDetailView extends StatelessWidget {
  const SkillDetailView({
    super.key,
    required this.skillId,
    this.dialog = false,
  });

  final String skillId;
  final bool dialog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final service = context.watch<SkillsService>();
    Skill? skill;
    for (final item in service.skills) {
      if (item.record.id == skillId) {
        skill = item;
        break;
      }
    }
    if (skill == null) {
      return Center(
        child: Text(
          l10n.skillsEmptyTitle,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      );
    }
    final current = skill;
    final body = _SkillDetailBody(skill: current);

    if (dialog) {
      return Column(
        children: [
          AppDialogHeader(
            title: current.name,
            actions: [
              _SkillEnabledSwitch(skill: current),
              _SkillMoreButton(skill: current, popAfterDelete: true),
            ],
          ),
          Expanded(child: body),
        ],
      );
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
            onTap: () {
              Haptics.light();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(current.name),
        actions: [
          _SkillEnabledSwitch(skill: current),
          _SkillMoreButton(skill: current, popAfterDelete: true),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
  }
}

class _SkillEnabledSwitch extends StatelessWidget {
  const _SkillEnabledSwitch({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: l10n.skillsEnabled,
      child: IosSwitch(
        key: SkillsKeys.enable(skill.record.id),
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

class _SkillMoreButton extends StatelessWidget {
  const _SkillMoreButton({required this.skill, required this.popAfterDelete});

  final Skill skill;
  final bool popAfterDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.skillsMoreActions,
      child: IosIconButton(
        key: SkillsKeys.more,
        icon: Lucide.Ellipsis,
        size: 22,
        minSize: 44,
        color: cs.onSurface,
        semanticLabel: l10n.skillsMoreActions,
        onTap: () {
          Haptics.light();
          final box = context.findRenderObject() as RenderBox?;
          final anchor = (box != null && box.hasSize)
              ? box.localToGlobal(Offset.zero)
              : DesktopMenuAnchor.positionOrCenter(context);
          unawaited(
            showSkillItemActions(
              context,
              skill,
              anchor: anchor,
              popAfterDelete: popAfterDelete,
            ),
          );
        },
      ),
    );
  }
}

/// Markdown body of a SKILL.md with YAML frontmatter removed.
String skillDetailMarkdownBody(String raw) {
  return SkillFrontmatter.parse(raw).body.trim();
}

class _SkillDetailBody extends StatelessWidget {
  const _SkillDetailBody({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    var missing = false;
    String? body;
    try {
      final md = File(skill.skillMdPath);
      if (md.existsSync()) {
        body = skillDetailMarkdownBody(md.readAsStringSync());
      } else {
        missing = true;
      }
    } catch (_) {
      missing = true;
    }

    final description = skill.description.trim();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Lucide.WandSparkles,
                size: 22,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 10),
              Text(
                skill.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFontWeights.semibold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.skillsDetailKindLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                l10n.skillsUsedCount(skill.record.useCount),
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        if (missing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                l10n.workspaceFileNotAvailable,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          )
        else if (body == null || body.isEmpty)
          _SkillBodyEmpty(label: l10n.skillsDetailBodyEmpty)
        else
          SectionCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: MarkdownWithCodeHighlight(
              text: body,
              baseStyle: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
      ],
    );
  }
}

class _SkillBodyEmpty extends StatelessWidget {
  const _SkillBodyEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: SkillsKeys.bodyEmpty,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Lucide.FileText,
            size: 44,
            color: cs.onSurface.withValues(alpha: 0.26),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFontWeights.semibold,
              color: cs.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> browseSkillFiles(BuildContext context, Skill skill) async {
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;
  final browser = FileBrowser(
    root: Directory(skill.dir),
    rootLabel: skill.name,
    modelPathOf: (hostPath) => skillModelPath(skill, hostPath),
  );
  if (useDesktopWorkspaceLayout(context)) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    await showAppDialog<void>(
      context,
      maxWidth: 720,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(title: l10n.skillsBrowseFiles),
            Expanded(child: browser),
          ],
        ),
      ),
    );
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (pageContext) => Scaffold(
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
              onTap: () {
                Haptics.light();
                Navigator.of(pageContext).maybePop();
              },
            ),
          ),
          title: Text(l10n.skillsBrowseFiles),
        ),
        body: browser,
      ),
    ),
  );
}

Rect _shareAnchor(BuildContext context) {
  try {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null &&
        box.hasSize &&
        box.size.width > 0 &&
        box.size.height > 0) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
  } catch (_) {}
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: 1,
    height: 1,
  );
}

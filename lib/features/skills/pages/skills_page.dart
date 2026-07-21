import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/providers/assistant_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../skill_manager.dart';

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key});

  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  List<SkillMetadata> _skills = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    SkillManager.initRoot().then((_) => _refresh());
  }

  Future<void> _refresh() async {
    final skills = await SkillManager.listSkills();
    if (!mounted) return;
    setState(() {
      _skills = skills;
      _loading = false;
    });
  }

  String? _extractNameFromFrontmatter(String content) {
    final parsed = SkillManager.parseFrontmatter(content);
    return parsed?.fields['name'];
  }

  String _localizeSaveError(SkillSaveError? error, AppLocalizations l10n) {
    if (error == null) return '';
    switch (error.code) {
      case 'invalid_frontmatter':
        return l10n.skillsInvalidFrontmatter;
      case 'name_missing':
        return l10n.skillsFrontmatterNameMissing;
      case 'name_mismatch':
        return l10n.skillsFrontmatterNameMismatch(
          error.params['frontmatterName'] ?? '',
          error.params['dirName'] ?? '',
        );
      case 'io_error':
        return l10n.skillsSaveFailed(error.params['detail'] ?? '');
      default:
        return l10n.skillsSaveFailed(error.params['detail'] ?? '');
    }
  }

  Future<void> _showAddDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            String? liveName;
            if (controller.text.trim().isNotEmpty) {
              final parsed = SkillManager.parseFrontmatter(controller.text);
              if (parsed != null) {
                liveName = parsed.fields['name'];
              }
            }

            return AlertDialog(
              title: Text(l10n.skillsImportManualTitle),
              content: SizedBox(
                width: 400,
                child: TextField(
                  controller: controller,
                  maxLines: 12,
                  decoration: InputDecoration(
                    hintText: l10n.skillsImportManualHint,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: liveName != null && liveName.isNotEmpty
                      ? () => Navigator.of(ctx).pop(controller.text)
                      : null,
                  child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty || !mounted) return;

    final name = _extractNameFromFrontmatter(result) ?? '';
    if (name.isEmpty) return;

    final error = await SkillManager.saveSkill(name: name, content: result);
    if (error != null) {
      if (!mounted) return;
      showAppSnackBar(context, message: _localizeSaveError(error, l10n));
      return;
    }
    await _refresh();
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final path = file.path!;
    final ext = p.extension(path).toLowerCase();

    int imported = 0;
    int failed = 0;

    if (ext == '.zip') {
      try {
        final bytes = await File(path).readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final entry in archive) {
          if (entry.isFile && p.basename(entry.name) == 'SKILL.md') {
            final content = utf8.decode(entry.content as List<int>);
            final name = _extractNameFromFrontmatter(content);
            if (name == null) {
              failed++;
              continue;
            }
            final error = await SkillManager.saveSkill(
              name: name,
              content: content,
            );
            if (error != null) {
              failed++;
            } else {
              imported++;
            }
          }
        }
        archive.clear();
      } catch (_) {
        failed++;
      }
    } else {
      try {
        final content = await File(path).readAsString();
        final name = _extractNameFromFrontmatter(content);
        if (name == null) {
          failed++;
        } else {
          final error = await SkillManager.saveSkill(
            name: name,
            content: content,
          );
          if (error != null) {
            failed++;
          } else {
            imported++;
          }
        }
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (imported > 0) {
      showAppSnackBar(context, message: l10n.skillsImportSuccess(imported));
    }
    if (failed > 0) {
      showAppSnackBar(
        context,
        message: l10n.skillsImportFailed(failed),
        type: NotificationType.error,
      );
    }
    await _refresh();
  }

  Future<void> _deleteSkill(String name) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.skillsDeleteConfirmTitle),
        content: Text(l10n.skillsDeleteConfirmMessage(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.skillsDeleteConfirmDeleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await SkillManager.deleteSkill(name);
    if (mounted) {
      context.read<AssistantProvider>().removeSkillFromAllAssistants(name);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.skillsTitle),
        actions: [
          IconButton(
            icon: const Icon(Lucide.Upload),
            tooltip: l10n.skillsImportFileLabel,
            onPressed: _importFromFile,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Lucide.Plus),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.skillsEmptyMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _skills.length,
                itemBuilder: (ctx, i) {
                  final skill = _skills[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Lucide.BookOpen, color: cs.primary),
                      title: Text(
                        skill.name,
                        style: TextStyle(fontWeight: AppFontWeights.semibold),
                      ),
                      subtitle: skill.description.isNotEmpty
                          ? Text(
                              skill.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Lucide.Trash2),
                        color: cs.error,
                        onPressed: () => _deleteSkill(skill.name),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

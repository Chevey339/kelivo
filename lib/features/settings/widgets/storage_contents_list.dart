import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../../core/providers/workspace_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/skills/skills_service.dart';
import '../../../core/services/storage/storage_usage_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_settings_rows.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../workspace/widgets/files/file_browser.dart';
import '../../workspace/widgets/preview/file_preview.dart';
import '../../workspace/workspace_layout.dart';
import 'custom_theme_widgets.dart';

/// The same measured entries supply both the breakdown and its file browser.
/// No conversation/workspace binding is needed to inspect files left on disk.
class StorageContentsList extends StatelessWidget {
  const StorageContentsList({
    super.key,
    required this.category,
    required this.fmtBytes,
  });

  final StorageUsageCategory category;
  final String Function(int) fmtBytes;

  static bool supports(StorageUsageCategoryKey key) => const {
    StorageUsageCategoryKey.workspaceFiles,
    StorageUsageCategoryKey.sessionFiles,
    StorageUsageCategoryKey.skills,
    StorageUsageCategoryKey.sandboxEnvironment,
  }.contains(key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workspaces = context.watch<WorkspaceProvider?>()?.workspaces;
    final chat = context.watch<ChatService?>();
    final skills = context.watch<SkillsService?>()?.skills;

    String label(StorageUsageSubcategory entry) {
      if (!entry.isDirectory) return entry.id;
      switch (category.key) {
        case StorageUsageCategoryKey.workspaceFiles:
          for (final workspace in workspaces ?? []) {
            if (workspace.id == entry.id) return workspace.name;
          }
        case StorageUsageCategoryKey.sessionFiles:
          final title = chat?.getConversation(entry.id)?.title;
          if (title != null && title.trim().isNotEmpty) return title;
          return '${l10n.storageSessionFilesUnlinked} · ${entry.id}';
        case StorageUsageCategoryKey.skills:
          for (final skill in skills ?? []) {
            if (p.equals(skill.dir, entry.path ?? '')) return skill.name;
          }
        default:
          break;
      }
      return entry.id;
    }

    if (category.subcategories.isEmpty) {
      return Center(child: Text(l10n.workspaceFilesEmpty));
    }
    return ListView.separated(
      itemCount: category.subcategories.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = category.subcategories[index];
        final title = label(entry);
        return SectionCard(
          child: IosNavRow(
            key: ValueKey('storage-content-${entry.id}'),
            icon: entry.isDirectory ? Lucide.Folder : Lucide.File,
            label: title,
            subtitle: fmtBytes(entry.stats.bytes),
            onTap: () => _open(context, entry, title),
          ),
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    StorageUsageSubcategory entry,
    String title,
  ) async {
    final path = entry.path;
    if (path == null) return;
    if (!entry.isDirectory) {
      await showFilePreview(context, File(path), title: title);
      return;
    }
    final browser = FileBrowser(
      root: Directory(path),
      rootLabel: title,
      modelPathOf: (hostPath) => p.relative(hostPath, from: path),
      // These include application-owned metadata and live environment files.
      // Workspace/skill/environment lifecycle changes stay in their managers.
      readOnly: true,
    );
    if (useDesktopWorkspaceLayout(context)) {
      await showAppDialog<void>(
        context,
        maxWidth: 960,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            children: [
              AppDialogHeader(title: title),
              Expanded(child: browser),
            ],
          ),
        ),
      );
    } else {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: IosIconButton(
                icon: Lucide.ArrowLeft,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            body: SafeArea(top: false, child: browser),
          ),
        ),
      );
    }
  }
}

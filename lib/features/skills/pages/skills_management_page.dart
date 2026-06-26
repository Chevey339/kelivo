import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../core/services/skills/skill_models.dart';
import '../../../core/services/skills/skill_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';

/// Mobile entry page for managing Agent Skills.
///
/// Wraps the shared [SkillManagementContent] in a [Scaffold] with an AppBar
/// whose action opens an import menu (SKILL.md / zip). The list body, import
/// flow, detail view and delete flow are all handled by
/// [SkillManagementContent] so mobile and desktop stay in sync.
///
/// NOTE(l10n): User-visible strings in this file are intentionally hardcoded
/// in Chinese. They will be moved into ARB files in Task 16 together with
/// other skills strings.
class SkillsManagementPage extends StatefulWidget {
  const SkillsManagementPage({super.key});

  @override
  State<SkillsManagementPage> createState() => _SkillsManagementPageState();
}

class _SkillsManagementPageState extends State<SkillsManagementPage> {
  final GlobalKey<SkillManagementContentState> _contentKey =
      GlobalKey<SkillManagementContentState>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IosIconButton(
          icon: Lucide.ArrowLeft,
          size: 22,
          minSize: 44,
          semanticLabel: l10n.skillsBackTooltip,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.skillsPageTitle,
          style: TextStyle(fontSize: 16, fontWeight: AppFontWeights.medium),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Lucide.Import, color: cs.onSurface),
            tooltip: l10n.skillsImportTooltip,
            onSelected: (value) {
              final state = _contentKey.currentState;
              if (state == null) return;
              if (value == 'md') {
                state.importSkillMd();
              } else if (value == 'zip') {
                state.importZip();
              }
            },
            itemBuilder: (ctx) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'md',
                child: Row(
                  children: [
                    Icon(Lucide.FileText, size: 18),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(ctx)!.skillsImportMd),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'zip',
                child: Row(
                  children: [
                    Icon(Lucide.Box, size: 18),
                    const SizedBox(width: 10),
                    Text(AppLocalizations.of(ctx)!.skillsImportZip),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SkillManagementContent(key: _contentKey),
    );
  }
}

/// Shared, AppBar-free content for managing Agent Skills.
///
/// Renders the skill list (or empty state). When [isDesktop] is `false` the
/// list uses [Slidable] swipe-to-delete and tapping a row opens a modal bottom
/// sheet; when `true` it uses a hover delete button and opens a dialog. The
/// import flow is exposed via [importSkillMd] / [importZip] so wrappers can
/// trigger it from their own toolbars.
class SkillManagementContent extends StatefulWidget {
  const SkillManagementContent({super.key, this.isDesktop = false});

  final bool isDesktop;

  @override
  State<SkillManagementContent> createState() => SkillManagementContentState();
}

class SkillManagementContentState extends State<SkillManagementContent> {
  List<SkillMeta> _skills = const <SkillMeta>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final skills = await SkillService.instance.listSkills();
    if (!mounted) return;
    setState(() {
      _skills = skills;
      _loading = false;
    });
  }

  /// Picks and imports a single `SKILL.md` file.
  Future<void> importSkillMd() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['md'],
      );
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null || path.isEmpty) return;
    await _runImport(() => SkillService.instance.importFromSkillMd(path));
  }

  /// Picks and imports a `.zip` skill archive.
  Future<void> importZip() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null || path.isEmpty) return;
    await _runImport(() => SkillService.instance.importFromZip(path));
  }

  Future<void> _runImport(Future<SkillImportResult> Function() importer) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await importer();
    if (!mounted) return;
    if (result.success && result.meta != null) {
      showAppSnackBar(
        context,
        message: l10n.skillsImportSuccess(result.meta!.name),
        type: NotificationType.success,
      );
      await _loadSkills();
    } else {
      await _showImportError(result.error ?? l10n.skillsImportErrorDialogTitle);
    }
  }

  Future<void> _showImportError(String message) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.skillsImportErrorDialogTitle),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.skillsImportErrorDialogClose),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDetail(SkillMeta meta) async {
    if (widget.isDesktop) {
      await showSkillDetailDialog(context, meta);
    } else {
      await showSkillDetailSheet(context, meta);
    }
    if (!mounted) return;
    // Reload in case the user toggled/deleted from within the detail view.
    await _loadSkills();
  }

  Future<void> _toggleEnabled(SkillMeta meta, bool enabled) async {
    await SkillService.instance.setEnabled(meta.name, enabled);
    await _loadSkills();
  }

  Future<bool> _confirmDelete(SkillMeta meta) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.skillsDeleteConfirmTitle),
          content: Text(l10n.skillsDeleteConfirmMessage(meta.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.skillsDeleteConfirmCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.skillsDeleteConfirmDelete),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _deleteSkill(SkillMeta meta) async {
    final confirmed = await _confirmDelete(meta);
    if (!confirmed) return;
    await SkillService.instance.deleteSkill(meta.name);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: l10n.skillsDeletedSnackbar(meta.name),
      type: NotificationType.info,
    );
    await _loadSkills();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_skills.isEmpty) {
      return _SkillsEmptyState(
        icon: Lucide.packageOpen,
        message: AppLocalizations.of(context)!.skillsEmptyState,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _skills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final meta = _skills[index];
        return _SkillRow(
          meta: meta,
          isDesktop: widget.isDesktop,
          onTap: () => _showDetail(meta),
          onToggle: (v) => _toggleEnabled(meta, v),
          onDelete: () => _deleteSkill(meta),
        );
      },
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.meta,
    required this.isDesktop,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final SkillMeta meta;
  final bool isDesktop;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final row = _SkillRowCard(
      meta: meta,
      isDesktop: isDesktop,
      onTap: onTap,
      onToggle: onToggle,
      onDelete: onDelete,
    );
    if (isDesktop) {
      // Desktop uses a hover delete button inside the card; no swipe gesture.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: row,
      );
    }
    // Mobile uses Slidable for swipe-to-delete.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Slidable(
        key: ValueKey('skill-${meta.name}'),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.32,
          children: [
            CustomSlidableAction(
              autoClose: true,
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.zero,
              child: _SlidableDeleteAction(onPressed: onDelete),
              onPressed: (_) => onDelete(),
            ),
          ],
        ),
        child: row,
      ),
    );
  }
}

class _SkillRowCard extends StatefulWidget {
  const _SkillRowCard({
    required this.meta,
    required this.isDesktop,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final SkillMeta meta;
  final bool isDesktop;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  State<_SkillRowCard> createState() => _SkillRowCardState();
}

class _SkillRowCardState extends State<_SkillRowCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = widget.meta;

    final card = IosCardPress(
      baseColor: widget.isDesktop
          ? (_hover
                ? (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.03))
                : (isDark
                      ? Colors.white10
                      : Colors.white.withValues(alpha: 0.96)))
          : (isDark ? Colors.white10 : Colors.white.withValues(alpha: 0.96)),
      pressedBlendStrength: widget.isDesktop ? 0.0 : 0.10,
      borderRadius: BorderRadius.circular(widget.isDesktop ? 14 : 12),
      border: Border.all(
        color: cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08),
        width: 0.6,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: widget.onTap,
      child: Row(
        children: [
          Icon(Lucide.package, size: 22, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        meta.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: AppFontWeights.semibold,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if ((meta.version ?? '').isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        'v${meta.version}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                if (meta.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(value: meta.globalEnabled, onChanged: widget.onToggle),
          if (widget.isDesktop) ...[
            const SizedBox(width: 6),
            _HoverDeleteButton(onTap: widget.onDelete),
          ],
        ],
      ),
    );

    if (!widget.isDesktop) {
      return card;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: card,
    );
  }
}

class _HoverDeleteButton extends StatefulWidget {
  const _HoverDeleteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_HoverDeleteButton> createState() => _HoverDeleteButtonState();
}

class _HoverDeleteButtonState extends State<_HoverDeleteButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? cs.error.withValues(alpha: isDark ? 0.20 : 0.12)
        : Colors.transparent;
    final fg = _hover ? cs.error : cs.onSurface.withValues(alpha: 0.6);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Tooltip(
          message: AppLocalizations.of(context)!.skillsListDeleteTooltip,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Lucide.Trash2, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

class _SlidableDeleteAction extends StatelessWidget {
  const _SlidableDeleteAction({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: isDark ? 0.22 : 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha: 0.35)),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Lucide.Trash2, size: 18, color: cs.error),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context)!.skillsListSlidableDelete,
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFontWeights.semibold,
                color: cs.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillsEmptyState extends StatelessWidget {
  const _SkillsEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: cs.onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail view (shared body + mobile bottom sheet + desktop dialog)
// ---------------------------------------------------------------------------

/// Presents the skill detail as a modal bottom sheet (mobile).
Future<void> showSkillDetailSheet(BuildContext context, SkillMeta meta) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetCtx) {
      final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.9;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SkillDetailBody(meta: meta),
      );
    },
  );
}

/// Presents the skill detail as a centered dialog (desktop).
Future<void> showSkillDetailDialog(BuildContext context, SkillMeta meta) async {
  final cs = Theme.of(context).colorScheme;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: SkillDetailBody(meta: meta, isDesktop: true),
        ),
      );
    },
  );
}

class SkillDetailBody extends StatefulWidget {
  const SkillDetailBody({
    super.key,
    required this.meta,
    this.isDesktop = false,
  });

  final SkillMeta meta;
  final bool isDesktop;

  @override
  State<SkillDetailBody> createState() => _SkillDetailBodyState();
}

class _SkillDetailBodyState extends State<SkillDetailBody> {
  late Future<String?> _skillMdFuture;

  @override
  void initState() {
    super.initState();
    _skillMdFuture = SkillService.instance.readSkillMd(widget.meta.name);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final meta = widget.meta;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Lucide.package, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  meta.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFontWeights.emphasis,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IosIconButton(
                icon: Lucide.X,
                size: 18,
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          if (meta.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.description,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SkillMetaTable(meta: meta),
          const SizedBox(height: 12),
          Flexible(
            child: FutureBuilder<String?>(
              future: _skillMdFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final content = snapshot.data;
                if (content == null || content.trim().isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      AppLocalizations.of(context)!.skillsDetailEmptyMd,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                }
                return Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: GptMarkdown(content),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _DangerDeleteButton(meta: meta),
          ),
        ],
      ),
    );
  }
}

class _SkillMetaTable extends StatelessWidget {
  const _SkillMetaTable({required this.meta});
  final SkillMeta meta;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final rows = <_MetaRow>[
      _MetaRow(label: l10n.skillsMetaName, value: meta.name),
      if ((meta.version ?? '').isNotEmpty)
        _MetaRow(label: l10n.skillsMetaVersion, value: meta.version!),
      if ((meta.license ?? '').isNotEmpty)
        _MetaRow(label: l10n.skillsMetaLicense, value: meta.license!),
      if ((meta.compatibility ?? '').isNotEmpty)
        _MetaRow(
          label: l10n.skillsMetaCompatibility,
          value: meta.compatibility!,
        ),
      if (meta.allowedTools != null && meta.allowedTools!.isNotEmpty)
        _MetaRow(
          label: l10n.skillsMetaAllowedTools,
          value: meta.allowedTools!.join(', '),
        ),
      if (meta.metadata != null && meta.metadata!.isNotEmpty)
        ...meta.metadata!.entries.map(
          (e) => _MetaRow(label: e.key, value: e.value.toString()),
        ),
      _MetaRow(
        label: l10n.skillsMetaEnabled,
        value: meta.globalEnabled
            ? l10n.skillsMetaEnabledValue
            : l10n.skillsMetaDisabledValue,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(
                height: 8,
                thickness: 0.4,
                color: cs.outlineVariant.withValues(alpha: 0.18),
              ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerDeleteButton extends StatefulWidget {
  const _DangerDeleteButton({required this.meta});
  final SkillMeta meta;

  @override
  State<_DangerDeleteButton> createState() => _DangerDeleteButtonState();
}

class _DangerDeleteButtonState extends State<_DangerDeleteButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? cs.error.withValues(alpha: isDark ? 0.90 : 0.92)
        : cs.error.withValues(alpha: isDark ? 0.85 : 0.90);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () async {
          final l10n = AppLocalizations.of(context)!;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: Text(l10n.skillsDeleteConfirmTitle),
                content: Text(
                  l10n.skillsDeleteConfirmMessage(widget.meta.name),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(l10n.skillsDeleteConfirmCancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(l10n.skillsDeleteConfirmDelete),
                  ),
                ],
              );
            },
          );
          if (confirmed != true) return;
          await SkillService.instance.deleteSkill(widget.meta.name);
          if (!context.mounted) return;
          Navigator.of(context).maybePop();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Lucide.Trash2, size: 16, color: cs.onError),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context)!.skillsDetailDeleteButton,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onError,
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

import 'package:flutter/material.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'desktop_workspace_text_field.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'desktop_workspace_button.dart';
import 'workspace_picker.dart';

class DesktopWorkspacePicker extends StatefulWidget {
  const DesktopWorkspacePicker({
    super.key,
    required this.workspaces,
    this.selectedId,
  });

  final List<Workspace> workspaces;
  final String? selectedId;

  @override
  State<DesktopWorkspacePicker> createState() => _DesktopWorkspacePickerState();
}

class _DesktopWorkspacePickerState extends State<DesktopWorkspacePicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.toLowerCase().trim();
    final items = widget.workspaces
        .where(
          (w) =>
              w.name.toLowerCase().contains(query) ||
              (w.hostPath?.toLowerCase().contains(query) ?? false),
        )
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDialogHeader(title: l10n.workspaceEntryBind),
        if (widget.workspaces.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: DesktopWorkspaceTextField(
              label: '',
              controller: _search,
              hintText: l10n.workspaceDesktopSearch,
              leadingIcon: Lucide.Search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
        Flexible(
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    widget.workspaces.isEmpty
                        ? l10n.workspacesEmpty
                        : l10n.workspaceDesktopNoResults,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final workspace = items[index];
                    final selected = workspace.id == widget.selectedId;
                    return Material(
                      color: selected
                          ? cs.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        splashFactory: NoSplash.splashFactory,
                        hoverColor: cs.onSurface.withValues(alpha: 0.035),
                        highlightColor: cs.onSurface.withValues(alpha: 0.065),
                        focusColor: cs.primary.withValues(alpha: 0.08),
                        key: ValueKey('workspace-section-pick-${workspace.id}'),
                        onTap: () => Navigator.of(context).pop(workspace.id),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                workspace.kind == WorkspaceKind.linked
                                    ? Lucide.Link
                                    : Lucide.FolderCode,
                                size: 20,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workspace.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: AppFontWeights.medium,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      workspace.hostPath ??
                                          l10n.workspaceFilesKindManaged,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(Lucide.Check, size: 18, color: cs.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: cs.outlineVariant.withValues(alpha: 0.12),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.centerRight,
            child: DesktopWorkspaceButton(
              key: const ValueKey('workspace-section-create'),
              label: l10n.workspaceEntryCreate,
              icon: Lucide.Plus,
              primary: true,
              onPressed: () =>
                  Navigator.of(context).pop(kCreateWorkspacePickerValue),
            ),
          ),
        ),
      ],
    );
  }
}

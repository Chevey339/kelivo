import 'package:flutter/material.dart';

import 'package:Kelivo/core/models/workspace.dart';
import 'package:Kelivo/features/workspace/pages/workspace_files_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/workspaces_page.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'desktop_workspace_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import 'desktop_workspace_button.dart';

class DesktopWorkspacesView extends StatefulWidget {
  const DesktopWorkspacesView({
    super.key,
    required this.workspaces,
    required this.onCreate,
    required this.onMore,
    this.showHeader = true,
  });

  final List<Workspace> workspaces;
  final Future<Workspace?> Function() onCreate;
  final void Function(Workspace workspace, Offset position) onMore;
  final bool showHeader;

  @override
  State<DesktopWorkspacesView> createState() => _DesktopWorkspacesViewState();
}

class _DesktopWorkspacesViewState extends State<DesktopWorkspacesView> {
  final _search = TextEditingController();
  String? _selectedId;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.workspaces.firstOrNull?.id;
  }

  @override
  void didUpdateWidget(DesktopWorkspacesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.workspaces.any((workspace) => workspace.id == _selectedId)) {
      _selectedId = widget.workspaces.firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    setState(() => _creating = true);
    try {
      final workspace = await widget.onCreate();
      if (!mounted || workspace == null) return;
      setState(() {
        _search.clear();
        _selectedId = workspace.id;
      });
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final query = _search.text.trim().toLowerCase();
    final filtered = widget.workspaces
        .where(
          (w) =>
              w.name.toLowerCase().contains(query) ||
              (w.hostPath?.toLowerCase().contains(query) ?? false),
        )
        .toList();
    final selected =
        widget.workspaces.where((w) => w.id == _selectedId).firstOrNull ??
        widget.workspaces.firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 660;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.showHeader)
                          Text(
                            l10n.workspacesTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: AppFontWeights.semibold,
                            ),
                          ),
                        if (widget.showHeader) const SizedBox(height: 4),
                        Text(
                          l10n.workspaceDesktopHostHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  DesktopWorkspaceButton(
                    key: WorkspacesPane.createKey,
                    label: l10n.workspaceMgmtNewWorkspace,
                    icon: Lucide.Plus,
                    primary: true,
                    onPressed: _creating ? null : _create,
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.12),
            ),
            if (widget.workspaces.isEmpty)
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      key: WorkspacesPane.emptyKey,
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Lucide.FolderCode,
                            size: 44,
                            color: cs.primary.withValues(alpha: 0.55),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.workspacesEmpty,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: AppFontWeights.semibold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.workspaceMgmtEmptyHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          DesktopWorkspaceButton(
                            label: l10n.workspacesEmptyCta,
                            icon: Lucide.Plus,
                            primary: true,
                            onPressed: _creating ? null : _create,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else ...[
              if (!wide)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            splashFactory: NoSplash.splashFactory,
                            hoverColor: cs.onSurface.withValues(alpha: 0.035),
                            highlightColor: cs.onSurface.withValues(
                              alpha: 0.065,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              key: const ValueKey('workspace-desktop-select'),
                              value: selected?.id,
                              isExpanded: true,
                              icon: Icon(
                                Lucide.ChevronsUpDown,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              items: [
                                for (final w in widget.workspaces)
                                  DropdownMenuItem(
                                    value: w.id,
                                    child: Text(
                                      w.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (id) =>
                                  setState(() => _selectedId = id),
                            ),
                          ),
                        ),
                      ),
                      if (selected != null)
                        Builder(
                          builder: (buttonContext) => IosIconButton(
                            key: WorkspacesPane.itemMoreKey(selected.id),
                            icon: Lucide.Ellipsis,
                            tooltip: l10n.workspacesItemMore,
                            onTap: () {
                              final box =
                                  buttonContext.findRenderObject()!
                                      as RenderBox;
                              widget.onMore(
                                selected,
                                box.localToGlobal(box.size.center(Offset.zero)),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide) ...[
                      SizedBox(
                        width: 244,
                        child: ColoredBox(
                          color: Colors.transparent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  10,
                                ),
                                child: DesktopWorkspaceTextField(
                                  key: const ValueKey(
                                    'workspace-desktop-search',
                                  ),
                                  label: '',
                                  controller: _search,
                                  hintText: l10n.workspaceDesktopSearch,
                                  leadingIcon: Lucide.Search,
                                  borderRadius: 12,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              Expanded(
                                child: filtered.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            l10n.workspaceDesktopNoResults,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        key: WorkspacesPane.listKey,
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          8,
                                        ),
                                        itemCount: filtered.length,
                                        itemBuilder: (context, index) {
                                          final workspace = filtered[index];
                                          final active =
                                              workspace.id == selected?.id;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Material(
                                              color: active
                                                  ? cs.primary.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                splashFactory:
                                                    NoSplash.splashFactory,
                                                hoverColor: cs.onSurface
                                                    .withValues(alpha: 0.035),
                                                highlightColor: cs.onSurface
                                                    .withValues(alpha: 0.065),
                                                focusColor: cs.primary
                                                    .withValues(alpha: 0.08),
                                                key: WorkspacesPane.itemKey(
                                                  workspace.id,
                                                ),
                                                onTap: () => setState(
                                                  () => _selectedId =
                                                      workspace.id,
                                                ),
                                                onSecondaryTapDown: (details) =>
                                                    widget.onMore(
                                                      workspace,
                                                      details.globalPosition,
                                                    ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        10,
                                                        10,
                                                        4,
                                                        10,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        workspace.kind ==
                                                                WorkspaceKind
                                                                    .linked
                                                            ? Lucide.Link
                                                            : Lucide.FolderCode,
                                                        size: 18,
                                                        color: active
                                                            ? cs.primary
                                                            : cs.onSurfaceVariant,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              workspace.name,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    active
                                                                    ? AppFontWeights
                                                                          .semibold
                                                                    : AppFontWeights
                                                                          .medium,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              workspace
                                                                      .hostPath ??
                                                                  l10n.workspaceFilesKindManaged,
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: cs
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Builder(
                                                        builder: (buttonContext) => IosIconButton(
                                                          key:
                                                              WorkspacesPane.itemMoreKey(
                                                                workspace.id,
                                                              ),
                                                          icon: Lucide.Ellipsis,
                                                          size: 16,
                                                          tooltip: l10n
                                                              .workspacesItemMore,
                                                          onTap: () {
                                                            final box =
                                                                buttonContext
                                                                        .findRenderObject()!
                                                                    as RenderBox;
                                                            widget.onMore(
                                                              workspace,
                                                              box.localToGlobal(
                                                                box.size.center(
                                                                  Offset.zero,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.12),
                      ),
                    ],
                    if (selected != null)
                      Expanded(
                        child: DesktopWorkspaceFiles(
                          key: ValueKey(selected.id),
                          workspace: selected,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

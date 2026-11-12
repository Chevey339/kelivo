import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../core/models/mcp_presentation.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../desktop/setting/mcp_edit_dialog.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../shared/widgets/selection_back_scope.dart';
import 'mcp_form.dart';
import 'mcp_group_picker.dart';
import '../../../desktop/setting/mcp_json_edit_dialog.dart';
import '../../../desktop/setting/mcp_timeout_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../utils/provider_grouping_logic.dart';
import '../../../theme/app_semantic_colors.dart';
import 'mcp_error_details_sheet.dart';
import 'mcp_icon_picker.dart';
import 'mcp_json_edit_sheet.dart';
import 'mcp_json_import.dart';
import 'mcp_server_card.dart';
import 'mcp_server_edit_sheet.dart';
import 'mcp_timeout_sheet.dart';
import 'mcp_text_dialog.dart';

const _other = '__ungrouped__';
typedef _Row = ({String groupId, McpServerConfig? server});

/// Both settings layouts share organization and selection behavior. Desktop
/// stays embedded in its settings pane; mobile retains its own scaffold.
class McpManagementView extends StatefulWidget {
  const McpManagementView({
    super.key,
    required this.desktop,
    this.embedded = false,
  });
  final bool desktop;
  final bool embedded;

  @override
  State<McpManagementView> createState() => _McpManagementViewState();
}

class _McpManagementViewState extends State<McpManagementView> {
  Set<String>? _selected;
  bool _busy = false;
  List<_Row>? _pendingRows;
  final Map<String, bool> _pendingCollapsed = {};
  bool _temporarilyCollapsed = false;
  int _groupDragGeneration = 0;
  int? _mountedGroupProxyGeneration;
  bool _collapsed(McpProvider mcp, String id) =>
      _temporarilyCollapsed ||
      (_pendingCollapsed[id] ?? mcp.groupCollapsed(id));

  void _onDragStart(List<_Row> rows, int index) {
    if (rows[index].server != null) return;
    _groupDragGeneration++;
    setState(() => _temporarilyCollapsed = true);
  }

  void _restoreAfterGroupDrag(int generation) {
    // The overlay has actually gone away. Waiting for its disposal avoids
    // expanding children under a still-landing header during a slow frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _temporarilyCollapsed &&
          generation == _groupDragGeneration) {
        setState(() => _temporarilyCollapsed = false);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onDragEnd() {
    final generation = _groupDragGeneration;
    // A very fast mouse drag can finish before Flutter ever builds its proxy.
    // Give the overlay this frame to mount; if it did not, there is no landing
    // animation to wait for. Mounted proxies restore through their disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mountedGroupProxyGeneration != generation) {
        _restoreAfterGroupDrag(generation);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _toggleGroup(McpProvider mcp, String id) async {
    if (_busy || _temporarilyCollapsed) return;
    final collapsed = !_collapsed(mcp, id);
    setState(() => _pendingCollapsed[id] = collapsed);
    await _run(() => mcp.setGroupCollapsed(id, collapsed));
    if (mounted) setState(() => _pendingCollapsed.remove(id));
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_busy || !mounted) return false;
    setState(() => _busy = true);
    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: NotificationType.error,
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggle(String id) => setState(() {
    final selection = _selected ??= {};
    if (!selection.remove(id)) selection.add(id);
  });

  Future<void> _edit(String? id) => widget.desktop
      ? showDesktopMcpEditDialog(context, serverId: id)
      : showMcpServerEditSheet(context, serverId: id);

  List<_Row> _rows(McpProvider mcp) {
    if (mcp.groups.isEmpty) {
      return [
        for (final server in mcp.servers) (groupId: _other, server: server),
      ];
    }
    final result = <_Row>[];
    for (final groupId in [...mcp.groups.map((g) => g.id), _other]) {
      final servers = mcp.servers.where(
        (server) =>
            (mcp.presentationFor(server.id).groupId ?? _other) == groupId,
      );
      if (groupId == _other && servers.isEmpty) continue;
      result.add((groupId: groupId, server: null));
      // Keep stable keyed slots through collapse and group dragging, like the
      // providers list. AnimatedSize hides their contents without reindexing.
      result.addAll(
        servers.map((server) => (groupId: groupId, server: server)),
      );
    }
    return result;
  }

  Future<void> _reorder(
    McpProvider mcp,
    List<_Row> rows,
    int oldIndex,
    int newIndex,
  ) async {
    final moved = rows[oldIndex];
    final logicRows = <ProviderGroupingRowVM>[
      for (final row in rows)
        if (row.server == null)
          ProviderGroupingHeaderVM(groupKey: row.groupId)
        else
          ProviderGroupingProviderVM(
            providerKey: row.server!.id,
            groupKey: row.groupId,
          ),
    ];
    late List<_Row> next;
    late Future<void> Function() persist;
    if (moved.server == null) {
      final intent = analyzeProviderGroupingHeaderReorder(
        rows: logicRows,
        oldIndex: oldIndex,
        newIndex: newIndex,
      );
      if (intent == null) return;
      final groupIds = rows
          .where((r) => r.server == null)
          .map((r) => r.groupId)
          .toList();
      groupIds.remove(moved.groupId);
      groupIds.insert(
        intent.targetDisplayIndex.clamp(0, groupIds.length),
        moved.groupId,
      );
      // MCP's ungrouped section stays last; it has no reorder handle.
      if (groupIds.remove(_other)) groupIds.add(_other);
      next = [for (final id in groupIds) ...rows.where((r) => r.groupId == id)];
      persist = () =>
          mcp.reorderGroup(moved.groupId, groupIds.indexOf(moved.groupId));
    } else if (mcp.groups.isEmpty) {
      next = [...rows]..removeAt(oldIndex);
      next.insert(newIndex.clamp(0, next.length), moved);
      final position = next.indexOf(moved);
      persist = () => mcp.moveServerBefore(
        moved.server!.id,
        null,
        position + 1 < next.length ? next[position + 1].server?.id : null,
      );
    } else {
      final analysis = analyzeProviderGroupingReorder(
        rows: logicRows,
        oldIndex: oldIndex,
        newIndex: newIndex,
        isGroupCollapsed: mcp.groupCollapsed,
      );
      if (analysis.isBlocked) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(
            context,
          )!.providerGroupsExpandToMoveToast,
        );
        return;
      }
      final intent = analysis.intent;
      if (intent == null) return;
      final target = rows
          .where(
            (r) =>
                r.server != null &&
                r.server!.id != moved.server!.id &&
                r.groupId == intent.targetGroupKey,
          )
          .toList();
      final position = intent.targetPos.clamp(0, target.length);
      final beforeId = position < target.length
          ? target[position].server!.id
          : null;
      next = rows.where((r) => r.server?.id != moved.server!.id).toList();
      final insertionIndex = beforeId != null
          ? next.indexWhere((r) => r.server?.id == beforeId)
          : next.lastIndexWhere((r) => r.groupId == intent.targetGroupKey) + 1;
      next.insert(insertionIndex, (
        groupId: intent.targetGroupKey,
        server: moved.server,
      ));
      persist = () => mcp.moveServerBefore(
        moved.server!.id,
        intent.targetGroupKey == _other ? null : intent.targetGroupKey,
        beforeId,
      );
    }
    // Publish the entire display order in the drop callback, before any I/O.
    // Storage remains authoritative on success; on failure _run reports it and
    // the old order is restored. A delayed write must never flash the old slot.
    setState(() => _pendingRows = next);
    try {
      await persist();
    } finally {
      if (mounted) setState(() => _pendingRows = null);
    }
  }

  Future<void> _groupName({McpGroup? group}) async {
    final mcp = context.read<McpProvider>();
    final l10n = AppLocalizations.of(context)!;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => McpTextDialog(
        title: group == null
            ? l10n.providerGroupsCreateDialogTitle
            : l10n.mcpRenameGroup,
        hint: l10n.providerGroupsNameHint,
        initialValue: group?.name ?? '',
        submitLabel: group == null
            ? l10n.providerGroupsCreateDialogOk
            : l10n.sideDrawerSave,
        invalidMessage: l10n.mcpGroupNameInvalid,
        valid: (name) =>
            name.isNotEmpty &&
            !mcp.groups.any(
              (item) =>
                  item.id != group?.id &&
                  item.name.toLowerCase() == name.toLowerCase(),
            ),
      ),
    );
    if (name != null && mounted) {
      await _run(() async {
        if (group == null) {
          await mcp.createGroup(name);
        } else {
          await mcp.renameGroup(group.id, name);
        }
      });
    }
  }

  Future<void> _move(Set<String> ids) async {
    final mcp = context.read<McpProvider>();
    final result = await showMcpGroupPicker(context, desktop: widget.desktop);
    if (!mounted || result == null) return;
    final groupId = result.groupId;
    final moved = await _run(() => mcp.moveServersToGroup(ids, groupId));
    if (moved && mounted) setState(() => _selected = null);
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = AppLocalizations.of(context)!;
    return await showMcpForm<bool>(
          context,
          desktop: widget.desktop,
          builder: (ctx) => McpForm(
            desktop: widget.desktop,
            title: title,
            actions: FormSheetActions(
              cancelLabel: l10n.mcpPageCancel,
              confirmLabel: l10n.mcpPageDelete,
              destructive: true,
              onCancel: () => Navigator.of(ctx).pop(false),
              onConfirm: () => Navigator.of(ctx).pop(true),
            ),
            children: [Text(message)],
          ),
        ) ??
        false;
  }

  Future<void> _delete(Set<String> ids) async {
    final mcp = context.read<McpProvider>();
    final l10n = AppLocalizations.of(context)!;
    if (!await _confirm(
          l10n.mcpPageConfirmDeleteTitle,
          ids.length == 1
              ? l10n.mcpPageConfirmDeleteContent
              : l10n.mcpDeleteSelectedConfirm(ids.length),
        ) ||
        !mounted) {
      return;
    }
    final previous = ids.length == 1 ? mcp.getById(ids.single) : null;
    final appearance = previous == null
        ? null
        : mcp.presentationFor(previous.id);
    final deleted = await _run(() => mcp.removeServers(ids));
    if (!deleted || !mounted) return;
    setState(() => _selected = null);
    final navigator = Navigator.of(context);
    showAppSnackBar(
      context,
      message: l10n.mcpPageServerDeleted,
      actionLabel: previous != null ? l10n.mcpPageUndo : null,
      onAction: previous == null
          ? null
          : () async {
              // The global toast outlives this page and remains actionable
              // while another server operation is in progress.
              try {
                await mcp.restoreServer(previous, appearance!);
              } catch (error) {
                if (navigator.mounted) {
                  showAppSnackBar(
                    navigator.context,
                    message: error.toString(),
                    type: NotificationType.error,
                  );
                }
              }
            },
    );
  }

  Future<void> _details(McpServerConfig server) {
    final mcp = context.read<McpProvider>();
    final message = mcp.errorFor(server.id);
    Future<void> reconnect(BuildContext ctx) async {
      await mcp.reconnect(server.id);
      if (mcp.isConnected(server.id) && ctx.mounted) Navigator.of(ctx).pop();
    }

    if (widget.desktop) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => McpErrorDetailsDialog(
          serverName: server.name,
          message: message,
          onReconnect: () => reconnect(ctx),
        ),
      );
    }
    return showFormSheet<void>(
      context,
      builder: (ctx) => McpErrorDetailsSheet(
        serverName: server.name,
        message: message,
        onReconnect: () => reconnect(ctx),
      ),
    );
  }

  void _serverMenu(
    BuildContext rowContext,
    McpServerConfig server, {
    Offset? anchor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final box = rowContext.findRenderObject() as RenderBox;
    unawaited(
      _showMenu(
        rowContext,
        anchor: anchor ?? box.localToGlobal(box.size.center(Offset.zero)),
        title: server.name,
        items: [
          ActionSheetItem(
            icon: Lucide.ListChecks,
            label: l10n.mcpSelectServers,
            onTap: () => _toggle(server.id),
          ),
          ActionSheetItem(
            icon: Lucide.Image,
            label: l10n.mcpIconTitle,
            onTap: () => showMcpIconPicker(
              rowContext,
              desktop: widget.desktop,
              currentIcon: context
                  .read<McpProvider>()
                  .presentationFor(server.id)
                  .icon,
              onSelected: (icon) =>
                  context.read<McpProvider>().setServerIcon(server.id, icon),
            ),
          ),
          ActionSheetItem(
            icon: Lucide.Folder,
            label: l10n.mcpMoveToGroup,
            onTap: () => _move({server.id}),
          ),
          ActionSheetItem(
            icon: Lucide.RefreshCw,
            label: l10n.mcpPageReconnect,
            onTap: () =>
                _run(() => context.read<McpProvider>().reconnect(server.id)),
          ),
          ActionSheetItem(
            icon: Lucide.Trash2,
            label: l10n.mcpPageDelete,
            destructive: true,
            onTap: () => _delete({server.id}),
          ),
        ],
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext anchorContext, {
    String? title,
    Offset? anchor,
    required List<ActionSheetItem> items,
  }) {
    if (!widget.desktop) {
      return showMobileActionSheet(context, title: title, items: items);
    }
    final box = anchorContext.findRenderObject() as RenderBox;
    return showDesktopContextMenuAt(
      context,
      backgroundColor: context.appColors.surfaceCard.withValues(alpha: .96),
      globalPosition:
          anchor ??
          box.localToGlobal(Offset(box.size.width - 220, box.size.height)),
      items: [
        for (final item in items)
          DesktopContextMenuItem(
            icon: item.icon,
            label: item.label,
            danger: item.destructive,
            onTap: item.onTap,
          ),
      ],
    );
  }

  Widget _menuButton({
    required String tooltip,
    required List<ActionSheetItem> items,
    Key? key,
  }) => Builder(
    builder: (ctx) => IosIconButton(
      key: key,
      icon: Lucide.Ellipsis,
      size: 20,
      minSize: 44,
      tooltip: tooltip,
      semanticLabel: tooltip,
      enabled: !_busy,
      onTap: () => _showMenu(ctx, items: items),
    ),
  );

  Widget _groupHeader(McpProvider mcp, String id, int index) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final group = mcp.groups.where((group) => group.id == id).firstOrNull;
    final members = (_pendingRows ?? _rows(mcp))
        .where((row) => row.server != null && row.groupId == id)
        .map((row) => row.server!.id)
        .toSet();
    final all =
        members.isNotEmpty &&
        members.every((id) => _selected?.contains(id) ?? false);
    Widget header = SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: IosCardPress(
              focusable: true,
              haptics: false,
              baseColor: Colors.transparent,
              pressedBlendStrength: 0,
              borderRadius: BorderRadius.circular(10),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onTap: () => _toggleGroup(mcp, id),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: _collapsed(mcp, id) ? 0 : .25,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Lucide.ChevronRight,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: .45),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        group?.name ?? l10n.providerGroupsOther,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.medium,
                          color: cs.onSurface.withValues(alpha: .65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${members.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: .4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selected != null)
            IosTextButton(
              label: all
                  ? l10n.sideDrawerSelectionDeselectAll
                  : l10n.sideDrawerSelectionSelectAll,
              fontSize: 12,
              onPressed: () => setState(() {
                if (all) {
                  _selected!.removeAll(members);
                } else {
                  _selected!.addAll(members);
                }
              }),
            )
          else if (group != null) ...[
            if (widget.desktop)
              ReorderableDragStartListener(
                index: index,
                enabled: !_busy,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox(
                    width: 32,
                    height: 44,
                    child: Icon(
                      Lucide.GripVertical,
                      size: 15,
                      color: cs.onSurface.withValues(alpha: .3),
                    ),
                  ),
                ),
              ),
            _menuButton(
              tooltip: l10n.providerGroupsManageAction,
              key: ValueKey('mcp-group-menu-$id'),
              items: [
                ActionSheetItem(
                  icon: Lucide.Pencil,
                  label: l10n.mcpRenameGroup,
                  onTap: () => _groupName(group: group),
                ),
                ActionSheetItem(
                  icon: Lucide.Trash2,
                  label: l10n.mcpPageDelete,
                  destructive: true,
                  onTap: () async {
                    if (await _confirm(
                          l10n.providerGroupsDeleteConfirmTitle,
                          l10n.mcpDeleteGroupConfirm,
                        ) &&
                        mounted) {
                      await _run(() => mcp.deleteGroup(group.id));
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (!widget.desktop && _selected == null && group != null) {
      header = ReorderableDelayedDragStartListener(
        index: index,
        enabled: !_busy,
        child: header,
      );
    }
    return header;
  }

  List<Widget> _actions(McpProvider mcp) {
    final l10n = AppLocalizations.of(context)!;
    return [
      IosIconButton(
        key: const ValueKey('mcp-selection-start'),
        tooltip: l10n.mcpSelectServers,
        semanticLabel: l10n.mcpSelectServers,
        enabled: !_busy,
        onTap: () => setState(() => _selected = {}),
        icon: Lucide.ListChecks,
        size: 20,
        minSize: 44,
      ),
      _menuButton(
        tooltip: l10n.providerGroupsManageAction,
        items: [
          ActionSheetItem(
            key: const ValueKey('mcp-create-group'),
            icon: Lucide.FolderPlus,
            label: l10n.providerGroupsCreateNewGroupAction,
            onTap: () => _groupName(),
          ),
          ActionSheetItem(
            icon: Lucide.Timer,
            label: l10n.mcpTimeoutSettingsTooltip,
            onTap: () => widget.desktop
                ? showDesktopMcpTimeoutDialog(context)
                : showMcpTimeoutSheet(context),
          ),
          ActionSheetItem(
            icon: Lucide.Download,
            label: l10n.mcpImportJson,
            onTap: () => showMcpJsonImport(context, desktop: widget.desktop),
          ),
          ActionSheetItem(
            icon: Lucide.Code,
            label: l10n.mcpJsonEditButtonTooltip,
            onTap: () => widget.desktop
                ? showDesktopMcpJsonEditDialog(context)
                : showMcpJsonEditSheet(context),
          ),
        ],
      ),
      IosIconButton(
        tooltip: l10n.mcpPageAddMcpTooltip,
        semanticLabel: l10n.mcpPageAddMcpTooltip,
        enabled: !_busy,
        onTap: () => _edit(null),
        icon: Lucide.Plus,
        size: 22,
        minSize: 44,
      ),
    ];
  }

  Widget _swipeAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) => Expanded(
    child: Builder(
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: IosCardPress(
          focusable: true,
          haptics: false,
          baseColor: color,
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Slidable.of(ctx)?.close();
            onTap();
          },
          child: SizedBox.expand(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: Theme.of(ctx).colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _selectionBar(McpProvider mcp, Set<String> selected) {
    final l10n = AppLocalizations.of(context)!;
    final enable = selected.any((id) => mcp.getById(id)?.enabled == false);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: IosTextButton(
                key: const ValueKey('mcp-selection-enable'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _run(() => mcp.setServersEnabled(selected, enable)),
                icon: Lucide.Power,
                label: enable
                    ? l10n.mcpEnableSelected
                    : l10n.mcpDisableSelected,
              ),
            ),
            Expanded(
              child: IosTextButton(
                key: const ValueKey('mcp-selection-move'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _move(selected),
                icon: Lucide.Folder,
                label: l10n.mcpMoveToGroup,
              ),
            ),
            Expanded(
              child: IosTextButton(
                key: const ValueKey('mcp-selection-delete'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _delete(selected),
                icon: Lucide.Trash2,
                color: Theme.of(context).colorScheme.error,
                label: l10n.mcpPageDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcp = context.watch<McpProvider>();
    final l10n = AppLocalizations.of(context)!;
    final rows = (_pendingRows ?? _rows(mcp))
        .where(
          (row) => row.server == null || mcp.getById(row.server!.id) != null,
        )
        .toList();
    final ids = mcp.servers.map((server) => server.id).toSet();
    final selected = _selected?.intersection(ids);
    final all =
        selected != null && ids.isNotEmpty && selected.length == ids.length;
    final title = Text(
      selected == null
          ? l10n.mcpAssistantSheetTitle
          : l10n.storageSpaceSelectedCount(selected.length),
    );
    final actions = selected == null
        ? _actions(mcp)
        : <Widget>[
            IosTextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _selected = all ? {} : ids),
              label: all
                  ? l10n.sideDrawerSelectionDeselectAll
                  : l10n.sideDrawerSelectionSelectAll,
            ),
          ];
    final cancel = selected == null
        ? null
        : IosTextButton(
            onPressed: _busy ? null : () => setState(() => _selected = null),
            label: l10n.mcpPageCancel,
          );
    final list = rows.isEmpty
        ? Center(child: Text(l10n.mcpPageNoServers))
        : Listener(
            // A cancellation may arrive before the overlay gets its first frame.
            onPointerCancel: (_) =>
                _restoreAfterGroupDrag(_groupDragGeneration),
            child: CustomScrollView(
              slivers: [
                SliverReorderableList(
                  itemCount: rows.length,
                  onReorderStart: (index) => _onDragStart(rows, index),
                  onReorderEnd: (_) => _onDragEnd(),
                  // Preserve the header's transparent surface while dragging.
                  proxyDecorator: (child, index, animation) {
                    final generation = _groupDragGeneration;
                    final proxy = Transform.scale(scale: .98, child: child);
                    return rows[index].server == null
                        ? _GroupDragProxy(
                            onMounted: () =>
                                _mountedGroupProxyGeneration = generation,
                            onRemoved: () => _restoreAfterGroupDrag(generation),
                            child: proxy,
                          )
                        : proxy;
                  },
                  onReorderItem: (oldIndex, newIndex) =>
                      _run(() => _reorder(mcp, rows, oldIndex, newIndex)),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final server = row.server == null
                        ? null
                        : mcp.getById(row.server!.id);
                    if (server == null) {
                      return KeyedSubtree(
                        key: ValueKey('mcp-group-${row.groupId}'),
                        child: _groupHeader(mcp, row.groupId, index),
                      );
                    }
                    Widget card = Builder(
                      builder: (rowContext) => GestureDetector(
                        onSecondaryTapDown: (details) => _serverMenu(
                          rowContext,
                          server,
                          anchor: details.globalPosition,
                        ),
                        child: McpServerCard(
                          server: server,
                          status: mcp.statusFor(server.id),
                          error: mcp.errorFor(server.id),
                          selectionMode: selected != null,
                          selected: selected?.contains(server.id) ?? false,
                          onTap: () {
                            if (selected != null) {
                              _toggle(server.id);
                            } else {
                              _edit(server.id);
                            }
                          },
                          onMore: () => _serverMenu(rowContext, server),
                          onEnabledChanged: widget.desktop
                              ? (value) => _run(
                                  () => mcp.updateServerMetadata(
                                    server.copyWith(enabled: value),
                                  ),
                                )
                              : null,
                          onDetails: () => _details(server),
                          onAuthorize: () => mcp.authorize(server.id),
                        ),
                      ),
                    );
                    if (selected == null && widget.desktop) {
                      card = ReorderableDragStartListener(
                        index: index,
                        enabled: !_busy,
                        child: card,
                      );
                    }
                    if (!widget.desktop && selected == null) {
                      card = ReorderableDelayedDragStartListener(
                        index: index,
                        enabled: !_busy,
                        child: card,
                      );
                      card = Slidable(
                        endActionPane: ActionPane(
                          motion: const StretchMotion(),
                          extentRatio: .42,
                          children: [
                            _swipeAction(
                              icon: Lucide.RefreshCw,
                              label: l10n.mcpPageReconnect,
                              color: Theme.of(context).colorScheme.primary,
                              onTap: () => _run(() => mcp.reconnect(server.id)),
                            ),
                            _swipeAction(
                              icon: Lucide.Trash2,
                              label: l10n.mcpPageDelete,
                              color: Theme.of(context).colorScheme.error,
                              onTap: () => _delete({server.id}),
                            ),
                          ],
                        ),
                        child: card,
                      );
                    }
                    return KeyedSubtree(
                      key: ValueKey(
                        '${widget.desktop ? 'desktop-mcp' : 'mcp'}-${server.id}',
                      ),
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        alignment: Alignment.topCenter,
                        child:
                            mcp.groups.isNotEmpty &&
                                _collapsed(mcp, row.groupId)
                            ? const SizedBox(width: double.infinity, height: 0)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: card,
                              ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
    final body = Column(
      children: [
        if (widget.embedded)
          SizedBox(
            height: 48,
            child: selected != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      title,
                      Align(alignment: Alignment.centerLeft, child: cancel),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (cancel != null) cancel,
                      Expanded(child: title),
                      ...actions,
                    ],
                  ),
          ),
        Expanded(child: list),
        if (selected != null) _selectionBar(mcp, selected),
      ],
    );
    if (widget.embedded) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 992),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: body,
          ),
        ),
      );
    }
    final page = Scaffold(
      appBar: AppBar(
        centerTitle: selected != null,
        leadingWidth: selected == null ? null : 76,
        leading:
            cancel ??
            IosIconButton(
              tooltip: l10n.mcpPageBackTooltip,
              semanticLabel: l10n.mcpPageBackTooltip,
              onTap: () => Navigator.of(context).maybePop(),
              icon: Lucide.ArrowLeft,
              minSize: 44,
            ),
        title: title,
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: body,
      ),
    );
    return SelectionBackScope(
      selecting: selected != null,
      onCancel: () {
        if (!_busy) setState(() => _selected = null);
      },
      child: page,
    );
  }
}

/// Restore group contents only after Flutter removes the drag overlay, whether
/// the user drops at a new slot, drops in place, or cancels the gesture.
class _GroupDragProxy extends StatefulWidget {
  const _GroupDragProxy({
    required this.child,
    required this.onMounted,
    required this.onRemoved,
  });
  final Widget child;
  final VoidCallback onMounted;
  final VoidCallback onRemoved;
  @override
  State<_GroupDragProxy> createState() => _GroupDragProxyState();
}

class _GroupDragProxyState extends State<_GroupDragProxy> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  void dispose() {
    widget.onRemoved();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

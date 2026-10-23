import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../core/models/mcp_presentation.dart';
import '../../../core/providers/mcp_provider.dart';
import '../../../desktop/setting/mcp_edit_dialog.dart';
import '../../../desktop/setting/mcp_json_edit_dialog.dart';
import '../../../desktop/setting/mcp_timeout_dialog.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../../../shared/widgets/form_sheet.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
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
      if (!mcp.groupCollapsed(groupId)) {
        result.addAll(
          servers.map((server) => (groupId: groupId, server: server)),
        );
      }
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
    final reordered = [...rows]..removeAt(oldIndex);
    reordered.insert(newIndex.clamp(0, reordered.length), moved);
    if (moved.server == null) {
      final groups = reordered
          .where((row) => row.server == null && row.groupId != _other)
          .map((row) => row.groupId)
          .toList();
      await mcp.reorderGroup(moved.groupId, groups.indexOf(moved.groupId));
      return;
    }
    if (mcp.groups.isEmpty) {
      final position = reordered.indexOf(moved);
      await mcp.moveServerBefore(
        moved.server!.id,
        null,
        position + 1 < reordered.length
            ? reordered[position + 1].server?.id
            : null,
      );
      return;
    }
    final position = reordered.indexOf(moved);
    // A drop above the first header belongs at the start of that group.
    String groupId = reordered.where((row) => row.server == null).first.groupId;
    for (var i = position - 1; i >= 0; i--) {
      if (reordered[i].server == null) {
        groupId = reordered[i].groupId;
        break;
      }
    }
    if (mcp.groupCollapsed(groupId)) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(
            context,
          )!.providerGroupsExpandToMoveToast,
        );
      }
      return;
    }
    final before = reordered
        .skip(position + 1)
        .where((row) => row.server != null && row.groupId == groupId)
        .firstOrNull
        ?.server
        ?.id;
    await mcp.moveServerBefore(
      moved.server!.id,
      groupId == _other ? null : groupId,
      before,
    );
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
    final l10n = AppLocalizations.of(context)!;
    final groupId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: context.overlaySurface,
        title: Text(l10n.mcpMoveToGroup),
        children: [
          for (final group in mcp.groups)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(group.id),
              child: SizedBox(
                height: 44,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(group.name),
                ),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(_other),
            child: SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.providerGroupsOther),
              ),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop('__new__'),
            child: SizedBox(
              height: 44,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.providerGroupsCreateNewGroupAction),
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted || groupId == null) return;
    if (groupId == '__new__') {
      await _groupName();
      if (mounted) await _move(ids);
      return;
    }
    final moved = await _run(
      () => mcp.moveServersToGroup(ids, groupId == _other ? null : groupId),
    );
    if (moved && mounted) setState(() => _selected = null);
  }

  Future<bool> _confirm(String title, String message) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: context.overlaySurface,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.mcpPageCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  l10n.mcpPageDelete,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
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
      showAdaptiveActionMenu(
        context,
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
            onTap: () => showMcpIconPicker(context, server.id),
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

  Widget _groupHeader(McpProvider mcp, String id, int index) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final group = mcp.groups.where((group) => group.id == id).firstOrNull;
    final members = mcp.servers
        .where(
          (server) => (mcp.presentationFor(server.id).groupId ?? _other) == id,
        )
        .map((server) => server.id)
        .toSet();
    final all =
        members.isNotEmpty &&
        members.every((id) => _selected?.contains(id) ?? false);
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _run(
                () => mcp.setGroupCollapsed(id, !mcp.groupCollapsed(id)),
              ),
              child: Row(
                children: [
                  Icon(
                    mcp.groupCollapsed(id)
                        ? Lucide.ChevronRight
                        : Lucide.ChevronDown,
                    size: 16,
                    color: cs.onSurface.withValues(alpha: .5),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      group?.name ?? l10n.providerGroupsOther,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: AppFontWeights.emphasis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${members.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: .5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selected != null)
            TextButton(
              onPressed: () => setState(() {
                if (all) {
                  _selected!.removeAll(members);
                } else {
                  _selected!.addAll(members);
                }
              }),
              child: Text(
                all
                    ? l10n.sideDrawerSelectionDeselectAll
                    : l10n.sideDrawerSelectionSelectAll,
              ),
            )
          else if (group != null) ...[
            ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Lucide.GripVertical,
                  size: 16,
                  color: cs.onSurface.withValues(alpha: .4),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l10n.providerGroupsManageAction,
              icon: const Icon(Lucide.Ellipsis, size: 18),
              onSelected: (action) async {
                if (action == 'rename') {
                  await _groupName(group: group);
                } else if (await _confirm(
                      l10n.providerGroupsDeleteConfirmTitle,
                      l10n.mcpDeleteGroupConfirm,
                    ) &&
                    mounted) {
                  await _run(() => mcp.deleteGroup(group.id));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(l10n.mcpRenameGroup),
                ),
                PopupMenuItem(value: 'delete', child: Text(l10n.mcpPageDelete)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _actions(McpProvider mcp) {
    final l10n = AppLocalizations.of(context)!;
    return [
      IconButton(
        key: const ValueKey('mcp-selection-start'),
        tooltip: l10n.mcpSelectServers,
        onPressed: _busy ? null : () => setState(() => _selected = {}),
        icon: const Icon(Lucide.ListChecks, size: 21),
      ),
      PopupMenuButton<String>(
        tooltip: l10n.providerGroupsManageAction,
        icon: const Icon(Lucide.Ellipsis, size: 21),
        onSelected: (action) {
          switch (action) {
            case 'group':
              _groupName();
            case 'timeout':
              widget.desktop
                  ? showDesktopMcpTimeoutDialog(context)
                  : showMcpTimeoutSheet(context);
            case 'import':
              showMcpJsonImport(context, desktop: widget.desktop);
            case 'json':
              widget.desktop
                  ? showDesktopMcpJsonEditDialog(context)
                  : showMcpJsonEditSheet(context);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            key: const ValueKey('mcp-create-group'),
            value: 'group',
            child: Text(l10n.providerGroupsCreateNewGroupAction),
          ),
          PopupMenuItem(
            value: 'timeout',
            child: Text(l10n.mcpTimeoutSettingsTooltip),
          ),
          PopupMenuItem(value: 'import', child: Text(l10n.mcpImportJson)),
          PopupMenuItem(
            value: 'json',
            child: Text(l10n.mcpJsonEditButtonTooltip),
          ),
        ],
      ),
      IconButton(
        tooltip: l10n.mcpPageAddMcpTooltip,
        onPressed: _busy ? null : () => _edit(null),
        icon: const Icon(Lucide.Plus, size: 22),
      ),
    ];
  }

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
              child: TextButton.icon(
                key: const ValueKey('mcp-selection-enable'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _run(() => mcp.setServersEnabled(selected, enable)),
                icon: const Icon(Lucide.Power, size: 20),
                label: Text(
                  enable ? l10n.mcpEnableSelected : l10n.mcpDisableSelected,
                ),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                key: const ValueKey('mcp-selection-move'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _move(selected),
                icon: const Icon(Lucide.Folder, size: 20),
                label: Text(l10n.mcpMoveToGroup),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                key: const ValueKey('mcp-selection-delete'),
                onPressed: selected.isEmpty || _busy
                    ? null
                    : () => _delete(selected),
                icon: Icon(
                  Lucide.Trash2,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                label: Text(l10n.mcpPageDelete),
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
    final rows = _rows(mcp);
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
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _selected = all ? {} : ids),
              child: Text(
                all
                    ? l10n.sideDrawerSelectionDeselectAll
                    : l10n.sideDrawerSelectionSelectAll,
              ),
            ),
          ];
    final cancel = selected == null
        ? null
        : TextButton(
            onPressed: _busy ? null : () => setState(() => _selected = null),
            child: Text(l10n.mcpPageCancel),
          );
    final list = rows.isEmpty
        ? Center(child: Text(l10n.mcpPageNoServers))
        : CustomScrollView(
            slivers: [
              SliverReorderableList(
                itemCount: rows.length,
                onReorderItem: (oldIndex, newIndex) =>
                    _run(() => _reorder(mcp, rows, oldIndex, newIndex)),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final server = row.server;
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
                        onLongPress: () => _serverMenu(rowContext, server),
                        avatarBuilder: widget.desktop || selected != null
                            ? null
                            : (avatar) => ReorderableDelayedDragStartListener(
                                index: index,
                                child: avatar,
                              ),
                        onEnabledChanged: widget.desktop
                            ? (value) => _run(
                                () => mcp.updateServerMetadata(
                                  server.copyWith(enabled: value),
                                ),
                              )
                            : null,
                        onDetails: () => _details(server),
                        onAuthorize: () => mcp.authorize(server.id),
                        actions: widget.desktop
                            ? [
                                IconButton(
                                  tooltip: l10n.mcpPageReconnect,
                                  onPressed: () =>
                                      _run(() => mcp.reconnect(server.id)),
                                  icon: const Icon(Lucide.RefreshCw, size: 18),
                                ),
                                IconButton(
                                  tooltip: l10n.mcpPageDelete,
                                  onPressed: () => _delete({server.id}),
                                  icon: const Icon(Lucide.Trash2, size: 18),
                                ),
                              ]
                            : const [],
                      ),
                    ),
                  );
                  if (selected == null && widget.desktop) {
                    card = ReorderableDragStartListener(
                      index: index,
                      child: card,
                    );
                  }
                  if (!widget.desktop && selected == null) {
                    card = Slidable(
                      endActionPane: ActionPane(
                        motion: const StretchMotion(),
                        extentRatio: .42,
                        children: [
                          SlidableAction(
                            onPressed: (_) =>
                                _run(() => mcp.reconnect(server.id)),
                            icon: Lucide.RefreshCw,
                            label: l10n.mcpPageReconnect,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                          ),
                          SlidableAction(
                            onPressed: (_) => _delete({server.id}),
                            icon: Lucide.Trash2,
                            label: l10n.mcpPageDelete,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ],
                      ),
                      child: card,
                    );
                  }
                  return Padding(
                    key: ValueKey(
                      '${widget.desktop ? 'desktop-mcp' : 'mcp'}-${server.id}',
                    ),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: card,
                  );
                },
              ),
            ],
          );
    final body = Column(
      children: [
        if (widget.embedded)
          SizedBox(
            height: 48,
            child: Row(
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
    return Scaffold(
      appBar: AppBar(
        leadingWidth: selected == null ? null : 76,
        leading:
            cancel ??
            IconButton(
              tooltip: l10n.mcpPageBackTooltip,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Lucide.ArrowLeft),
            ),
        title: title,
        actions: actions,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: body,
      ),
    );
  }
}

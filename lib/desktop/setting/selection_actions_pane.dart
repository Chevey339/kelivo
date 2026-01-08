import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/models/selection_action.dart';

/// Desktop: Selection Actions (scripts for floating action bar) settings pane
class DesktopSelectionActionsPane extends StatelessWidget {
  const DesktopSelectionActionsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selection Actions',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: cs.onSurface.withOpacity(0.9)),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () => _showActionEditor(context, null),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _SelectionActionsCard(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showActionEditor(BuildContext context, SelectionAction? existing) async {
    final result = await showDialog<SelectionAction>(
      context: context,
      builder: (ctx) => _ActionEditorDialog(existing: existing),
    );
    if (result != null) {
      final sp = context.read<SettingsProvider>();
      if (existing != null) {
        await sp.updateSelectionAction(result);
      } else {
        await sp.addSelectionAction(result);
      }
    }
  }
}

/// Card showing list of configured selection actions
class _SelectionActionsCard extends StatefulWidget {
  @override
  State<_SelectionActionsCard> createState() => _SelectionActionsCardState();
}

class _SelectionActionsCardState extends State<_SelectionActionsCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sp = context.watch<SettingsProvider>();
    final actions = sp.selectionActions;

    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover
        ? cs.primary.withOpacity(isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (actions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(lucide.Lucide.Zap, size: 32, color: cs.onSurface.withOpacity(0.3)),
                    const SizedBox(height: 12),
                    Text(
                      'No actions configured',
                      style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click + to add scripts that run on selected text',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.4)),
                    ),
                  ],
                ),
              )
            else ...[
              ...actions.map((action) => _ActionItem(
                action: action,
                onEdit: () => _showActionEditor(context, action),
                onDelete: () async {
                  await context.read<SettingsProvider>().removeSelectionAction(action.id);
                },
              )),
            ],
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(lucide.Lucide.info, size: 14, color: cs.primary.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select text in chat → floating bar appears → click action to run script with selected text',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showActionEditor(BuildContext context, SelectionAction? existing) async {
    final result = await showDialog<SelectionAction>(
      context: context,
      builder: (ctx) => _ActionEditorDialog(existing: existing),
    );
    if (result != null) {
      final sp = context.read<SettingsProvider>();
      if (existing != null) {
        await sp.updateSelectionAction(result);
      } else {
        await sp.addSelectionAction(result);
      }
    }
  }
}

class _ActionItem extends StatefulWidget {
  final SelectionAction action;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionItem({required this.action, required this.onEdit, required this.onDelete});

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _hover = false;

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'volume2': return lucide.Lucide.Volume2;
      case 'languages': return lucide.Lucide.Languages;
      case 'search': return lucide.Lucide.Search;
      case 'sparkles': return lucide.Lucide.Sparkles;
      case 'brain': return lucide.Lucide.Brain;
      case 'terminal': return lucide.Lucide.Terminal;
      case 'code': return lucide.Lucide.Code;
      case 'fileText': return lucide.Lucide.FileText;
      case 'link': return lucide.Lucide.Link;
      case 'share': return lucide.Lucide.Share;
      case 'bookmark': return lucide.Lucide.Bookmark;
      case 'zap': return lucide.Lucide.Zap;
      case 'wand': return lucide.Lucide.Wand2;
      case 'bot': return lucide.Lucide.Bot;
      case 'messageCircle': return lucide.Lucide.MessageCircle;
      default: return lucide.Lucide.Terminal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _hover 
              ? (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(_getIcon(widget.action.iconName), size: 18, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.action.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    widget.action.scriptPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            if (_hover) ...[
              _SmallIconBtn(icon: lucide.Lucide.Settings2, onTap: widget.onEdit),
              const SizedBox(width: 4),
              _SmallIconBtn(icon: lucide.Lucide.Trash2, onTap: widget.onDelete),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionEditorDialog extends StatefulWidget {
  final SelectionAction? existing;
  const _ActionEditorDialog({this.existing});

  @override
  State<_ActionEditorDialog> createState() => _ActionEditorDialogState();
}

class _ActionEditorDialogState extends State<_ActionEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _pathController;
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _pathController = TextEditingController(text: widget.existing?.scriptPath ?? '');
    _selectedIcon = widget.existing?.iconName ?? 'terminal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Action' : 'Add Action'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g., TTS, Translate, Summarize',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Script Path',
                      hintText: '/path/to/script.py or script.sh',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(lucide.Lucide.FolderOpen),
                  onPressed: () async {
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.any,
                      dialogTitle: 'Select Script',
                    );
                    if (result != null && result.files.single.path != null) {
                      _pathController.text = result.files.single.path!;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Icon', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SelectionAction.availableIcons.map((iconName) {
                final isSelected = _selectedIcon == iconName;
                return InkWell(
                  onTap: () => setState(() => _selectedIcon = iconName),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primary.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outlineVariant.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      _getIconData(iconName),
                      size: 18,
                      color: isSelected ? cs.primary : cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final path = _pathController.text.trim();
            if (name.isEmpty || path.isEmpty) return;
            
            final action = widget.existing != null
                ? widget.existing!.copyWith(name: name, scriptPath: path, iconName: _selectedIcon)
                : SelectionAction.create(name: name, scriptPath: path, iconName: _selectedIcon);
            Navigator.of(context).pop(action);
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'volume2': return lucide.Lucide.Volume2;
      case 'languages': return lucide.Lucide.Languages;
      case 'search': return lucide.Lucide.Search;
      case 'sparkles': return lucide.Lucide.Sparkles;
      case 'brain': return lucide.Lucide.Brain;
      case 'terminal': return lucide.Lucide.Terminal;
      case 'code': return lucide.Lucide.Code;
      case 'fileText': return lucide.Lucide.FileText;
      case 'link': return lucide.Lucide.Link;
      case 'share': return lucide.Lucide.Share;
      case 'bookmark': return lucide.Lucide.Bookmark;
      case 'zap': return lucide.Lucide.Zap;
      case 'wand': return lucide.Lucide.Wand2;
      case 'bot': return lucide.Lucide.Bot;
      case 'messageCircle': return lucide.Lucide.MessageCircle;
      default: return lucide.Lucide.Terminal;
    }
  }
}

class _SmallIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SmallIconBtn({required this.icon, required this.onTap});

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hover
                ? (isDark ? Colors.white10 : Colors.black.withOpacity(0.06))
                : Colors.transparent,
          ),
          child: Icon(widget.icon, size: 16, color: cs.onSurface.withOpacity(0.65)),
        ),
      ),
    );
  }
}

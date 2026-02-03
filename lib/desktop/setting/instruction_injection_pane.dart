import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/models/instruction_injection.dart';
import '../../core/providers/instruction_injection_group_provider.dart';
import '../../core/providers/instruction_injection_provider.dart';
import '../../shared/widgets/snackbar.dart';

class DesktopInstructionInjectionPane extends StatefulWidget {
  const DesktopInstructionInjectionPane({super.key});

  @override
  State<DesktopInstructionInjectionPane> createState() =>
      _DesktopInstructionInjectionPaneState();
}

class _DesktopInstructionInjectionPaneState
    extends State<DesktopInstructionInjectionPane> {
  static const List<String> _textExtensions = <String>[
    'txt',
    'json',
    'yaml',
    'yml',
    'lua',
    'md',
    'log',
    'ini',
    'conf',
    'cfg',
    'csv',
    'py',
    'js',
    'ts',
    'toml',
    'xml',
    'sql',
    'sh',
  ];

  @override
  void initState() {
    super.initState();
    // Ensure items are loaded on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InstructionInjectionProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<InstructionInjectionProvider>();
    final groupUi = context.watch<InstructionInjectionGroupProvider>();
    final items = provider.items;

    final Map<String, List<InstructionInjection>> grouped =
        <String, List<InstructionInjection>>{};
    for (final item in items) {
      final g = item.group.trim();
      (grouped[g] ??= <InstructionInjection>[]).add(item);
    }
    final groupNames = grouped.keys.toList()
      ..sort((a, b) {
        final aa = a.trim();
        final bb = b.trim();
        if (aa.isEmpty && bb.isNotEmpty) return -1;
        if (aa.isNotEmpty && bb.isEmpty) return 1;
        return aa.toLowerCase().compareTo(bb.toLowerCase());
      });

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
                            l10n.instructionInjectionTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: cs.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Import,
                        onTap: _importFromFiles,
                        tooltip: l10n.instructionInjectionImportTooltip,
                      ),
                      const SizedBox(width: 6),
                      _SmallIconBtn(
                        icon: lucide.Lucide.Plus,
                        onTap: () => _showAddEditDialog(context),
                        tooltip: l10n.instructionInjectionAddTooltip,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            lucide.Lucide.Layers,
                            size: 56,
                            color: cs.onSurface.withOpacity(0.28),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.instructionInjectionEmptyMessage,
                            style: TextStyle(
                              color: cs.onSurface.withOpacity(0.65),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final groupName in groupNames) ...[
                  SliverToBoxAdapter(
                    child: _GroupHeader(
                      title: groupName.trim().isEmpty
                          ? l10n.instructionInjectionUngroupedGroup
                          : groupName.trim(),
                      collapsed: groupUi.isCollapsed(groupName),
                      onToggle: () => context
                          .read<InstructionInjectionGroupProvider>()
                          .toggleCollapsed(groupName),
                    ),
                  ),
                  if (!groupUi.isCollapsed(groupName))
                    SliverReorderableList(
                      itemCount: grouped[groupName]?.length ?? 0,
                      itemBuilder: (context, index) {
                        final item = grouped[groupName]![index];
                        final displayTitle = item.title.trim().isEmpty
                            ? l10n.instructionInjectionDefaultTitle
                            : item.title;
                        return KeyedSubtree(
                          key: ValueKey(
                            'desktop-instruction-injection-${item.id}',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReorderableDragStartListener(
                              index: index,
                              child: _InstructionInjectionCard(
                                title: displayTitle,
                                prompt: item.prompt,
                                onTap: () =>
                                    _showAddEditDialog(context, item: item),
                                onEdit: () =>
                                    _showAddEditDialog(context, item: item),
                                onDelete: () async {
                                  await context
                                      .read<InstructionInjectionProvider>()
                                      .delete(item.id);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex -= 1;
                        await context
                            .read<InstructionInjectionProvider>()
                            .reorderWithinGroup(
                              group: groupName,
                              oldIndex: oldIndex,
                              newIndex: newIndex,
                            );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog(
    BuildContext context, {
    InstructionInjection? item,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => _InstructionInjectionEditDialog(
        title: item == null
            ? l10n.instructionInjectionAddTitle
            : l10n.instructionInjectionEditTitle,
        initTitle: item?.title ?? '',
        initGroup: item?.group ?? '',
        initPrompt: item?.prompt ?? '',
      ),
    );
    if (result == null) return;
    final title = (result['title'] ?? '').trim();
    final group = (result['group'] ?? '').trim();
    final prompt = (result['prompt'] ?? '').trim();
    if (title.isEmpty || prompt.isEmpty) return;

    final provider = context.read<InstructionInjectionProvider>();
    if (item == null) {
      final newItem = InstructionInjection(
        id: const Uuid().v4(),
        title: title,
        prompt: prompt,
        group: group,
      );
      await provider.add(newItem);
    } else {
      await provider.update(
        item.copyWith(title: title, group: group, prompt: prompt),
      );
    }
  }

  Future<String?> _readPickedFileAsString(PlatformFile file) async {
    try {
      if (file.bytes != null && file.bytes!.isNotEmpty) {
        return utf8.decode(file.bytes!, allowMalformed: true);
      }
    } catch (_) {}
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    try {
      return await File(path).readAsString();
    } catch (_) {
      try {
        final bytes = await File(path).readAsBytes();
        return utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _importFromFiles() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _textExtensions,
        withData: true,
      );
    } catch (_) {
      return;
    }
    if (result == null || result.files.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<InstructionInjectionProvider>();
    final List<InstructionInjection> imports = [];

    for (final file in result.files) {
      final name = file.name.trim();
      final ext = (file.extension ?? '').toLowerCase();
      if (!_textExtensions.contains(ext)) continue;
      final content = await _readPickedFileAsString(file);
      final prompt = content ?? '';
      if (name.isEmpty || prompt.trim().isEmpty) continue;
      imports.add(
        InstructionInjection(
          id: const Uuid().v4(),
          title: name,
          prompt: prompt,
        ),
      );
    }

    await provider.addMany(imports);
    if (!mounted) return;

    showAppSnackBar(
      context,
      message: l10n.instructionInjectionImportSuccess(imports.length),
      type: imports.isEmpty
          ? NotificationType.warning
          : NotificationType.success,
    );
  }
}

class _InstructionInjectionCard extends StatefulWidget {
  const _InstructionInjectionCard({
    required this.title,
    required this.prompt,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final String title;
  final String prompt;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_InstructionInjectionCard> createState() =>
      _InstructionInjectionCardState();
}

class _InstructionInjectionCardState extends State<_InstructionInjectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderColor = _hover
        ? cs.primary.withOpacity(isDark ? 0.5 : 0.7)
        : cs.outlineVariant.withOpacity(isDark ? 0.12 : 0.08);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.0),
          ),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(lucide.Lucide.Layers, size: 20, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.prompt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _SmallIconBtn(
                icon: lucide.Lucide.Settings2,
                onTap: widget.onEdit,
              ),
              const SizedBox(width: 6),
              _SmallIconBtn(icon: lucide.Lucide.Trash2, onTap: widget.onDelete),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionInjectionEditDialog extends StatefulWidget {
  const _InstructionInjectionEditDialog({
    required this.title,
    required this.initTitle,
    required this.initGroup,
    required this.initPrompt,
  });
  final String title;
  final String initTitle;
  final String initGroup;
  final String initPrompt;

  @override
  State<_InstructionInjectionEditDialog> createState() =>
      _InstructionInjectionEditDialogState();
}

class _InstructionInjectionEditDialogState
    extends State<_InstructionInjectionEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _groupController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initTitle);
    _groupController = TextEditingController(text: widget.initGroup);
    _promptController = TextEditingController(text: widget.initPrompt);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _groupController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 58),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _SmallIconBtn(
                        icon: lucide.Lucide.X,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.instructionInjectionNameLabel),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _groupController,
                    decoration: _deskInputDecoration(context).copyWith(
                      hintText: l10n.instructionInjectionGroupLabel,
                      helperText: l10n.instructionInjectionGroupHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    maxLines: 8,
                    decoration: _deskInputDecoration(
                      context,
                    ).copyWith(hintText: l10n.instructionInjectionPromptLabel),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _DeskIosButton(
                label: l10n.quickPhraseSaveButton,
                filled: true,
                dense: true,
                onTap: () {
                  Navigator.of(context).pop({
                    'title': _titleController.text,
                    'group': _groupController.text,
                    'prompt': _promptController.text,
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
    if ((widget.tooltip ?? '').isEmpty) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.filled,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool dense;
  final VoidCallback onTap;

  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.filled
        ? cs.onPrimary
        : cs.onSurface.withOpacity(0.9);
    final bg = widget.filled
        ? (_hover ? cs.primary.withOpacity(0.92) : cs.primary)
        : (_hover
              ? (isDark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.05))
              : Colors.transparent);
    final borderColor = widget.filled
        ? Colors.transparent
        : cs.outlineVariant.withOpacity(isDark ? 0.22 : 0.18);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.dense ? 8 : 12,
              horizontal: 12,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: widget.dense ? 13 : 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _deskInputDecoration(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: false,
    filled: true,
    fillColor: isDark ? Colors.white10 : const Color(0xFFF7F7F9),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: cs.outlineVariant.withOpacity(0.2),
        width: 0.8,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary.withOpacity(0.45), width: 1.0),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

class _GroupHeader extends StatefulWidget {
  const _GroupHeader({
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  State<_GroupHeader> createState() => _GroupHeaderState();
}

class _GroupHeaderState extends State<_GroupHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = (isDark ? Colors.white : Colors.black).withOpacity(
      isDark ? 0.08 : 0.05,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: _hover ? hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Center(
                    child: AnimatedRotation(
                      turns: widget.collapsed ? 0.0 : 0.25, // right -> down
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        lucide.Lucide.ChevronRight,
                        size: 16,
                        color: cs.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withOpacity(0.9),
                    ),
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

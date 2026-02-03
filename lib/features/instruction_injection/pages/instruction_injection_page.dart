import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/models/instruction_injection.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/instruction_injection_group_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/haptics.dart';
import '../../../shared/widgets/snackbar.dart';

class InstructionInjectionPage extends StatefulWidget {
  const InstructionInjectionPage({super.key});

  @override
  State<InstructionInjectionPage> createState() =>
      _InstructionInjectionPageState();
}

class _InstructionInjectionPageState extends State<InstructionInjectionPage> {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InstructionInjectionProvider>().initialize();
    });
  }

  Future<void> _showAddEditSheet({InstructionInjection? item}) async {
    final cs = Theme.of(context).colorScheme;

    final result = await showModalBottomSheet<Map<String, String>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _InstructionInjectionEditSheet(item: item);
      },
    );

    if (result != null) {
      final title = result['title']?.trim() ?? '';
      final prompt = result['prompt']?.trim() ?? '';
      final group = result['group']?.trim() ?? '';
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
          item.copyWith(title: title, prompt: prompt, group: group),
        );
      }
    }
  }

  Future<void> _deleteItem(InstructionInjection item) async {
    await context.read<InstructionInjectionProvider>().delete(item.id);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    return Scaffold(
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.instructionInjectionBackTooltip,
          child: _TactileIconButton(
            icon: Lucide.ArrowLeft,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.instructionInjectionTitle),
        actions: [
          Tooltip(
            message: l10n.instructionInjectionImportTooltip,
            child: _TactileIconButton(
              icon: Lucide.Import,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
              onTap: _importFromFiles,
            ),
          ),
          Tooltip(
            message: l10n.instructionInjectionAddTooltip,
            child: _TactileIconButton(
              icon: Lucide.Plus,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
              onTap: () => _showAddEditSheet(),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Lucide.Layers,
                    size: 64,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.instructionInjectionEmptyMessage,
                    style: TextStyle(
                      color: cs.onSurface.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final groupName in groupNames) ...[
                  _GroupHeader(
                    title: groupName.trim().isEmpty
                        ? l10n.instructionInjectionUngroupedGroup
                        : groupName.trim(),
                    collapsed: groupUi.isCollapsed(groupName),
                    onToggle: () => context
                        .read<InstructionInjectionGroupProvider>()
                        .toggleCollapsed(groupName),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: groupUi.isCollapsed(groupName)
                        ? const SizedBox.shrink()
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: grouped[groupName]?.length ?? 0,
                            buildDefaultDragHandles: false,
                            proxyDecorator: (child, index, animation) {
                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  final t = Curves.easeOut.transform(
                                    animation.value,
                                  );
                                  return Transform.scale(
                                    scale: 0.98 + 0.02 * t,
                                    child: child,
                                  );
                                },
                              );
                            },
                            onReorder: (oldIndex, newIndex) {
                              if (newIndex > oldIndex) newIndex -= 1;
                              context
                                  .read<InstructionInjectionProvider>()
                                  .reorderWithinGroup(
                                    group: groupName,
                                    oldIndex: oldIndex,
                                    newIndex: newIndex,
                                  );
                            },
                            itemBuilder: (context, index) {
                              final item = grouped[groupName]![index];
                              final displayTitle = item.title.trim().isEmpty
                                  ? l10n.instructionInjectionDefaultTitle
                                  : item.title;
                              return KeyedSubtree(
                                key: ValueKey(
                                  'reorder-instruction-injection-${item.id}',
                                ),
                                child: ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Slidable(
                                      key: ValueKey(item.id),
                                      endActionPane: ActionPane(
                                        motion: const StretchMotion(),
                                        extentRatio: 0.35,
                                        children: [
                                          CustomSlidableAction(
                                            autoClose: true,
                                            backgroundColor: Colors.transparent,
                                            child: Container(
                                              width: double.infinity,
                                              height: double.infinity,
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? cs.error.withOpacity(0.22)
                                                    : cs.error.withOpacity(
                                                        0.14,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: cs.error.withOpacity(
                                                    0.35,
                                                  ),
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 8,
                                                  ),
                                              alignment: Alignment.center,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Lucide.Trash2,
                                                      color: cs.error,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      l10n.quickPhraseDeleteButton,
                                                      style: TextStyle(
                                                        color: cs.error,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            onPressed: (_) => _deleteItem(item),
                                          ),
                                        ],
                                      ),
                                      child: _TactileCard(
                                        pressedScale: 0.98,
                                        onTap: () =>
                                            _showAddEditSheet(item: item),
                                        builder: (pressed, overlay) {
                                          final baseBg = isDark
                                              ? Colors.white10
                                              : Colors.white.withOpacity(0.96);
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Color.alphaBlend(
                                                overlay,
                                                baseBg,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: cs.outlineVariant
                                                    .withOpacity(
                                                      isDark ? 0.1 : 0.08,
                                                    ),
                                                width: 0.6,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Lucide.Layers,
                                                              size: 18,
                                                              color: cs.primary,
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                displayTitle,
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 8,
                                                        ),
                                                        Text(
                                                          item.prompt,
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color:
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Lucide.ChevronRight,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textBase = cs.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Center(
                child: AnimatedRotation(
                  turns: collapsed ? 0.0 : 0.25,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Lucide.ChevronRight,
                    size: 16,
                    color: textBase.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: textBase,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionInjectionEditSheet extends StatefulWidget {
  const _InstructionInjectionEditSheet({required this.item});

  final InstructionInjection? item;

  @override
  State<_InstructionInjectionEditSheet> createState() =>
      _InstructionInjectionEditSheetState();
}

class _InstructionInjectionEditSheetState
    extends State<_InstructionInjectionEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _groupController;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _groupController = TextEditingController(text: widget.item?.group ?? '');
    _promptController = TextEditingController(text: widget.item?.prompt ?? '');
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
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                widget.item == null
                    ? l10n.instructionInjectionAddTitle
                    : l10n.instructionInjectionEditTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.instructionInjectionNameLabel,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _groupController,
              decoration: InputDecoration(
                labelText: l10n.instructionInjectionGroupLabel,
                hintText: l10n.instructionInjectionGroupHint,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: l10n.instructionInjectionPromptLabel,
                alignLabelWithHint: true,
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withOpacity(0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _IosOutlineButton(
                    label: l10n.quickPhraseCancelButton,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _IosFilledButton(
                    label: l10n.quickPhraseSaveButton,
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
          ],
        ),
      ),
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final press = base.withOpacity(0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: _pressed ? press : base,
        ),
      ),
    );
  }
}

class _TactileCard extends StatefulWidget {
  const _TactileCard({
    required this.builder,
    this.onTap,
    this.pressedScale = 0.98,
  });
  final Widget Function(bool pressed, Color overlay) builder;
  final VoidCallback? onTap;
  final double pressedScale;

  @override
  State<_TactileCard> createState() => _TactileCardState();
}

class _TactileCardState extends State<_TactileCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = _pressed
        ? (isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.05))
        : Colors.transparent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => Future.delayed(
              const Duration(milliseconds: 120),
              () => _set(false),
            ),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              Haptics.soft();
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed, overlay),
      ),
    );
  }
}

class _IosOutlineButton extends StatefulWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _IosFilledButton extends StatefulWidget {
  const _IosFilledButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cs.primary,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

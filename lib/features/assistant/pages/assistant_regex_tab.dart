import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/assistant_regex.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../core/services/haptics.dart';

class AssistantRegexTab extends StatefulWidget {
  const AssistantRegexTab({super.key, required this.assistantId});
  final String assistantId;

  @override
  State<AssistantRegexTab> createState() => _AssistantRegexTabState();
}

class _AssistantRegexTabState extends State<AssistantRegexTab> {
  List<AssistantRegexScope> _normalizeScopes(Iterable<AssistantRegexScope> scopes) {
    final set = {...scopes};
    return AssistantRegexScope.values.where((e) => set.contains(e)).toList(growable: false);
  }

  void _reorder(int oldIndex, int newIndex) {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    if (newIndex > oldIndex) newIndex -= 1;
    ap.reorderAssistantRegex(
      assistantId: widget.assistantId,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  }

  Future<void> _toggleRule(AssistantRegex rule, bool enabled) async {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = assistant.regexRules.map((r) {
      if (r.id == rule.id) return r.copyWith(enabled: enabled);
      return r;
    }).toList();
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  Future<void> _deleteRule(AssistantRegex rule) async {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = List<AssistantRegex>.of(assistant.regexRules)..removeWhere((r) => r.id == rule.id);
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  Future<void> _addOrEdit({AssistantRegex? rule}) async {
    final data = await _showRegexEditor(context, rule: rule);
    if (data == null) return;
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = List<AssistantRegex>.of(assistant.regexRules);
    final updated = AssistantRegex(
      id: rule?.id ?? const Uuid().v4(),
      name: data.name,
      pattern: data.pattern,
      replacement: data.replacement,
      scopes: _normalizeScopes(data.scopes),
      visualOnly: data.visualOnly,
      replaceOnly: data.replaceOnly,
      enabled: rule?.enabled ?? true,
    );
    if (rule == null) {
      list.add(updated);
    } else {
      final idx = list.indexWhere((r) => r.id == rule.id);
      if (idx == -1) {
        list.add(updated);
      } else {
        list[idx] = updated;
      }
    }
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assistant = context.watch<AssistantProvider>().getById(widget.assistantId);
    if (assistant == null) return const SizedBox.shrink();
    final rules = assistant.regexRules;

    if (rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Lucide.Wand2, size: 64, color: cs.primary.withOpacity(0.6)),
              const SizedBox(height: 16),
              Text(
                l10n.assistantEditRegexDescription,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 24),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: IosCardPress(
                  onTap: () => _addOrEdit(),
                  borderRadius: BorderRadius.circular(12),
                  baseColor: isDark ? Colors.white10 : cs.primary.withOpacity(0.12),
                  pressedBlendStrength: 0.18,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        l10n.assistantEditAddRegexButton,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: rules.length,
          buildDefaultDragHandles: false,
          proxyDecorator: (child, index, animation) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                final t = Curves.easeOut.transform(animation.value);
                return Transform.scale(
                  scale: 0.98 + 0.02 * t,
                  child: child,
                );
              },
            );
          },
          onReorder: _reorder,
          itemBuilder: (context, index) {
            final rule = rules[index];
            return KeyedSubtree(
              key: ValueKey('assistant-regex-${rule.id}'),
              child: ReorderableDelayedDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RegexRuleCard(
                    rule: rule,
                    onTap: () => _addOrEdit(rule: rule),
                    onDelete: () => _deleteRule(rule),
                    onToggle: (v) => _toggleRule(rule, v),
                    desktop: false,
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 60,
          child: Center(
            child: _GlassCircleButton(
              icon: Lucide.Plus,
              color: cs.primary,
              onTap: () => _addOrEdit(),
            ),
          ),
        ),
      ],
    );
  }
}

class AssistantRegexDesktopPane extends StatefulWidget {
  const AssistantRegexDesktopPane({super.key, required this.assistantId});
  final String assistantId;

  @override
  State<AssistantRegexDesktopPane> createState() => _AssistantRegexDesktopPaneState();
}

class _AssistantRegexDesktopPaneState extends State<AssistantRegexDesktopPane> {
  List<AssistantRegexScope> _normalizeScopes(Iterable<AssistantRegexScope> scopes) {
    final set = {...scopes};
    return AssistantRegexScope.values.where((e) => set.contains(e)).toList(growable: false);
  }

  void _reorder(int oldIndex, int newIndex) {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    if (newIndex > oldIndex) newIndex -= 1;
    ap.reorderAssistantRegex(
      assistantId: widget.assistantId,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );
  }

  Future<void> _toggleRule(AssistantRegex rule, bool enabled) async {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = assistant.regexRules.map((r) {
      if (r.id == rule.id) return r.copyWith(enabled: enabled);
      return r;
    }).toList();
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  Future<void> _deleteRule(AssistantRegex rule) async {
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = List<AssistantRegex>.of(assistant.regexRules)..removeWhere((r) => r.id == rule.id);
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  Future<void> _addOrEdit({AssistantRegex? rule}) async {
    final data = await _showRegexEditor(context, rule: rule);
    if (data == null) return;
    final ap = context.read<AssistantProvider>();
    final assistant = ap.getById(widget.assistantId);
    if (assistant == null) return;
    final list = List<AssistantRegex>.of(assistant.regexRules);
    final updated = AssistantRegex(
      id: rule?.id ?? const Uuid().v4(),
      name: data.name,
      pattern: data.pattern,
      replacement: data.replacement,
      scopes: _normalizeScopes(data.scopes),
      visualOnly: data.visualOnly,
      replaceOnly: data.replaceOnly,
      enabled: rule?.enabled ?? true,
    );
    if (rule == null) {
      list.add(updated);
    } else {
      final idx = list.indexWhere((r) => r.id == rule.id);
      if (idx == -1) {
        list.add(updated);
      } else {
        list[idx] = updated;
      }
    }
    await ap.updateAssistant(assistant.copyWith(regexRules: list));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assistant = context.watch<AssistantProvider>().getById(widget.assistantId);
    if (assistant == null) return const SizedBox.shrink();
    final rules = assistant.regexRules;

    return Container(
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.assistantEditPageRegexTab,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.assistantEditRegexDescription,
                        style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.65)),
                      ),
                    ],
                  ),
                ),
                IosCardPress(
                  onTap: () => _addOrEdit(),
                  borderRadius: BorderRadius.circular(12),
                  baseColor: isDark ? Colors.white10 : cs.primary.withOpacity(0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  pressedBlendStrength: 0.18,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Lucide.Plus, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        l10n.assistantEditAddRegexButton,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: rules.isEmpty
                ? Center(
                    child: Text(
                      l10n.assistantEditRegexDescription,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.6)),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: rules.length,
                    buildDefaultDragHandles: false,
                    proxyDecorator: (child, index, animation) {
                      return AnimatedBuilder(
                        animation: animation,
                        builder: (context, _) {
                          final t = Curves.easeOut.transform(animation.value);
                          return Transform.scale(
                            scale: 0.985 + 0.015 * t,
                            child: child,
                          );
                        },
                      );
                    },
                    onReorder: _reorder,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return KeyedSubtree(
                        key: ValueKey('assistant-regex-desktop-${rule.id}'),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _RegexRuleCard(
                              rule: rule,
                              onTap: () => _addOrEdit(rule: rule),
                              onDelete: () => _deleteRule(rule),
                              onToggle: (v) => _toggleRule(rule, v),
                              desktop: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegexRuleCard extends StatefulWidget {
  const _RegexRuleCard({
    required this.rule,
    required this.onTap,
    required this.onDelete,
    required this.onToggle,
    required this.desktop,
  });

  final AssistantRegex rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final bool desktop;

  @override
  State<_RegexRuleCard> createState() => _RegexRuleCardState();
}

class _RegexRuleCardState extends State<_RegexRuleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    final borderBase = cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06);
    final borderColor = widget.desktop && _hovered ? cs.primary.withOpacity(0.55) : borderBase;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: IosCardPress(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        baseColor: bg,
        pressedBlendStrength: 0.16,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 0.7),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.rule.name.isEmpty ? l10n.assistantRegexUntitled : widget.rule.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IosSwitch(
                      value: widget.rule.enabled,
                      onChanged: widget.onToggle,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _buildScopePills(context, widget.rule),
                      ),
                    ),
                    IosCardPress(
                      onTap: widget.onDelete,
                      borderRadius: BorderRadius.circular(12),
                      baseColor: Colors.transparent,
                      pressedBlendStrength: 0.16,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Lucide.Trash2, size: 16, color: cs.error),
                          const SizedBox(width: 6),
                          Text(
                            l10n.assistantRegexDeleteButton,
                            style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildScopePills(BuildContext context, AssistantRegex rule) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pills = <String>[];
    if (rule.scopes.contains(AssistantRegexScope.user)) {
      pills.add(l10n.assistantRegexScopeUser);
    }
    if (rule.scopes.contains(AssistantRegexScope.assistant)) {
      pills.add(l10n.assistantRegexScopeAssistant);
    }
    if (rule.visualOnly) {
      pills.add(l10n.assistantRegexScopeVisualOnly);
    }
    if (rule.replaceOnly) {
      pills.add(l10n.assistantRegexScopeReplaceOnly);
    }
    return pills
        .map(
          (p) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : cs.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withOpacity(0.35)),
            ),
            child: Text(
              p,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        )
        .toList();
  }
}

class _GlassCircleButton extends StatefulWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 48,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  State<_GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<_GlassCircleButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glassBase = isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06);
    final overlay = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05);
    final tileColor = _pressed ? Color.alphaBlend(overlay, glassBase) : glassBase;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.10 : 0.10);

    final child = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(child: Icon(widget.icon, size: 18, color: widget.color)),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              decoration: BoxDecoration(
                color: tileColor,
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RegexFormData {
  const _RegexFormData({
    required this.name,
    required this.pattern,
    required this.replacement,
    required this.scopes,
    required this.visualOnly,
    required this.replaceOnly,
  });
  final String name;
  final String pattern;
  final String replacement;
  final List<AssistantRegexScope> scopes;
  final bool visualOnly;
  final bool replaceOnly;
}

Future<_RegexFormData?> _showRegexEditor(BuildContext context, {AssistantRegex? rule}) async {
  final platform = Theme.of(context).platform;
  final isDesktop = platform == TargetPlatform.macOS || platform == TargetPlatform.linux || platform == TargetPlatform.windows;
  return isDesktop
      ? _showRegexDialog(context, rule: rule)
      : _showRegexBottomSheet(context, rule: rule);
}

Future<_RegexFormData?> _showRegexBottomSheet(BuildContext context, {AssistantRegex? rule}) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: rule?.name ?? '');
  final patternCtrl = TextEditingController(text: rule?.pattern ?? '');
  final replacementCtrl = TextEditingController(text: rule?.replacement ?? '');
  final Set<AssistantRegexScope> scopes = {...(rule?.scopes ?? <AssistantRegexScope>[AssistantRegexScope.user])};
  bool visualOnly = rule?.visualOnly ?? false;
  bool replaceOnly = rule?.replaceOnly ?? false;

  final result = await showModalBottomSheet<_RegexFormData>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> submit() async {
            final name = nameCtrl.text.trim();
            final pattern = patternCtrl.text.trim();
            if (name.isEmpty || pattern.isEmpty || scopes.isEmpty) {
              showAppSnackBar(ctx, message: l10n.assistantRegexValidationError, type: NotificationType.warning);
              return;
            }
            try {
              RegExp(pattern);
            } catch (_) {
              showAppSnackBar(ctx, message: l10n.assistantRegexInvalidPattern, type: NotificationType.warning);
              return;
            }
            Navigator.of(ctx).pop(_RegexFormData(
              name: name,
              pattern: pattern,
              replacement: replacementCtrl.text,
              scopes: scopes.toList(),
              visualOnly: visualOnly,
              replaceOnly: replaceOnly,
            ));
          }

          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          final maxHeight = MediaQuery.of(ctx).size.height * 0.9;
          return SafeArea(
            top: false,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Row(
                          children: [
                            IosIconButton(
                              icon: Lucide.X,
                              size: 20,
                              minSize: 44,
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  rule == null ? l10n.assistantRegexAddTitle : l10n.assistantRegexEditTitle,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            IosCardPress(
                              onTap: submit,
                              borderRadius: BorderRadius.circular(10),
                              baseColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              pressedBlendStrength: 0.1,
                              child: Text(
                                rule == null ? l10n.assistantRegexAddAction : l10n.assistantRegexSaveAction,
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RegexTextField(controller: nameCtrl, label: l10n.assistantRegexNameLabel, autofocus: true),
                            const SizedBox(height: 12),
                            _RegexTextField(controller: patternCtrl, label: l10n.assistantRegexPatternLabel),
                            const SizedBox(height: 12),
                            _RegexTextField(
                              controller: replacementCtrl,
                              label: l10n.assistantRegexReplacementLabel,
                              multiline: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.assistantRegexScopeLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeUser,
                                  selected: scopes.contains(AssistantRegexScope.user),
                                  onTap: () {
                                    setState(() {
                                      if (scopes.contains(AssistantRegexScope.user)) {
                                        scopes.remove(AssistantRegexScope.user);
                                      } else {
                                        scopes.add(AssistantRegexScope.user);
                                      }
                                    });
                                  },
                                  desktop: false,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeAssistant,
                                  selected: scopes.contains(AssistantRegexScope.assistant),
                                  onTap: () {
                                    setState(() {
                                      if (scopes.contains(AssistantRegexScope.assistant)) {
                                        scopes.remove(AssistantRegexScope.assistant);
                                      } else {
                                        scopes.add(AssistantRegexScope.assistant);
                                      }
                                    });
                                  },
                                  desktop: false,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeVisualOnly,
                                  selected: visualOnly,
                                  onTap: () {
                                    setState(() {
                                      visualOnly = !visualOnly;
                                      if (visualOnly) replaceOnly = false;
                                    });
                                  },
                                  desktop: false,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeReplaceOnly,
                                  selected: replaceOnly,
                                  onTap: () {
                                    setState(() {
                                      replaceOnly = !replaceOnly;
                                      if (replaceOnly) visualOnly = false;
                                    });
                                  },
                                  desktop: false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
  return result;
}

Future<_RegexFormData?> _showRegexDialog(BuildContext context, {AssistantRegex? rule}) async {
  final cs = Theme.of(context).colorScheme;
  final l10n = AppLocalizations.of(context)!;
  final nameCtrl = TextEditingController(text: rule?.name ?? '');
  final patternCtrl = TextEditingController(text: rule?.pattern ?? '');
  final replacementCtrl = TextEditingController(text: rule?.replacement ?? '');
  final Set<AssistantRegexScope> scopes = {...(rule?.scopes ?? <AssistantRegexScope>[AssistantRegexScope.user])};
  bool visualOnly = rule?.visualOnly ?? false;
  bool replaceOnly = rule?.replaceOnly ?? false;

  final result = await showDialog<_RegexFormData>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return Dialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: StatefulBuilder(
          builder: (ctx, setState) {
            Future<void> submit() async {
              final name = nameCtrl.text.trim();
              final pattern = patternCtrl.text.trim();
              if (name.isEmpty || pattern.isEmpty || scopes.isEmpty) {
                showAppSnackBar(ctx, message: l10n.assistantRegexValidationError, type: NotificationType.warning);
                return;
              }
              try {
                RegExp(pattern);
              } catch (_) {
                showAppSnackBar(ctx, message: l10n.assistantRegexInvalidPattern, type: NotificationType.warning);
                return;
              }
              Navigator.of(ctx).pop(_RegexFormData(
                name: name,
                pattern: pattern,
                replacement: replacementCtrl.text,
                scopes: scopes.toList(),
                visualOnly: visualOnly,
                replaceOnly: replaceOnly,
              ));
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rule == null ? l10n.assistantRegexAddTitle : l10n.assistantRegexEditTitle,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                            IosIconButton(
                              icon: Lucide.X,
                              size: 18,
                              padding: const EdgeInsets.all(8),
                              onTap: () => Navigator.of(ctx).maybePop(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RegexTextField(controller: nameCtrl, label: l10n.assistantRegexNameLabel, autofocus: true),
                            const SizedBox(height: 12),
                            _RegexTextField(controller: patternCtrl, label: l10n.assistantRegexPatternLabel),
                            const SizedBox(height: 12),
                            _RegexTextField(
                              controller: replacementCtrl,
                              label: l10n.assistantRegexReplacementLabel,
                              multiline: true,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.assistantRegexScopeLabel,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeUser,
                                  selected: scopes.contains(AssistantRegexScope.user),
                                  onTap: () {
                                    setState(() {
                                      if (scopes.contains(AssistantRegexScope.user)) {
                                        scopes.remove(AssistantRegexScope.user);
                                      } else {
                                        scopes.add(AssistantRegexScope.user);
                                      }
                                    });
                                  },
                                  desktop: true,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeAssistant,
                                  selected: scopes.contains(AssistantRegexScope.assistant),
                                  onTap: () {
                                    setState(() {
                                      if (scopes.contains(AssistantRegexScope.assistant)) {
                                        scopes.remove(AssistantRegexScope.assistant);
                                      } else {
                                        scopes.add(AssistantRegexScope.assistant);
                                      }
                                    });
                                  },
                                  desktop: true,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeVisualOnly,
                                  selected: visualOnly,
                                  onTap: () {
                                    setState(() {
                                      visualOnly = !visualOnly;
                                      if (visualOnly) replaceOnly = false;
                                    });
                                  },
                                  desktop: true,
                                ),
                                _ScopeChoiceCard(
                                  label: l10n.assistantRegexScopeReplaceOnly,
                                  selected: replaceOnly,
                                  onTap: () {
                                    setState(() {
                                      replaceOnly = !replaceOnly;
                                      if (replaceOnly) visualOnly = false;
                                    });
                                  },
                                  desktop: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IosCardPress(
                            onTap: () => Navigator.of(ctx).maybePop(),
                            borderRadius: BorderRadius.circular(12),
                            baseColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            pressedBlendStrength: 0.12,
                            child: Text(
                              l10n.assistantRegexCancelButton,
                              style: TextStyle(color: cs.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IosCardPress(
                            onTap: submit,
                            borderRadius: BorderRadius.circular(12),
                            baseColor: cs.primary.withOpacity(0.12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            pressedBlendStrength: 0.16,
                            child: Text(
                              rule == null ? l10n.assistantRegexAddAction : l10n.assistantRegexSaveAction,
                              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  nameCtrl.dispose();
  patternCtrl.dispose();
  replacementCtrl.dispose();
  return result;
}

class _RegexTextField extends StatelessWidget {
  const _RegexTextField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.multiline = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      autofocus: autofocus,
      minLines: multiline ? 1 : 1,
      maxLines: multiline ? null : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.done,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary.withOpacity(0.5)),
        ),
      ),
    );
  }
}

class _ScopeChoiceCard extends StatefulWidget {
  const _ScopeChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.desktop,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool desktop;

  @override
  State<_ScopeChoiceCard> createState() => _ScopeChoiceCardState();
}

class _ScopeChoiceCardState extends State<_ScopeChoiceCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.selected ? cs.primary.withOpacity(0.16) : (isDark ? Colors.white10 : const Color(0xFFF2F3F5));
    final borderBase = widget.selected ? cs.primary.withOpacity(0.55) : cs.outlineVariant.withOpacity(isDark ? 0.14 : 0.12);
    final borderColor = (widget.desktop && _hovered) ? cs.primary : borderBase;
    final fg = widget.selected ? cs.primary : cs.onSurface.withOpacity(0.8);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

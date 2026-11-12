import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant_copy_options.dart';
import '../../../core/models/memory_entry.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/memory_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/providers/quick_phrase_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/assistant_copy_service.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_tile_button.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/platform_utils.dart';
import '../../settings/widgets/memory_ui.dart' show memoryTypeLabel;

/// Every assistant-copy entry point uses this flow and refreshes the same
/// provider caches after the single durable copy operation.
Future<void> copyAssistantWithScope(
  BuildContext context,
  String assistantId,
) async {
  final provider = context.read<AssistantProvider>();
  final source = provider.getById(assistantId);
  if (source == null) return;
  final l10n = AppLocalizations.of(context)!;
  final memory = context.read<MemoryProvider?>();
  final memoryV2 = context.read<MemoryProviderV2?>();
  final phrases = context.read<QuickPhraseProvider?>();
  final worldBooks = context.read<WorldBookProvider?>();
  final injections = context.read<InstructionInjectionProvider?>();
  final id = await showAssistantCopyDialog(
    context,
    assistantName: source.name,
    loadMemories: () =>
        AssistantCopyService(provider.preferences).loadMemories(assistantId),
    onCopy: (options) async {
      final id = await provider.duplicateAssistant(
        assistantId,
        l10n: l10n,
        options: options,
      );
      if (id == null) throw StateError('assistant_copy_source_missing');
      try {
        await Future.wait([
          if (options.memories && memory != null) memory.loadAll(),
          if (options.memories && memoryV2 != null)
            memoryV2.reloadCurrentScope(),
          if (options.quickPhrases && phrases != null) phrases.loadAll(),
          if (options.worldBooks && worldBooks != null) worldBooks.loadAll(),
          if (options.instructionInjections && injections != null)
            injections.loadAll(),
        ]);
      } catch (error) {
        // The copy is already durable. A cache refresh must not turn success
        // into a retry that would create a second assistant.
        debugPrint('Assistant copy cache refresh failed: $error');
      }
      return id;
    },
  );
  if (id != null && context.mounted) {
    showAppSnackBar(
      context,
      message: l10n.assistantSettingsCopySuccess,
      type: NotificationType.success,
    );
  }
}

Future<String?> showAssistantCopyDialog(
  BuildContext context, {
  required String assistantName,
  required Future<AssistantCopyMemories> Function() loadMemories,
  required Future<String> Function(AssistantCopyOptions) onCopy,
}) {
  final desktop =
      PlatformUtils.isDesktopTarget || ResponsiveHelper.isDesktop(context);
  Widget panel() => _AssistantCopyPanel(
    assistantName: assistantName,
    loadMemories: loadMemories,
    onCopy: onCopy,
  );
  if (desktop) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.overlaySurface,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          height: MediaQuery.sizeOf(ctx).height * 0.85,
          child: panel(),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useSafeArea: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (ctx) =>
        SizedBox(height: MediaQuery.sizeOf(ctx).height * 0.9, child: panel()),
  );
}

class _AssistantCopyPanel extends StatefulWidget {
  const _AssistantCopyPanel({
    required this.assistantName,
    required this.loadMemories,
    required this.onCopy,
  });
  final String assistantName;
  final Future<AssistantCopyMemories> Function() loadMemories;
  final Future<String> Function(AssistantCopyOptions) onCopy;

  @override
  State<_AssistantCopyPanel> createState() => _AssistantCopyPanelState();
}

class _AssistantCopyPanelState extends State<_AssistantCopyPanel> {
  bool _memories = false;
  bool _quickPhrases = false;
  bool _regexRules = true;
  bool _worldBooks = false;
  bool _injections = false;
  bool _skills = true;
  bool _mcp = true;
  bool _tools = true;
  bool _workspace = true;
  Set<String>? _memoryIds;
  Set<int>? _legacyIds;
  AssistantCopyMemories? _data;
  bool _loadingMemories = false;
  bool _loadFailed = false;
  bool _selectingMemories = false;
  bool _busy = false;
  bool _copyFailed = false;
  final Set<String> _expandedMemoryGroups = {};

  Future<void> _loadMemories() async {
    if (_loadingMemories || _data != null) return;
    setState(() {
      _loadingMemories = true;
      _loadFailed = false;
    });
    try {
      final data = await widget.loadMemories();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMemories = false);
    }
  }

  AssistantCopyOptions get _options => AssistantCopyOptions(
    memories: _memories,
    memoryIds: _memoryIds == null ? null : Set.of(_memoryIds!),
    legacyMemoryIds: _legacyIds == null ? null : Set.of(_legacyIds!),
    quickPhrases: _quickPhrases,
    regexRules: _regexRules,
    worldBooks: _worldBooks,
    instructionInjections: _injections,
    skills: _skills,
    mcp: _mcp,
    tools: _tools,
    workspace: _workspace,
  );

  Future<void> _copy(AssistantCopyOptions options) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _copyFailed = false;
    });
    try {
      final id = await widget.onCopy(options);
      if (mounted) Navigator.of(context).pop(id);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _copyFailed = true;
        });
      }
    }
  }

  int get _selectedCount => !_memories
      ? 0
      : (_data?.entries
                    .where(
                      (e) => _memoryIds == null || _memoryIds!.contains(e.id),
                    )
                    .length ??
                0) +
            (_data?.legacy
                    .where(
                      (e) => _legacyIds == null || _legacyIds!.contains(e.id),
                    )
                    .length ??
                0);

  void _materializeSelection() {
    _memoryIds ??= _memories
        ? _data!.entries.map((e) => e.id).toSet()
        : <String>{};
    _legacyIds ??= _memories ? _data!.legacy.map((e) => e.id).toSet() : <int>{};
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  if (_selectingMemories)
                    IconButton(
                      key: const ValueKey('assistant-copy-memory-back'),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(Lucide.ArrowLeft, size: 20),
                      onPressed: () =>
                          setState(() => _selectingMemories = false),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectingMemories
                              ? l10n.assistantCopyChooseMemories
                              : l10n.assistantCopyTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFontWeights.emphasis,
                          ),
                        ),
                        Text(
                          widget.assistantName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('assistant-copy-close'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Lucide.X, size: 20),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _selectingMemories ? _memoryPicker(l10n) : _ranges(l10n),
            ),
            if (_copyFailed)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.assistantCopyFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (!_selectingMemories)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: IosTileButton(
                        key: const ValueKey('assistant-copy-all'),
                        label: l10n.assistantCopyAll,
                        icon: Lucide.Copy,
                        enabled: !_busy,
                        onTap: () => _copy(const AssistantCopyOptions.all()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: IosTileButton(
                        key: const ValueKey('assistant-copy-confirm'),
                        label: _busy
                            ? l10n.assistantCopyInProgress
                            : l10n.assistantSettingsCopyButton,
                        icon: Lucide.Check,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        enabled: !_busy,
                        onTap: () => _copy(_options),
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

  Widget _ranges(AppLocalizations l10n) {
    Widget option(
      String id,
      String title,
      bool value,
      ValueChanged<bool> change, {
      String? subtitle,
    }) => _CopyOptionRow(
      id: id,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: _busy ? null : (value) => setState(() => change(value)),
    );
    return ListView(
      key: const PageStorageKey('assistant-copy-ranges'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      children: [
        Text(
          l10n.assistantCopyDefaultHint,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          children: [
            _CopyOptionRow(
              id: 'config',
              title: l10n.assistantCopyConfiguration,
              subtitle: l10n.assistantCopyConfigurationHint,
              value: true,
            ),
            _CopyOptionRow(
              id: 'memories',
              title: l10n.assistantCopyMemories,
              subtitle: l10n.assistantCopyMemoriesHint,
              value: _memories,
              onChanged: _busy
                  ? null
                  : (value) => setState(() {
                      _memories = value;
                      _memoryIds = null;
                      _legacyIds = null;
                    }),
              titleTrailing: _memorySelectionAction(l10n),
            ),
            option(
              'phrases',
              l10n.assistantEditPageQuickPhraseTab,
              _quickPhrases,
              (v) => _quickPhrases = v,
              subtitle: l10n.assistantCopyPhrasesHint,
            ),
            option(
              'regex',
              l10n.assistantEditPageRegexTab,
              _regexRules,
              (v) => _regexRules = v,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          l10n.assistantCopyBindingsHint,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        SectionCard(
          children: [
            option(
              'world-books',
              l10n.assistantCopyWorldBooks,
              _worldBooks,
              (v) => _worldBooks = v,
            ),
            option(
              'injections',
              l10n.instructionInjectionTitle,
              _injections,
              (v) => _injections = v,
            ),
            option(
              'skills',
              l10n.assistantCopySkills,
              _skills,
              (v) => _skills = v,
            ),
            option('mcp', 'MCP', _mcp, (v) => _mcp = v),
            option('tools', l10n.assistantCopyTools, _tools, (v) => _tools = v),
            option(
              'workspace',
              l10n.assistantCopyWorkspace,
              _workspace,
              (v) => _workspace = v,
            ),
          ],
        ),
      ],
    );
  }

  Widget _memorySelectionAction(AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final total = (_data?.entries.length ?? 0) + (_data?.legacy.length ?? 0);
    final count = total > 0 ? '$_selectedCount/$total' : null;
    final VoidCallback? onTap = _busy
        ? null
        : () {
            setState(() => _selectingMemories = true);
            _loadMemories();
          };
    return Semantics(
      button: true,
      enabled: !_busy,
      label: l10n.assistantCopyChooseMemories,
      value: count,
      onTap: onTap,
      excludeSemantics: true,
      child: IosCardPress(
        key: const ValueKey('assistant-copy-choose-memories'),
        onTap: onTap,
        focusable: true,
        haptics: false,
        baseColor: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                l10n.assistantCopyChooseEntries,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFontWeights.medium,
                  color: _busy
                      ? cs.onSurfaceVariant.withValues(alpha: 0.45)
                      : cs.primary,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(width: 3),
            Icon(
              Lucide.ChevronRight,
              size: 14,
              color: cs.onSurfaceVariant.withValues(alpha: _busy ? 0.35 : 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memoryPicker(AppLocalizations l10n) {
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.assistantCopyMemoryLoadFailed),
              const SizedBox(height: 12),
              IosTileButton(
                label: l10n.assistantCopyRetry,
                icon: Lucide.RefreshCw,
                onTap: _loadMemories,
              ),
            ],
          ),
        ),
      );
    }
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    final total = data.entries.length + data.legacy.length;
    if (total == 0) return Center(child: Text(l10n.assistantCopyNoMemories));
    final rows = <Widget Function()>[];
    Widget group(String id, Widget selection) {
      final expanded = _expandedMemoryGroups.contains(id);
      return Row(
        children: [
          Expanded(child: selection),
          IconButton(
            key: ValueKey('assistant-copy-expand-$id'),
            tooltip: expanded
                ? MaterialLocalizations.of(context).expandedIconTapHint
                : MaterialLocalizations.of(context).collapsedIconTapHint,
            icon: Icon(
              expanded ? Lucide.ChevronUp : Lucide.ChevronDown,
              size: 20,
            ),
            onPressed: () => setState(() {
              if (expanded) {
                _expandedMemoryGroups.remove(id);
              } else {
                _expandedMemoryGroups.add(id);
              }
            }),
          ),
        ],
      );
    }

    rows.add(
      () => _CopyOptionRow(
        id: 'memories-all',
        title: l10n.assistantCopySelectAll,
        subtitle: '$_selectedCount/$total',
        value: _selectedCount == total,
        onChanged: (v) => setState(() {
          _memories = v;
          _memoryIds = null;
          _legacyIds = null;
        }),
      ),
    );
    for (final type in MemoryType.values) {
      final entries = data.entries.where((e) => e.type == type).toList();
      if (entries.isEmpty) continue;
      final selected = entries
          .where(
            (e) =>
                _memories && (_memoryIds == null || _memoryIds!.contains(e.id)),
          )
          .length;
      rows.add(
        () => group(
          type.name,
          _CopyOptionRow(
            id: 'group-${type.name}',
            title: memoryTypeLabel(l10n, type),
            subtitle: '$selected/${entries.length}',
            value: selected == entries.length,
            onChanged: (v) => setState(() {
              _materializeSelection();
              for (final entry in entries) {
                if (v) {
                  _memoryIds!.add(entry.id);
                } else {
                  _memoryIds!.remove(entry.id);
                }
              }
              _memories = _memoryIds!.isNotEmpty || _legacyIds!.isNotEmpty;
            }),
          ),
        ),
      );
      if (!_expandedMemoryGroups.contains(type.name)) continue;
      for (final entry in entries) {
        rows.add(
          () => Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: _CopyOptionRow(
              id: 'memory-${entry.id}',
              title: entry.content,
              subtitle: entry.status == MemoryStatus.archived
                  ? l10n.memoryEntryStatusArchived
                  : null,
              value:
                  _memories &&
                  (_memoryIds == null || _memoryIds!.contains(entry.id)),
              onChanged: (v) => setState(() {
                _materializeSelection();
                if (v) {
                  _memoryIds!.add(entry.id);
                } else {
                  _memoryIds!.remove(entry.id);
                }
                _memories = _memoryIds!.isNotEmpty || _legacyIds!.isNotEmpty;
              }),
            ),
          ),
        );
      }
    }
    if (data.legacy.isNotEmpty) {
      final selected = data.legacy
          .where(
            (e) =>
                _memories && (_legacyIds == null || _legacyIds!.contains(e.id)),
          )
          .length;
      rows.add(
        () => group(
          'legacy',
          _CopyOptionRow(
            id: 'group-legacy',
            title: l10n.legacyMemoryPageTitle,
            subtitle: '$selected/${data.legacy.length}',
            value: selected == data.legacy.length,
            onChanged: (v) => setState(() {
              _materializeSelection();
              _legacyIds = v ? data.legacy.map((e) => e.id).toSet() : {};
              _memories = _memoryIds!.isNotEmpty || _legacyIds!.isNotEmpty;
            }),
          ),
        ),
      );
      for (final entry
          in _expandedMemoryGroups.contains('legacy')
              ? data.legacy
              : const []) {
        rows.add(
          () => Padding(
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: _CopyOptionRow(
              id: 'legacy-memory-${entry.id}',
              title: entry.content,
              value:
                  _memories &&
                  (_legacyIds == null || _legacyIds!.contains(entry.id)),
              onChanged: (v) => setState(() {
                _materializeSelection();
                if (v) {
                  _legacyIds!.add(entry.id);
                } else {
                  _legacyIds!.remove(entry.id);
                }
                _memories = _memoryIds!.isNotEmpty || _legacyIds!.isNotEmpty;
              }),
            ),
          ),
        );
      }
    }
    return ListView.builder(
      key: const PageStorageKey('assistant-copy-memories'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: rows.length,
      itemBuilder: (_, index) => rows[index](),
    );
  }
}

class _CopyOptionRow extends StatelessWidget {
  const _CopyOptionRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.titleTrailing,
    required this.value,
    this.onChanged,
  });
  final String id;
  final String title;
  final String? subtitle;
  final Widget? titleTrailing;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => IosCardPress(
    onTap: onChanged == null ? null : () => onChanged!(!value),
    focusable: onChanged != null,
    borderRadius: BorderRadius.circular(12),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    child: Row(
      children: [
        IosCheckbox(
          key: ValueKey('assistant-copy-$id'),
          value: value,
          onChanged: onChanged,
          semanticLabel: title,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (titleTrailing == null)
                Text(title, style: const TextStyle(fontSize: 14))
              else
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14)),
                      titleTrailing!,
                    ],
                  ),
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

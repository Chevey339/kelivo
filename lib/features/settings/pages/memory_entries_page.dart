import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

import '../../../core/models/memory_entry.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/memory_provider_v2.dart';
import '../../../core/services/memory/memory_tools.dart';
import '../../../desktop/widgets/desktop_select_dropdown.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/selection_back_scope.dart';
import '../../../utils/platform_utils.dart';
import '../widgets/memory_ui.dart';

/// Global memory list with search, filters, batch delete, orphan cleanup (§14.4).
class MemoryEntriesPage extends StatelessWidget {
  const MemoryEntriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(l10n.memoryEntriesPageTitle),
      ),
      body: const MemoryEntriesContent(),
    );
  }
}

class MemoryEntriesContent extends StatefulWidget {
  const MemoryEntriesContent({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  State<MemoryEntriesContent> createState() => _MemoryEntriesContentState();
}

enum _ScopeFilter { all, global, assistant }

enum _StatusFilter { all, active, archived }

class _MemoryEntriesContentState extends State<MemoryEntriesContent> {
  final _search = TextEditingController();
  _ScopeFilter _scope = _ScopeFilter.all;
  MemoryType? _type;
  _StatusFilter _status = _StatusFilter.all;
  String? _assistantFilterId;
  final Set<String> _selected = {};
  bool _selecting = false;
  List<MemoryEntry>? _searchResults;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MemoryProviderV2>().initialize(loadAll: true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final tokens = MemoryTools.searchTokens(q);
    if (tokens.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    final results = await context.read<MemoryProviderV2>().search(
      tokens: tokens,
      acrossAll: true,
      includeArchived: true,
      type: _type,
    );
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  List<MemoryEntry> _filtered(List<MemoryEntry> source) {
    return source
        .where((e) {
          if (_type != null && e.type != _type) return false;
          switch (_scope) {
            case _ScopeFilter.all:
              break;
            case _ScopeFilter.global:
              if (e.scope != MemoryScope.global) return false;
            case _ScopeFilter.assistant:
              if (e.scope != MemoryScope.assistant) return false;
              if (_assistantFilterId != null &&
                  e.assistantId != _assistantFilterId) {
                return false;
              }
          }
          switch (_status) {
            case _StatusFilter.all:
              break;
            case _StatusFilter.active:
              if (e.status != MemoryStatus.active) return false;
            case _StatusFilter.archived:
              if (e.status != MemoryStatus.archived) return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  Future<void> _showEditSheet({MemoryEntry? existing}) {
    return showMemoryEntryEditor(
      context,
      existing: existing,
      allowAssistantPicker: true,
    );
  }

  Future<void> _toggleBatchDelete() async {
    if (!_selecting) {
      setState(() => _selecting = true);
      return;
    }
    if (_selected.isEmpty) {
      setState(() {
        _selecting = false;
        _selected.clear();
      });
      return;
    }
    final mp = context.read<MemoryProviderV2>();
    final ids = _selected.toList();
    if (!await confirmBatchHardDelete(context, count: ids.length)) {
      return;
    }
    if (!mounted) return;
    await mp.hardDeleteMany(ids);
    setState(() {
      _selected.clear();
      _selecting = false;
    });
  }

  Widget _desktopToolbar(AppLocalizations l10n, AssistantProvider ap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DesktopSelectDropdown<_ScopeFilter>(
            value: _scope,
            minWidth: 120,
            maxLabelWidth: 160,
            options: [
              for (final v in _ScopeFilter.values)
                DesktopSelectOption(
                  value: v,
                  label: switch (v) {
                    _ScopeFilter.all => l10n.memoryFilterScopeAll,
                    _ScopeFilter.global => l10n.memoryFilterScopeGlobal,
                    _ScopeFilter.assistant => l10n.memoryFilterScopeAssistant,
                  },
                ),
            ],
            onSelected: (v) => setState(() => _scope = v),
          ),
          DesktopSelectDropdown<MemoryType?>(
            value: _type,
            minWidth: 120,
            maxLabelWidth: 160,
            options: [
              DesktopSelectOption(value: null, label: l10n.memoryFilterTypeAll),
              for (final t in MemoryType.values)
                DesktopSelectOption(value: t, label: memoryTypeLabel(l10n, t)),
            ],
            onSelected: (v) async {
              setState(() => _type = v);
              if (_search.text.trim().isNotEmpty) {
                await _runSearch(_search.text);
              }
            },
          ),
          DesktopSelectDropdown<_StatusFilter>(
            value: _status,
            minWidth: 120,
            maxLabelWidth: 160,
            options: [
              for (final v in _StatusFilter.values)
                DesktopSelectOption(
                  value: v,
                  label: switch (v) {
                    _StatusFilter.all => l10n.memoryFilterStatusAll,
                    _StatusFilter.active => l10n.memoryFilterStatusActive,
                    _StatusFilter.archived => l10n.memoryFilterStatusArchived,
                  },
                ),
            ],
            onSelected: (v) => setState(() => _status = v),
          ),
          if (_scope == _ScopeFilter.assistant)
            DesktopSelectDropdown<String?>(
              value: _assistantFilterId,
              minWidth: 140,
              maxLabelWidth: 200,
              options: [
                DesktopSelectOption(
                  value: null,
                  label: l10n.memoryUiAssistantAll,
                ),
                for (final a in ap.assistants)
                  DesktopSelectOption(value: a.id, label: a.name),
              ],
              onSelected: (v) => setState(() => _assistantFilterId = v),
            ),
          MemorySelectChip(
            label: _selecting
                ? l10n.memoryEntryActionBatchDelete
                : l10n.providersPageMultiSelectTooltip,
            emphasized: _selecting,
            onTap: _toggleBatchDelete,
          ),
          MemorySelectChip(
            label: l10n.memoryEntryActionAdd,
            emphasized: true,
            icon: Lucide.Plus,
            onTap: () => _showEditSheet(),
          ),
        ],
      ),
    );
  }

  Widget _mobileToolbar(AppLocalizations l10n, AssistantProvider ap) {
    return MemoryFadingHorizontalScroll(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          _FilterChip(
            label: switch (_scope) {
              _ScopeFilter.all => l10n.memoryFilterScopeAll,
              _ScopeFilter.global => l10n.memoryFilterScopeGlobal,
              _ScopeFilter.assistant => l10n.memoryFilterScopeAssistant,
            },
            onTap: () async {
              final next = await showMemoryOptionPicker<_ScopeFilter>(
                context,
                title: l10n.memoryEntryScopeLabel,
                selected: _scope,
                options: [
                  for (final v in _ScopeFilter.values)
                    MemoryPickerOption(
                      value: v,
                      label: switch (v) {
                        _ScopeFilter.all => l10n.memoryFilterScopeAll,
                        _ScopeFilter.global => l10n.memoryFilterScopeGlobal,
                        _ScopeFilter.assistant =>
                          l10n.memoryFilterScopeAssistant,
                      },
                    ),
                ],
              );
              if (next != null) setState(() => _scope = next);
            },
          ),
          if (_scope == _ScopeFilter.assistant) ...[
            const SizedBox(width: 8),
            _FilterChip(
              label: _assistantFilterId == null
                  ? l10n.memoryUiAssistantAll
                  : (ap.getById(_assistantFilterId!)?.name ??
                        l10n.memoryUiAssistantAll),
              onTap: () async {
                final next = await showMemoryOptionPicker<String?>(
                  context,
                  title: l10n.memoryUiAssistantLabel,
                  selected: _assistantFilterId,
                  options: [
                    MemoryPickerOption(
                      value: null,
                      label: l10n.memoryUiAssistantAll,
                    ),
                    for (final a in ap.assistants)
                      MemoryPickerOption(value: a.id, label: a.name),
                  ],
                );
                if (!mounted) return;
                setState(() => _assistantFilterId = next);
              },
            ),
          ],
          const SizedBox(width: 8),
          _FilterChip(
            label: _type == null
                ? l10n.memoryFilterTypeAll
                : memoryTypeLabel(l10n, _type!),
            onTap: () async {
              final next = await showMemoryOptionPicker<MemoryType?>(
                context,
                title: l10n.memoryEntryTypeLabel,
                selected: _type,
                options: [
                  MemoryPickerOption(
                    value: null,
                    label: l10n.memoryFilterTypeAll,
                  ),
                  for (final t in MemoryType.values)
                    MemoryPickerOption(
                      value: t,
                      label: memoryTypeLabel(l10n, t),
                    ),
                ],
              );
              if (!mounted) return;
              setState(() => _type = next);
              if (_search.text.trim().isNotEmpty) {
                await _runSearch(_search.text);
              }
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: switch (_status) {
              _StatusFilter.all => l10n.memoryFilterStatusAll,
              _StatusFilter.active => l10n.memoryFilterStatusActive,
              _StatusFilter.archived => l10n.memoryFilterStatusArchived,
            },
            onTap: () async {
              final next = await showMemoryOptionPicker<_StatusFilter>(
                context,
                title: l10n.memoryUiStatusLabel,
                selected: _status,
                options: [
                  for (final v in _StatusFilter.values)
                    MemoryPickerOption(
                      value: v,
                      label: switch (v) {
                        _StatusFilter.all => l10n.memoryFilterStatusAll,
                        _StatusFilter.active => l10n.memoryFilterStatusActive,
                        _StatusFilter.archived =>
                          l10n.memoryFilterStatusArchived,
                      },
                    ),
                ],
              );
              if (next != null) setState(() => _status = next);
            },
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _selecting
                ? l10n.memoryEntryActionBatchDelete
                : l10n.providersPageMultiSelectTooltip,
            emphasized: _selecting,
            onTap: _toggleBatchDelete,
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: l10n.memoryEntryActionAdd,
            emphasized: true,
            onTap: () => _showEditSheet(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final mp = context.watch<MemoryProviderV2>();
    final ap = context.watch<AssistantProvider>();
    final source = _searchResults ?? mp.entries;
    final filtered = _filtered(source);
    final active = filtered
        .where((e) => e.status == MemoryStatus.active)
        .toList();
    final archived = filtered
        .where((e) => e.status == MemoryStatus.archived)
        .toList();
    final desktop = PlatformUtils.isDesktopTarget;
    final listPadding = desktop
        ? (widget.padding ?? const EdgeInsets.fromLTRB(4, 0, 4, 20))
        : (widget.padding ?? const EdgeInsets.only(bottom: 24));

    final content = Column(
      children: [
        Padding(
          padding: widget.padding == null
              ? EdgeInsets.fromLTRB(desktop ? 12 : 16, 8, desktop ? 12 : 16, 4)
              : const EdgeInsets.fromLTRB(0, 0, 0, 4),
          child: MemorySearchField(
            controller: _search,
            hintText: l10n.memorySearchHint,
            onChanged: _runSearch,
          ),
        ),
        if (desktop)
          Padding(
            padding: widget.padding == null
                ? const EdgeInsets.symmetric(horizontal: 12)
                : EdgeInsets.zero,
            child: _desktopToolbar(l10n, ap),
          )
        else
          _mobileToolbar(l10n, ap),
        const MemoryOrphanBanner(),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchResults != null
                        ? l10n.memorySearchEmpty
                        : l10n.memoryEntryEmpty,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                )
              : ListView(
                  padding: listPadding,
                  children: [
                    ...active.map(
                      (e) => MemoryEntryCard(
                        entry: e,
                        assistantName: resolveAssistantName(
                          context,
                          e.assistantId,
                        ),
                        selectable: _selecting,
                        selected: _selected.contains(e.id),
                        onSelectedChanged: (v) {
                          setState(() {
                            if (v) {
                              _selected.add(e.id);
                            } else {
                              _selected.remove(e.id);
                            }
                          });
                        },
                        onEdit: () => _showEditSheet(existing: e),
                      ),
                    ),
                    if (archived.isNotEmpty &&
                        (_status == _StatusFilter.all ||
                            _status == _StatusFilter.archived)) ...[
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          desktop ? 8 : 16,
                          16,
                          desktop ? 8 : 16,
                          4,
                        ),
                        child: Text(
                          l10n.memoryEntryArchivedSection,
                          style: TextStyle(
                            fontSize: desktop ? 13.5 : 15,
                            fontWeight: AppFontWeights.emphasis,
                          ),
                        ),
                      ),
                      ...archived.map(
                        (e) => MemoryEntryCard(
                          entry: e,
                          assistantName: resolveAssistantName(
                            context,
                            e.assistantId,
                          ),
                          selectable: _selecting,
                          selected: _selected.contains(e.id),
                          onSelectedChanged: (v) {
                            setState(() {
                              if (v) {
                                _selected.add(e.id);
                              } else {
                                _selected.remove(e.id);
                              }
                            });
                          },
                          onEdit: () => _showEditSheet(existing: e),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
    return SelectionBackScope(
      selecting: _selecting,
      onCancel: () => setState(() {
        _selecting = false;
        _selected.clear();
      }),
      child: content,
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return MemorySelectChip(
      label: label,
      emphasized: emphasized,
      trailingIcon: Lucide.ChevronDown,
      onTap: onTap,
    );
  }
}

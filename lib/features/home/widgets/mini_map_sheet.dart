import 'dart:math';

import 'package:flutter/material.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

Future<String?> showMiniMapSheet(
  BuildContext context,
  List<ChatMessage> messages, {
  bool selecting = false,
  Set<String>? selectedMessageIds,
  Listenable? selectionListenable,
  ValueChanged<String>? onToggleSelection,
}) async {
  assert(
    !selecting || (selectedMessageIds != null && onToggleSelection != null),
    'Mini map selection mode requires selectedMessageIds and onToggleSelection.',
  );
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MiniMapSheet(
      messages: messages,
      selecting: selecting,
      selectedMessageIds: selectedMessageIds,
      selectionListenable: selectionListenable,
      onToggleSelection: onToggleSelection,
    ),
  );
}

class _MiniMapSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final Listenable? selectionListenable;
  final ValueChanged<String>? onToggleSelection;

  const _MiniMapSheet({
    required this.messages,
    this.selecting = false,
    this.selectedMessageIds,
    this.selectionListenable,
    this.onToggleSelection,
  });

  @override
  State<_MiniMapSheet> createState() => _MiniMapSheetState();
}

class _MiniMapSheetState extends State<_MiniMapSheet> with TickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _query = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _clearOrCloseSearch({bool close = false}) {
    setState(() {
      _query = '';
      _searchController.clear();
      _isSearching = close ? false : _isSearching;
    });
    if (close) {
      _searchFocusNode.unfocus();
    } else {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searchWidth = min(MediaQuery.sizeOf(context).width * 0.6, 260.0);

    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, controller) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Pinned title
                Row(
                  children: [
                    Icon(Lucide.Map, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.miniMapTitle,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSearchToggle(context, searchWidth),
                  ],
                ),
                const SizedBox(height: 12),
                // Scrollable content
                Expanded(
                  child: widget.selecting && widget.selectionListenable != null
                      ? AnimatedBuilder(
                          animation: widget.selectionListenable!,
                          builder: (context, child) {
                            final pairs = _filteredPairs(_buildPairs(widget.messages));
                            return ListView(
                              controller: controller,
                              children: [
                                for (final p in pairs)
                                  _MiniMapRow(
                                    pair: p,
                                    selecting: true,
                                    selectedMessageIds: widget.selectedMessageIds!,
                                    onToggleSelection: widget.onToggleSelection!,
                                  ),
                              ],
                            );
                          },
                        )
                      : ListView(
                          controller: controller,
                          children: [
                            for (final p in _filteredPairs(_buildPairs(widget.messages)))
                              _MiniMapRow(
                                pair: p,
                                selecting: widget.selecting,
                                selectedMessageIds: widget.selectedMessageIds,
                                onToggleSelection: widget.onToggleSelection,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _legendDot(Color c) {
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: c.withOpacity(0.8), shape: BoxShape.circle));
  }

  Widget _buildSearchToggle(BuildContext context, double maxWidth) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withOpacity(isDark ? 0.5 : 0.8);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axis: Axis.horizontal,
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: _isSearching
            ? ConstrainedBox(
                key: const ValueKey('miniMapSearchField'),
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) => setState(() => _query = value),
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: MaterialLocalizations.of(context).searchFieldLabel,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            filled: true,
                            fillColor: cs.surfaceVariant.withOpacity(isDark ? 0.35 : 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: cs.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Lucide.X, size: 18, color: cs.onSurface.withOpacity(0.7)),
                        onPressed: () => _clearOrCloseSearch(close: true),
                        tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                      ),
                    ),
                  ],
                ),
              )
            : SizedBox(
                key: const ValueKey('miniMapSearchButton'),
                height: 36,
                width: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Lucide.Search, size: 20, color: cs.onSurface),
                  onPressed: _startSearch,
                  tooltip: MaterialLocalizations.of(context).searchFieldLabel,
                ),
              ),
      ),
    );
  }

  List<_QaPair> _buildPairs(List<ChatMessage> items) {
    final pairs = <_QaPair>[];
    ChatMessage? pendingUser;
    for (final m in items) {
      if (m.role == 'user') {
        // Push previous if it had no assistant
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: null));
        }
        pendingUser = m;
      } else if (m.role == 'assistant') {
        if (pendingUser != null) {
          pairs.add(_QaPair(user: pendingUser, assistant: m));
          pendingUser = null;
        } else {
          // Assistant without user: show as orphan on the right
          pairs.add(_QaPair(user: null, assistant: m));
        }
      }
    }
    if (pendingUser != null) {
      pairs.add(_QaPair(user: pendingUser, assistant: null));
    }
    return pairs;
  }

  List<_QaPair> _filteredPairs(List<_QaPair> base) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return base;
    return base.where((pair) {
      final user = pair.user?.content.toLowerCase() ?? '';
      final asst = pair.assistant?.content.toLowerCase() ?? '';
      return user.contains(needle) || asst.contains(needle);
    }).toList();
  }
}

class _QaPair {
  final ChatMessage? user;
  final ChatMessage? assistant;
  _QaPair({required this.user, required this.assistant});
}

class _MiniMapRow extends StatelessWidget {
  final _QaPair pair;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final ValueChanged<String>? onToggleSelection;

  const _MiniMapRow({
    required this.pair,
    this.selecting = false,
    this.selectedMessageIds,
    this.onToggleSelection,
  });

  String _oneLine(String s) {
    // Strip inline embed markers used in user messages to avoid noise
    var t = s
        // remove vendor inline reasoning blocks if present
        .replaceAll(RegExp(r'<think>[\s\S]*?<\/think>', caseSensitive: false), '')
        .replaceAll(RegExp(r"\[image:[^\]]+\]"), "")
        .replaceAll(RegExp(r"\[file:[^\]]+\]"), "")
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userText = pair.user?.content ?? '';
    final asstText = pair.assistant?.content ?? '';

    final bool userSelected =
        selectedMessageIds != null && pair.user != null && selectedMessageIds!.contains(pair.user!.id);
    final bool assistantSelected =
        selectedMessageIds != null && pair.assistant != null && selectedMessageIds!.contains(pair.assistant!.id);

    final userBg = (isDark ? cs.primary.withOpacity(0.15) : cs.primary.withOpacity(0.08));
    final userSelectedBg = (isDark ? cs.primary.withOpacity(0.26) : cs.primary.withOpacity(0.14));
    final userBorder = cs.primary.withOpacity(isDark ? 0.45 : 0.35);

    final assistantSelectedBg = (isDark ? cs.primary.withOpacity(0.18) : cs.primary.withOpacity(0.10));
    final assistantBorder = cs.primary.withOpacity(isDark ? 0.38 : 0.28);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // User bubble — match main chat style (right aligned rounded rectangle)
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75 - 32, // subtract side paddings approx in sheet
              ),
              child: Material(
                color: Colors.transparent,
                child: selecting
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pair.user != null ? () => onToggleSelection?.call(pair.user!.id) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: userSelected ? userSelectedBg : userBg,
                            borderRadius: BorderRadius.circular(16),
                            border: userSelected ? Border.all(color: userBorder, width: 1) : null,
                          ),
                          child: Text(
                            userText.isNotEmpty ? _oneLine(userText) : ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15.5, height: 1.4, color: cs.onSurface),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: pair.user != null ? () => Navigator.of(context).pop(pair.user!.id) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: userBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            userText.isNotEmpty ? _oneLine(userText) : ' ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15.5, height: 1.4, color: cs.onSurface),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Assistant message
          Material(
            color: Colors.transparent,
            child: selecting
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: pair.assistant != null ? () => onToggleSelection?.call(pair.assistant!.id) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: assistantSelected ? assistantSelectedBg : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: assistantSelected ? Border.all(color: assistantBorder, width: 1) : null,
                      ),
                      child: Text(
                        asstText.isNotEmpty ? _oneLine(asstText) : ' ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.7, height: 1.5),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: pair.assistant != null ? () => Navigator.of(context).pop(pair.assistant!.id) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        asstText.isNotEmpty ? _oneLine(asstText) : ' ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15.7, height: 1.5),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

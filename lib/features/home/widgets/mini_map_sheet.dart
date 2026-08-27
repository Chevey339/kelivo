import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../../core/database/chat_database_repository.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/message_part.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/search_highlight.dart';

Future<String?> showMiniMapSheet(
  BuildContext context,
  List<ChatMessage> messages, {
  bool selecting = false,
  Set<String>? selectedMessageIds,
  Listenable? selectionListenable,
  ValueChanged<String>? onToggleSelection,
  Future<List<MiniMapSearchHit>> Function(String query)? onSearch,
}) async {
  assert(
    !selecting || (selectedMessageIds != null && onToggleSelection != null),
    'Mini map selection mode requires selectedMessageIds and onToggleSelection.',
  );
  return await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.overlaySurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MiniMapSheet(
      messages: messages,
      selecting: selecting,
      selectedMessageIds: selectedMessageIds,
      selectionListenable: selectionListenable,
      onToggleSelection: onToggleSelection,
      onSearch: onSearch,
    ),
  );
}

class _MiniMapSheet extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool selecting;
  final Set<String>? selectedMessageIds;
  final Listenable? selectionListenable;
  final ValueChanged<String>? onToggleSelection;
  final Future<List<MiniMapSearchHit>> Function(String query)? onSearch;

  const _MiniMapSheet({
    required this.messages,
    this.selecting = false,
    this.selectedMessageIds,
    this.selectionListenable,
    this.onToggleSelection,
    this.onSearch,
  });

  @override
  State<_MiniMapSheet> createState() => _MiniMapSheetState();
}

class _MiniMapSheetState extends State<_MiniMapSheet>
    with TickerProviderStateMixin {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late List<_QaPair> _pairs;
  late List<_QaPair> _visiblePairs;
  String _query = '';
  bool _isSearching = false;
  bool _searchLoading = false;
  Map<String, MiniMapSearchHit> _hits = const <String, MiniMapSearchHit>{};
  Timer? _searchDebounce;
  int _searchSerial = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _pairs = _buildPairs(widget.messages);
    _visiblePairs = _pairs;
  }

  @override
  void didUpdateWidget(covariant _MiniMapSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _pairs = _buildPairs(widget.messages);
      _syncVisiblePairs();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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

  void _resetSearchResults() {
    _searchDebounce?.cancel();
    _searchSerial++;
    _query = '';
    _hits = const <String, MiniMapSearchHit>{};
    _searchLoading = false;
    _syncVisiblePairs();
  }

  void _clearOrCloseSearch({bool close = false}) {
    setState(() {
      _searchController.clear();
      _isSearching = close ? false : _isSearching;
      _resetSearchResults();
    });
    if (close) {
      _searchFocusNode.unfocus();
    } else {
      _searchFocusNode.requestFocus();
    }
  }

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _resetSearchResults();
        _query = value;
      });
      return;
    }
    if (widget.onSearch == null) {
      setState(() {
        _query = value;
        _syncVisiblePairs();
      });
      return;
    }
    _searchSerial++;
    setState(() => _query = value);
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_runSearch(trimmed));
    });
  }

  Future<void> _runSearch(String needle) async {
    final onSearch = widget.onSearch;
    if (onSearch == null) return;
    final serial = _searchSerial;
    if (mounted) {
      setState(() => _searchLoading = true);
    }
    final results = await onSearch(needle);
    if (!mounted || serial != _searchSerial) return;
    setState(() {
      _hits = {for (final hit in results) hit.messageId: hit};
      _searchLoading = false;
      _syncVisiblePairs();
    });
  }

  void _syncVisiblePairs() {
    _visiblePairs = _filteredPairs(_pairs);
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
          Widget buildList() {
            if (_searchLoading) {
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  ),
                ),
              );
            }
            if (_query.trim().isNotEmpty && _visiblePairs.isEmpty) {
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Text(
                    AppLocalizations.of(context)!.miniMapSearchNoResults,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              );
            }
            final pairs = _visiblePairs;
            return ListView.builder(
              controller: controller,
              itemCount: pairs.length,
              itemBuilder: (context, index) {
                final pair = pairs[index];
                return _MiniMapRow(
                  pair: pair,
                  selecting: widget.selecting,
                  selectedMessageIds: widget.selectedMessageIds,
                  onToggleSelection: widget.onToggleSelection,
                  userHit: pair.user == null ? null : _hits[pair.user!.id],
                  assistantHit: pair.assistant == null
                      ? null
                      : _hits[pair.assistant!.id],
                  searchNeedle: _query.trim().toLowerCase(),
                );
              },
            );
          }

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
                      color: cs.onSurface.withValues(alpha: 0.2),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFontWeights.emphasis,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Lucide.ChevronsDown,
                          size: 18,
                          color: cs.onSurface,
                        ),
                        tooltip: AppLocalizations.of(
                          context,
                        )!.miniMapScrollToBottomTooltip,
                        onPressed: () {
                          if (controller.hasClients &&
                              controller.position.maxScrollExtent > 0) {
                            controller.jumpTo(
                              controller.position.maxScrollExtent,
                            );
                          }
                        },
                      ),
                    ),
                    _buildSearchToggle(context, searchWidth),
                  ],
                ),
                const SizedBox(height: 12),
                // Scrollable content
                Expanded(
                  child: widget.selecting && widget.selectionListenable != null
                      ? AnimatedBuilder(
                          animation: widget.selectionListenable!,
                          builder: (context, child) => buildList(),
                        )
                      : buildList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchToggle(BuildContext context, double maxWidth) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = cs.outlineVariant.withValues(alpha: isDark ? 0.5 : 0.8);

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
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.search,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: MaterialLocalizations.of(
                              context,
                            ).searchFieldLabel,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: cs.surfaceContainerHighest.withValues(
                              alpha: isDark ? 0.35 : 0.6,
                            ),
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
                        icon: Icon(
                          Lucide.X,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                        onPressed: () => _clearOrCloseSearch(close: true),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonLabel,
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
    if (widget.onSearch != null) {
      return base.where((pair) {
        final userId = pair.user?.id;
        final assistantId = pair.assistant?.id;
        return (userId != null && _hits.containsKey(userId)) ||
            (assistantId != null && _hits.containsKey(assistantId));
      }).toList();
    }
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
  final MiniMapSearchHit? userHit;
  final MiniMapSearchHit? assistantHit;
  final String searchNeedle;

  const _MiniMapRow({
    required this.pair,
    this.selecting = false,
    this.selectedMessageIds,
    this.onToggleSelection,
    this.userHit,
    this.assistantHit,
    this.searchNeedle = '',
  });

  String _summaryText(ChatMessage? message) {
    if (message == null) return '';
    // ImagePart/FilePart are excluded; only TextPart contributes to the summary.
    final text = message.parts
        .whereType<TextPart>()
        .map((part) => part.text)
        .join();
    return _oneLine(text);
  }

  String _oneLine(String s) {
    // Strip vendor inline reasoning blocks if present; attachment markers are
    // no longer parsed because summaries are built from TextPart only.
    return _flattenWhitespace(
      s.replaceAll(
        RegExp(
          r'<(?:think|thought)>[\s\S]*?<\/(?:think|thought)>',
          caseSensitive: false,
        ),
        '',
      ),
    );
  }

  /// Collapse newlines so maxLines: 1 still shows the hit. Do not strip
  /// think/thought blocks — a keyword inside them must stay visible.
  String _flattenWhitespace(String s) {
    return s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _snippetDisplay(MiniMapSearchHit hit) {
    final prefix = hit.snippetStart > 0 ? '…' : '';
    return '$prefix${_flattenWhitespace(hit.snippet)}';
  }

  Widget _bubbleLabel({
    required BuildContext context,
    required ChatMessage? message,
    required MiniMapSearchHit? hit,
    required TextStyle style,
    required TextAlign textAlign,
  }) {
    if (hit != null) {
      final display = _snippetDisplay(hit);
      final flattenedNeedle = _flattenWhitespace(searchNeedle);
      final tokens = flattenedNeedle.isEmpty
          ? const <String>[]
          : <String>[flattenedNeedle];
      final highlight = style.copyWith(
        backgroundColor: context.appColors.searchHighlight,
      );
      final l10n = AppLocalizations.of(context)!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: highlightSearchText(
                  display,
                  tokens,
                  style,
                  highlight,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.miniMapSearchMatchCount(hit.matchCount),
            style: style.copyWith(
              fontSize: (style.fontSize ?? 14) - 1.5,
              color: (style.color ?? Theme.of(context).colorScheme.onSurface)
                  .withValues(alpha: 0.55),
            ),
          ),
        ],
      );
    }
    final text = _summaryText(message);
    return Text(
      text.isNotEmpty ? text : ' ',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
      textAlign: textAlign,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userStyle = TextStyle(
      fontSize: 15.5,
      height: 1.4,
      color: cs.onSurface,
    );
    final assistantStyle = TextStyle(fontSize: 15.7, height: 1.5);

    final bool userSelected =
        selectedMessageIds != null &&
        pair.user != null &&
        selectedMessageIds!.contains(pair.user!.id);
    final bool assistantSelected =
        selectedMessageIds != null &&
        pair.assistant != null &&
        selectedMessageIds!.contains(pair.assistant!.id);

    final userBg = (isDark
        ? cs.primary.withValues(alpha: 0.15)
        : cs.primary.withValues(alpha: 0.08));
    final userSelectedBg = (isDark
        ? cs.primary.withValues(alpha: 0.26)
        : cs.primary.withValues(alpha: 0.14));
    final userBorder = cs.primary.withValues(alpha: isDark ? 0.45 : 0.35);

    final assistantBg = cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04);
    final assistantSelectedBg = (isDark
        ? cs.primary.withValues(alpha: 0.18)
        : cs.primary.withValues(alpha: 0.10));
    final assistantBorder = cs.primary.withValues(alpha: isDark ? 0.38 : 0.28);

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
                maxWidth:
                    MediaQuery.sizeOf(context).width * 0.75 -
                    32, // subtract side paddings approx in sheet
              ),
              child: Material(
                color: Colors.transparent,
                child: selecting
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pair.user != null
                            ? () => onToggleSelection?.call(pair.user!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: userSelected ? userSelectedBg : userBg,
                            borderRadius: BorderRadius.circular(16),
                            border: userSelected
                                ? Border.all(color: userBorder, width: 1)
                                : null,
                          ),
                          child: _bubbleLabel(
                            context: context,
                            message: pair.user,
                            hit: userHit,
                            style: userStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: pair.user != null
                            ? () => Navigator.of(context).pop(pair.user!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: userBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _bubbleLabel(
                            context: context,
                            message: pair.user,
                            hit: userHit,
                            style: userStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Assistant message
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(
                  context,
                ).width, //* 0.75 - 32, // subtract side paddings approx in sheet
              ),
              child: Material(
                color: Colors.transparent,
                child: selecting
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: pair.assistant != null
                            ? () => onToggleSelection?.call(pair.assistant!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: assistantSelected
                                ? assistantSelectedBg
                                : assistantBg,
                            borderRadius: BorderRadius.circular(16),
                            border: assistantSelected
                                ? Border.all(color: assistantBorder, width: 1)
                                : null,
                          ),
                          child: _bubbleLabel(
                            context: context,
                            message: pair.assistant,
                            hit: assistantHit,
                            style: assistantStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: pair.assistant != null
                            ? () =>
                                  Navigator.of(context).pop(pair.assistant!.id)
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: assistantBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _bubbleLabel(
                            context: context,
                            message: pair.assistant,
                            hit: assistantHit,
                            style: assistantStyle,
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

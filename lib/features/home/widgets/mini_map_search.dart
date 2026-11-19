import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../utils/utf16_safe_cut.dart';
import '../../browser/widgets/browser_text_field.dart';
import '../../chat/services/conversation_find_service.dart';

typedef MiniMapSelection = ({String messageId, ConversationFindHit? match});
typedef MiniMapSearch =
    Stream<List<ConversationFindPreview>> Function(
      String query,
      bool Function() isCurrent,
    );

class MiniMapSearchPanel extends StatefulWidget {
  const MiniMapSearchPanel({
    super.key,
    required this.onSearch,
    required this.onSelect,
    required this.onClose,
    required this.browseList,
    this.scrollController,
  });

  final MiniMapSearch onSearch;
  final ValueChanged<MiniMapSelection> onSelect;
  final VoidCallback onClose;
  final Widget browseList;
  final ScrollController? scrollController;

  @override
  State<MiniMapSearchPanel> createState() => _MiniMapSearchPanelState();
}

class _MiniMapSearchPanelState extends State<MiniMapSearchPanel> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  final _localScroll = ScrollController();
  final _results = <ConversationFindPreview>[];
  Timer? _debounce;
  String _query = '';
  int _generation = 0;
  bool _searching = false;
  bool _failed = false;

  ScrollController get _scroll => widget.scrollController ?? _localScroll;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final composing = _field.value.composing;
    final query = composing.isValid && !composing.isCollapsed
        ? ''
        : _field.text.trim();
    if (query == _query) return;
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _results.clear();
      _query = query;
      _searching = query.isNotEmpty;
      _failed = false;
    });
    if (_searching) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      _debounce = Timer(const Duration(milliseconds: 200), () {
        unawaited(_search(query, generation));
      });
    }
  }

  Future<void> _search(String query, int generation) async {
    bool current() => mounted && generation == _generation;
    try {
      await for (final batch in widget.onSearch(query, current)) {
        if (!current()) return;
        setState(() => _results.addAll(batch));
      }
    } catch (error, stack) {
      if (!current()) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'minimap search',
        ),
      );
      _failed = true;
    } finally {
      if (current()) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    _localScroll.dispose();
    super.dispose();
  }

  Widget _status(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Center(
        child: _searching
            ? const CupertinoActivityIndicator(radius: 8)
            : Text(
                _failed
                    ? l10n.miniMapSearchFailed
                    : l10n.miniMapSearchNoResults,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: BrowserTextField(
                    key: const ValueKey('miniMapSearchField'),
                    controller: _field,
                    focusNode: _focus,
                    autofocus: true,
                    placeholder: l10n.miniMapSearchHint,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    prefix: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: Icon(
                        Lucide.Search,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IosIconButton(
                key: const ValueKey('miniMapCloseSearchButton'),
                icon: Lucide.X,
                minSize: 36,
                tooltip: l10n.commonClose,
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? widget.browseList
              : ListView.builder(
                  key: const ValueKey('miniMapSearchResults'),
                  controller: _scroll,
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount:
                      _results.length +
                      (_results.isEmpty || _searching || _failed ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _results.length) return _status(context);
                    final preview = _results[index];
                    return _MiniMapPreviewRow(
                      preview: preview,
                      onTap: () {
                        _focus.unfocus();
                        widget.onSelect((
                          messageId: preview.hit.messageId,
                          match: preview.hit,
                        ));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MiniMapPreviewRow extends StatelessWidget {
  const _MiniMapPreviewRow({required this.preview, required this.onTap});

  final ConversationFindPreview preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isUser = preview.role == 'user';
    final tint = isUser ? colors.primary : colors.onSurface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final alignment = isUser
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FractionallySizedBox(
        widthFactor: .9,
        alignment: alignment,
        child: Align(
          alignment: alignment,
          child: IosCardPress(
            baseColor: tint.withValues(
              alpha: isUser ? (dark ? .15 : .08) : .05,
            ),
            borderRadius: BorderRadius.circular(16),
            focusable: true,
            haptics: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const fontSize = 15.0;
                final textScaler = MediaQuery.textScalerOf(context);
                final countText = l10n.miniMapSearchMatchCount(
                  preview.matchCount,
                );
                final countStyle = TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontWeight: MediaQuery.boldTextOf(context)
                      ? FontWeight.bold
                      : null,
                );
                final countWidth = TextPainter.computeWidth(
                  text: TextSpan(
                    text: countText,
                    style: DefaultTextStyle.of(context).style.merge(countStyle),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: textScaler,
                  locale: Localizations.maybeLocaleOf(context),
                  maxLines: 1,
                );
                final countBelow = countWidth > constraints.maxWidth * .28;
                const gap = 8.0;
                final textWidth =
                    constraints.maxWidth - (countBelow ? 0 : countWidth + gap);
                // Reserve space for the match at large text sizes and narrow
                // widths by trimming the leading context first.
                final room = (textWidth * .75 / textScaler.scale(fontSize))
                    .floor();
                var before = preview.before;
                if (before.length > room) {
                  before = room < 2
                      ? ''
                      : '…${before.substring(utf16SafeTailStart(before, before.length - room + 1))}';
                }
                final highlight = TextStyle(
                  backgroundColor: context.appColors.searchHighlight,
                );
                final snippet = Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: before),
                      for (final segment in preview.segments)
                        TextSpan(
                          text: segment.text,
                          style: segment.highlighted ? highlight : null,
                        ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.4,
                    color: colors.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
                final count = Text(
                  countText,
                  textAlign: TextAlign.end,
                  style: countStyle,
                );
                if (countBelow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      snippet,
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: count,
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: snippet),
                    const SizedBox(width: gap),
                    count,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

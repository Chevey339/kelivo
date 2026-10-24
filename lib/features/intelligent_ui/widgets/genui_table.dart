import '../text/ui_number.dart';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_table_data.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_resolved_node.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_control_region.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_interactions.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_view_tabs.dart';

/// One paginated presentation for DataTable nodes and validated Chart rows.
/// Persistent settings stay in the surface; only editing/focus/scroll are local.
class GenUiDataTable extends StatefulWidget {
  const GenUiDataTable({
    super.key,
    required this.id,
    required this.node,
    required this.token,
  });
  final String id;
  final UiResolvedNode node;
  final UiRuntimeToken token;
  @override
  State<GenUiDataTable> createState() => _GenUiDataTableState();
}

class _GenUiDataTableState extends State<GenUiDataTable> {
  final _filter = TextEditingController();
  final _filterFocus = FocusNode(debugLabel: 'GenUI table filter');
  final _scroll = ScrollController();
  GenUiInteractions? _scope;
  VoidCallback? _unsubscribe, _reset;
  bool _syncing = false, _filterFailed = false;
  bool _viewFailed = false, _viewportFocused = false;
  String? _lastFilter;
  Object? _widthSignature;
  List<double> _widths = const [];
  UiSurfaceController get _surface => _scope!.controller.surface;
  UiTableData get _data => widget.node.tableData!;
  Map<String, Object?> get _view => _surface.state.view[widget.id] ?? const {};
  bool get _interactive =>
      !_scope!.readOnly &&
      _surface.accepts(widget.token) &&
      _scope!.controller.tree.enabled[widget.id] == true;
  bool get _sortable => widget.node.properties['sortable'] != false;
  bool get _filterable => widget.node.properties['filterable'] != false;
  int get _defaultPageSize =>
      (widget.node.properties['pageSize'] as num?)?.toInt() ?? 10;

  @override
  void initState() {
    super.initState();
    _filter.addListener(_filterChanged);
    _filterFocus.addListener(_blur);
  }

  void _blur() {
    if (!_filterFocus.hasFocus) _surface.flushQuietly();
    if (mounted) setState(() {});
  }

  void _readFilter({bool force = false}) {
    final committed = _view['filter'] as String? ?? '';
    final pending = _scope!.controller.tableFilterDraft(widget.id, committed);
    final text = pending?.text ?? committed;
    if (!force && committed == _lastFilter) return;
    _lastFilter = committed;
    _filterFailed = pending?.failed ?? false;
    if (force) _viewFailed = false;
    if (!force && _filter.text == text) return;
    _syncing = true;
    try {
      _filter.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } finally {
      _syncing = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = GenUiInteractions.of(context);
    if (scope.controller != _scope?.controller) {
      _unsubscribe?.call();
      _reset?.call();
      _scope = scope;
      _readFilter(force: true);
      _unsubscribe = scope.controller.listen(widget.id, () {
        if (!mounted) return;
        _readFilter();
        setState(() {});
      });
      _reset = _surface.listenReset(() {
        if (!mounted) return;
        _readFilter(force: true);
        setState(() {});
      });
    }
    _scope = scope;
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _reset?.call();
    _filter.removeListener(_filterChanged);
    _filter.dispose();
    _filterFocus.removeListener(_blur);
    _filterFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  UiMutationResult _change(Map<String, Object?> changes, {bool flush = true}) {
    if (!_interactive) return UiMutationResult.readOnly;
    final result = _surface.setView(widget.id, {
      ..._view,
      ...changes,
    }, token: widget.token);
    setState(() => _viewFailed = result == UiMutationResult.invalid);
    if (flush) _surface.flushQuietly();
    return result;
  }

  void _rememberFilter() => _scope!.controller.rememberTableFilter(
    widget.id,
    _filter.text,
    committed: _view['filter'] as String? ?? '',
    failed: _filterFailed,
    token: widget.token,
  );

  void _filterChanged() {
    if (_syncing || _scope == null || !_interactive) return;
    _surface.noteInteraction(token: widget.token);
    if (_filter.value.composing.isValid &&
        !_filter.value.composing.isCollapsed) {
      _rememberFilter();
      return;
    }
    // Losing focus clears composing directly on the controller, bypassing
    // inputFormatters. Apply the same bound at every committed-value entry.
    final bounded = _boundedFilterValue(_filter.value);
    if (bounded != _filter.value) {
      _syncing = true;
      try {
        _filter.value = bounded;
      } finally {
        _syncing = false;
      }
    }
    if (_filter.text == (_view['filter'] ?? '')) {
      _rememberFilter();
      if (_filterFailed) {
        setState(() {
          _filterFailed = false;
          _viewFailed = false;
        });
      }
      return;
    }
    final result = _change({'filter': _filter.text, 'page': 0}, flush: false);
    setState(() => _filterFailed = result == UiMutationResult.invalid);
    _rememberFilter();
  }

  UiTablePage _page() => _data.project(
    view: _view,
    defaultPageSize: _defaultPageSize,
    format: _text,
    sortable: _sortable,
    filterable: _filterable,
  );

  List<double> _columnWidths(GenUiTheme theme, TextScaler scaler) {
    final signature = (
      _data,
      theme.body,
      theme.label,
      scaler,
      Directionality.of(context),
      AppLocalizations.of(context)!.localeName,
    );
    if (_widthSignature == signature) return _widths;
    _widthSignature = signature;
    // Bounded measurement: inspect scalar text once per data/appearance change,
    // then measure a few representative strings. Cells can still wrap; paging
    // and filtering never make widths jump or remeasure thousands of paragraphs.
    _widths = [
      for (var c = 0; c < _data.columns.length; c++)
        (() {
          final col = _data.columns[c];
          var longest = '';
          for (final row in _data.rows) {
            final text = _text(col, row.values[c]);
            if (text.length > longest.length) longest = text;
          }
          final maximum = scaler.scale(col.numeric ? 180 : 240);
          var width = scaler.scale(col.numeric ? 64 : 120);
          final samples = [
            (col.label, true),
            (longest, false),
            for (final row in _data.rows.take(3))
              (_text(col, row.values[c]), false),
          ];
          for (final (text, header) in samples) {
            if (text.length > 80) {
              width = maximum;
              break;
            }
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: header ? theme.label : theme.body,
              ),
              textScaler: scaler,
              textDirection: Directionality.of(context),
            )..layout();
            width = math.max(
              width,
              painter.width + theme.sm * 2 + (header && _sortable ? 23 : 0),
            );
            painter.dispose();
          }
          return math.min(maximum, width);
        })(),
    ];
    return _widths;
  }

  void _pageBy(int delta) {
    final page = _page();
    _change({'page': (page.page + delta).clamp(0, page.pages - 1)});
  }

  void _sort(UiTableColumn column) {
    final page = _page();
    final same = page.sortKey == column.viewKey;
    _change({
      'sortKey': same && page.descending ? null : column.viewKey,
      'descending': same && !page.descending,
      'page': 0,
    });
  }

  String _text(UiTableColumn column, Object? value) {
    final l10n = AppLocalizations.of(context)!;
    return value is num
        ? genUiNumber(value, digits: column.digits)
        : value == null
        ? '—'
        : value is bool
        ? (value ? l10n.genuiValueTrue : l10n.genuiValueFalse)
        : value as String;
  }

  KeyEventResult _key(FocusNode focus, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.pageUp) {
      if (!_interactive) return KeyEventResult.ignored;
      _pageBy(key == LogicalKeyboardKey.pageDown ? 1 : -1);
      return KeyEventResult.handled;
    }
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    double? offset;
    if (key == LogicalKeyboardKey.home) offset = 0;
    if (key == LogicalKeyboardKey.end) {
      offset = _scroll.position.maxScrollExtent;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final direction = Directionality.of(context) == TextDirection.rtl
          ? -1
          : 1;
      offset =
          _scroll.offset +
          (key == LogicalKeyboardKey.arrowRight ? 80 : -80) * direction;
    }
    if (offset == null) return KeyEventResult.ignored;
    _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context), l10n = AppLocalizations.of(context)!;
    final page = _page();
    final matcher = uiTableFilter(page.filter);
    final exporting = _scope!.exporting;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (exporting && page.filter.isNotEmpty)
          Text(
            '${l10n.genuiTableFilterHint}: ${page.filter}',
            style: theme.caption,
          ),
        if (_filterable && !exporting)
          Row(
            children: [
              Expanded(
                child: GenUiControlRegion(
                  child: Semantics(
                    label: l10n.genuiTableFilterHint,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: IosFormTextField(
                        label: '',
                        controller: _filter,
                        focusNode: _filterFocus,
                        key: ValueKey('genui-table-filter-${widget.id}'),
                        inlineLabel: false,
                        hintText: l10n.genuiTableFilterHint,
                        outerPadding: EdgeInsets.zero,
                        enabled: _interactive,
                        textStyle: theme.body,
                        onSubmitted: (_) => _surface.flushQuietly(),
                        inputFormatters: [_filterLengthFormatter],
                        fieldDecoration: BoxDecoration(
                          color: theme.fill,
                          borderRadius: BorderRadius.circular(
                            theme.controlRadius,
                          ),
                          border: Border.all(
                            color: _filterFailed
                                ? theme.error
                                : _filterFocus.hasFocus
                                ? theme.primary
                                : theme.hairlineStrong,
                            width: _filterFocus.hasFocus ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: theme.sm),
              Flexible(
                flex: 0,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.genuiTableRows(page.total),
                    style: theme.caption,
                  ),
                ),
              ),
            ],
          ),
        if ((_viewFailed || _filterFailed) && !exporting)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.genuiViewStateFailed,
              style: theme.caption.copyWith(color: theme.error),
            ),
          ),
        SizedBox(height: theme.xs),
        if (!_filterable || exporting)
          Semantics(
            liveRegion: true,
            child: Text(l10n.genuiTableRows(page.total), style: theme.caption),
          ),
        SizedBox(height: theme.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final minimums = _columnWidths(theme, scaler);
            final sum = minimums.fold(0.0, (a, b) => a + b);
            final width = math.max(sum, constraints.maxWidth);
            return Focus(
              canRequestFocus: !exporting,
              onKeyEvent: _key,
              onFocusChange: (value) =>
                  setState(() => _viewportFocused = value),
              child: Container(
                key: ValueKey('genui-table-viewport-${widget.id}'),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(theme.controlRadius),
                  border: Border.all(
                    color: _viewportFocused ? theme.primary : theme.transparent,
                    width: 2,
                  ),
                ),
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: width > constraints.maxWidth,
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.only(
                      bottom: width > constraints.maxWidth ? theme.sm : 0,
                    ),
                    child: SizedBox(
                      width: width,
                      child: Table(
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        columnWidths: {
                          for (var c = 0; c < minimums.length; c++)
                            c: FixedColumnWidth(
                              minimums[c] + (width - sum) / minimums.length,
                            ),
                        },
                        border: TableBorder(
                          horizontalInside: BorderSide(color: theme.hairline),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: theme.cardFill),
                            children: [
                              for (final col in _data.columns)
                                _header(
                                  col,
                                  page,
                                  theme,
                                  l10n,
                                  exporting: exporting,
                                ),
                            ],
                          ),
                          for (final row in page.rows)
                            TableRow(
                              key: ValueKey((widget.id, row.key)),
                              children: [
                                for (var c = 0; c < _data.columns.length; c++)
                                  _cell(
                                    _data.columns[c],
                                    row.values[c],
                                    matcher,
                                    theme,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (page.rows.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.lg),
            child: Text(
              l10n.genuiTableEmpty,
              textAlign: TextAlign.center,
              style: theme.caption,
            ),
          ),
        SizedBox(height: theme.xs),
        Text(
          l10n.genuiTablePageInfo(page.from, page.to, page.total),
          style: theme.caption,
        ),
        if (!exporting)
          Wrap(
            spacing: theme.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: math.min(
                  280,
                  MediaQuery.textScalerOf(context).scale(180),
                ),
                child: GenUiViewTabs(
                  labels: [
                    l10n.genuiTablePerPage(10),
                    l10n.genuiTablePerPage(20),
                  ],
                  index: page.pageSize == 20 ? 1 : 0,
                  enabled: _interactive,
                  onChanged: (index) =>
                      _change({'pageSize': index == 0 ? 10 : 20, 'page': 0}),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GenUiControlRegion(
                    child: IosIconButton(
                      key: ValueKey('genui-table-previous-${widget.id}'),
                      icon: Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronLeft,
                      semanticLabel: l10n.genuiTablePreviousPage,
                      tooltip: l10n.genuiTablePreviousPage,
                      minSize: 44,
                      color: theme.primary,
                      enabled: _interactive && page.page > 0,
                      onTap: () => _pageBy(-1),
                    ),
                  ),
                  Text(
                    '${page.page + 1}/${page.pages}',
                    style: theme.caption,
                    textDirection: TextDirection.ltr,
                  ),
                  GenUiControlRegion(
                    child: IosIconButton(
                      key: ValueKey('genui-table-next-${widget.id}'),
                      icon: Directionality.of(context) == TextDirection.rtl
                          ? LucideIcons.chevronLeft
                          : LucideIcons.chevronRight,
                      semanticLabel: l10n.genuiTableNextPage,
                      tooltip: l10n.genuiTableNextPage,
                      minSize: 44,
                      color: theme.primary,
                      enabled: _interactive && page.page + 1 < page.pages,
                      onTap: () => _pageBy(1),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _header(
    UiTableColumn col,
    UiTablePage page,
    GenUiTheme theme,
    AppLocalizations l10n, {
    required bool exporting,
  }) {
    final selected = page.sortKey == col.viewKey;
    final state = selected
        ? page.descending
              ? l10n.genuiSortDesc
              : l10n.genuiSortAsc
        : l10n.genuiSortNone;
    if (!_sortable || exporting) {
      return Semantics(
        role: SemanticsRole.columnHeader,
        label: '${col.label}, $state',
        child: ExcludeSemantics(
          child: Padding(
            padding: EdgeInsets.all(theme.xs),
            child: Text(
              '${col.label}${selected
                  ? page.descending
                        ? ' ↓'
                        : ' ↑'
                  : ''}',
              style: theme.header.copyWith(color: theme.secondaryInk),
              textAlign: col.numeric ? TextAlign.end : TextAlign.start,
            ),
          ),
        ),
      );
    }
    return GenUiControlRegion(
      child: Semantics(
        role: SemanticsRole.columnHeader,
        label: '${col.label}, $state',
        button: true,
        enabled: _interactive,
        onTap: _interactive ? () => _sort(col) : null,
        child: ExcludeSemantics(
          child: IosTextButton(
            key: ValueKey('genui-table-sort-${widget.id}-${col.key}'),
            label: col.label,
            icon: selected
                ? page.descending
                      ? LucideIcons.arrowDown
                      : LucideIcons.arrowUp
                : null,
            onPressed: _interactive ? () => _sort(col) : null,
            color: theme.secondaryInk,
            fontSize: theme.label.fontSize!,
            mainAxisAlignment: col.numeric
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
          ),
        ),
      ),
    );
  }

  Widget _cell(
    UiTableColumn col,
    Object? value,
    RegExp? matcher,
    GenUiTheme theme,
  ) {
    final text = _text(col, value);
    final numeric = col.numeric || value is num;
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in matcher?.allMatches(text) ?? const <RegExpMatch>[]) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            backgroundColor: theme.searchHighlight,
            color: theme.ink,
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return Semantics(
      label: '${col.label}: $text',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: EdgeInsets.symmetric(
            horizontal: theme.sm,
            vertical: theme.xs,
          ),
          alignment: numeric
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Text.rich(
            TextSpan(children: spans),
            style: theme.body.copyWith(
              fontFeatures: value is num
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
            textDirection: value is num ? TextDirection.ltr : null,
          ),
        ),
      ),
    );
  }
}

// The persisted filter budget is UTF-16 length. Keep complete graphemes while
// enforcing that same bound, and leave an active IME composition untouched.
final _filterLengthFormatter = TextInputFormatter.withFunction(
  (old, next) => _boundedFilterValue(next),
);

TextEditingValue _boundedFilterValue(TextEditingValue next) {
  if (next.text.length <= UiBudgets.tableFilterCodeUnits ||
      (next.composing.isValid && !next.composing.isCollapsed)) {
    return next;
  }
  final text = StringBuffer();
  for (final character in next.text.characters) {
    if (text.length + character.length > UiBudgets.tableFilterCodeUnits) break;
    text.write(character);
  }
  final bounded = text.toString();
  return next.copyWith(
    text: bounded,
    composing: TextRange.empty,
    selection: next.selection.isValid
        ? TextSelection(
            baseOffset: next.selection.baseOffset.clamp(0, bounded.length),
            extentOffset: next.selection.extentOffset.clamp(0, bounded.length),
          )
        : TextSelection.collapsed(offset: bounded.length),
  );
}

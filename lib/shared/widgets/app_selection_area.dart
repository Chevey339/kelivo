import 'ios_tactile.dart';
import 'option_sheet.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:uuid/uuid.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/quote_ref.dart';
import '../../features/chat/models/selection_snapshot.dart';
import '../../utils/source_text_map.dart';
import '../../features/chat/widgets/quote_chip.dart' show selectionUsesDesktop;
import '../../features/chat/widgets/quote_interaction_scope.dart';
import '../../features/chat/widgets/selection_quick_toolbar.dart';
import '../../features/chat/widgets/selection_result_panel.dart';
import 'package:super_clipboard/super_clipboard.dart' show ClipboardWriter;
import '../markdown/rich_clipboard.dart';
import 'app_text_selection_toolbar.dart';
import 'snackbar.dart';
import 'selection_scroll_container.dart';

import 'package:markstream/markstream.dart'
    show
        MarkstreamSelectionController,
        MarkstreamSelectionScope,
        MarkstreamCopyLimitException;
import '../../l10n/app_localizations.dart';

/// App-owned selection actions shared by messages and Markdown previews.
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({
    super.key,
    required this.child,
    this.clipboardWriter,
    this.copyByteLimit,
    this.message,
    this.sourceText,
    this.sourceOffset,
    this.sourceMap,
    this.onQuoteSelected,
  });

  final Widget child;
  final ClipboardWriter? clipboardWriter;

  /// Optional budget for source and plain-text previews without AST projections.
  final int? copyByteLimit;
  final ChatMessage? message;
  final String? sourceText;
  final int? sourceOffset;
  final SourceTextMap? sourceMap;
  final VoidCallback? onQuoteSelected;

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  static const _translation = MethodChannel('app.ios_translation');
  bool _translationAvailable = false;
  String _selectedText = '';
  final _ownedMarkdownSelection = MarkstreamSelectionController();
  final _regionFocus = FocusNode();
  final _selectionKey = GlobalKey<SelectionScrollContainerState>();
  final _areaKey = GlobalKey<SelectionAreaState>();
  final _quickToolbar = OverlayPortalController();
  final _scrollPositions = <ScrollPosition>[];
  bool _pointerSelecting = false,
      _keyboardSelecting = false,
      _contextClick = false;
  SelectionSnapshot? _quickSnapshot;
  Rect? _quickAnchor;
  bool _quickScheduled = false;
  int _toolbarRevision = 0;
  int _quickRequestedRevision = 0;
  late final _copyAction = _SelectionCopyAction(
    intercept: () =>
        _regionFocus.hasPrimaryFocus &&
        (_hasCopyBudget || (widget.message?.quotes.isNotEmpty ?? false)),
    copy: _copyNativeSelection,
  );
  late MarkstreamSelectionController _markdownSelection;

  @override
  void initState() {
    super.initState();
    _regionFocus.addListener(_focusChanged);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_loadTranslationAvailability());
    }
  }

  void _focusChanged() {
    if (!_regionFocus.hasFocus) _hideQuickToolbar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final position in _scrollPositions) {
      position.removeListener(_hideQuickToolbar);
    }
    _scrollPositions.clear();
    if (widget.message == null) return;
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (!_scrollPositions.contains(position)) {
          _scrollPositions.add(position);
          position.addListener(_hideQuickToolbar);
        }
      }
      return true;
    });
  }

  void _hideQuickToolbar() {
    _toolbarRevision++;
    if (_quickToolbar.isShowing) _quickToolbar.hide();
  }

  SelectionSnapshot? _captureSelection() {
    final message = widget.message;
    final text = _markdownSelection.hasSelection
        ? _markdownSelection.selectedPlainText
        : _selectionKey.currentState?.selectedText ?? _selectedText;
    if (message == null || text.trim().isEmpty) return null;
    final source = widget.sourceText ?? message.content;
    final ranges =
        _markdownSelection.selections
            .expand((selection) => selection.sourceRanges)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    final range = _selectionKey.currentState?.selectedRange;
    final start = ranges.isNotEmpty
        ? ranges.first.start
        : range?.startOffset ?? source.indexOf(text);
    final end = ranges.isNotEmpty
        ? ranges.map((span) => span.end).reduce((a, b) => a > b ? a : b)
        : range?.endOffset ?? start + text.length;
    final base = widget.sourceOffset ?? message.content.indexOf(source);
    final offset = base < 0 ? 0 : base;
    final mappedRange = widget.sourceMap?.sourceRange(
      start.clamp(0, source.length),
      end.clamp(0, source.length),
    );
    final absoluteStart =
        mappedRange?.start ?? offset + start.clamp(0, source.length);
    final selectedQuoteTexts = <String>[];
    for (final match in RegExp(quotePlaceholder).allMatches(source)) {
      final selected = ranges.isEmpty
          ? match.start >= start && match.start < end
          : ranges.any(
              (range) => range.start <= match.start && range.end > match.start,
            );
      if (!selected) continue;
      final raw =
          widget.sourceMap?.sourceRange(match.start, match.end).start ??
          offset + match.start;
      final index = RegExp(quotePlaceholder)
          .allMatches(
            message.content.substring(0, raw.clamp(0, message.content.length)),
          )
          .length;
      selectedQuoteTexts.add(
        index < message.quotes.length
            ? message.quotes[index].text
            : quotePlaceholder,
      );
    }
    String expandQuotes(String value) {
      if (message.quotes.isEmpty) return value;
      var index = 0;
      return value.replaceAllMapped(
        RegExp(quotePlaceholder),
        (_) => index < selectedQuoteTexts.length
            ? selectedQuoteTexts[index++]
            : quotePlaceholder,
      );
    }

    return SelectionSnapshot(
      messageId: message.id,
      role: message.role,
      start: absoluteStart,
      end: mappedRange?.end ?? offset + end.clamp(0, source.length),
      text: expandQuotes(text),
      markdown: expandQuotes(
        _markdownSelection.hasSelection
            ? _markdownSelection.selectedMarkdown
            : text,
      ),
    );
  }

  Rect _selectionAnchor({Offset? fallbackAnchor}) {
    final rects = _selectionKey.currentState?.globalSelectionRects;
    if (rects != null && rects.isNotEmpty) return rects.first;
    final anchor =
        fallbackAnchor ??
        _areaKey
            .currentState
            ?.selectableRegion
            .contextMenuAnchors
            .primaryAnchor ??
        Offset.zero;
    return Rect.fromLTWH(anchor.dx, anchor.dy, 1, 18);
  }

  void _scheduleQuickToolbar() {
    if (!selectionUsesDesktop || widget.message == null) {
      return;
    }
    // Coalesce to the latest selection. Clearing/reselecting before the frame
    // must not strand the new request behind a cancelled callback.
    _quickRequestedRevision = _toolbarRevision;
    if (_quickScheduled) return;
    _quickScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _quickScheduled = false;
      if (!mounted ||
          _quickRequestedRevision != _toolbarRevision ||
          _pointerSelecting ||
          _keyboardSelecting ||
          _contextClick) {
        return;
      }
      final snapshot = _captureSelection();
      if (snapshot == null) {
        _hideQuickToolbar();
        return;
      }
      _quickSnapshot = snapshot;
      _quickAnchor = _selectionAnchor();
      _areaKey.currentState?.selectableRegion.hideToolbar(false);
      _quickToolbar.show();
    });
    // Pointer-up may change no render object after the last drag frame.
    // A post-frame callback alone does not request that next frame.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _quote(SelectionSnapshot snapshot) {
    final actions = QuoteInteractionScope.maybeOf(context);
    final message = widget.message;
    if (actions == null || message == null) return;
    _hideQuickToolbar();
    _areaKey.currentState?.selectableRegion.hideToolbar();
    widget.onQuoteSelected?.call();
    unawaited(
      actions.onQuote(
        QuoteRef(
          id: const Uuid().v4(),
          messageId: snapshot.messageId,
          start: snapshot.start,
          end: snapshot.end,
          text: snapshot.text,
          model: message.modelId,
          createdAt: message.timestamp,
        ),
      ),
    );
  }

  void _translate(SelectionSnapshot snapshot, Rect anchor) {
    final message = widget.message;
    if (message == null) return;
    _hideQuickToolbar();
    _areaKey.currentState?.selectableRegion.hideToolbar();
    unawaited(
      showSelectionTranslationPanel(
        context,
        message: message,
        text: snapshot.text,
        anchor: anchor,
      ),
    );
  }

  KeyEventResult _keyEvent(FocusNode node, KeyEvent event) {
    if (widget.message == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      _hideQuickToolbar();
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyL &&
        (defaultTargetPlatform == TargetPlatform.macOS
            ? keyboard.isMetaPressed
            : keyboard.isControlPressed)) {
      final snapshot = _captureSelection();
      if (snapshot != null && QuoteInteractionScope.maybeOf(context) != null) {
        _quote(snapshot);
        return KeyEventResult.handled;
      }
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (keyboard.isShiftPressed) {
        _contextClick = false;
        _keyboardSelecting = true;
        _hideQuickToolbar();
      }
    } else if (event is KeyUpEvent && _keyboardSelecting) {
      _keyboardSelecting = false;
      _scheduleQuickToolbar();
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadTranslationAvailability() async {
    try {
      final available =
          await _translation.invokeMethod<bool>('isAvailable') ?? false;
      if (mounted && available != _translationAvailable) {
        setState(() => _translationAvailable = available);
      }
    } on MissingPluginException {
      // Native translation is not available in this host.
    } on PlatformException {
      // Selection remains usable if the native availability query fails.
    }
  }

  Future<void> _presentTranslation(String text, Offset anchor) async {
    try {
      await _translation.invokeMethod<void>('present', {
        'text': text,
        'anchorX': anchor.dx,
        'anchorY': anchor.dy,
      });
    } on MissingPluginException {
      // The toolbar already closed; there is no native view to present.
    } on PlatformException {
      // A native presentation error must not break the message selection.
    }
  }

  void _copyFailure(Object error) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showAppSnackBar(
      context,
      message: error is MarkstreamCopyLimitException
          ? l10n.genuiCopyLimit
          : l10n.markdownCopySelectionFailed,
      type: error is MarkstreamCopyLimitException
          ? NotificationType.warning
          : NotificationType.error,
    );
  }

  bool get _hasCopyBudget =>
      widget.copyByteLimit != null ||
      _markdownSelection.selectionByteLimit != null;

  bool _writeSelection(String text) {
    if (text.isEmpty) return false;
    try {
      _markdownSelection.verifyCopyBudget([
        text,
      ], byteLimit: widget.copyByteLimit);
    } on MarkstreamCopyLimitException catch (error) {
      _copyFailure(error);
      return false;
    }
    unawaited(
      Clipboard.setData(ClipboardData(text: text)).catchError(_copyFailure),
    );
    return true;
  }

  bool _copyNativeSelection() => _writeSelection(
    _captureSelection()?.text ??
        _selectionKey.currentState?.selectedText ??
        _selectedText,
  );

  Future<void> _copyRichText(SelectableRegionState region) async {
    final pending = copyRichMarkdownSelection(
      _markdownSelection,
      writer: widget.clipboardWriter,
      byteLimit: widget.copyByteLimit,
    );
    region.hideToolbar();
    try {
      await pending;
    } catch (error) {
      _copyFailure(error);
    }
  }

  Widget _buildMenu(BuildContext context, SelectableRegionState region) {
    final text = _selectedText;
    // Reading these anchors consumes Flutter's saved right-click position.
    final anchors = region.contextMenuAnchors;
    final snapshot = _captureSelection();
    if (widget.message != null && snapshot != null) {
      return _buildMessageMenu(context, region, snapshot, anchors);
    }
    return AppTextSelectionToolbar(
      anchors: anchors,
      selectionContext: region.context,
      onDismiss: () => region.hideToolbar(false),
      buttonItems: [
        for (final item in region.contextMenuButtonItems)
          if (item.type == ContextMenuButtonType.copy && _hasCopyBudget)
            ContextMenuButtonItem(
              type: item.type,
              label: item.label,
              onPressed: () {
                final copied = _copyNativeSelection();
                if (copied &&
                    (defaultTargetPlatform == TargetPlatform.android ||
                        defaultTargetPlatform == TargetPlatform.fuchsia)) {
                  region.clearSelection();
                }
                region.hideToolbar();
              },
            )
          else
            item,
        if (_markdownSelection.hasSelection)
          ContextMenuButtonItem(
            label: AppLocalizations.of(context)!.markdownCopyMarkdownAction,
            onPressed: () {
              final markdown = _markdownSelection.selectedMarkdown;
              _writeSelection(markdown);
              region.hideToolbar();
            },
          ),
        if (_markdownSelection.hasSelection)
          ContextMenuButtonItem(
            label: AppLocalizations.of(context)!.markdownCopyRichTextAction,
            onPressed: () => unawaited(_copyRichText(region)),
          ),
        if (_translationAvailable && text.trim().isNotEmpty)
          ContextMenuButtonItem(
            label: AppLocalizations.of(
              context,
            )!.chatMessageWidgetTranslateTooltip,
            onPressed: () {
              region.hideToolbar();
              unawaited(_presentTranslation(text, anchors.primaryAnchor));
            },
          ),
      ],
    );
  }

  Widget _buildMessageMenu(
    BuildContext context,
    SelectableRegionState region,
    SelectionSnapshot snapshot,
    TextSelectionToolbarAnchors anchors,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final anchor = _selectionAnchor(fallbackAnchor: anchors.primaryAnchor);
    final items = region.contextMenuButtonItems;
    final selectedMarkdown = _markdownSelection.hasSelection
        ? snapshot.markdown
        : null;
    final copy = ContextMenuButtonItem(
      type: ContextMenuButtonType.copy,
      onPressed: () {
        _writeSelection(snapshot.text);
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.fuchsia) {
          region.clearSelection();
        }
        region.hideToolbar();
      },
    );
    final markdown = ContextMenuButtonItem(
      label: l10n.selectionCopyMarkdown,
      onPressed: () {
        _writeSelection(snapshot.markdown);
        region.hideToolbar();
      },
    );
    final rich = ContextMenuButtonItem(
      label: l10n.selectionCopyRich,
      onPressed: () {
        final pending = copyRichTextSnapshot(
          snapshot.text,
          markdown: selectedMarkdown,
          writer: widget.clipboardWriter,
          verifyBudget: (values) => _markdownSelection.verifyCopyBudget(
            values,
            byteLimit: widget.copyByteLimit,
          ),
        );
        region.hideToolbar();
        unawaited(pending.catchError(_copyFailure));
      },
    );
    final quote = ContextMenuButtonItem(
      label: l10n.selectionQuote,
      onPressed: QuoteInteractionScope.maybeOf(this.context) == null
          ? null
          : () => _quote(snapshot),
    );
    final translate = ContextMenuButtonItem(
      label: defaultTargetPlatform == TargetPlatform.iOS
          ? l10n.selectionAiTranslateIos
          : l10n.selectionTranslate,
      onPressed: () => _translate(snapshot, anchor),
    );
    final selectAll =
        items
            .where((item) => item.type == ContextMenuButtonType.selectAll)
            .firstOrNull ??
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () => region.selectAll(SelectionChangedCause.toolbar),
        );
    if (selectionUsesDesktop) {
      if (!_contextClick) return const SizedBox.shrink();
      return AppTextSelectionToolbar(
        anchors: anchors,
        buttonItems: [copy, markdown, rich, quote, translate, selectAll],
        separatorsBefore: {quote, selectAll},
        shortcuts: {quote: quoteKeyboardHint},
        selectionContext: region.context,
        onDismiss: () => region.hideToolbar(false),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // SelectableRegion exposes system actions rather than EditableTextState.
      // Preserve every supplied item; keep our native translation bridge too.
      final systemTranslate = _translationAvailable
          ? ContextMenuButtonItem(
              label: l10n.selectionTranslate,
              onPressed: () {
                region.hideToolbar();
                unawaited(
                  _presentTranslation(snapshot.text, anchors.primaryAnchor),
                );
              },
            )
          : null;
      return AppTextSelectionToolbar(
        anchors: anchors,
        selectionContext: region.context,
        onDismiss: () => region.hideToolbar(false),
        buttonItems: [
          copy,
          quote,
          if (systemTranslate != null) systemTranslate,
          translate,
          for (final item in items)
            if (item.type != ContextMenuButtonType.copy) item,
          markdown,
          rich,
        ],
      );
    }
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      children: [
        for (final item in [
          copy,
          quote,
          translate,
          for (final item in items)
            if (item.type != ContextMenuButtonType.copy &&
                item.type != ContextMenuButtonType.selectAll)
              item,
          selectAll,
        ])
          TextSelectionToolbarTextButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: item.onPressed,
            child: Text(
              AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
            ),
          ),
        IosIconButton(
          tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
          icon: LucideIcons.ellipsisVertical,
          size: 18,
          minSize: 44,
          onTap: () async {
            region.hideToolbar();
            final item = await showOptionSheet<ContextMenuButtonItem>(
              this.context,
              title: MaterialLocalizations.of(this.context).copyButtonLabel,
              items: [
                for (final item in [markdown, rich])
                  OptionSheetItem(value: item, label: item.label!),
              ],
            );
            if (mounted) item?.onPressed?.call();
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (final position in _scrollPositions) {
      position.removeListener(_hideQuickToolbar);
    }
    _regionFocus.removeListener(_focusChanged);
    _ownedMarkdownSelection.dispose();
    _regionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _markdownSelection =
        MarkstreamSelectionScope.maybeOf(context) ?? _ownedMarkdownSelection;
    return MarkstreamSelectionScope(
      controller: _markdownSelection,
      child: Actions(
        actions: {CopySelectionTextIntent: _copyAction},
        child: OverlayPortal(
          controller: _quickToolbar,
          overlayChildBuilder: (overlayContext) {
            final snapshot = _quickSnapshot, anchor = _quickAnchor;
            if (snapshot == null || anchor == null) {
              return const SizedBox.shrink();
            }
            final overlay =
                Overlay.of(overlayContext).context.findRenderObject()
                    as RenderBox;
            final origin = overlay.localToGlobal(Offset.zero);
            final viewport =
                (_selectionKey.currentState?.globalViewport ??
                        (Offset.zero & MediaQuery.sizeOf(overlayContext)))
                    .shift(-origin);
            return Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: SelectionToolbarPositionDelegate(
                  anchor: anchor.shift(-origin),
                  viewport: viewport,
                ),
                child: TapRegion(
                  onTapOutside: (_) => _hideQuickToolbar(),
                  child: SelectionQuickToolbar(
                    onQuote: () => _quote(snapshot),
                    onTranslate: () => _translate(snapshot, anchor),
                  ),
                ),
              ),
            );
          },
          child: Focus(
            onKeyEvent: _keyEvent,
            canRequestFocus: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _hideQuickToolbar();
                return false;
              },
              child: Listener(
                onPointerDown: (event) {
                  _contextClick = event.buttons == kSecondaryMouseButton;
                  _pointerSelecting = !_contextClick;
                  _keyboardSelecting = false;
                  _hideQuickToolbar();
                },
                onPointerUp: (_) {
                  _pointerSelecting = false;
                  _keyboardSelecting = false;
                  _scheduleQuickToolbar();
                },
                onPointerCancel: (_) {
                  _pointerSelecting = false;
                  _hideQuickToolbar();
                },
                child: SelectionArea(
                  key: _areaKey,
                  focusNode: _regionFocus,
                  onSelectionChanged: (content) {
                    _selectedText = content?.plainText ?? '';
                    if (_selectedText.isEmpty) {
                      _hideQuickToolbar();
                    } else {
                      if (selectionUsesDesktop &&
                          HardwareKeyboard.instance.isShiftPressed) {
                        _keyboardSelecting = true;
                        _hideQuickToolbar();
                      }
                      _scheduleQuickToolbar();
                    }
                  },
                  contextMenuBuilder: _buildMenu,
                  child: SelectionScrollContainer(
                    key: _selectionKey,
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flutter's overridable copy action reaches this ancestor for keyboard copy.
/// Editable inputs retain their own action because their focus is distinct.
class _SelectionCopyAction extends Action<CopySelectionTextIntent> {
  _SelectionCopyAction({required this.intercept, required this.copy});
  final bool Function() intercept, copy;
  @override
  bool isEnabled(CopySelectionTextIntent intent) =>
      intercept() || (callingAction?.isEnabled(intent) ?? false);
  @override
  Object? invoke(CopySelectionTextIntent intent) {
    if (intercept()) {
      copy();
      return null;
    }
    return callingAction?.invoke(intent);
  }
}

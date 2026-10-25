import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  });

  final Widget child;
  final ClipboardWriter? clipboardWriter;

  /// Optional budget for source and plain-text previews without AST projections.
  final int? copyByteLimit;

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
  late final _copyAction = _SelectionCopyAction(
    intercept: () => _regionFocus.hasPrimaryFocus && _hasCopyBudget,
    copy: _copyNativeSelection,
  );
  late MarkstreamSelectionController _markdownSelection;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      unawaited(_loadTranslationAvailability());
    }
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
    _selectionKey.currentState?.selectedText ?? _selectedText,
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
    final anchors = region.contextMenuAnchors;
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

  @override
  void dispose() {
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
        child: SelectionArea(
          focusNode: _regionFocus,
          onSelectionChanged: (content) =>
              _selectedText = content?.plainText ?? '',
          contextMenuBuilder: _buildMenu,
          child: SelectionScrollContainer(
            key: _selectionKey,
            child: widget.child,
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

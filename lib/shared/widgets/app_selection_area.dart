import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:markstream/markstream.dart'
    show
        StableSelectionContainer,
        MarkstreamSelectionController,
        MarkstreamSelectionScope;
import '../../l10n/app_localizations.dart';

/// App-owned selection actions shared by messages and Markdown previews.
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({super.key, required this.child});

  final Widget child;

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  static const _translation = MethodChannel('app.ios_translation');
  bool _translationAvailable = false;
  String _selectedText = '';
  final _ownedMarkdownSelection = MarkstreamSelectionController();
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

  Widget _buildMenu(BuildContext context, SelectableRegionState region) {
    final text = _selectedText;
    final anchors = region.contextMenuAnchors;
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: anchors,
      buttonItems: [
        ...region.contextMenuButtonItems,
        if (_markdownSelection.hasSelection)
          ContextMenuButtonItem(
            label: AppLocalizations.of(context)!.markdownCopyMarkdownAction,
            onPressed: () {
              final markdown = _markdownSelection.selectedMarkdown;
              region.hideToolbar();
              if (markdown.isNotEmpty) {
                unawaited(Clipboard.setData(ClipboardData(text: markdown)));
              }
            },
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _markdownSelection =
        MarkstreamSelectionScope.maybeOf(context) ?? _ownedMarkdownSelection;
    return MarkstreamSelectionScope(
      controller: _markdownSelection,
      child: SelectionArea(
        onSelectionChanged: (content) =>
            _selectedText = content?.plainText ?? '',
        contextMenuBuilder: _buildMenu,
        child: StableSelectionContainer(child: widget.child),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import 'ios_text_selection_toolbar.dart';

/// Platform selection menus whose desktop labels use the application font.
class AppTextSelectionToolbar extends StatelessWidget {
  const AppTextSelectionToolbar({
    super.key,
    required this.anchors,
    required this.buttonItems,
    required this.selectionContext,
    required this.onDismiss,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<ContextMenuButtonItem> buttonItems;
  final BuildContext selectionContext;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = theme.platform;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        context.select<SettingsProvider?, bool>(
          (settings) => settings?.iosNativeSelectionMenuEnabled ?? true,
        )) {
      return IosTextSelectionToolbar(
        anchors: anchors,
        buttonItems: buttonItems,
        selectionContext: selectionContext,
        onDismiss: onDismiss,
      );
    }
    if (platform != TargetPlatform.macOS &&
        platform != TargetPlatform.windows &&
        platform != TargetPlatform.linux) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: anchors,
        buttonItems: buttonItems,
      );
    }

    // Flutter's desktop labels set inherit: false, bypassing the app font.
    // Keep their sizing while explicitly carrying over the theme's fonts.
    final appStyle = theme.textTheme.bodyMedium;
    final style = TextStyle(
      inherit: false,
      fontFamily: appStyle?.fontFamily,
      fontFamilyFallback: appStyle?.fontFamilyFallback,
      fontSize: 14,
      letterSpacing: -0.15,
      fontWeight: FontWeight.w400,
    );
    return AdaptiveTextSelectionToolbar(
      anchors: anchors,
      children: [
        for (final item in buttonItems)
          if (platform == TargetPlatform.macOS)
            _MacSelectionButton(item: item, style: style)
          else
            DesktopTextSelectionToolbarButton(
              onPressed: item.onPressed,
              child: Text(
                AdaptiveTextSelectionToolbar.getButtonLabel(context, item),
                overflow: TextOverflow.ellipsis,
                style: style.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
            ),
      ],
    );
  }
}

class _MacSelectionButton extends StatefulWidget {
  const _MacSelectionButton({required this.item, required this.style});

  final ContextMenuButtonItem item;
  final TextStyle style;

  @override
  State<_MacSelectionButton> createState() => _MacSelectionButtonState();
}

class _MacSelectionButtonState extends State<_MacSelectionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CupertinoDesktopTextSelectionToolbarButton(
        onPressed: widget.item.onPressed,
        child: Text(
          AdaptiveTextSelectionToolbar.getButtonLabel(context, widget.item),
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(
            color: _hovered
                ? CupertinoTheme.of(context).primaryContrastingColor
                : CupertinoDynamicColor.resolve(
                    const CupertinoDynamicColor.withBrightness(
                      color: CupertinoColors.black,
                      darkColor: CupertinoColors.white,
                    ),
                    context,
                  ),
          ),
        ),
      ),
    );
  }
}

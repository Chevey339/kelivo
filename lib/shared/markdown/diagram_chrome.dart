import 'package:flutter/material.dart';
import 'package:markstream/markstream.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

/// Shared presentation only; diagram state and rendering stay with each owner.
class DiagramChrome extends StatelessWidget {
  const DiagramChrome({
    super.key,
    required this.theme,
    required this.imageSelected,
    required this.onImage,
    required this.onCode,
    required this.actions,
  });
  final MarkstreamTheme theme;
  final bool imageSelected;
  final VoidCallback onImage, onCode;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final chrome = theme.chrome;
    final labels = AppLocalizations.of(context)!;
    return SelectionContainer.disabled(
      child: Container(
        key: const ValueKey('markdown-diagram-header'),
        height: chrome.height,
        padding: chrome.padding,
        decoration: BoxDecoration(
          color: chrome.background,
          border: Border(
            bottom: BorderSide(
              color: chrome.divider,
              width: MarkstreamTheme.stroke,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                primary: false,
                child: Container(
                  height: 26,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colors.fillInline,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DiagramTab(
                        theme: theme,
                        label: labels.mermaidImageTab,
                        selected: imageSelected,
                        onTap: onImage,
                      ),
                      _DiagramTab(
                        theme: theme,
                        label: labels.mermaidCodeTab,
                        selected: !imageSelected,
                        onTap: onCode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _DiagramTab extends StatelessWidget {
  const _DiagramTab({
    required this.theme,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final MarkstreamTheme theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ]
            : null,
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          splashFactory: NoSplash.splashFactory,
          backgroundColor: selected ? theme.colors.surface : Colors.transparent,
          foregroundColor: selected ? theme.colors.ink : theme.colors.ink2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          textStyle: theme.chrome.label,
        ),
        child: Text(label, maxLines: 1),
      ),
    ),
  );
}

class DiagramAction extends StatelessWidget {
  const DiagramAction({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });
  final MarkstreamTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => IosIconButton(
    icon: icon,
    onTap: onTap,
    enabled: enabled && onTap != null,
    tooltip: label,
    semanticLabel: label,
    color: theme.chrome.actionColor,
    size: theme.chrome.actionIconSize,
    minSize: theme.chrome.actionSize,
    borderRadius: theme.chrome.actionRadius,
    padding: const EdgeInsets.all(6.5),
  );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'genui_clipboard.dart';
import 'genui_source_selection.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'genui_control_region.dart';
import 'genui_theme.dart';

/// Line decorations are host diagnostics, never model-specified presentation.
/// A bounded viewport avoids mounting every line of an invalid oversized block.
class GenUiDiagnosticSource extends StatelessWidget {
  const GenUiDiagnosticSource({
    super.key,
    required this.source,
    required this.errorLines,
    this.exporting = false,
  });
  final String source;
  final Set<int> errorLines;
  final bool exporting;
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final code = theme.markdown.code;
    final lines = source.split('\n');
    final l10n = AppLocalizations.of(context)!;
    Widget line(int index) => Container(
      key: ValueKey('genui-source-line-${index + 1}'),
      padding: EdgeInsetsDirectional.only(start: theme.xs, end: theme.xs),
      decoration: BoxDecoration(
        color: errorLines.contains(index + 1) ? theme.errorWash : null,
        border: Border(
          left: BorderSide(
            color: errorLines.contains(index + 1)
                ? theme.error
                : theme.transparent,
            width: 2,
          ),
        ),
      ),
      child: Semantics(
        label: errorLines.contains(index + 1)
            ? l10n.genuiErrorLine(index + 1)
            : null,
        child: Text(
          lines[index].isEmpty ? ' ' : lines[index],
          style: code.text,
        ),
      ),
    );
    return GenUiSourceSelection(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: code.backgroundColor,
            borderRadius: BorderRadius.circular(code.radius),
            border: Border.all(color: code.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: code.headerBackgroundColor,
                padding: code.headerPadding,
                child: Row(
                  children: [
                    Expanded(child: Text('kelivo-ui', style: code.label)),
                    if (!exporting)
                      GenUiControlRegion(
                        child: IosIconButton(
                          icon: LucideIcons.copy,
                          size: 16,
                          minSize: 44,
                          tooltip: l10n.genuiCopySource,
                          color: theme.captionInk,
                          onTap: () => copyGenUiText(context, source),
                        ),
                      ),
                  ],
                ),
              ),
              if (exporting)
                for (var i = 0; i < lines.length; i++) line(i)
              else
                SizedBox(
                  height: math.min(
                    320,
                    math.max(
                      64,
                      lines.length *
                          MediaQuery.textScalerOf(
                            context,
                          ).scale(code.text.fontSize ?? 13) *
                          (code.text.height ?? 1.5),
                    ),
                  ),
                  child: ListView.builder(
                    primary: false,
                    padding: EdgeInsets.symmetric(vertical: theme.xs),
                    itemCount: lines.length,
                    itemBuilder: (_, index) => line(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

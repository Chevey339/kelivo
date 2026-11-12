import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/markdown/markdown_with_code_highlight.dart';
import '../../../shared/widgets/app_selection_area.dart';

/// Renders translation results while keeping the original text for copying.
class TranslationOutput extends StatelessWidget {
  const TranslationOutput({
    super.key,
    required this.text,
    required this.streaming,
    required this.padding,
    required this.style,
  });

  final ValueListenable<String> text;
  final bool streaming;
  final EdgeInsetsGeometry padding;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ValueListenableBuilder<String>(
      valueListenable: text,
      builder: (context, source, _) {
        if (source.isEmpty) {
          return Padding(
            padding: padding,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(
                AppLocalizations.of(context)!.translatePageOutputHint,
                style: style.copyWith(color: Theme.of(context).hintColor),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          primary: false,
          padding: padding,
          child: SizedBox(
            width: double.infinity,
            child: AppSelectionArea(
              child: MarkdownWithCodeHighlight(
                text: source,
                streaming: streaming,
                baseStyle: style,
              ),
            ),
          ),
        );
      },
    ),
  );
}

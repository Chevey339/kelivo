import 'package:flutter/widgets.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import '../../models/ui_context_attachment.dart';
import '../genui_context_chip.dart';
import '../genui_draft_dialog.dart';
import '../genui_layout.dart';
import '../genui_theme.dart';

final genUiContextGalleryText = UiContextText(
  title: 'Line parameters',
  body: 'Slope a: 3.1\nUse intercept: Yes\nIntercept b: 1\ny at x=5: 16.5',
);
final genUiContextGalleryReplacement = UiContextText(
  title: 'Budget calculator',
  body: 'Monthly budget: 2500 USD\nSavings: 500 USD',
);
final genUiContextGalleryDraft = ComposerDraftInput(
  text: 'Keep my original question.\n\nExplain the current line parameters.',
  uiContext: UiContextAttachment.history(genUiContextGalleryText),
);

/// Visual development fixtures only; production staging uses the guarded host.
class GenUiContextGallery extends StatelessWidget {
  const GenUiContextGallery({super.key});
  @override
  Widget build(BuildContext context) => GenUiColumn(
    children: [
      Text('Frozen context', style: GenUiTheme.of(context).title),
      GenUiContextChip(content: genUiContextGalleryText, onRemove: () {}),
      GenUiContextChip(
        content: genUiContextGalleryText,
        stale: true,
        onRemove: () {},
      ),
      GenUiContextChip(content: genUiContextGalleryText, readOnly: true),
      Wrap(
        children: [
          IosTextButton(
            label: 'Preview replacement',
            onPressed: () => confirmGenUiReplacement(
              context,
              current: UiContextAttachment.history(genUiContextGalleryText),
              replacement: UiContextAttachment.history(
                genUiContextGalleryReplacement,
              ),
            ),
          ),
          IosTextButton(
            label: 'Preview merge',
            onPressed: () =>
                confirmGenUiMerge(context, genUiContextGalleryDraft),
          ),
        ],
      ),
    ],
  );
}

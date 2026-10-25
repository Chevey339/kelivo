import 'package:flutter/material.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import '../models/ui_context_attachment.dart';
import 'genui_context_chip.dart';
import 'genui_theme.dart';

Future<bool> confirmGenUiReplacement(
  BuildContext context, {
  required UiContextAttachment current,
  required UiContextAttachment replacement,
}) async =>
    await showAppDialog<bool>(
      context,
      maxWidth: 720,
      child: GenUiDraftDialog(current: current, replacement: replacement),
    ) ==
    true;

Future<bool> confirmGenUiMerge(
  BuildContext context,
  ComposerDraftInput merged,
) async =>
    await showAppDialog<bool>(
      context,
      maxWidth: 720,
      child: GenUiDraftDialog(merged: merged),
    ) ==
    true;

/// The same centered preview is used on mobile and desktop. The composer is
/// changed only after the host rechecks its captured owner and exact draft.
class GenUiDraftDialog extends StatelessWidget {
  const GenUiDraftDialog({
    super.key,
    this.current,
    this.replacement,
    this.merged,
  }) : assert((merged != null) != (current != null && replacement != null));
  final UiContextAttachment? current, replacement;
  final ComposerDraftInput? merged;

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    child: Builder(
      builder: (context) {
        final theme = GenUiTheme.of(context),
            l10n = AppLocalizations.of(context)!;
        Widget labelled(String label, UiContextAttachment value) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: theme.caption),
            SizedBox(height: theme.xs),
            GenUiContextChip(content: value.text, readOnly: true),
          ],
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDialogHeader(
              title: merged == null
                  ? l10n.genuiReplaceTitle
                  : l10n.genuiMergeTitle,
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(theme.md),
                  child: merged == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(l10n.genuiReplaceBody, style: theme.body),
                            SizedBox(height: theme.sm),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final previews = [
                                  labelled(l10n.genuiReplaceCurrent, current!),
                                  labelled(l10n.genuiReplaceNew, replacement!),
                                ];
                                return constraints.maxWidth >= 540 &&
                                        MediaQuery.textScalerOf(
                                              context,
                                            ).scale(1) <
                                            1.3
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: previews[0]),
                                          SizedBox(width: theme.sm),
                                          Expanded(child: previews[1]),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          previews[0],
                                          SizedBox(height: theme.sm),
                                          previews[1],
                                        ],
                                      );
                              },
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (merged!.uiContext case final attachment?) ...[
                              GenUiContextChip(
                                content: attachment.text,
                                readOnly: true,
                              ),
                              SizedBox(height: theme.sm),
                            ],
                            SelectableText(merged!.text, style: theme.body),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(theme.sm),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: theme.xs,
                children: [
                  IosTextButton(
                    label: l10n.homePageCancel,
                    color: theme.secondaryInk,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  Stack(
                    children: [
                      Positioned.fill(
                        top: theme.xxs,
                        bottom: theme.xxs,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.primary,
                            borderRadius: BorderRadius.circular(
                              theme.controlRadius,
                            ),
                          ),
                        ),
                      ),
                      IosTextButton(
                        label: merged == null
                            ? l10n.genuiReplaceConfirm
                            : l10n.genuiMergeConfirm,
                        color: theme.onPrimary,
                        padding: EdgeInsets.symmetric(horizontal: theme.md),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

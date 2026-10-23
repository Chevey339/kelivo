import 'package:flutter/material.dart';
import '../genui_content.dart';
import '../genui_layout.dart';
import '../genui_theme.dart';

/// Shared by the isolated preview, native gallery and pixel golden fixtures.
/// These are authored examples, not model output or application data.
class GenUiContentGallery extends StatelessWidget {
  const GenUiContentGallery({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(theme.cardRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.md),
        child: const GenUiColumn(
          children: [
            GenUiText(text: 'Explore the result', variant: 'title'),
            GenUiText(
              text:
                  'Local calculations update immediately. Select text to copy any explanation.',
            ),
            GenUiText(
              text: 'Values below are synthetic examples.',
              variant: 'caption',
            ),
            GenUiText(text: 'v = a × x + b', variant: 'mono'),
            GenUiRow(
              children: [
                GenUiMetric(
                  label: 'Estimated distance',
                  value: 42.5,
                  unit: 'km',
                  digits: 1,
                  trend: 2.5,
                ),
                GenUiMetric(
                  label: 'Unavailable result',
                  value: null,
                  unit: 'km',
                ),
              ],
            ),
            GenUiSection(
              title: 'Local model',
              subtitle: 'Adjustments never send a message automatically.',
              tone: 'primary',
              children: [
                GenUiFormula(tex: r'y = ax + b'),
                GenUiMarkdown(
                  text:
                      '**Independent controls.** Explore the _same state_ in each view.\n\n- Values stay on this device.\n- Code remains selectable.\n\n`a = 3.1`',
                ),
              ],
            ),
            GenUiDivider(label: 'Status'),
            GenUiRow(
              distribution: 'fit',
              gap: 'small',
              children: [
                GenUiBadge(text: 'Neutral'),
                GenUiBadge(text: 'Primary', tone: 'primary'),
                GenUiBadge(text: 'Success', tone: 'success'),
                GenUiBadge(text: 'Warning', tone: 'warning'),
                GenUiBadge(text: 'Error', tone: 'error'),
              ],
            ),
            GenUiCallout(
              title: 'Information',
              text: 'These values help compare scenarios.',
              tone: 'info',
            ),
            GenUiCallout(
              title: 'Tip',
              text: 'Keep the original units when comparing results.',
              tone: 'tip',
            ),
            GenUiCallout(
              title: 'Warning',
              text: 'The selected range contains a missing value.',
              tone: 'warning',
            ),
            GenUiCallout(
              title: 'Calculation error',
              text: 'Check the divisor before calculating.',
              tone: 'error',
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/translate/widgets/translation_output.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';
import '../../support/markdown_render_helpers.dart';

const _mixedContent = r'''# Translation

**Bold** text, `inline code` and [a link](https://example.com).

> Quoted text

- First item
- Second item

```dart
final value = 42;
```

| Symbol | Value |
| --- | --- |
| $y$ | 2 |

Inline math $x^2$.

$$
\frac{a}{b}
$$
''';

Widget _host({
  required SettingsProvider settings,
  required ValueNotifier<String> text,
  bool streaming = false,
}) => ChangeNotifierProvider.value(
  value: settings,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: TranslationOutput(
        text: text,
        streaming: streaming,
        padding: const EdgeInsets.all(14),
        style: const TextStyle(fontSize: 15, height: 1.4),
      ),
    ),
  ),
);

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} output supports mixed Markdown, '
      'selection and math preferences',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.windows
            : TargetPlatform.android;
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(desktop ? 1000 : 390, 1100);
          addTearDown(tester.view.reset);
          final settings = SettingsProvider(createBusinessTestPreferences());
          addTearDown(settings.dispose);
          await settings.loaded;
          final text = ValueNotifier(_mixedContent);
          addTearDown(text.dispose);
          await tester.pumpWidget(_host(settings: settings, text: text));
          await tester.pumpAndSettle();

          expect(find.byType(MarkstreamCodeBlock), findsOneWidget);
          expect(find.byType(MarkstreamTableBlock), findsOneWidget);
          expect(find.byType(Math), findsNWidgets(3));
          expect(
            markdownParagraph(tester, 'Translation').text.toPlainText(),
            'Translation',
          );
          expect(markdownParagraph(tester, 'Quoted text'), isNotNull);
          expect(markdownParagraph(tester, 'First item'), isNotNull);

          final region = tester.state<SelectableRegionState>(
            find.byType(SelectableRegion),
          );
          region.selectAll(SelectionChangedCause.keyboard);
          await tester.pumpAndSettle();
          final selection = MarkstreamSelectionScope.maybeOf(
            tester.element(find.byType(MarkstreamView)),
          )!;
          expect(selection.selectedPlainText, contains('Bold text'));
          expect(selection.selectedMarkdown, contains('**Bold**'));
          expect(selection.selectedMarkdown, contains(r'$x^2$'));
          expect(text.value, _mixedContent);

          await settings.setEnableDollarLatex(false);
          await tester.pumpAndSettle();
          expect(find.byType(Math), findsOneWidget);
          expect(markdownParagraph(tester, r'$x^2$'), isNotNull);
          await settings.setEnableMathRendering(false);
          await tester.pumpAndSettle();
          expect(find.byType(Math), findsNothing);
          expect(text.value, _mixedContent);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} output scrolls long text and wide tables '
      'without moving the reading position on streamed updates',
      (tester) async {
        debugDefaultTargetPlatformOverride = desktop
            ? TargetPlatform.windows
            : TargetPlatform.android;
        try {
          tester.view.devicePixelRatio = 1;
          // The desktop result occupies one pane of a two-column page.
          tester.view.physicalSize = Size(desktop ? 500 : 390, 650);
          addTearDown(tester.view.reset);
          final settings = SettingsProvider(createBusinessTestPreferences());
          addTearDown(settings.dispose);
          await settings.loaded;
          final header = List.filled(8, 'Wide column').join(' | ');
          final delimiter = List.filled(8, '---').join(' | ');
          final row = List.filled(8, 'Cell content').join(' | ');
          final text = ValueNotifier(
            '| $header |\n| $delimiter |\n| $row |\n\n'
            '${List.generate(80, (i) => 'Paragraph $i with **translated** text.').join('\n\n')}',
          );
          addTearDown(text.dispose);
          await tester.pumpWidget(
            _host(settings: settings, text: text, streaming: true),
          );
          await tester.pumpAndSettle();

          final scrollables = tester.stateList<ScrollableState>(
            find.byType(Scrollable),
          );
          expect(
            scrollables.any(
              (s) =>
                  s.position.axis == Axis.horizontal &&
                  s.position.maxScrollExtent > 0,
            ),
            isTrue,
          );
          final vertical = scrollables.firstWhere(
            (s) => s.position.axis == Axis.vertical,
          );
          expect(vertical.position.maxScrollExtent, greaterThan(650));
          vertical.position.jumpTo(500);
          await tester.pumpAndSettle();
          final offset = vertical.position.pixels;
          text.value += '\n\nAnother streamed paragraph.';
          await tester.pumpAndSettle();
          expect(vertical.position.pixels, offset);
          vertical.position.jumpTo(vertical.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            markdownParagraph(tester, 'Another streamed paragraph.'),
            isNotNull,
          );
          expect(tester.takeException(), isNull);

          text.value = '';
          await tester.pumpAndSettle();
          expect(find.byType(MarkstreamView), findsNothing);
          expect(find.text('Translated result appears here…'), findsOneWidget);
          text.value = '# Next translation';
          await tester.pumpAndSettle();
          expect(
            tester
                .state<ScrollableState>(find.byType(Scrollable))
                .position
                .pixels,
            0,
          );
          expect(markdownParagraph(tester, 'Next translation'), isNotNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}

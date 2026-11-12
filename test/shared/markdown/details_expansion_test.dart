import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/markdown/markdown_with_code_highlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  testWidgets(
    'app-owned details choices survive separate text-block remounts',
    (tester) async {
      final firstKey = Object();
      final secondKey = Object();
      const source = '<details><summary>Same summary</summary>Body</details>';
      Widget host({bool visible = true, String firstSource = source}) =>
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: visible
                    ? Column(
                        children: [
                          MarkdownWithCodeHighlight(
                            text: firstSource,
                            detailsStateKey: firstKey,
                          ),
                          MarkdownWithCodeHighlight(
                            text: source,
                            detailsStateKey: secondKey,
                          ),
                        ],
                      )
                    : const SizedBox(),
              ),
            ),
          );

      Finder body(int index) => find.descendant(
        of: find.byType(MarkstreamDetailsBlock).at(index),
        matching: find.byKey(const ValueKey('markstream-details-body')),
      );

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Same summary').first);
      await tester.pumpAndSettle();
      expect(body(0), findsOneWidget);
      expect(body(1), findsNothing);

      await tester.pumpWidget(host(visible: false));
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(body(0), findsOneWidget);
      expect(body(1), findsNothing);

      await tester.pumpWidget(host(visible: false));
      await tester.pumpWidget(
        host(firstSource: source.replaceFirst('Body', 'Edit')),
      );
      await tester.pumpAndSettle();
      expect(body(0), findsNothing);
      expect(body(1), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

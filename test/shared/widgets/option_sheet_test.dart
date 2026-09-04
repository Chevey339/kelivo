import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/option_sheet.dart';

import '../../support/business_test_harness.dart';

void main() {
  testWidgets('selected check mark and returns value', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    String? result;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () async {
                    result = await showOptionSheet<String>(
                      context,
                      title: 'Workspace',
                      selected: 'a',
                      items: const [
                        OptionSheetItem(
                          value: 'a',
                          icon: Lucide.Folder,
                          label: 'Alpha',
                        ),
                        OptionSheetItem(
                          value: 'b',
                          icon: Lucide.Folder,
                          label: 'Beta',
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byIcon(Lucide.Check), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();

    expect(result, 'b');
    expect(find.text('Beta'), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/update_required_screen.dart';

Widget wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'explains how to stay on an older version without touching data',
    (tester) async {
      useTallSurface(tester);
      var toolOpens = 0;
      await tester.pumpWidget(
        wrap(
          UpdateRequiredScreen(
            diagnosticCode: 'database_schema_too_new',
            openConversionTool: () async => toolOpens++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Kelivo to continue'), findsOneWidget);
      expect(find.text('If you need an older version'), findsOneWidget);
      expect(
        find.textContaining('export a backup from Settings'),
        findsOneWidget,
      );
      expect(
        find.textContaining(UpdateRequiredScreen.conversionToolUrl),
        findsWidgets,
      );
      expect(
        find.textContaining('install the older version and import'),
        findsOneWidget,
      );
      expect(find.text('Open conversion tool'), findsOneWidget);
      expect(
        find.textContaining('Diagnostic code: database_schema_too_new'),
        findsOneWidget,
      );

      await tester.tap(find.text('Open conversion tool'));
      await tester.pump();
      expect(toolOpens, 1);
    },
  );
}

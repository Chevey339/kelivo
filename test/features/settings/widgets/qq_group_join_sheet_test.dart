import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/l10n/app_localizations.dart';
import 'package:Cuplivo/shared/widgets/custom_bottom_sheet.dart';
import 'package:Cuplivo/shared/widgets/ios_tactile.dart';
import 'package:Cuplivo/shared/widgets/qq_group_join_sheet.dart';

Widget _opener() {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showQQGroupJoinSheet(context: context),
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'qq group picker uses bottom sheet on mobile and lists both groups',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_opener());
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byKey(CustomBottomSheet.panelKey), findsOneWidget);
        expect(find.byType(Dialog), findsNothing);
        // Title (sheet header) + both group rows.
        expect(find.text('Join our QQ Group'), findsOneWidget);
        expect(find.text('Kelivo Group 1'), findsOneWidget);
        expect(find.text('Kelivo Group 2'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('qq group picker uses dialog on desktop and can be closed', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_opener());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byKey(CustomBottomSheet.panelKey), findsNothing);
      expect(find.text('Kelivo Group 1'), findsOneWidget);
      expect(find.text('Kelivo Group 2'), findsOneWidget);

      // Close via the X button.
      await tester.tap(find.byType(IosIconButton));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

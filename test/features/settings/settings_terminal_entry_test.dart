import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/pages/settings_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

Future<void> _pumpSettingsPage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS settings shows terminal entry below network proxy', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await _pumpSettingsPage(tester);
    debugDefaultTargetPlatformOverride = null;

    final proxyFinder = find.text('Network Proxy');
    final terminalFinder = find.text('Terminal');

    expect(proxyFinder, findsOneWidget);
    expect(terminalFinder, findsOneWidget);
    expect(
      tester.getTopLeft(terminalFinder).dy,
      greaterThan(tester.getTopLeft(proxyFinder).dy),
    );
  });

  testWidgets('Android settings does not show iOS terminal entry', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await _pumpSettingsPage(tester);
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Terminal'), findsNothing);
  });
}

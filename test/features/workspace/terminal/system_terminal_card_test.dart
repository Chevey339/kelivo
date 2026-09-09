import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/workspace/terminal/widgets/system_terminal_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/theme/theme_factory.dart';

void main() {
  testWidgets('open button is disabled when onOpen is null', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SystemTerminalCard(hostDir: '/tmp/workspace'),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<IosTileButton>(
      find.descendant(
        of: find.byKey(SystemTerminalCard.openKey),
        matching: find.byType(IosTileButton),
      ),
    );
    expect(button.enabled, isFalse);
  });
}

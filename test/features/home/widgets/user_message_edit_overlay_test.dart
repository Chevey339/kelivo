import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/user_message_edit_overlay.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness({
    required bool visible,
    String previewText = 'original prompt',
    double bottomInset = 88,
    VoidCallback? onCancel,
    VoidCallback? onSaveOnly,
    VoidCallback? onPreviewTap,
  }) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              UserMessageEditOverlay(
                visible: visible,
                previewText: previewText,
                topInset: 56,
                bottomInset: bottomInset,
                onCancel: onCancel ?? () {},
                onSaveOnly: onSaveOnly ?? () {},
                onPreviewTap: onPreviewTap ?? () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('visible overlay exposes save-only and preview actions', (
    tester,
  ) async {
    var saved = 0;
    var previewTapped = 0;

    await tester.pumpWidget(
      buildHarness(
        visible: true,
        onSaveOnly: () => saved++,
        onPreviewTap: () => previewTapped++,
      ),
    );

    await tester.tap(find.text('original prompt'));
    await tester.pump();
    expect(previewTapped, 1);

    await tester.tap(find.text('Save Only'), warnIfMissed: false);
    await tester.pump();
    expect(saved, 1);
  });

  testWidgets('hidden overlay ignores pointer actions', (tester) async {
    var saved = 0;
    var cancelled = 0;

    await tester.pumpWidget(
      buildHarness(
        visible: false,
        onCancel: () => cancelled++,
        onSaveOnly: () => saved++,
      ),
    );

    await tester.tap(find.text('Save Only'), warnIfMissed: false);
    await tester.tapAt(const Offset(20, 120));
    await tester.pump();

    expect(saved, 0);
    expect(cancelled, 0);
  });

  testWidgets('background tap cancels edit mode', (tester) async {
    var cancelled = 0;

    await tester.pumpWidget(
      buildHarness(visible: true, onCancel: () => cancelled++),
    );

    await tester.tapAt(const Offset(20, 120));
    await tester.pump();

    expect(cancelled, 1);
  });

  testWidgets('save-only action sits to the left of close action', (
    tester,
  ) async {
    await tester.pumpWidget(buildHarness(visible: true));

    final saveLeft = tester.getTopLeft(find.text('Save Only')).dx;
    final closeLeft = tester.getTopLeft(find.byIcon(Lucide.X)).dx;

    expect(saveLeft, lessThan(closeLeft));
  });

  testWidgets('overlay background fills the area behind the input', (
    tester,
  ) async {
    var cancelled = 0;

    await tester.pumpWidget(
      buildHarness(visible: true, onCancel: () => cancelled++),
    );

    await tester.tapAt(const Offset(20, 560));
    await tester.pump();

    expect(cancelled, 1);
  });

  testWidgets('long preview fits when expanded input leaves little height', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildHarness(
        visible: true,
        bottomInset: 394,
        previewText: List.filled(24, 'long original prompt').join(' '),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Save Only'), findsOneWidget);
  });
}

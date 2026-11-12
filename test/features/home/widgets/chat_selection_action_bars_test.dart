import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_selection_action_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';

Future<void> _pumpBar(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(createBusinessTestPreferences()),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the same selection offers sharing and deletion', (tester) async {
    var shares = 0;
    var deletes = 0;
    await _pumpBar(
      tester,
      ChatSelectionActionBar(
        hasSelection: true,
        hasMultiVersionSelection: false,
        onShare: () => shares++,
        onDeleteCurrentVersions: () => deletes++,
        onDeleteAllVersions: () => fail('single version selection'),
      ),
    );
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('TXT'), findsNothing);
    await tester.tap(find.text('Share'));
    await tester.tap(find.text('Delete'));
    expect(shares, 1);
    expect(deletes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty selection disables both actions', (tester) async {
    await _pumpBar(
      tester,
      ChatSelectionActionBar(
        hasSelection: false,
        hasMultiVersionSelection: false,
        onShare: () => fail('no selection'),
        onDeleteCurrentVersions: () => fail('no selection'),
        onDeleteAllVersions: () => fail('no selection'),
      ),
    );
    expect(
      tester
          .widgetList<IosCardPress>(find.byType(IosCardPress))
          .every((button) => button.onTap == null),
      isTrue,
    );
    await tester.tap(find.text('Share'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'version chooser can cancel or select either deletion scope',
    (tester) async {
      var currentDeletes = 0;
      var allDeletes = 0;
      await _pumpBar(
        tester,
        ChatSelectionActionBar(
          hasSelection: true,
          hasMultiVersionSelection: true,
          onShare: () {},
          onDeleteCurrentVersions: () => currentDeletes++,
          onDeleteAllVersions: () => allDeletes++,
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete This Version'), findsOneWidget);
      expect(find.text('Delete All Versions'), findsOneWidget);
      expect(
        find.byType(BottomSheet),
        defaultTargetPlatform == TargetPlatform.android
            ? findsOneWidget
            : findsNothing,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(currentDeletes, 0);
      expect(allDeletes, 0);
      expect(find.text('Delete This Version'), findsNothing);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete This Version'));
      await tester.pumpAndSettle();
      expect(currentDeletes, 1);
      expect(allDeletes, 0);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete All Versions'));
      await tester.pumpAndSettle();
      expect(currentDeletes, 1);
      expect(allDeletes, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.macOS,
    }),
  );

  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets('actions fit $size with large Chinese text', (tester) async {
      await _pumpBar(
        tester,
        ChatSelectionActionBar(
          hasSelection: true,
          hasMultiVersionSelection: true,
          onShare: () {},
          onDeleteCurrentVersions: () {},
          onDeleteAllVersions: () {},
        ),
        size: size,
        locale: const Locale('zh'),
        textScale: 2,
      );
      expect(find.text('分享'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

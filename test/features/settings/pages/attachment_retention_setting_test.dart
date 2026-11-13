import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/attachment_retention.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/widgets/attachment_retention_setting.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';

import '../../../support/storage_images_test_fixture.dart';

void main() {
  for (final desktop in [false, true]) {
    testWidgets(
      'retention accepts zero, persists days and rejects invalid values desktop=$desktop',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('haptic_feedback'),
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            const MethodChannel('haptic_feedback'),
            null,
          ),
        );
        tester.view.physicalSize = Size(desktop ? 1100 : 400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
        late SettingsProvider settings;
        await tester.runAsync(() async {
          settings = SettingsProvider(fixture.preferences);
          await settings.loaded;
        });
        addTearDown(() async {
          settings.dispose();
          await fixture.dispose();
        });
        var refreshes = 0;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: AttachmentRetentionSetting(
                  onChanged: () async {
                    refreshes++;
                  },
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('7 天'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('attachment-retention-setting')),
        );
        await tester.pumpAndSettle();
        final field = find.byType(TextField);
        await tester.enterText(field, '3651');
        await tester.pump();
        expect(
          tester
              .widget<IosTileButton>(find.widgetWithText(IosTileButton, '保存'))
              .enabled,
          isFalse,
        );
        await tester.enterText(field, '0');
        await tester.pump();
        if (!desktop) {
          tester.view.physicalSize = const Size(400, 400);
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.widgetWithText(IosTileButton, '保存'));
        }
        await tester.tap(find.widgetWithText(IosTileButton, '保存'));
        for (var i = 0; i < 100 && refreshes == 0; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(settings.attachmentRetentionDays, 0);
        expect(
          fixture.preferences.getInt(AttachmentRetention.preferenceKey),
          0,
        );
        expect(find.text('删除最后一个引用后立即回收'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
      ),
    );
  }
}

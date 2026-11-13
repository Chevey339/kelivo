import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/attachment_retention.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/settings/widgets/attachment_cleanup_button.dart';
import 'package:Kelivo/features/settings/pages/storage_space_page.dart';
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
                appBar: AppBar(
                  actions: [
                    AttachmentCleanupButton(
                      onChanged: () async {
                        refreshes++;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(find.byTooltip('自动清理附件'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('attachment-cleanup-settings')),
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
        expect(
          tester
              .widget<IosTileButton>(find.widgetWithText(IosTileButton, '保存'))
              .enabled,
          isFalse,
        );
        if (!desktop) {
          tester.view.physicalSize = const Size(400, 400);
          tester.view.viewInsets = const FakeViewPadding(bottom: 180);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('立即清理'));
        }
        await tester.tap(find.text('立即清理'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(
          tester
              .widget<IosTileButton>(find.widgetWithText(IosTileButton, '保存'))
              .enabled,
          isTrue,
        );
        await tester.ensureVisible(find.widgetWithText(IosTileButton, '保存'));
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
        tester.view.physicalSize = Size(desktop ? 1100 : 400, 900);
        tester.view.viewInsets = const FakeViewPadding();
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('attachment-cleanup-settings')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        await tester.tap(find.text('延后清理'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '7',
        );
        await tester.enterText(find.byType(TextField), '14');
        await tester.pump();
        await tester.tap(find.widgetWithText(IosTileButton, '保存'));
        for (var i = 0; i < 100 && refreshes < 2; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(refreshes, 2);
        expect(settings.attachmentRetentionDays, 14);
        expect(
          fixture.preferences.getInt(AttachmentRetention.preferenceKey),
          14,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.iOS,
      ),
    );
    testWidgets(
      'cleanup settings live in the storage toolbar desktop=$desktop',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(desktop ? 1100 : 400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
        addTearDown(fixture.dispose);
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(fixture.preferences),
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: StorageSpacePage(embedded: desktop),
            ),
          ),
        );
        final button = find.byKey(
          const ValueKey('attachment-cleanup-settings'),
        );
        for (var i = 0; i < 200 && find.text('文件').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(button, findsOneWidget);
        expect(
          tester.getCenter(button).dx,
          greaterThan((desktop ? 1100 : 400) * .65),
        );
        expect(tester.getCenter(button).dy, lessThan(120));
        await tester.tap(find.text('文件').first);
        for (var i = 0; i < 200 && find.text('共 0 项').evaluate().isEmpty; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pumpAndSettle();
        expect(button, desktop ? findsOneWidget : findsNothing);
        expect(find.text('清理未使用'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
    );
  }
}

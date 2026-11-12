import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_store.dart';
import 'package:Kelivo/features/browser/pages/browser_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

// Run using flutter drive and --keep-app-running. Data is entirely temporary.
// The second case uses the pre-iOS26 inset-layout path with the same real WK
// renderer; it is geometry coverage, not execution on an actual iOS18 runtime.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native thumbnails omit status-bar strip in both viewport layouts',
    (tester) async {
      final results = <Map<String, Object?>>[];
      for (final underlap in [true, false]) {
        debugDefaultTargetPlatformOverride = underlap
            ? TargetPlatform.iOS
            : TargetPlatform.android;
        final directory = await Directory.systemTemp.createTemp(
          'browser-thumbnail-',
        );
        final database = AppDatabase(NativeDatabase.memory());
        final preferences = BusinessPreferences(BusinessRepository(database));
        await preferences.load();
        final settings = SettingsProvider(preferences);
        await settings.loaded;
        final service = BrowserService(
          store: BrowserStore(directory: directory),
        );
        await service.initialize();
        final tab = await service.createTab(ownerSessionId: 'thumbnail-probe');
        try {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: settings,
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BrowserPage(
                  service: service,
                  conversationId: 'thumbnail-probe',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await service.loadHtml(
            '''<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;background:#e8c04a}body{min-height:1800px}header{height:48px;background:#123456}h1{margin:0;padding:24px}</style>
<header></header><h1>Content begins at the blue stripe</h1>''',
            tabId: tab.id,
          );
          await service.waitForLoad(tabId: tab.id);
          final slot = find.byKey(const ValueKey('browserMobileViewportSlot'));
          final media = MediaQuery.of(tester.element(slot));
          final clock = Stopwatch()..start();
          while (!service.isTabPresented(tab.id) ||
              (tester.getTopLeft(slot).dy -
                          (underlap ? 0 : media.viewPadding.top))
                      .abs() >
                  .5) {
            if (clock.elapsed > const Duration(seconds: 8)) {
              fail('viewport did not settle');
            }
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          await service.refreshActivePreview();
          final bytes = service.previewForTab(tab.id);
          expect(bytes, isNotNull);
          final codec = await ui.instantiateImageCodec(bytes!);
          final frame = await codec.getNextFrame();
          codec.dispose();
          final image = frame.image;
          try {
            expect(
              image.width,
              440,
              reason: 'thumbnail limit is physical pixels, not Retina points',
            );
            final rgba = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            final index = ((image.width ~/ 2) + image.width * 2) * 4;
            final rgb = [for (var c = 0; c < 3; c++) rgba.getUint8(index + c)];
            for (var c = 0; c < 3; c++) {
              expect(
                rgb[c],
                closeTo([0x12, 0x34, 0x56][c], 12),
                reason:
                    'top pixel must be website, not status padding ($underlap)',
              );
            }
            final logicalHeight = media.size.height - media.viewPadding.top;
            expect(
              image.height / image.width,
              closeTo(logicalHeight / media.size.width, .005),
            );
            results.add({
              'underlap': underlap,
              'width': image.width,
              'height': image.height,
              'screenScale': media.devicePixelRatio,
              'decodedBytes': image.width * image.height * 4,
              'viewportTop': tester.getTopLeft(slot).dy,
              'safeTop': media.viewPadding.top,
              'topRGB': rgb,
            });
            debugPrint('THUMBNAIL_GEOMETRY ${results.last}');
          } finally {
            image.dispose();
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await service.flush();
          service.dispose();
          settings.dispose();
          await database.close();
          await directory.delete(recursive: true);
          debugDefaultTargetPlatformOverride = null;
        }
      }
      binding.reportData = {'thumbnailGeometry': results};
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

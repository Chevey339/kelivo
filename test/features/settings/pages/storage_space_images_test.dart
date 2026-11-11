import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_icon_cache.dart';
import 'package:Kelivo/features/settings/pages/storage_space_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/storage_images_test_fixture.dart';

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 500 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(ready(), isTrue);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('active MCP icons are visibly protected in the file list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
    addTearDown(fixture.dispose);
    await tester.runAsync(() async {
      final source = await fixture.file(
        'incoming',
        img.encodePng(img.Image(width: 2, height: 2)),
      );
      final name = await McpIconCache.importFile(source.path);
      await fixture.preferences.setString(
        'mcp_presentation_v1',
        jsonEncode({
          'servers': {
            'server': {
              'icon': {'type': 'file', 'value': name},
            },
          },
        }),
      );
    });
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(fixture.preferences),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const StorageSpacePage(),
        ),
      ),
    );
    await _until(tester, () => find.text('文件').evaluate().isNotEmpty);
    await tester.tap(find.text('文件').last);
    await _until(tester, () => find.text('使用中').evaluate().isNotEmpty);
    expect(find.byType(IosCheckbox), findsNothing);
    expect(
      tester
          .widget<IosTileButton>(find.widgetWithText(IosTileButton, '全选'))
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final desktop in [false, true]) {
    testWidgets(
      'image filters, counts and protected selection, desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = Size(desktop ? 1200 : 400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
        addTearDown(fixture.dispose);
        final bytes = img.encodePng(img.Image(width: 2, height: 2));
        late File active;
        late File unused;
        await tester.runAsync(() async {
          await fixture.file('upload/chat.png', bytes);
          await fixture.file('images/mcp_img_preview.png', bytes);
          active = await fixture.file('avatars/active.png', bytes);
          unused = await fixture.file('avatars/unused.png', bytes);
          await fixture.assistants([
            {'id': 'a', 'name': 'A', 'avatar': active.path},
          ]);
        });
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(fixture.preferences),
            child: MaterialApp(
              locale: const Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (_, child) => AppSnackBarOverlay(child: child!),
              home: const StorageSpacePage(),
            ),
          ),
        );
        await _until(tester, () => find.text('图片').evaluate().isNotEmpty);
        expect(find.text('助手'), findsNothing);
        if (!desktop) {
          await tester.tap(find.text('图片').last);
        }
        await _until(tester, () => find.text('共 4 项').evaluate().isNotEmpty);
        await tester.pumpAndSettle();
        expect(find.text('使用中'), findsOneWidget);
        expect(find.text('用户上传'), findsNothing);
        expect(find.text('助手发出'), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('storage-visible-bytes')))
              .data,
          '${bytes.length * 4} B',
        );
        await tester.tap(find.text('全选'));
        await tester.pumpAndSettle();
        expect(find.text('已选 3 项'), findsOneWidget);

        Future<void> filter(String label) async {
          await tester.ensureVisible(find.text(label));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }

        await filter('工具图片');
        expect(find.text('共 1 项'), findsOneWidget);
        expect(find.text('全选'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('storage-visible-bytes')))
              .data,
          '${bytes.length} B',
        );
        await filter('头像与背景');
        expect(find.text('共 2 项'), findsOneWidget);
        final activeTile = find.byKey(ValueKey('storage-image-${active.path}'));
        expect(
          find.descendant(of: activeTile, matching: find.byType(IosCheckbox)),
          findsNothing,
        );
        await tester.longPress(activeTile);
        await tester.pumpAndSettle();
        expect(find.text('共 2 项'), findsOneWidget);
        await tester.tap(find.text('全选'));
        await tester.pumpAndSettle();
        expect(find.text('已选 1 项'), findsOneWidget);
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        expect(find.textContaining('正在使用的头像与背景会保留'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, '删除'));
        await _until(
          tester,
          () => find.text('已删除 1 个项目').evaluate().isNotEmpty,
        );
        await _until(tester, () => find.text('共 1 项').evaluate().isNotEmpty);
        AppSnackBarManager().dismissAll();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(active.existsSync(), isTrue);
        expect(unused.existsSync(), isFalse);
        expect(
          tester
              .widget<IosTileButton>(find.widgetWithText(IosTileButton, '全选'))
              .enabled,
          isFalse,
        );
        await filter('聊天图片');
        expect(find.text('共 1 项'), findsOneWidget);
        await tester.tap(find.text('全选'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, '删除'));
        await _until(tester, () => find.text('共 0 项').evaluate().isNotEmpty);
        expect(find.text('工具图片'), findsOneWidget);
        expect(find.text('头像与背景'), findsOneWidget);
        AppSnackBarManager().dismissAll();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/utils/icon_cache.dart';
import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
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

Widget _storagePage(StorageImagesFixture fixture, {ChatService? chat}) =>
    MultiProvider(
      providers: [
        Provider<BusinessRepository>.value(
          value: BusinessRepository(fixture.database),
        ),
        if (chat != null)
          ChangeNotifierProvider<ChatService>.value(value: chat),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(fixture.preferences),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (_, child) => AppSnackBarOverlay(child: child!),
        home: const StorageSpacePage(),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final desktop in [false, true]) {
    testWidgets(
      'file metadata is browsable while the database is busy, desktop=$desktop',
      (tester) async {
        tester.view.physicalSize = Size(desktop ? 1200 : 400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
        addTearDown(fixture.dispose);
        final photo = (await tester.runAsync(() async {
          await fixture.file('upload/manual.pdf');
          return fixture.file(
            'images/photo.png',
            img.encodePng(img.Image(width: 2, height: 2)),
          );
        }))!;
        var scans = 0;
        final owner = Object();
        AttachmentFileLock.registerTransientOwner(
          owner,
          capture: () {
            scans++;
            return null;
          },
          active: () => false,
        );
        addTearDown(() => AttachmentFileLock.unregisterTransientOwner(owner));
        await tester.pumpWidget(_storagePage(fixture));
        await _until(tester, () => find.text('文件').evaluate().isNotEmpty);
        final release = Completer<void>();
        late Future<void> transaction;
        await tester.runAsync(() async {
          final entered = Completer<void>();
          transaction = fixture.database.transaction(() async {
            await fixture.database.customSelect('SELECT 1').get();
            entered.complete();
            await release.future;
          });
          await entered.future;
        });
        try {
          await tester.tap(find.text('文件').last);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.text('manual.pdf'), findsOneWidget);
          expect(find.text('正在检查附件使用情况…'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(find.byType(IosCheckbox), findsNothing);
          expect(
            tester
                .widget<IosTileButton>(
                  find.widgetWithText(IosTileButton, '清理未使用'),
                )
                .enabled,
            isFalse,
          );
          await tester.longPress(find.text('manual.pdf'));
          expect(find.text('已选 1 项'), findsNothing);
        } finally {
          release.complete();
          await tester.runAsync(() => transaction);
        }
        await _until(tester, () => find.text('未使用').evaluate().isNotEmpty);
        expect(find.text('manual.pdf'), findsOneWidget);
        expect(find.byType(IosCheckbox), findsOneWidget);
        final firstCheck = scans;
        expect(firstCheck, greaterThan(0));
        if (!desktop) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('图片').last);
        await tester.pumpAndSettle();
        await _until(
          tester,
          () =>
              find
                  .byKey(ValueKey('storage-image-${photo.path}'))
                  .evaluate()
                  .isNotEmpty &&
              find.text('未使用').evaluate().isNotEmpty,
        );
        expect(scans, firstCheck);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        desktop ? TargetPlatform.macOS : TargetPlatform.android,
      ),
    );
  }
  testWidgets(
    'visible usage updates after raw settings and external WAL writes',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
      addTearDown(fixture.dispose);
      final file = (await tester.runAsync(
        () => fixture.file('upload/icon.dat'),
      ))!;
      await tester.pumpWidget(_storagePage(fixture));
      await _until(tester, () => find.text('文件').evaluate().isNotEmpty);
      await tester.tap(find.text('文件').last);
      await _until(tester, () => find.text('未使用').evaluate().isNotEmpty);
      await tester.longPress(find.text('icon.dat'));
      await tester.pump();
      expect(find.text('已选 1 项'), findsOneWidget);

      final write = fixture.preferences.setString('avatar_value', file.path);
      await _until(
        tester,
        () => find.text('正在检查附件使用情况…').evaluate().isNotEmpty,
      );
      expect(await write, isTrue);
      expect(find.text('已选 1 项'), findsNothing);
      expect(find.byType(IosCheckbox), findsNothing);
      await _until(tester, () => find.text('使用中').evaluate().isNotEmpty);
      expect(find.byType(IosCheckbox), findsNothing);

      await tester.runAsync(() async {
        final other = sqlite3.open('${fixture.root.path}/kelivo.db');
        try {
          other.execute('DELETE FROM preference_rows WHERE key = ?', [
            'avatar_value',
          ]);
        } finally {
          other.close();
        }
      });
      await _until(tester, () => find.text('未使用').evaluate().isNotEmpty);
      expect(find.text('已选 1 项'), findsNothing);
      expect(find.byType(IosCheckbox), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('an empty open category picks up new temporary attachments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
    addTearDown(fixture.dispose);
    final chat = ChatService(
      existingRepository: ChatDatabaseRepository(fixture.database),
    );
    await tester.runAsync(() async {
      await chat.init();
      await chat.runAssetReferenceMaintenance();
      await chat.runAssetMaintenance();
    });
    addTearDown(chat.close);
    await tester.pumpWidget(_storagePage(fixture, chat: chat));
    await _until(tester, () => find.text('文件').evaluate().isNotEmpty);
    await tester.tap(find.text('文件').last);
    await _until(tester, () => find.text('暂无内容').evaluate().isNotEmpty);

    await tester.runAsync(() async {
      final business = BusinessRepository(fixture.database);
      final before = await business.readStorageChangeVersion();
      final conversation = await chat.createDraftConversation(
        temporary: true,
        title: 'Temporary',
      );
      final file = await fixture.file('upload/new.txt');
      await chat.addMessage(
        conversationId: conversation.id,
        role: 'user',
        parts: [FilePart(uri: file.path, name: 'new.txt')],
      );
      expect(await business.readStorageChangeVersion(), before);
    });
    await _until(
      tester,
      () => find.textContaining('Temporary').evaluate().isNotEmpty,
    );
    expect(find.text('new.txt'), findsOneWidget);
    expect(find.byType(IosCheckbox), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'storage details can copy a load failure and recover on refresh',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? copied;
      var clipboardBusy = true;
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          if (clipboardBusy) throw PlatformException(code: 'clipboard_busy');
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
      addTearDown(fixture.dispose);
      const part = FilePart(
        uri: 'kelivo-file:///upload/manual.pdf',
        name: 'manual.pdf',
      );
      Future<void> setPayload(String payload) =>
          fixture.database.customStatement(
            "UPDATE message_part_rows SET payload = ? WHERE kind = 'file'",
            [payload],
          );
      await tester.runAsync(() async {
        await fixture.file('upload/manual.pdf');
        await fixture.message([part]);
        await setPayload('private message content');
      });
      await tester.pumpWidget(_storagePage(fixture));
      await _until(tester, () => find.text('文件').evaluate().isNotEmpty);
      await tester.tap(find.text('文件').last);
      await _until(tester, () => find.text('复制错误详情').evaluate().isNotEmpty);
      await tester.pumpAndSettle();
      expect(find.textContaining('FormatException'), findsOneWidget);
      expect(find.text('manual.pdf'), findsOneWidget);
      expect(find.byType(IosCheckbox), findsNothing);
      expect(find.text('清理未使用'), findsNothing);
      await tester.tap(find.text('复制错误详情'));
      await tester.pumpAndSettle();
      expect(find.text('无法复制错误详情，请重试。'), findsOneWidget);
      expect(copied, isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      clipboardBusy = false;
      await tester.tap(find.text('复制错误详情'));
      await tester.pump();
      expect(copied, contains('FormatException'));
      expect(copied, contains('storage_attachment_usage.dart'));
      expect(copied, isNot(contains('private message content')));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.runAsync(() => setPayload(part.encodePayload()));
      await tester.tap(find.bySemanticsLabel('刷新').hitTestable());
      await _until(tester, () => find.text('使用中').evaluate().isNotEmpty);
      expect(find.text('复制错误详情'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

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
      final name = await IconCache.importFile(source.path);
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
    final platform = TargetPlatformVariant.only(
      desktop ? TargetPlatform.macOS : TargetPlatform.android,
    );
    testWidgets(
      'image thumbnails preserve aspect ratio and crop centrally, desktop=$desktop',
      (tester) async {
        tester.view.devicePixelRatio = 4;
        tester.view.physicalSize =
            Size(desktop ? 1200 : 400, 900) * tester.view.devicePixelRatio;
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(StorageImagesFixture.create))!;
        addTearDown(fixture.dispose);
        final expectedSizes = <File, (int, int)>{};
        await tester.runAsync(() async {
          for (final (width, height, expectedSize) in const [
            (256, 768, (256, 768)),
            (768, 256, (768, 256)),
            (256, 5120, (204, 4096)), // Limited by the longest decode edge.
            (384, 3072, (362, 2896)), // Limited by the decoded pixel count.
          ]) {
            final file = await fixture.file(
              'upload/${width}x$height.png',
              img.encodePng(img.Image(width: width, height: height)),
            );
            expectedSizes[file] = expectedSize;
          }
        });
        await tester.pumpWidget(_storagePage(fixture));
        await _until(tester, () => find.text('图片').evaluate().isNotEmpty);
        if (!desktop) await tester.tap(find.text('图片').last);

        for (final sample in expectedSizes.entries) {
          final tile = find.byKey(ValueKey('storage-image-${sample.key.path}'));
          final pixels = find.descendant(
            of: tile,
            matching: find.byType(RawImage),
          );
          await _until(
            tester,
            () =>
                pixels.evaluate().isNotEmpty &&
                tester.widget<RawImage>(pixels).image != null,
          );
          final thumbnail = tester.widget<RawImage>(pixels);
          final decoded = thumbnail.image!;
          expect((decoded.width, decoded.height), sample.value);
          expect(thumbnail.fit, BoxFit.cover);
          expect(thumbnail.alignment, Alignment.center);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: platform,
    );

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
        await tester.pumpWidget(_storagePage(fixture));
        await _until(tester, () => find.text('图片').evaluate().isNotEmpty);
        expect(find.text('助手'), findsNothing);
        if (!desktop) {
          await tester.tap(find.text('图片').last);
        }
        await _until(tester, () => find.text('使用中').evaluate().isNotEmpty);
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
        expect(find.textContaining('仍在使用的文件会保留'), findsOneWidget);
        await tester.tap(find.widgetWithText(IosTileButton, '删除').last);
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
        await tester.tap(find.widgetWithText(IosTileButton, '删除').last);
        await _until(tester, () => find.text('共 0 项').evaluate().isNotEmpty);
        expect(find.text('工具图片'), findsOneWidget);
        expect(find.text('头像与背景'), findsOneWidget);
        AppSnackBarManager().dismissAll();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.physicalSize = Size(desktop ? 1200 : 400, 320);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
      variant: platform,
    );
  }
}

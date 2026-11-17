import 'dart:async';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/backup_page_harness.dart';
import '../../support/business_test_harness.dart';

Future<void> _openSettingsPage(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _expectAbove(WidgetTester tester, String upper, String lower) {
  final upperTop = tester.getTopLeft(find.text(upper).first).dy;
  final lowerTop = tester.getTopLeft(find.text(lower).first).dy;

  expect(upperTop, lessThan(lowerTop));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scope editor stays open until both settings are committed', (
    tester,
  ) async {
    final business = await createBusinessTestHarness();
    final settings = SettingsProvider(business.preferences);
    await settings.loaded;
    await pumpBackupSettingsPage(
      tester,
      settings: settings,
      business: business,
    );
    await tester.tap(find.byKey(const ValueKey('backup-scope-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backup-scope-chats')));

    final gate = Completer<void>();
    unawaited(business.preferences.runExclusiveMutation(() => gate.future));
    try {
      final save = find.byKey(const ValueKey('backup-scope-save'));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(tester.widget<IosTextButton>(save).onPressed, isNull);
      await tester.flingFrom(
        tester.getCenter(save),
        const Offset(0, 500),
        1800,
      );
      await tester.pumpAndSettle();
      expect(save, findsOneWidget);
      expect(
        settings.webDavConfig.scope.includes(BackupCategory.chats),
        isTrue,
      );
    } finally {
      gate.complete();
    }
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(settings.webDavConfig.scope.includes(BackupCategory.chats), isFalse);
    expect(settings.s3Config.scope.includes(BackupCategory.chats), isFalse);
  });

  testWidgets(
    'desktop reopens during an edit and restores a rejected field independently',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const savedUrl = 'https://original.example';
      final business = await createBusinessTestHarness(
        initial: {
          'webdav_config_v1': const WebDavConfig(
            url: savedUrl,
            password: 'private-fixture',
          ).toJsonString(),
        },
      );
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;
      Future<void> open() => pumpBackupSettingsPage(
        tester,
        settings: settings,
        business: business,
        desktop: true,
      );
      Finder field(String hint) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == hint,
      );
      final url = field('https://dav.example.com/remote.php/webdav/');
      final username = field('Username');
      await open();
      final gate = Completer<void>();
      unawaited(business.preferences.runExclusiveMutation(() => gate.future));
      const newUrl = 'https://updated.example';
      try {
        await tester.enterText(url, newUrl);
        expect(settings.savingWebDavConfig, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await open();
        expect(tester.widget<TextField>(url).controller!.text, savedUrl);
      } finally {
        gate.complete();
      }
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(url).controller!.text, newUrl);
      await business.database.customStatement('''
      CREATE TRIGGER reject_url BEFORE INSERT ON preference_rows
      WHEN NEW.key = 'webdav_config_v1' AND NEW.value LIKE '%rejected.example%'
      BEGIN SELECT RAISE(ABORT, 'private-fixture'); END
    ''');
      await tester.enterText(url, 'https://rejected.example');
      await tester.enterText(username, 'updated-user');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(url).controller!.text, newUrl);
      expect(
        tester.widget<TextField>(username).controller!.text,
        'updated-user',
      );
      expect(settings.webDavConfig.url, newUrl);
      expect(settings.webDavConfig.username, 'updated-user');
      expect(settings.savingWebDavConfig, isFalse);
      expect(
        find.text('Could not save the backup settings. Please try again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  for (final desktop in [false, true]) {
    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} keeps encryption enabled after leaving and reopening the page',
      (tester) async {
        await tester.binding.setSurfaceSize(
          desktop ? const Size(1100, 800) : const Size(390, 844),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final business = await createBusinessTestHarness();
        final settings = SettingsProvider(business.preferences);
        addTearDown(settings.dispose);
        await settings.loaded;
        Future<void> openPage() => pumpBackupSettingsPage(
          tester,
          settings: settings,
          business: business,
          desktop: desktop,
        );
        await openPage();
        final control = find.byKey(const ValueKey('backup-encryption-switch'));
        await tester.ensureVisible(control);
        await tester.tap(control);
        await tester.pumpAndSettle();
        for (final key in ['backup-password', 'backup-password-confirmation']) {
          await tester.enterText(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(TextField),
            ),
            'session password',
          );
        }
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        // Argon2 runs outside the widget tester's fake clock.
        final deadline = DateTime.now().add(const Duration(seconds: 12));
        while (!settings.backupEncryptionEnabled &&
            DateTime.now().isBefore(deadline)) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(settings.backupEncryptionEnabled, isTrue);
        expect(tester.widget<IosSwitch>(control).value, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await openPage();
        await tester.ensureVisible(control);
        expect(tester.widget<IosSwitch>(control).value, isTrue);
        expect(
          await settings.resolveBackupEncryptionPassword(() async {
            fail('Reopening the page must reuse the session password.');
          }),
          'session password',
        );
        expect(
          business.preferences.getBool('backup_encryption_enabled_v1'),
          isTrue,
        );
      },
    );

    testWidgets(
      '${desktop ? 'desktop' : 'mobile'} preserves saved servers when changing backup scope after a cold start',
      (tester) async {
        await tester.binding.setSurfaceSize(
          desktop ? const Size(1100, 800) : const Size(390, 844),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const dav = WebDavConfig(
          url: 'https://dav.example.com',
          username: 'test-user',
          password: 'test-password',
          path: 'dav-folder',
        );
        const s3 = S3Config(
          endpoint: 'https://s3.example.com',
          bucket: 'test-bucket',
          accessKeyId: 'test-id',
          secretAccessKey: 'test-secret',
          sessionToken: 'test-token',
          prefix: 's3-folder',
          pathStyle: false,
        );
        final business = await createBusinessTestHarness(
          initial: {
            'webdav_config_v1': dav.toJsonString(),
            's3_config_v1': s3.toJsonString(),
          },
        );
        final settings = SettingsProvider(business.preferences);
        // The home screen creates backup providers in the first build.
        expect(settings.webDavConfig.toJson(), dav.toJson());
        expect(settings.s3Config.toJson(), s3.toJson());
        await pumpBackupSettingsPage(
          tester,
          settings: settings,
          business: business,
          desktop: desktop,
        );
        expect(find.text('Back Up Now').hitTestable(), findsOneWidget);
        expect(find.text('Import Backup File').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('backup-scope-providers')),
          findsNothing,
        );
        final picker = find.byKey(const ValueKey('backup-scope-picker'));
        expect(find.text('15/15'), findsOneWidget);
        expect(tester.getSize(picker).height, lessThanOrEqualTo(48));
        expect(
          tester.getCenter(find.text('15/15')).dy,
          tester.getCenter(find.text('Backup and import content')).dy,
        );
        await tester.tap(picker);
        await tester.pumpAndSettle();
        expect(
          find.byType(BottomSheet),
          desktop ? findsNothing : findsOneWidget,
        );
        expect(find.byType(Dialog), desktop ? findsOneWidget : findsNothing);
        for (final category in BackupCategory.values) {
          expect(
            tester
                .widget<IosSwitch>(
                  find.byKey(ValueKey('backup-scope-${category.name}')),
                )
                .value,
            isTrue,
          );
        }
        for (final category in [
          BackupCategory.providers,
          BackupCategory.files,
          BackupCategory.environmentVariables,
        ]) {
          final control = find.byKey(ValueKey('backup-scope-${category.name}'));
          await tester.ensureVisible(control);
          await tester.pumpAndSettle();
          await tester.tap(control);
          await tester.pumpAndSettle();
          expect(settings.webDavConfig.scope.includes(category), isTrue);
        }
        // Saving stays reachable even after scrolling to the final category.
        await tester.ensureVisible(
          find.byKey(const ValueKey('backup-scope-settings')),
        );
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('backup-scope-save'));
        expect(save.hitTestable(), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('12/15'), findsOneWidget);
        for (final category in [
          BackupCategory.providers,
          BackupCategory.files,
          BackupCategory.environmentVariables,
        ]) {
          expect(settings.webDavConfig.scope.includes(category), isFalse);
          expect(settings.s3Config.scope.includes(category), isFalse);
        }
        await tester.tap(find.byKey(const ValueKey('backup-scope-picker')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IosSwitch>(
                find.byKey(const ValueKey('backup-scope-providers')),
              )
              .value,
          isFalse,
        );
        await tester.tap(find.text('Deselect all'));
        await tester.pumpAndSettle();
        for (final category in BackupCategory.values) {
          expect(
            tester
                .widget<IosSwitch>(
                  find.byKey(ValueKey('backup-scope-${category.name}')),
                )
                .value,
            isFalse,
          );
        }
        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        for (final category in BackupCategory.values) {
          expect(
            tester
                .widget<IosSwitch>(
                  find.byKey(ValueKey('backup-scope-${category.name}')),
                )
                .value,
            isTrue,
          );
        }
        await tester.tap(find.byKey(const ValueKey('backup-scope-cancel')));
        await tester.pumpAndSettle();
        expect(find.text('12/15'), findsOneWidget);
        expect(
          settings.webDavConfig.scope.includes(BackupCategory.skills),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        final reloaded = SettingsProvider(business.preferences);
        await reloaded.loaded;
        expect(
          reloaded.webDavConfig.toJson(),
          dav.copyWith(scope: settings.webDavConfig.scope).toJson(),
        );
        expect(
          reloaded.s3Config.toJson(),
          s3.copyWith(scope: settings.webDavConfig.scope).toJson(),
        );
        expect(
          reloaded.webDavConfig.scope.excluded,
          settings.webDavConfig.scope.excluded,
        );
        expect(
          reloaded.s3Config.scope.excluded,
          settings.webDavConfig.scope.excluded,
        );
      },
    );
  }

  group('BackupPage mobile backup settings navigation', () {
    testWidgets('opens WebDAV settings as a full page and saves config', (
      tester,
    ) async {
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;

      await pumpBackupSettingsPage(
        tester,
        settings: settings,
        business: business,
      );

      await _openSettingsPage(tester, 'WebDAV Server Settings');

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.widgetWithText(AppBar, 'WebDAV Server Settings'), findsOne);
      expect(find.text('WebDAV Server URL'), findsOneWidget);
      expect(find.text('User-Agent'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), ' https://dav.example.com/root ');
      await tester.enterText(fields.at(4), ' KelivoTest/1.0 ');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(AppBar, 'WebDAV Server Settings'),
        findsNothing,
      );
      expect(settings.webDavConfig.url, 'https://dav.example.com/root');
      expect(settings.webDavConfig.userAgent, 'KelivoTest/1.0');
    });

    testWidgets('shows local backup before WebDAV and S3 backup sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;

      await pumpBackupSettingsPage(
        tester,
        settings: settings,
        business: business,
      );

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Local Backup'), findsOneWidget);
      expect(find.text('WebDAV Backup'), findsOneWidget);
      expect(find.text('S3 Backup'), findsOneWidget);
      _expectAbove(tester, 'Local Backup', 'Backup Reminder');
      _expectAbove(tester, 'Local Backup', 'WebDAV Backup');
      _expectAbove(tester, 'WebDAV Backup', 'S3 Backup');
    });

    testWidgets('opens S3 settings as a full page and saves config', (
      tester,
    ) async {
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;

      await pumpBackupSettingsPage(
        tester,
        settings: settings,
        business: business,
      );

      await _openSettingsPage(tester, 'S3 Settings');

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.widgetWithText(AppBar, 'S3 Settings'), findsOne);
      expect(find.text('Endpoint'), findsOneWidget);
      expect(find.text('User-Agent'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), ' https://s3.example.com ');
      await tester.enterText(fields.at(7), ' KelivoS3/1.0 ');
      final gate = Completer<void>();
      unawaited(business.preferences.runExclusiveMutation(() => gate.future));
      try {
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AppBar, 'S3 Settings'), findsOne);
        expect(tester.testTextInput.hasAnyClients, isFalse);
      } finally {
        gate.complete();
      }
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'S3 Settings'), findsNothing);
      expect(settings.s3Config.endpoint, 'https://s3.example.com');
      expect(settings.s3Config.userAgent, 'KelivoS3/1.0');
    });

    testWidgets('desktop shows local backup before WebDAV and S3 sections', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1100, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      await settings.loaded;

      await pumpBackupSettingsPage(
        tester,
        desktop: true,
        settings: settings,
        business: business,
      );

      expect(find.text('Backup Reminder'), findsOneWidget);
      expect(find.text('Local Backup'), findsOneWidget);
      expect(find.text('WebDAV Server Settings'), findsOneWidget);
      expect(find.text('S3 Settings'), findsOneWidget);
      _expectAbove(tester, 'Local Backup', 'Backup Reminder');
      _expectAbove(tester, 'Local Backup', 'WebDAV Server Settings');
      _expectAbove(tester, 'WebDAV Server Settings', 'S3 Settings');
    });
  });
}

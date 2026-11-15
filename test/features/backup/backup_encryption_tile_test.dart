import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_encryption.dart';
import 'package:Kelivo/features/backup/backup_task_runner.dart';
import 'package:Kelivo/features/backup/widgets/backup_encryption_tile.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/ios_checkbox.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';

import '../../support/business_test_harness.dart';
import '../../support/backup_password_store.dart';

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  // The password verifier runs Argon2 in a separate isolate.
  final deadline = DateTime.now().add(const Duration(seconds: 12));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  expect(ready(), true);
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.macOS,
    TargetPlatform.windows,
  ]) {
    testWidgets(
      '$platform: after restart, export requires a password and cancellation stops it',
      (tester) async {
        await tester.binding.setSurfaceSize(
          platform == TargetPlatform.iOS
              ? const Size(390, 844)
              : const Size(1100, 800),
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final business = await createBusinessTestHarness(
          initial: {'backup_encryption_enabled_v1': true},
        );
        final settings = SettingsProvider(business.preferences);
        addTearDown(settings.dispose);
        await settings.loaded;
        var exports = 0;
        String? exportedPassword;
        bool? success;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              theme: ThemeData(platform: platform),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      success = await runBackupTask(
                        context,
                        title: 'Export',
                        task: (handle) async {
                          exportedPassword = await backupPasswordForExport(
                            context,
                          );
                          exports++;
                        },
                      );
                    },
                    child: const Text('Export'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Export'));
        // The progress dialog below the password prompt keeps animating.
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(TextField), findsNWidgets(2));
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(success, isFalse);
        expect(exports, 0);
        expect(settings.backupEncryptionEnabled, isTrue);

        await tester.tap(find.text('Export'));
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.enterText(find.byType(TextField).first, 'after restart');
        await tester.enterText(find.byType(TextField).last, 'after restart');
        await tester.pump();
        await tester.tap(find.text('Save'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(exportedPassword, 'after restart');
        expect(exports, 1);
        expect(success, isTrue);
        // Let the earlier cancellation snackbar expire.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '$platform: encryption requires matching passwords and clears when disabled',
      (tester) async {
        final business = await createBusinessTestHarness();
        final vault = TestBackupPasswordStore();
        final settings = SettingsProvider(
          business.preferences,
          backupPasswordStore: vault,
        );
        await settings.loaded;
        addTearDown(settings.dispose);
        final encryption = find.byKey(
          const ValueKey('backup-encryption-switch'),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              theme: ThemeData(platform: platform),
              home: const Scaffold(body: BackupEncryptionTile()),
            ),
          ),
        );
        await tester.tap(encryption);
        await tester.pumpAndSettle();
        final actions = find.byKey(const ValueKey('backup-password-actions'));
        expect(
          find.byType(FormSheet),
          platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
        );
        if (platform != TargetPlatform.iOS) {
          expect(find.byType(BottomSheet), findsNothing);
        }
        expect(tester.widget<FormSheetActions>(actions).onConfirm, isNull);
        final eye = find.byKey(const ValueKey('backup-password-visibility'));
        expect(
          tester.getCenter(eye).dx,
          greaterThan(tester.getRect(find.byType(TextField).first).right - 40),
        );
        await tester.enterText(find.byType(TextField).first, '  secret  ');
        await tester.enterText(find.byType(TextField).last, 'secret');
        await tester.pump();
        expect(find.text('Passwords do not match.'), findsOneWidget);
        expect(tester.widget<FormSheetActions>(actions).onConfirm, isNull);
        await tester.enterText(find.byType(TextField).last, '  secret  ');
        await tester.pump();
        await tester.tap(
          find.byKey(const ValueKey('backup-password-visibility')),
        );
        await tester.pump();
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .every((field) => !field.obscureText),
          isTrue,
        );
        final checkbox = find.byKey(const ValueKey('backup-password-remember'));
        expect(tester.widget<IosCheckbox>(checkbox).value, false);
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pump();
        await tester.tap(find.text('Save'));
        await _waitFor(tester, () => settings.backupPasswordRemembered);
        await tester.pumpAndSettle();
        expect(vault.value, '  secret  ');
        expect(settings.autoBackupEnabled, false);
        expect(tester.widget<IosSwitch>(encryption).value, isTrue);
        final rememberSwitch = find.byKey(
          const ValueKey('backup-remember-password-switch'),
        );
        expect(tester.widget<IosSwitch>(rememberSwitch).value, true);
        if (platform == TargetPlatform.macOS) {
          await tester.tap(rememberSwitch);
          await tester.pumpAndSettle();
          expect(settings.backupEncryptionEnabled, true);
          expect(vault.value, isNull);
          await tester.tap(rememberSwitch);
          await tester.pumpAndSettle();
          expect(find.byType(TextField), findsOneWidget);
          await tester.enterText(find.byType(TextField), '  secret  ');
          await tester.pump();
          await tester.tap(find.text('OK'));
          await _waitFor(tester, () => settings.backupPasswordRemembered);
          await tester.pumpAndSettle();
          expect(vault.value, '  secret  ');
          expect(settings.autoBackupEnabled, false);
        }
        await tester.tap(encryption);
        await tester.pumpAndSettle();
        expect(settings.backupEncryptionEnabled, false);
        expect(vault.value, isNull);
      },
    );
  }

  for (final (writable, missingCredential) in [
    (true, false),
    (false, false),
    (true, true),
  ]) {
    testWidgets(
      'manual export can remember a password (writable: $writable, previously saved: $missingCredential)',
      (tester) async {
        const password = 'manual export';
        final verifier = await tester.runAsync(
          () => BackupEncryption.passwordVerifier(password),
        );
        final business = await createBusinessTestHarness(
          initial: {
            'backup_encryption_enabled_v1': true,
            'backup_password_verifier_v1': verifier!,
            if (missingCredential) 'backup_password_remember_manual_v1': true,
          },
        );
        final vault = TestBackupPasswordStore()..available = writable;
        final settings = SettingsProvider(
          business.preferences,
          backupPasswordStore: vault,
        );
        await settings.loaded;
        addTearDown(settings.dispose);
        String? exported;
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: settings,
            child: MaterialApp(
              theme: ThemeData(platform: TargetPlatform.macOS),
              builder: (_, child) => AppSnackBarOverlay(child: child!),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: const Locale('en'),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async =>
                        exported = await backupPasswordForExport(context),
                    child: const Text('Export'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Export'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        final checkbox = find.byKey(const ValueKey('backup-password-remember'));
        expect(tester.widget<IosCheckbox>(checkbox).value, false);
        await tester.enterText(find.byType(TextField), password);
        await tester.tap(checkbox);
        await tester.pump();
        await tester.tap(find.text('OK'));
        await _waitFor(tester, () => exported != null);
        await tester.pumpAndSettle();
        expect(exported, password);
        expect(settings.autoBackupEnabled, false);
        expect(settings.backupPasswordRemembered, writable);
        expect(vault.value, writable ? password : null);
        if (!writable) {
          expect(
            find.text(
              'The password couldn’t be saved on this device. This backup will continue.',
            ),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets(
    'restore retry shows the authentication error and allows cancellation',
    (tester) async {
      String? result = 'pending';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    result = await backupPasswordPrompt(context)(retry: true),
                child: const Text('Restore'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(IosCheckbox), findsNothing);
      expect(
        find.text(
          'The password is incorrect, or the backup is damaged. Try again or cancel.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );

  testWidgets('mobile password dialog fits with keyboard and cancels safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final business = await createBusinessTestHarness();
    final settings = SettingsProvider(business.preferences);
    await settings.loaded;
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          theme: ThemeData.dark().copyWith(platform: TargetPlatform.iOS),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(viewInsets: const EdgeInsets.only(bottom: 300)),
            child: child!,
          ),
          home: const Scaffold(body: BackupEncryptionTile()),
        ),
      ),
    );
    await tester.tap(find.byType(IosSwitch));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(settings.backupPasswordRemembered, false);
    expect(tester.widget<IosSwitch>(find.byType(IosSwitch)).value, isFalse);
  });
}

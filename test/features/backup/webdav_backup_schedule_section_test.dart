import 'dart:convert';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/webdav_backup_schedule_provider.dart';
import 'package:Kelivo/features/backup/widgets/webdav_backup_schedule_section.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/shared/widgets/form_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/business_test_harness.dart';

late SettingsProvider _testSettings;

class _ScheduleStore extends WebDavBackupScheduleStore {
  WebDavBackupScheduleSettings settings = const WebDavBackupScheduleSettings();
  WebDavBackupScheduleState state = const WebDavBackupScheduleState();

  @override
  Future<WebDavBackupScheduleSettings> readSettings() async => settings;

  @override
  Future<void> writeSettings(WebDavBackupScheduleSettings value) async {
    settings = value;
  }

  @override
  Future<WebDavBackupScheduleState> readState() async => state;

  @override
  Future<void> writeState(WebDavBackupScheduleState value) async {
    state = value;
  }
}

Widget _sectionHarness(
  WebDavBackupScheduleProvider provider, {
  SettingsProvider? settings,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider<WebDavBackupScheduleProvider>.value(value: provider),
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings ?? _testSettings,
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (_, child) => AppSnackBarOverlay(child: child!),
    home: const Scaffold(
      body: SingleChildScrollView(child: WebDavBackupScheduleSection()),
    ),
  ),
);

Widget _pickerHarness({
  required bool desktop,
  required ValueChanged<int?> onSelected,
}) => ChangeNotifierProvider<SettingsProvider>.value(
  value: _testSettings,
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onSelected(
              await showWebDavScheduleIntervalPicker(
                context,
                selectedHours: 24,
                desktop: desktop,
              ),
            );
          },
          child: const Text('Choose interval'),
        ),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final business = await createBusinessTestHarness();
    _testSettings = SettingsProvider(business.preferences);
    await _testSettings.loaded;
  });
  tearDown(() => _testSettings.dispose());

  testWidgets('automatic backups require saved server settings', (
    tester,
  ) async {
    final business = await createBusinessTestHarness();
    final provider = WebDavBackupScheduleProvider(
      preferences: business.preferences,
      backup: (_) async {},
      store: _ScheduleStore(),
      syncSchedule: (_) async {},
      autoLoad: false,
    );
    addTearDown(provider.dispose);
    await provider.refresh();
    await tester.pumpWidget(_sectionHarness(provider));

    final toggle = tester.widget<IosSwitch>(
      find.byKey(const ValueKey('webdav-schedule-enabled')),
    );
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(
      find.text(
        'Configure and save your WebDAV server before enabling automatic backup.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'saving server settings immediately makes the schedule available',
    (tester) async {
      final business = await createBusinessTestHarness();
      final settings = SettingsProvider(business.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      final provider = WebDavBackupScheduleProvider(
        preferences: business.preferences,
        backup: (_) async {},
        store: _ScheduleStore(),
        syncSchedule: (_) async {},
        autoLoad: false,
      );
      addTearDown(provider.dispose);
      await provider.refresh();
      await tester.pumpWidget(_sectionHarness(provider, settings: settings));
      expect(
        tester
            .widget<IosSwitch>(
              find.byKey(const ValueKey('webdav-schedule-enabled')),
            )
            .onChanged,
        isNull,
      );

      await settings.setWebDavConfig(
        const WebDavConfig(url: 'https://dav.example.com'),
      );
      await tester.pump();
      expect(
        tester
            .widget<IosSwitch>(
              find.byKey(const ValueKey('webdav-schedule-enabled')),
            )
            .onChanged,
        isNotNull,
      );
    },
  );

  testWidgets('enabling saves the schedule and reveals its repeat interval', (
    tester,
  ) async {
    final business = await createBusinessTestHarness(
      initial: {
        'webdav_config_v1': jsonEncode({'url': 'https://dav.example.com'}),
      },
    );
    final store = _ScheduleStore();
    final provider = WebDavBackupScheduleProvider(
      preferences: business.preferences,
      backup: (_) async {},
      store: store,
      syncSchedule: (_) async {},
      autoLoad: false,
    );
    addTearDown(provider.dispose);
    await provider.refresh();
    await tester.pumpWidget(_sectionHarness(provider));
    expect(find.text('Repeat interval'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('webdav-schedule-enabled')));
    await tester.pumpAndSettle();
    expect(store.settings.enabled, isTrue);
    expect(find.text('Repeat interval'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets(
    'network policy can be changed before running a disabled schedule',
    (tester) async {
      final business = await createBusinessTestHarness(
        initial: {
          'webdav_config_v1': jsonEncode({'url': 'https://dav.example.com'}),
        },
      );
      final store = _ScheduleStore();
      var uploads = 0;
      final provider = WebDavBackupScheduleProvider(
        preferences: business.preferences,
        backup: (_) async => uploads++,
        store: store,
        networkAvailable: (wifiOnly) async => !wifiOnly,
        syncSchedule: (_) async {},
        autoLoad: false,
      );
      addTearDown(provider.dispose);
      await provider.refresh();
      await tester.pumpWidget(_sectionHarness(provider));

      await tester.tap(find.byKey(const ValueKey('webdav-schedule-wifi-only')));
      await tester.pumpAndSettle();
      expect(store.settings.enabled, isFalse);
      expect(store.settings.wifiOnly, isFalse);

      await tester.tap(find.byKey(const ValueKey('webdav-schedule-run-now')));
      await tester.pumpAndSettle();
      expect(uploads, 1);
      expect(provider.state.lastSuccess, isNotNull);
      expect(find.text('Backup uploaded'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('encrypted backups show password confirmation guidance', (
    tester,
  ) async {
    final business = await createBusinessTestHarness(
      initial: {
        'webdav_config_v1': jsonEncode({'url': 'https://dav.example.com'}),
      },
    );
    final store = _ScheduleStore()
      ..state = const WebDavBackupScheduleState(
        lastError: 'backup_password_required',
      );
    final provider = WebDavBackupScheduleProvider(
      preferences: business.preferences,
      backup: (_) async {},
      store: store,
      syncSchedule: (_) async {},
      autoLoad: false,
    );
    addTearDown(provider.dispose);
    await provider.refresh();
    await tester.pumpWidget(_sectionHarness(provider));

    expect(
      find.text(
        'Encrypted backups require password confirmation. Use manual WebDAV '
        'backup, or turn off backup encryption to use scheduled backups.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('backup_password_required'), findsNothing);
  });

  testWidgets('mobile interval selection returns chosen repeat interval', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _pickerHarness(desktop: false, onSelected: (value) => selected = value),
    );

    await tester.tap(find.text('Choose interval'));
    await tester.pumpAndSettle();
    expect(find.byType(FormSheet), findsOneWidget);
    expect(find.text('Every hour'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('webdav-schedule-hours-6')));
    await tester.pumpAndSettle();
    expect(selected, 6);
    expect(find.byType(FormSheet), findsNothing);
  });

  testWidgets('desktop selects intervals in a dialog without a bottom sheet', (
    tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      _pickerHarness(desktop: true, onSelected: (value) => selected = value),
    );

    await tester.tap(find.text('Choose interval'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(const ValueKey('webdav-schedule-hours-24')));
    await tester.pumpAndSettle();
    expect(selected, 24);
  });

  testWidgets('dismissing the interval dialog leaves the schedule unchanged', (
    tester,
  ) async {
    int? selected = 24;
    await tester.pumpWidget(
      _pickerHarness(desktop: true, onSelected: (value) => selected = value),
    );

    await tester.tap(find.text('Choose interval'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  test(
    'known waiting states have useful labels without exposing raw errors',
    () {
      final l10n = AppLocalizationsEn();
      expect(
        webDavScheduleErrorLabel(l10n, 'wifi_required'),
        l10n.webDavScheduleWifiRequired,
      );
      expect(
        webDavScheduleErrorLabel(l10n, 'network_unavailable'),
        l10n.webDavScheduleNetworkUnavailable,
      );
      expect(
        webDavScheduleErrorLabel(l10n, 'backup_busy'),
        l10n.webDavScheduleBackupBusy,
      );
      expect(
        webDavScheduleErrorLabel(l10n, 'backup_password_required'),
        'Encrypted backups require password confirmation. Use manual WebDAV '
        'backup, or turn off backup encryption to use scheduled backups.',
      );
      expect(
        webDavScheduleErrorLabel(l10n, 'HTTP 401 at https://private.example'),
        l10n.webDavScheduleFailed,
      );
    },
  );
}

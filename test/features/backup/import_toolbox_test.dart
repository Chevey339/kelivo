import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/backup_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_encryption.dart';
import 'package:Kelivo/core/services/backup/backup_task_progress.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/import_toolbox.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/backup_page_harness.dart';
import '../../support/business_test_harness.dart';
import '../../support/claude_test_api.dart' show FakePathProviderPlatform;

class _Launcher extends UrlLauncherPlatform {
  final launches = <(String, PreferredLaunchMode)>[];
  bool available = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launches.add((url, options.mode));
    return available;
  }
}

class _Picker extends FilePicker {
  late File file;
  late String name;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async => FilePickerResult([
    PlatformFile(name: name, path: file.path, size: file.lengthSync()),
  ]);
}

class _EmptyChat extends ChatService {
  @override
  bool get initialized => true;
}

class _RecordingBackup extends BackupProvider {
  _RecordingBackup({
    required super.chatService,
    required super.businessPreferences,
    required super.businessRepository,
  });
  final restores = <(String, RestoreMode)>[];

  @override
  Future<void> restoreFromLocalFile(
    File file,
    WebDavConfig cfg, {
    RestoreMode mode = RestoreMode.overwrite,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
    bool allowUnverifiedForwardCompatible = false,
    ForwardCompatibilityPrompt? onForwardCompatibility,
    BackupPasswordPrompt? onPassword,
  }) async => restores.add((file.path, mode));
}

// The file reads and import isolates run outside the widget test clock.
Future<void> _waitFor(WidgetTester tester, String label) async {
  final deadline = Stopwatch()..start();
  while (find.text(label).evaluate().isEmpty &&
      deadline.elapsed < const Duration(seconds: 8)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(find.text(label), findsOneWidget);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Picker picker;
  late _Launcher launcher;
  late BusinessTestHarness business;
  late SettingsProvider settings;
  late _EmptyChat chat;
  late _RecordingBackup backup;

  setUp(() async {
    final temp = Directory.systemTemp.createTempSync('kelivo_toolbox_ui_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(temp.path);
    addTearDown(() => PathProviderPlatform.instance = paths);
    final previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = launcher = _Launcher();
    addTearDown(() => UrlLauncherPlatform.instance = previousLauncher);
    picker = _Picker()..file = File('${temp.path}/picked.zip');
    FilePicker.platform = picker;
    business = await createBusinessTestHarness();
    settings = SettingsProvider(business.preferences);
    await settings.loaded;
    addTearDown(settings.dispose);
    chat = _EmptyChat();
    backup = _RecordingBackup(
      chatService: chat,
      businessPreferences: business.preferences,
      businessRepository: business.repository,
    );
  });

  void select(String name, String entry, Map<String, Object?> json) {
    picker.name = name;
    final archive = Archive()
      ..addFile(ArchiveFile.string(entry, jsonEncode(json)));
    picker.file.writeAsBytesSync(ZipEncoder().encode(archive));
  }

  for (final desktop in [false, true]) {
    final platform = desktop ? 'desktop' : 'mobile';
    final locale = Locale(desktop ? 'zh' : 'en');
    final l10n = lookupAppLocalizations(locale);
    Future<void> openPage(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(
        desktop ? const Size(1100, 800) : const Size(390, 844),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpBackupSettingsPage(
        tester,
        settings: settings,
        business: business,
        desktop: desktop,
        locale: locale,
        chat: chat,
        backup: backup,
      );
    }

    Future<void> tap(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
    }

    testWidgets(
      '$platform opens the toolbox from the entry, version errors and notifications',
      (tester) async {
        await openPage(tester);
        final title = desktop ? '从其他APP导入' : 'Import from Other Apps';
        expect(l10n.backupPageImportFromOtherApps, title);
        final subtitle = l10n.backupPageImportFromOtherAppsSubtitle;
        expect(find.text(subtitle), findsOneWidget);
        for (final source in importToolboxSources) {
          expect(subtitle.toLowerCase().replaceAll(' ', ''), contains(source));
        }
        expect(
          subtitle,
          contains(desktop ? '文件不会上传' : 'the file is not uploaded'),
        );
        expect(
          tester.getTopLeft(find.text(title)).dy,
          greaterThan(
            tester.getTopLeft(find.text(l10n.backupPageImportFromChatbox)).dy,
          ),
        );
        await tap(tester, title);
        final launch = (
          importToolboxUrl,
          PreferredLaunchMode.externalApplication,
        );
        expect(launcher.launches, [launch]);

        launcher.available = false;
        await tap(tester, title);
        final failed = l10n.backupPageImportToolboxOpenFailed(importToolboxUrl);
        expect(find.text(failed), findsOneWidget);
        String? copied;
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        await tap(tester, l10n.browserCopyLink);
        expect(copied, importToolboxUrl);
        launcher.available = true;

        for (final cherry in [false, true]) {
          final version = cherry ? 7 : 3;
          select(
            'backup.zip',
            cherry ? 'metadata.json' : 'manifest.json',
            cherry
                ? {'version': version}
                : {'format': 'chatbox-backup', 'formatVersion': version},
          );
          await tap(
            tester,
            cherry
                ? l10n.backupPageImportFromCherryStudio
                : l10n.backupPageImportFromChatbox,
          );
          if (cherry && !desktop) await tap(tester, l10n.backupPageOK);
          await tap(tester, l10n.backupPageMergeMode);
          final error = cherry
              ? l10n.backupPageCherryStudioUnsupportedBackupVersion('$version')
              : l10n.backupPageChatboxUnsupportedBackupVersion('$version');
          expect(
            error,
            contains(desktop ? '格式版本 $version' : 'format version $version'),
          );
          expect(
            error,
            contains(
              desktop
                  ? '「备份文件导入」，并选择「合并」'
                  : 'Import Backup File and choose Merge',
            ),
          );
          await _waitFor(tester, error);
          final before = launcher.launches.length;
          await tap(tester, l10n.backupPageOpenImportToolbox);
          expect(find.text(error), findsOneWidget);
          expect(find.text(l10n.backupProgressCopyError), findsOneWidget);
          await tap(tester, l10n.commonClose);
          await tester.pumpAndSettle();
          expect(find.text(error), findsOneWidget);
          await tap(tester, l10n.backupPageOpenImportToolbox);
          expect(launcher.launches.skip(before), [launch, launch]);
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(seconds: 9));
      },
    );

    testWidgets(
      '$platform offers both modes for full backups and only restores a confirmed toolbox merge',
      (tester) async {
        await openPage(tester);
        final imported = {'id': 'imported-chatbox-assistant'};
        for (final (name, assistants, mergeOnly) in [
          ('kelivo-import-deepseek-sql-v5-20261117T080000Z (1).zip', [], true),
          ('kelivo_backup_2026-01-01T00-00-00.000000.zip', [imported], false),
          ('kelivo-backup-sql-v5-20261117T080000Z.zip', [imported], false),
          (
            'export.zip',
            [
              imported,
              {'id': 'mine'},
            ],
            false,
          ),
          ('export.zip', [imported], true),
        ]) {
          select(name, 'settings.json', {
            'assistants_v1': jsonEncode(assistants),
          });
          await tap(tester, l10n.backupPageImportBackupFile);
          await _waitFor(tester, l10n.backupPageSelectImportMode);
          expect(
            find.text(l10n.backupPageOverwriteMode),
            mergeOnly ? findsNothing : findsOneWidget,
          );
          expect(
            find.text(l10n.backupPageToolboxImportMergeOnlyHint),
            mergeOnly ? findsOneWidget : findsNothing,
          );
          expect(find.text(l10n.backupPageMergeMode), findsOneWidget);
          await tap(tester, l10n.backupPageCancel);
          await tester.pumpAndSettle();
          expect(backup.restores, isEmpty);
        }
        await tap(tester, l10n.backupPageImportBackupFile);
        await _waitFor(tester, l10n.backupPageMergeMode);
        await tap(tester, l10n.backupPageMergeMode);
        await _waitFor(tester, l10n.backupPageRestartRequired);
        expect(backup.restores, [(picker.file.path, RestoreMode.merge)]);
      },
    );
  }
}

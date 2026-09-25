import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_page.dart';
import 'package:Kelivo/features/assistant/widgets/assistant_default_workspace_row.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

const _assistantId = 'assistant-workspace-tab';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final bytes = await File(
      'dependencies/gpt_markdown/lib/fonts/JetBrainsMono-Regular.ttf',
    ).readAsBytes();
    await (FontLoader(
      'WorkspaceTest',
    )..addFont(Future.value(bytes.buffer.asByteData()))).load();
  });

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;
  late AppDatabase database;
  late WorkspaceProvider workspaces;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('kelivo_assistant_ws_tab_');
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    database = AppDatabase(NativeDatabase.memory());
    await database.customSelect('SELECT 1;').getSingle();
    workspaces = WorkspaceProvider(store: ExtensionEntityStore(database));
    await workspaces.loaded;
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    await database.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('picks and clears a default from basic settings on $platform', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const haptics = MethodChannel('haptic_feedback');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(haptics, (_) async => true);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(haptics, null),
      );
      final workspace = await tester.runAsync(
        () => workspaces.create(name: 'verification-ws'),
      );
      if (workspace == null) fail('workspace create failed');

      final harness = await createBusinessTestHarness(
        initial: {
          'assistants_v1': Assistant.encodeList([
            Assistant(id: _assistantId, name: 'Default Assistant'),
          ]),
        },
      );
      final ap = AssistantProvider(preferences: harness.preferences);
      await tester.runAsync(() => ap.loaded);
      expect(ap.getById(_assistantId)?.defaultWorkspaceId, isNull);

      tester.view.physicalSize = platform == TargetPlatform.iOS
          ? const Size(400, 900)
          : const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider.value(value: ap),
            ChangeNotifierProvider<WorkspaceProvider>.value(value: workspaces),
          ],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'WorkspaceTest'),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openAssistantBasicSettings(
                    context,
                    assistantId: _assistantId,
                  ),
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();

      final row = find.byKey(AssistantDefaultWorkspaceRow.defaultWorkspaceKey);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.text('Workspace'), findsNothing);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(AssistantDefaultWorkspaceRow.manageKey),
        findsOneWidget,
      );
      expect(
        find.byType(BottomSheet),
        platform == TargetPlatform.iOS ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('None'));
      await tester.pumpAndSettle();
      expect(ap.getById(_assistantId)!.defaultWorkspaceId, isNull);
      expect(
        ap.getById(_assistantId)!.defaultWorkspaceSetup,
        DefaultWorkspaceSetup.completed,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text('verification-ws'));
      await tester.pumpAndSettle();

      expect(ap.getById(_assistantId)!.defaultWorkspaceId, workspace.id);
      expect(find.text('verification-ws'), findsOneWidget);
      expect(find.text('Default workspace'), findsWidgets);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.text('None').last);
      await tester.pumpAndSettle();
      expect(ap.getById(_assistantId)!.defaultWorkspaceId, isNull);
      expect(
        ap.getById(_assistantId)!.defaultWorkspaceSetup,
        DefaultWorkspaceSetup.completed,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

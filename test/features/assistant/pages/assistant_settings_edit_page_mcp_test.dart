import 'dart:io';
import "../../../support/business_test_harness.dart";
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/quick_phrase_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/memory/memory_pipeline.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_page.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => '$path/cache';

  @override
  Future<String?> getTemporaryPath() async => '$path/tmp';
}

const _assistantId = 'assistant-mcp-test';

Future<
  ({
    AssistantProvider assistantProvider,
    ChatService chatService,
    MemoryProviderV2 memoryV2,
    MemoryPipelineService pipeline,
  })
>
_createAssistantProvider(WidgetTester tester) async {
  final tempDir = await tester.runAsync(
    () => Directory.systemTemp.createTemp('kelivo_asst_edit_'),
  );
  final previousPathProvider = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir!.path);
  addTearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final harness = await createBusinessTestHarness(
    initial: {
      'assistants_v1': Assistant.encodeList(const [
        Assistant(id: _assistantId, name: 'Test Assistant', temperature: 0.6),
      ]),
    },
  );
  final chatRepository = ChatDatabaseRepository(harness.database);
  await chatRepository.ensureReady();
  final chatService = ChatService(existingRepository: chatRepository);
  final provider = AssistantProvider(
    preferences: harness.preferences,
    chatService: chatService,
  );
  for (var i = 0; i < 25; i++) {
    if (provider.getById(_assistantId) != null) break;
    await tester.pump(const Duration(milliseconds: 10));
  }
  final memoryV2 = MemoryProviderV2(
    repository: MemoryRepository(harness.preferences),
    chatRepository: chatRepository,
  );
  final settings = SettingsProvider(harness.preferences);
  final pipeline = MemoryPipelineService(
    chatService: chatService,
    repository: memoryV2.repository,
    chatRepository: chatRepository,
    settings: () => settings,
    assistants: () => provider,
    memoryV2: () => memoryV2,
    generateText:
        ({
          required config,
          required modelId,
          required prompt,
          String? conversationId,
          int? thinkingBudget,
        }) async => '<user_memory>false</user_memory>',
  );
  return (
    assistantProvider: provider,
    chatService: chatService,
    memoryV2: memoryV2,
    pipeline: pipeline,
  );
}

Widget _buildHarness({
  required AssistantProvider assistantProvider,
  required ChatService chatService,
  required MemoryProviderV2 memoryV2,
  required MemoryPipelineService pipeline,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(assistantProvider.preferences),
      ),
      ChangeNotifierProvider.value(value: assistantProvider),
      ChangeNotifierProvider.value(value: chatService),
      ChangeNotifierProvider(
        create: (_) =>
            MemoryProvider(preferences: assistantProvider.preferences),
      ),
      ChangeNotifierProvider.value(value: memoryV2),
      Provider.value(value: pipeline),
      ChangeNotifierProvider(
        create: (_) =>
            QuickPhraseProvider(preferences: assistantProvider.preferences),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('assistant edit page shows MCP tab on mobile', (tester) async {
    final bundle = await _createAssistantProvider(tester);
    final assistantProvider = bundle.assistantProvider;

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MCP'), findsOneWidget);
  });

  testWidgets('assistant local tools page uses clock icon for time info', (
    tester,
  ) async {
    final bundle = await _createAssistantProvider(tester);
    final assistantProvider = bundle.assistantProvider;

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: const AssistantSettingsEditPage(assistantId: _assistantId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Local Tools'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Time Info'), findsOneWidget);
    final timeInfoRow = find
        .ancestor(of: find.text('Time Info'), matching: find.byType(Row))
        .first;
    expect(
      find.descendant(
        of: timeInfoRow,
        matching: find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.clock,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: timeInfoRow,
        matching: find.byWidgetPredicate(
          (widget) => widget is Icon && widget.icon == Lucide.Calendar,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'blocked location permission offers settings and can recover',
    (tester) async {
      const channel = MethodChannel('app.device_tools');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
      });
      var granted = false;
      var permanentlyDenied = false;
      var settingsOpened = false;
      messenger.setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'hasLocationPermission':
            return granted;
          case 'requestLocationPermission':
            if (permanentlyDenied) {
              throw PlatformException(
                code: DeviceLocalTools.locationPermissionPermanentlyDenied,
              );
            }
            return false;
          case 'openAppSettings':
            settingsOpened = true;
            return null;
          default:
            fail('Unexpected device call: ${call.method}');
        }
      });
      final bundle = await _createAssistantProvider(tester);
      await tester.pumpWidget(
        _buildHarness(
          assistantProvider: bundle.assistantProvider,
          chatService: bundle.chatService,
          memoryV2: bundle.memoryV2,
          pipeline: bundle.pipeline,
          child: const AppSnackBarOverlay(
            child: AssistantSettingsEditPage(assistantId: _assistantId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Local Tools'));
      await tester.pumpAndSettle();
      final locationTitle = find.text('Current Location');
      await tester.ensureVisible(locationTitle);
      await tester.pumpAndSettle();
      final locationSwitch = find.descendant(
        of: find.ancestor(of: locationTitle, matching: find.byType(Row)).first,
        matching: find.byType(IosSwitch),
      );

      // Ordinary denial should not redirect or offer a permanent-denial action.
      await tester.tap(locationSwitch);
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsNothing);
      expect(tester.widget<IosSwitch>(locationSwitch).value, isFalse);

      permanentlyDenied = true;
      await tester.tap(locationSwitch);
      await tester.pumpAndSettle();
      expect(find.text('Open Settings'), findsOneWidget);
      expect(
        find.text(
          'Location permission is blocked. Allow location access in system settings, then turn this tool on again.',
        ),
        findsOneWidget,
      );
      expect(settingsOpened, isFalse);
      expect(tester.widget<IosSwitch>(locationSwitch).value, isFalse);
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(settingsOpened, isTrue);

      granted = true;
      await tester.tap(locationSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<IosSwitch>(locationSwitch).value, isTrue);
      expect(
        bundle.assistantProvider.getById(_assistantId)!.localToolIds,
        contains(LocalToolNames.currentLocation),
      );
      // Drain the notification's dismissal timer before disposing its navigator.
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('assistant desktop dialog shows MCP menu item', (tester) async {
    final bundle = await _createAssistantProvider(tester);
    final assistantProvider = bundle.assistantProvider;

    await tester.pumpWidget(
      _buildHarness(
        assistantProvider: assistantProvider,
        chatService: bundle.chatService,
        memoryV2: bundle.memoryV2,
        pipeline: bundle.pipeline,
        child: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showAssistantDesktopDialog(
                  context,
                  assistantId: _assistantId,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('MCP'), findsOneWidget);
  });
}

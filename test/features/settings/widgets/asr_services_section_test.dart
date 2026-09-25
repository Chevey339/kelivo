import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/asr/asr_service_options.dart';
import 'package:Kelivo/core/services/asr/sherpa_model_manager.dart';
import 'package:Kelivo/features/settings/widgets/asr_services_section.dart';
import 'package:Kelivo/features/settings/widgets/voice_service_widgets.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(const {}));

  testWidgets('ASR add editor uses the voice-service component vocabulary', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);

    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
    );

    await tester.tap(find.byTooltip('Add speech recognition service'));
    await tester.pumpAndSettle();

    expect(find.text('Add Speech Recognition'), findsOneWidget);
    expect(find.text('System'), findsWidgets);
    expect(find.text('Offline Model'), findsOneWidget);
    expect(find.text('OpenAI Realtime'), findsOneWidget);
    expect(find.text('DashScope'), findsOneWidget);
    expect(find.text('Volcengine'), findsOneWidget);
    expect(find.text('MiMo'), findsOneWidget);
    expect(find.text('Step'), findsOneWidget);
    expect(find.byType(VoiceServiceMobileCard), findsNWidgets(2));
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Radio<dynamic>), findsNothing);
    final nameRect = tester.getRect(find.byType(TextField).first);
    final providerGridRect = tester.getRect(
      find.byKey(const ValueKey('asr-provider-choice-grid')),
    );
    expect(providerGridRect.left, nameRect.left);
    expect(providerGridRect.right, nameRect.right);
    final statusRect = tester.getRect(
      find.byKey(const ValueKey('asr-system-status')),
    );
    expect(statusRect.left, nameRect.left);
    expect(statusRect.right, nameRect.right);
  });

  testWidgets('offline model editor uses one icon-free model list', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);

    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
    );

    await tester.tap(find.byTooltip('Add speech recognition service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline Model'));
    await tester.pumpAndSettle();

    final modelList = find.byKey(const ValueKey('asr-local-model-list'));
    expect(modelList, findsOneWidget);
    final nameRect = tester.getRect(find.byType(TextField).first);
    final modelListRect = tester.getRect(modelList);
    expect(modelListRect.left, nameRect.left);
    expect(modelListRect.right, nameRect.right);
    for (final model in SherpaModelCatalog.models) {
      expect(find.byKey(ValueKey('asr-model-${model.id}')), findsOneWidget);
    }
    expect(
      find.descendant(of: modelList, matching: find.byIcon(Lucide.HardDrive)),
      findsNothing,
    );
  });

  testWidgets(
    'legacy MiMo default is shortened without changing custom names',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.setAsrServices([
        MimoAsrOptions(id: 'legacy-mimo', name: 'MiMo Speech Recognition'),
        MimoAsrOptions(id: 'custom-mimo', name: 'MiMo Speech Recognition Pro'),
      ]);
      final fixture = _ModelManagerFixture.create();
      addTearDown(fixture.dispose);

      await _pumpSection(
        tester,
        settings: settings,
        modelManager: fixture.manager,
      );

      expect(find.text('MiMo'), findsOneWidget);
      expect(find.text('MiMo Speech Recognition'), findsNothing);
      expect(find.text('MiMo Speech Recognition Pro'), findsOneWidget);
    },
  );

  testWidgets('editing Step and MiMo keeps advanced values not shown in UI', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.setAsrServices([
      StepAsrOptions(
        id: 'step-test',
        name: 'Step custom',
        apiKey: 'step-key',
        sampleRate: 24000,
        segmentDurationSec: 17,
        enableItn: false,
        enableTimestamp: true,
        hotwords: const ['Kelivo', 'ASR'],
      ),
      MimoAsrOptions(
        id: 'mimo-test',
        name: 'MiMo custom',
        apiKey: 'mimo-key',
        sampleRate: 22050,
        segmentDurationSec: 19,
      ),
    ]);
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);

    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
    );

    await tester.tap(find.byTooltip('Edit').at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final step = settings.asrServices.first as StepAsrOptions;
    expect(step.sampleRate, 24000);
    expect(step.segmentDurationSec, 17);
    expect(step.enableItn, isFalse);
    expect(step.enableTimestamp, isTrue);
    expect(step.hotwords, const ['Kelivo', 'ASR']);

    await tester.tap(find.byTooltip('Edit').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();

    final mimo = settings.asrServices[1] as MimoAsrOptions;
    expect(mimo.sampleRate, 22050);
    expect(mimo.segmentDurationSec, 19);
  });

  testWidgets(
    'editing OpenAI and DashScope keeps advanced values not shown in UI',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.setAsrServices([
        OpenAiRealtimeAsrOptions(
          id: 'openai-test',
          name: 'OpenAI custom',
          apiKey: 'openai-key',
          prompt: 'Kelivo vocabulary',
          sampleRate: 48000,
          vadThreshold: 0.42,
          prefixPaddingMs: 420,
          silenceDurationMs: 940,
        ),
        DashScopeAsrOptions(
          id: 'dashscope-test',
          name: 'DashScope custom',
          apiKey: 'dashscope-key',
          sampleRate: 24000,
          vadThreshold: 0.36,
          silenceDurationMs: 1230,
        ),
      ]);
      final fixture = _ModelManagerFixture.create();
      addTearDown(fixture.dispose);

      await _pumpSection(
        tester,
        settings: settings,
        modelManager: fixture.manager,
      );

      await tester.tap(find.byTooltip('Edit').at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final openAi = settings.asrServices.first as OpenAiRealtimeAsrOptions;
      expect(openAi.prompt, 'Kelivo vocabulary');
      expect(openAi.sampleRate, 48000);
      expect(openAi.vadThreshold, 0.42);
      expect(openAi.prefixPaddingMs, 420);
      expect(openAi.silenceDurationMs, 940);

      await tester.tap(find.byTooltip('Edit').at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();

      final dashScope = settings.asrServices[1] as DashScopeAsrOptions;
      expect(dashScope.sampleRate, 24000);
      expect(dashScope.vadThreshold, 0.36);
      expect(dashScope.silenceDurationMs, 1230);
    },
  );

  testWidgets('desktop ASR editor reuses the custom TTS-style selector', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);

    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
      desktop: true,
    );

    await tester.tap(find.byTooltip('Add speech recognition service'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(VoiceServiceSelectRow<AsrServiceKind>), findsOneWidget);
    expect(find.byType(DropdownButton<dynamic>), findsNothing);
    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.decoration?.filled, isNot(isTrue));
    final border = nameField.decoration?.border as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.circular(10));
    final nameRect = tester.getRect(find.byType(TextField).first);
    final statusRect = tester.getRect(
      find.byKey(const ValueKey('asr-system-status')),
    );
    expect(statusRect.left, nameRect.left);
    expect(statusRect.right, nameRect.right);
  });

  testWidgets('mobile reorders speech recognition after a long press', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAsrServices([
      SystemAsrOptions(id: 'alpha', name: 'Alpha ASR'),
      SystemAsrOptions(id: 'beta', name: 'Beta ASR'),
    ]);
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);
    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
    );

    final first = tester.getCenter(find.text('Alpha ASR'));
    final second = tester.getCenter(find.text('Beta ASR'));
    final quick = await tester.startGesture(first);
    await quick.moveBy(Offset(0, second.dy - first.dy + 24));
    await quick.up();
    await tester.pumpAndSettle();
    expect(settings.asrServices.map((service) => service.id), [
      'alpha',
      'beta',
    ]);

    final drag = await tester.startGesture(
      tester.getCenter(find.text('Alpha ASR')),
    );
    await tester.pump(kLongPressTimeout);
    final distance = second.dy - first.dy + 40;
    for (double dy = 8; dy <= distance; dy += 8) {
      await drag.moveTo(first + Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(settings.asrServices.map((service) => service.id), [
      'beta',
      'alpha',
    ]);
  });

  testWidgets('desktop reorders speech recognition by dragging a card', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setAsrServices([
      SystemAsrOptions(id: 'alpha', name: 'Alpha ASR'),
      SystemAsrOptions(id: 'beta', name: 'Beta ASR'),
    ]);
    final fixture = _ModelManagerFixture.create();
    addTearDown(fixture.dispose);
    await _pumpSection(
      tester,
      settings: settings,
      modelManager: fixture.manager,
      desktop: true,
    );

    final first = tester.getCenter(find.text('Alpha ASR'));
    final second = tester.getCenter(find.text('Beta ASR'));
    final drag = await tester.startGesture(first);
    await tester.pump();
    final distance = second.dy - first.dy + 40;
    for (double dy = 8; dy <= distance; dy += 8) {
      await drag.moveTo(first + Offset(0, dy));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await drag.up();
    await tester.pumpAndSettle();

    expect(settings.asrServices.map((service) => service.id), [
      'beta',
      'alpha',
    ]);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required SettingsProvider settings,
  required SherpaModelManager modelManager,
  bool desktop = false,
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider<SettingsProvider>.value(
      value: settings,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: AsrServicesSection(
                  desktop: desktop,
                  modelManager: modelManager,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _ModelManagerFixture {
  _ModelManagerFixture(this.directory, this.manager);

  final Directory directory;
  final SherpaModelManager manager;

  static _ModelManagerFixture create() {
    final directory = Directory.systemTemp.createTempSync('kelivo-asr-ui-');
    return _ModelManagerFixture(
      directory,
      SherpaModelManager(modelsRoot: directory),
    );
  }

  void dispose() {
    manager.dispose();
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

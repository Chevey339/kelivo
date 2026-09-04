import 'dart:io';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/features/assistant/pages/assistant_settings_edit_skills_tab.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../workspace/skills/skills_test_fakes.dart';

const _assistantId = 'assistant-skills-tab';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_skills_tab_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('toggles skillIds null ↔ list', (tester) async {
    final enabled = createTempSkill(
      id: 'keep',
      name: 'Keep',
      description: 'Enabled skill',
      parent: tempDir,
    );
    final disabled = createTempSkill(
      id: 'off',
      name: 'Off',
      description: 'Disabled skill',
      enabled: false,
      parent: tempDir,
    );
    final skills = FakeSkillsService(
      skills: [enabled, disabled],
      skillsDirectory: tempDir,
    );

    final harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList([
          Assistant(id: _assistantId, name: 'Skills Assistant'),
        ]),
      },
    );
    final ap = AssistantProvider(preferences: harness.preferences);
    await tester.runAsync(() => ap.loaded);
    expect(ap.getById(_assistantId)?.skillIds, isNull);

    tester.view.physicalSize = const Size(400, 900);
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
          ChangeNotifierProvider<SkillsService>.value(value: skills),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: AssistantSettingsEditSkillsTab(assistantId: _assistantId),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(AssistantSettingsEditSkillsTab.useAllKey),
      findsOneWidget,
    );
    expect(
      find.byKey(AssistantSettingsEditSkillsTab.skillKey('keep')),
      findsOneWidget,
    );
    expect(
      find.byKey(AssistantSettingsEditSkillsTab.skillKey('off')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(AssistantSettingsEditSkillsTab.useAllKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ap.getById(_assistantId)!.skillIds, ['keep']);
    expect(
      find.byKey(AssistantSettingsEditSkillsTab.skillKey('keep')),
      findsOneWidget,
    );
    expect(
      find.byKey(AssistantSettingsEditSkillsTab.skillKey('off')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(AssistantSettingsEditSkillsTab.skillKey('keep')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ap.getById(_assistantId)!.skillIds, isEmpty);

    await tester.tap(find.byKey(AssistantSettingsEditSkillsTab.useAllKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(ap.getById(_assistantId)!.skillIds, isNull);
  });
}

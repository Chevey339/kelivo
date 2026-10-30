import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/assistant_memory.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/models/user_profile_field.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/memory_provider.dart';
import 'package:Kelivo/core/providers/memory_provider_v2.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/memory/memory_repository.dart';
import 'package:Kelivo/features/settings/pages/legacy_memory_page.dart';
import 'package:Kelivo/features/settings/pages/memory_entries_page.dart';
import 'package:Kelivo/features/settings/pages/user_profile_page.dart';
import 'package:Kelivo/features/settings/widgets/memory_ui.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_switch.dart';

import '../../../support/business_test_harness.dart';

class _MemoryHarness {
  _MemoryHarness({
    required this.preferences,
    required this.chatRepository,
    required this.memoryV2,
    required this.legacyMemory,
    required this.assistants,
    required this.settings,
  });

  final BusinessPreferences preferences;
  final ChatDatabaseRepository chatRepository;
  final MemoryProviderV2 memoryV2;
  final MemoryProvider legacyMemory;
  final AssistantProvider assistants;
  final SettingsProvider settings;
}

Future<_MemoryHarness> _createHarness({
  List<Assistant> assistantList = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final harness = await createBusinessTestHarness(
    initial: {
      if (assistantList.isNotEmpty)
        'assistants_v1': Assistant.encodeList(assistantList),
    },
  );
  final chatRepository = ChatDatabaseRepository(harness.database);
  await chatRepository.ensureReady();
  final memoryRepo = MemoryRepository(harness.preferences);
  final memoryV2 = MemoryProviderV2(
    repository: memoryRepo,
    chatRepository: chatRepository,
  );
  final legacy = MemoryProvider(preferences: harness.preferences);
  final assistants = AssistantProvider(preferences: harness.preferences);
  await assistants.loaded;
  final settings = SettingsProvider(harness.preferences);
  await settings.loaded;
  return _MemoryHarness(
    preferences: harness.preferences,
    chatRepository: chatRepository,
    memoryV2: memoryV2,
    legacyMemory: legacy,
    assistants: assistants,
    settings: settings,
  );
}

Widget _wrap(_MemoryHarness h, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: h.settings),
      ChangeNotifierProvider.value(value: h.assistants),
      ChangeNotifierProvider.value(value: h.memoryV2),
      ChangeNotifierProvider.value(value: h.legacyMemory),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('memory list shows global vs assistant and archived section', (
    tester,
  ) async {
    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Alpha', temperature: 0.6),
      ],
    );
    await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Global fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.create(
      scope: MemoryScope.assistant,
      assistantId: 'a1',
      type: MemoryType.workflow,
      content: 'Assistant fact',
      source: MemorySource.manual,
    );
    final archived = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.voice,
      content: 'Archived fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.archive(archived.id);
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(_wrap(h, const MemoryEntriesContent()));
    await tester.pumpAndSettle();

    expect(find.text('Global fact'), findsOneWidget);
    expect(find.text('Assistant fact'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('Archived fact'), findsOneWidget);
    expect(find.text('Global'), findsWidgets);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('assistant memory list only shows memories visible to it', (
    tester,
  ) async {
    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Alpha', temperature: 0.6),
        Assistant(id: 'a2', name: 'Beta', temperature: 0.6),
      ],
    );
    await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Global fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.create(
      scope: MemoryScope.assistant,
      assistantId: 'a1',
      type: MemoryType.workflow,
      content: 'Alpha fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.create(
      scope: MemoryScope.assistant,
      assistantId: 'a2',
      type: MemoryType.workflow,
      content: 'Beta fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(h, const MemoryEntriesContent(assistantId: 'a1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Global fact'), findsOneWidget);
    expect(find.text('Alpha fact'), findsOneWidget);
    expect(find.text('Beta fact'), findsNothing);
    expect(find.text('This assistant'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fact');
    await tester.pumpAndSettle();
    expect(find.text('Global fact'), findsOneWidget);
    expect(find.text('Alpha fact'), findsOneWidget);
    expect(find.text('Beta fact'), findsNothing);
  });

  testWidgets('add memory stays reachable on a phone-width toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    await tester.pumpWidget(_wrap(h, const MemoryEntriesContent()));
    await tester.pumpAndSettle();

    // The filter chips overflow and scroll; add must not scroll with them.
    expect(find.text('Add memory').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Add memory').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEntryEditForm), findsOneWidget);
  });

  testWidgets('assistant memory list adds with the assistant write scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness(
      assistantList: const [
        Assistant(
          id: 'a1',
          name: 'Alpha',
          temperature: 0.6,
          memoryWriteScope: MemoryWriteScope.alwaysAssistant,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrap(h, const MemoryEntriesContent(assistantId: 'a1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add memory'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(MemoryEntryEditForm),
        matching: find.byType(TextField),
      ),
      'Prefers short answers',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final added = h.memoryV2.entries.singleWhere(
      (e) => e.content == 'Prefers short answers',
    );
    expect(added.scope, MemoryScope.assistant);
    expect(added.assistantId, 'a1');
    expect(find.text('Prefers short answers'), findsOneWidget);
  });

  testWidgets('archive restore and hard delete reach provider with confirm', (
    tester,
  ) async {
    final h = await _createHarness();
    final entry = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Delete me',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(h, MemoryEntryCard(entry: h.memoryV2.entries.first, onEdit: () {})),
    );
    await tester.pumpAndSettle();

    // Archive via long-press context menu
    await tester.longPress(find.text('Delete me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.entries.singleWhere((e) => e.id == entry.id).status,
      MemoryStatus.archived,
    );

    await tester.pumpWidget(
      _wrap(h, MemoryEntryCard(entry: h.memoryV2.entries.first, onEdit: () {})),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Delete me'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.entries.singleWhere((e) => e.id == entry.id).status,
      MemoryStatus.active,
    );

    // Hard delete requires confirmation
    final deleteButtons = find.byTooltip('Delete');
    expect(deleteButtons, findsOneWidget);
    await tester.tap(deleteButtons);
    await tester.pumpAndSettle();
    expect(find.text('Delete memory?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.memoryV2.entries.where((e) => e.id == entry.id), isNotEmpty);

    await tester.tap(deleteButtons);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.memoryV2.entries.where((e) => e.id == entry.id), isEmpty);
  });

  testWidgets('profile add edit clear custom and reject invalid key', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(_wrap(h, const UserProfileContent()));
    await tester.pumpAndSettle();

    // Profile fields use the standard modal bottom sheet + form (not CustomBottomSheet).
    Finder inSheet(Finder matching) =>
        find.descendant(of: find.byType(BottomSheet), matching: matching);

    await tester.tap(find.text('Preferred name'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    // Nickname edit has no preferred-name hint subtitle under the title.
    expect(
      find.textContaining('unrelated to the sidebar display name'),
      findsNothing,
    );
    await tester.enterText(inSheet(find.byType(TextField)), 'Alex');
    await tester.tap(inSheet(find.text('Save')));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.profileFields.any(
        (f) => f.key == 'preferred_name' && f.value == 'Alex',
      ),
      isTrue,
    );

    await tester.tap(find.text('Preferred name'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Clear')));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.profileFields.any((f) => f.key == 'preferred_name'),
      isFalse,
    );

    await tester.tap(find.text('Add custom field'));
    await tester.pumpAndSettle();
    final sheetFields = inSheet(find.byType(TextField));
    expect(sheetFields, findsNWidgets(2));
    await tester.enterText(sheetFields.at(0), 'custom.company');
    await tester.enterText(sheetFields.at(1), 'Acme');
    await tester.tap(inSheet(find.text('Save')));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.profileFields.any(
        (f) => f.key == 'custom.company' && f.value == 'Acme',
      ),
      isTrue,
    );

    await tester.tap(find.text('custom.company'));
    await tester.pumpAndSettle();
    await tester.enterText(inSheet(find.byType(TextField)), 'Beta');
    await tester.tap(inSheet(find.text('Save')));
    await tester.pumpAndSettle();
    expect(
      h.memoryV2.profileFields.any(
        (f) => f.key == 'custom.company' && f.value == 'Beta',
      ),
      isTrue,
    );

    // Invalid keys are rejected by the model + UI guard.
    expect(UserProfileField.isValidKey('bad key!'), isFalse);
    await expectLater(
      h.memoryV2.putProfileField('bad key!', 'x', MemorySource.manual),
      throwsA(isA<ArgumentError>()),
    );
    expect(h.memoryV2.profileFields.any((f) => f.key == 'bad key!'), isFalse);
  });

  testWidgets('memory editor sheet opens and cancels without throwing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(_wrap(h, const MemoryEntriesContent()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add memory'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEntryEditForm), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryEntryEditForm), findsNothing);
    expect(tester.takeException(), isNull);
    expect(h.memoryV2.entries, isEmpty);
  });

  testWidgets('memory editor sheet saves a new global memory', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(_wrap(h, const MemoryEntriesContent()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add memory'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(MemoryEntryEditForm),
        matching: find.byType(TextField),
      ),
      'Likes espresso',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      h.memoryV2.entries.any(
        (e) => e.content == 'Likes espresso' && e.scope == MemoryScope.global,
      ),
      isTrue,
    );
  });

  testWidgets('desktop memory editor uses centered Dialog not bottom sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final h = await _createHarness();
      await h.memoryV2.refreshAll();

      await tester.pumpWidget(_wrap(h, const MemoryEntriesContent()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add memory'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsWidgets);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(MemoryEntryEditForm), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(MemoryEntryEditForm),
          matching: find.byType(TextField),
        ),
        'Desktop fact',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        h.memoryV2.entries.any((e) => e.content == 'Desktop fact'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('desktop profile field editor uses Dialog not bottom sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final h = await _createHarness();
      await h.memoryV2.refreshAll();

      await tester.pumpWidget(_wrap(h, const UserProfileContent()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preferred name'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsWidgets);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.enterText(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        ),
        'Casey',
      );
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('Save')),
      );
      await tester.pumpAndSettle();

      expect(
        h.memoryV2.profileFields.any(
          (f) => f.key == 'preferred_name' && f.value == 'Casey',
        ),
        isTrue,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('legacy content can be scoped to a single assistant', (
    tester,
  ) async {
    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Writer', temperature: 0.6),
        Assistant(id: 'a2', name: 'Coder', temperature: 0.6),
      ],
    );
    await h.legacyMemory.add(assistantId: 'a1', content: 'Writer memory');
    await h.legacyMemory.add(assistantId: 'a2', content: 'Coder memory');

    await tester.pumpWidget(
      _wrap(h, const LegacyMemoryContent(assistantId: 'a2')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coder memory'), findsOneWidget);
    expect(find.text('Writer memory'), findsNothing);
  });

  testWidgets('orphan cleanup shows count and deletes on confirm', (
    tester,
  ) async {
    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'alive', name: 'Alive', temperature: 0.6),
      ],
    );
    // Create orphan by writing assistant-scoped entry for missing assistant.
    await h.memoryV2.create(
      scope: MemoryScope.assistant,
      assistantId: 'gone',
      type: MemoryType.identity,
      content: 'Orphan memory',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();
    expect(h.memoryV2.orphanCount, 1);

    await tester.pumpWidget(_wrap(h, const MemoryOrphanBanner()));
    await tester.pumpAndSettle();
    expect(find.textContaining('orphaned'), findsOneWidget);

    await tester.tap(find.text('Clean up'));
    await tester.pumpAndSettle();
    expect(find.text('Clean up orphaned memories?'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Clean up'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.memoryV2.orphanCount, 0);
    expect(h.memoryV2.entries, isEmpty);
  });

  testWidgets('legacy page is read-only with no mutation affordances', (
    tester,
  ) async {
    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Writer', temperature: 0.6),
      ],
    );
    // Seed legacy store directly via provider add (test setup only).
    await h.legacyMemory.add(assistantId: 'a1', content: 'Old memory line');

    await tester.pumpWidget(_wrap(h, const LegacyMemoryContent()));
    await tester.pumpAndSettle();

    expect(find.text('Old memory line'), findsOneWidget);
    expect(find.textContaining('older version'), findsOneWidget);
    // No edit / delete / archive controls
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Archive'), findsNothing);
    expect(find.byType(IosSwitch), findsNothing);
    expect(find.byType(TextField), findsOneWidget); // search only
    expect(find.byTooltip('Copy'), findsOneWidget);
  });

  testWidgets('legacy export text format', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final text = LegacyMemoryContent.buildExportText(
      l10n: l10n,
      memories: [
        AssistantMemory(id: 1, assistantId: 'a1', content: 'One'),
        AssistantMemory(id: 2, assistantId: 'a1', content: 'Two'),
      ],
      assistantName: (_) => 'Writer',
      now: DateTime(2026, 8, 8, 14, 3),
    );
    expect(text, contains('# Kelivo legacy memory export'));
    expect(text, contains('# 2026-08-08 14:03'));
    expect(text, contains('## Assistant: Writer'));
    expect(text, contains('- One'));
    expect(text, contains('- Two'));
  });

  testWidgets('create form can default to assistant scope', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Alpha', temperature: 0.6),
      ],
    );

    await tester.pumpWidget(
      _wrap(
        h,
        const MemoryEntryEditForm(
          title: 'Add memory',
          defaultAssistantId: 'a1',
          defaultScope: MemoryScope.assistant,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chips = tester.widgetList<MemorySelectChip>(
      find.byType(MemorySelectChip),
    );
    expect(chips.any((c) => c.label == 'This assistant' && c.selected), isTrue);
  });

  testWidgets('edit form renders type and scope chips', (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    final entry = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Original fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(h, MemoryEntryEditForm(title: 'Edit memory', existing: entry)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identity'), findsOneWidget);
    expect(find.text('Workflow'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);
    expect(find.text('Instruction'), findsOneWidget);
    expect(find.text('Global'), findsWidgets);
    expect(find.text('This assistant'), findsOneWidget);
  });

  testWidgets('edit form content-only save does not confirm scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness();
    final entry = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Original fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(h, MemoryEntryEditForm(title: 'Edit memory', existing: entry)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(MemoryEntryEditForm),
        matching: find.byType(TextField),
      ),
      'Updated fact',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Change memory scope?'), findsNothing);
    expect(tester.takeException(), isNull);
    final saved = h.memoryV2.entries.singleWhere((e) => e.id == entry.id);
    expect(saved.content, 'Updated fact');
    expect(saved.type, MemoryType.identity);
    expect(saved.scope, MemoryScope.global);
  });

  testWidgets('edit form saves content type and scope together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final h = await _createHarness(
      assistantList: const [
        Assistant(id: 'a1', name: 'Alpha', temperature: 0.6),
      ],
    );
    final entry = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Original fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(
        h,
        MemoryEntryEditForm(
          title: 'Edit memory',
          existing: entry,
          defaultAssistantId: 'a1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(MemoryEntryEditForm),
        matching: find.byType(TextField),
      ),
      'Updated fact',
    );
    await tester.tap(find.text('Workflow'));
    await tester.tap(find.text('This assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Change memory scope?'), findsOneWidget);
    await tester.tap(find.text('Change scope'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final saved = h.memoryV2.entries.singleWhere((e) => e.id == entry.id);
    expect(saved.content, 'Updated fact');
    expect(saved.type, MemoryType.workflow);
    expect(saved.scope, MemoryScope.assistant);
    expect(saved.assistantId, 'a1');
  });

  testWidgets('edit form still writes remaining fields after dismiss', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList(const [
          Assistant(id: 'a1', name: 'Alpha', temperature: 0.6),
        ]),
      },
    );
    final chatRepository = ChatDatabaseRepository(harness.database);
    await chatRepository.ensureReady();
    final gate = Completer<void>();
    final memoryRepo = _GateOnContentRepo(harness.preferences, gate: gate);
    final memoryV2 = MemoryProviderV2(
      repository: memoryRepo,
      chatRepository: chatRepository,
    );
    final h = _MemoryHarness(
      preferences: harness.preferences,
      chatRepository: chatRepository,
      memoryV2: memoryV2,
      legacyMemory: MemoryProvider(preferences: harness.preferences),
      assistants: AssistantProvider(preferences: harness.preferences),
      settings: SettingsProvider(harness.preferences),
    );
    await h.assistants.loaded;
    await h.settings.loaded;

    final entry = await h.memoryV2.create(
      scope: MemoryScope.global,
      type: MemoryType.identity,
      content: 'Original fact',
      source: MemorySource.manual,
    );
    await h.memoryV2.refreshAll();

    await tester.pumpWidget(
      _wrap(
        h,
        MemoryEntryEditForm(
          title: 'Edit memory',
          existing: entry,
          defaultAssistantId: 'a1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(MemoryEntryEditForm),
        matching: find.byType(TextField),
      ),
      'Updated fact',
    );
    await tester.tap(find.text('Workflow'));
    await tester.tap(find.text('This assistant'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change scope'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = h.memoryV2.entries.singleWhere((e) => e.id == entry.id);
    expect(saved.content, 'Updated fact');
    expect(saved.type, MemoryType.workflow);
    expect(saved.scope, MemoryScope.assistant);
    expect(saved.assistantId, 'a1');
  });
}

class _GateOnContentRepo extends MemoryRepository {
  _GateOnContentRepo(super.preferences, {required this.gate});

  final Completer<void> gate;

  @override
  Future<MemoryEntry?> updateContent(String id, String content) async {
    await gate.future;
    return super.updateContent(id, content);
  }
}

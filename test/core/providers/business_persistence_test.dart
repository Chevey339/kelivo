import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/quick_phrase.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/backup_reminder_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_group_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/tag_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/services/instruction_injection_store.dart';
import 'package:Kelivo/core/services/memory_store.dart';
import 'package:Kelivo/core/services/quick_phrase_store.dart';
import 'package:Kelivo/core/services/world_book_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'context stores preserve entities, order, and mappings after reopen',
    () async {
      final fixture = await BusinessPreferencesTestHarness.create();
      addTearDown(fixture.dispose);

      final first = await fixture.open();
      final worldBooks = WorldBookStore(first.preferences);
      final memories = MemoryStore(first.preferences);
      final phrases = QuickPhraseStore(first.preferences);
      final injections = InstructionInjectionStore(first.preferences);

      await worldBooks.save(const <WorldBook>[
        WorldBook(id: 'book-b', name: 'B'),
        WorldBook(id: 'book-a', name: 'A'),
      ]);
      await worldBooks.setActiveIds(const <String>[
        'book-a',
        'book-a',
        'book-b',
      ], assistantId: 'assistant-a');
      await worldBooks.setCollapsed('book-b', true);

      final firstMemory = await memories.add(
        assistantId: 'assistant-a',
        content: 'remember A',
      );
      await memories.add(assistantId: 'assistant-b', content: 'remember B');

      await phrases.save(const <QuickPhrase>[
        QuickPhrase(id: 'phrase-b', title: 'B', content: 'second'),
        QuickPhrase(id: 'phrase-a', title: 'A', content: 'first'),
      ]);

      await injections.save(const <InstructionInjection>[
        InstructionInjection(id: 'injection-b', title: 'B', prompt: 'second'),
        InstructionInjection(id: 'injection-a', title: 'A', prompt: 'first'),
      ]);
      await injections.setActiveIds(const <String>[
        'injection-a',
      ], assistantId: 'assistant-a');

      await first.close();

      final reopened = await fixture.open();
      final reopenedWorldBooks = WorldBookStore(reopened.preferences);
      final reopenedMemories = MemoryStore(reopened.preferences);
      final reopenedPhrases = QuickPhraseStore(reopened.preferences);
      final reopenedInjections = InstructionInjectionStore(
        reopened.preferences,
      );

      expect(
        (await reopenedWorldBooks.getAll()).map((book) => book.id),
        <String>['book-b', 'book-a'],
      );
      expect(
        await reopenedWorldBooks.getActiveIds(assistantId: 'assistant-a'),
        <String>['book-a', 'book-b'],
      );
      expect(await reopenedWorldBooks.getCollapsedBooksMap(), <String, bool>{
        'book-b': true,
      });
      expect(
        await reopenedMemories.getForAssistant('assistant-a'),
        hasLength(1),
      );
      expect(
        (await reopenedMemories.getForAssistant('assistant-a')).single.id,
        firstMemory.id,
      );
      expect(
        (await reopenedPhrases.getAll()).map((phrase) => phrase.id),
        <String>['phrase-b', 'phrase-a'],
      );
      expect(
        (await reopenedInjections.getAll()).map((item) => item.id),
        <String>['injection-b', 'injection-a'],
      );
      expect(
        await reopenedInjections.getActiveIds(assistantId: 'assistant-a'),
        <String>['injection-a'],
      );
      expect(
        reopened.preferences.containsKey('instruction_injections_active_id_v1'),
        isFalse,
      );
      expect(
        reopened.preferences.containsKey(
          'instruction_injections_active_ids_v1',
        ),
        isFalse,
      );

      await reopened.close();
    },
  );

  test('providers restore public state from the same database', () async {
    final fixture = await BusinessPreferencesTestHarness.create();
    addTearDown(fixture.dispose);

    final first = await fixture.open();
    await first.preferences.setString(
      'assistants_v1',
      Assistant.encodeList(const <Assistant>[
        Assistant(id: 'assistant-a', name: 'A'),
        Assistant(id: 'assistant-b', name: 'B'),
      ]),
    );
    await first.preferences.setString('current_assistant_id_v1', 'assistant-a');

    final assistants = AssistantProvider(preferences: first.preferences);
    final tags = TagProvider(preferences: first.preferences);
    final user = UserProvider(preferences: first.preferences);
    final groups = InstructionInjectionGroupProvider(
      preferences: first.preferences,
    );
    final reminders = BackupReminderProvider(
      preferences: first.preferences,
      autoLoad: false,
    );
    addTearDown(assistants.dispose);
    addTearDown(tags.dispose);
    addTearDown(user.dispose);
    addTearDown(groups.dispose);
    addTearDown(reminders.dispose);

    await Future.wait(<Future<void>>[
      _nextNotification(assistants),
      _nextNotification(tags),
      _nextNotification(groups),
    ]);
    await reminders.load(startTimer: false);

    await assistants.setCurrentAssistant('assistant-b');
    await assistants.updateAssistant(
      assistants.getById('assistant-a')!.copyWith(searchEnabled: true),
    );
    final tagId = await tags.createTag('Work');
    await tags.assignAssistantToTag('assistant-a', tagId);
    await tags.setCollapsed(tagId, true);
    await user.setName('Taylor');
    await user.setAvatarEmoji('🌿');
    await groups.setCollapsed('Pinned', true);
    await reminders.saveSchedule(
      enabled: true,
      intervalDays: 14,
      reminderMinutesOfDay: 21 * 60 + 15,
      now: DateTime(2026, 7, 18, 9),
    );

    await first.close();

    final reopened = await fixture.open();
    final restoredAssistants = AssistantProvider(
      preferences: reopened.preferences,
    );
    final restoredTags = TagProvider(preferences: reopened.preferences);
    final restoredUser = UserProvider(preferences: reopened.preferences);
    final restoredGroups = InstructionInjectionGroupProvider(
      preferences: reopened.preferences,
    );
    final restoredReminders = BackupReminderProvider(
      preferences: reopened.preferences,
      autoLoad: false,
    );
    addTearDown(restoredAssistants.dispose);
    addTearDown(restoredTags.dispose);
    addTearDown(restoredUser.dispose);
    addTearDown(restoredGroups.dispose);
    addTearDown(restoredReminders.dispose);

    await Future.wait(<Future<void>>[
      _nextNotification(restoredAssistants),
      _nextNotification(restoredTags),
      _nextNotification(restoredUser),
      _nextNotification(restoredGroups),
    ]);
    await restoredReminders.load(startTimer: false);

    expect(restoredAssistants.currentAssistantId, 'assistant-b');
    expect(restoredAssistants.getById('assistant-a')?.searchEnabled, isTrue);
    expect(restoredTags.tags.single.name, 'Work');
    expect(restoredTags.tagOfAssistant('assistant-a'), tagId);
    expect(restoredTags.isCollapsed(tagId), isTrue);
    expect(restoredUser.name, 'Taylor');
    expect(restoredUser.avatarType, 'emoji');
    expect(restoredUser.avatarValue, '🌿');
    expect(restoredGroups.isCollapsed('Pinned'), isTrue);
    expect(restoredReminders.enabled, isTrue);
    expect(restoredReminders.intervalDays, 14);
    expect(restoredReminders.reminderMinutesOfDay, 21 * 60 + 15);
    expect(restoredReminders.enabledAt, DateTime(2026, 7, 18, 9));

    await reopened.close();
  });

  test('concurrent instruction initialization seeds one default', () async {
    final fixture = await BusinessPreferencesTestHarness.create();
    addTearDown(fixture.dispose);
    final session = await fixture.open();
    final provider = InstructionInjectionProvider(
      preferences: session.preferences,
    );
    addTearDown(provider.dispose);

    await Future.wait(<Future<void>>[
      provider.initialize(),
      provider.initialize(),
      provider.initialize(),
    ]);

    expect(provider.items, hasLength(1));
    expect(provider.items.single.prompt, isNotEmpty);
    await session.close();

    final reopened = await fixture.open();
    final restored = InstructionInjectionProvider(
      preferences: reopened.preferences,
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.items, hasLength(1));
    expect(restored.items.single.id, provider.items.single.id);
    await reopened.close();
  });

  test(
    'MCP seeds once, restores timeout, and commits memory after storage',
    () async {
      final fixture = await BusinessPreferencesTestHarness.create();
      addTearDown(fixture.dispose);

      final first = await fixture.open();
      final provider = McpProvider(preferences: first.preferences);
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.servers.isNotEmpty);

      expect(
        provider.servers.where((server) => server.id == 'kelivo_fetch'),
        hasLength(1),
      );
      await provider.updateRequestTimeout(
        const Duration(seconds: 42),
        reconnectActive: false,
      );
      final customId = await provider.addServer(
        enabled: false,
        name: 'Docs',
        transport: McpTransportType.http,
        url: 'https://example.test/mcp',
      );

      await first.close();

      final reopened = await fixture.open();
      final restored = McpProvider(preferences: reopened.preferences);
      addTearDown(restored.dispose);
      await _waitUntil(() => restored.servers.length == 2);

      expect(
        restored.servers.where((server) => server.id == 'kelivo_fetch'),
        hasLength(1),
      );
      expect(restored.getById(customId)?.name, 'Docs');
      expect(restored.requestTimeout, const Duration(seconds: 42));

      await reopened.close();
      final beforeFailedWrite = List<McpServerConfig>.of(restored.servers);
      await expectLater(
        restored.addServer(
          enabled: false,
          name: 'Must not appear',
          transport: McpTransportType.http,
          url: 'https://example.test/fail',
        ),
        throwsA(anything),
      );
      expect(restored.servers, orderedEquals(beforeFailedWrite));
    },
  );

  test(
    'concurrent MCP snapshot mutations preserve every intended update',
    () async {
      final fixture = await BusinessPreferencesTestHarness.create();
      addTearDown(fixture.dispose);

      final first = await fixture.open();
      await first.preferences.setString(
        'mcp_servers_v1',
        jsonEncode(<Map<String, dynamic>>[
          McpServerConfig(
            id: 'kelivo_fetch',
            enabled: false,
            name: '@kelivo/fetch',
            transport: McpTransportType.inmemory,
          ).toJson(),
          McpServerConfig(
            id: 'docs',
            enabled: false,
            name: 'Docs',
            transport: McpTransportType.http,
            url: 'https://docs.example.test/mcp',
            tools: <McpToolConfig>[
              McpToolConfig(enabled: true, name: 'lookup'),
            ],
          ).toJson(),
        ]),
      );
      final provider = McpProvider(preferences: first.preferences);
      addTearDown(provider.dispose);
      await _waitUntil(() => provider.servers.length == 2);

      final searchAdd = provider.addServer(
        enabled: false,
        name: 'Search',
        transport: McpTransportType.http,
        url: 'https://search.example.test/mcp',
      );
      final archiveAdd = provider.addServer(
        enabled: false,
        name: 'Archive',
        transport: McpTransportType.http,
        url: 'https://archive.example.test/mcp',
      );
      final ids = await Future.wait(<Future<String>>[searchAdd, archiveAdd]);

      expect(provider.getById(ids[0])?.name, 'Search');
      expect(provider.getById(ids[1])?.name, 'Archive');

      final logsId = await provider.addServer(
        enabled: false,
        name: 'Logs',
        transport: McpTransportType.http,
        url: 'https://logs.example.test/mcp',
      );
      await provider.updateServer(
        provider
            .getById('docs')!
            .copyWith(
              tools: <McpToolConfig>[
                McpToolConfig(enabled: true, name: 'lookup'),
                McpToolConfig(enabled: true, name: 'search'),
              ],
            ),
      );
      expect(provider.getById('docs')?.tools, hasLength(2));
      final staleRename = provider.getById('docs')!.copyWith(name: 'Docs v2');
      await provider.setToolEnabled('docs', 'lookup', false);
      await provider.updateServerMetadata(staleRename);

      expect(provider.getById('docs')?.name, 'Docs v2');
      expect(
        provider
            .getById('docs')
            ?.tools
            .singleWhere((tool) => tool.name == 'lookup')
            .enabled,
        isFalse,
      );

      await Future.wait(<Future<void>>[
        provider.removeServer('docs'),
        provider.reorderServers(4, 2),
      ]);
      expect(provider.servers.map((server) => server.id), <String>[
        'kelivo_fetch',
        logsId,
        ids[0],
        ids[1],
      ]);

      await first.close();
      final reopened = await fixture.open();
      final restored = McpProvider(preferences: reopened.preferences);
      addTearDown(restored.dispose);
      await _waitUntil(() => restored.servers.length == 4);

      expect(restored.getById(ids[0])?.name, 'Search');
      expect(restored.getById(ids[1])?.name, 'Archive');
      expect(restored.getById(logsId)?.name, 'Logs');
      await reopened.close();
    },
  );
}

Future<void> _nextNotification(ChangeNotifier notifier) {
  final completer = Completer<void>();
  void listener() {
    notifier.removeListener(listener);
    if (!completer.isCompleted) completer.complete();
  }

  notifier.addListener(listener);
  return completer.future.timeout(const Duration(seconds: 2));
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for provider state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

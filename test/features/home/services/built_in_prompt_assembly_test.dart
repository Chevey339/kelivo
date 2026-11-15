import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/business_data.dart';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/instruction_injection.dart';
import 'package:Kelivo/core/models/workspace_binding.dart';
import 'package:Kelivo/core/models/world_book.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/instruction_injection_provider.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/providers/workspace_provider.dart';
import 'package:Kelivo/core/providers/world_book_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/search/search_tool_service.dart';
import 'package:Kelivo/core/services/skills/skills_service.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/claude_test_api.dart' show FakePathProviderPlatform;
import '../../../support/fake_workspace_runtime.dart';

class _ChatController extends Fake implements ChatController {}

class _StreamController extends Fake implements stream.StreamController {}

class _Runtime extends FakeWorkspaceRuntime {
  @override
  Future<RuntimeStatus> status() async =>
      const RuntimeStatus(ready: true, engine: 'proot', sandboxed: true);
}

String systemText(UnprocessedRequestContext request) =>
    request.apiMessages.singleWhere((m) => m['role'] == 'system')['content']
        as String;

// Include every model-facing description, including nested parameter schemas.
// Labels make the snapshots readable and are excluded from the character counts.
Map<String, String> descriptions(List<Map<String, dynamic>> tools) {
  final result = <String, String>{};
  void visit(String path, Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key == 'description' && entry.value is String) {
          result[path] = entry.value as String;
        } else {
          visit('$path.${entry.key}', entry.value);
        }
      }
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        visit('$path[$i]', value[i]);
      }
    }
  }

  for (final tool in tools) {
    final fn = tool['function'] as Map;
    visit(fn['name'] as String, fn);
  }
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late Directory directory;
  late SettingsProvider settings;
  late WorkspaceProvider workspaces;
  late SkillsService skills;
  late WorldBookProvider books;
  late InstructionInjectionProvider instructions;
  late ChatService chat;
  late Conversation bound;
  late MessageGenerationService generation;
  const persona = 'You are a careful editor.';
  const plain = Assistant(
    id: 'plain',
    name: 'Plain',
    systemPrompt: persona,
    skillIds: [],
  );
  const full = Assistant(
    id: 'full',
    name: 'Full',
    systemPrompt: persona,
    enableMemory: true,
    allowPastConversationRecall: true,
    searchEnabled: true,
    skillIds: ['proofread'],
  );

  setUp(() async {
    harness = await createBusinessTestHarness(
      initial: {
        BusinessEntityKind.assistant.sourceKey: jsonEncode([
          full.toJson(),
          plain.toJson(),
        ]),
      },
    );
    directory = await Directory.systemTemp.createTemp('kelivo-prompt-');
    final paths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = FakePathProviderPlatform(directory.path);
    addTearDown(() async {
      PathProviderPlatform.instance = paths;
      await directory.delete(recursive: true);
    });
    final store = ExtensionEntityStore(harness.database);
    settings = SettingsProvider(harness.preferences);
    workspaces = WorkspaceProvider(store: store);
    skills = SkillsService(
      store: store,
      skillsDirectory: Directory('${directory.path}/skills'),
    );
    books = WorldBookProvider(preferences: harness.preferences);
    instructions = InstructionInjectionProvider(
      preferences: harness.preferences,
    );
    chat = ChatService(
      existingRepository: ChatDatabaseRepository(harness.database),
    );
    await chat.init();
    await settings.loaded;
    await skills.importFromText(
      '---\nname: proofread\ndescription: Check a document for typos.\n---\nRead the provided document.',
    );
    final workspace = await workspaces.create(name: 'Editorial');
    chat.newConversationExtras = (_) => WorkspaceBinding(
      workspaceId: workspace.id,
      cwd: '/workspace/editorial',
    ).applyTo({});
    bound = await chat.createConversation(assistantId: full.id);
    await instructions.initialize();
    await instructions.add(
      const InstructionInjection(
        id: 'brief',
        title: 'Brief',
        prompt: 'Use short paragraphs.',
      ),
    );
    await instructions.setActiveIds(['brief'], assistantId: full.id);
    await books.initialize();
  });
  tearDown(() async {
    skills.dispose();
    workspaces.dispose();
    books.dispose();
    instructions.dispose();
    settings.dispose();
    await chat.close();
    await harness.close();
  });

  Future<void> mount(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: workspaces),
          ChangeNotifierProvider.value(value: skills),
          ChangeNotifierProvider.value(value: instructions),
          ChangeNotifierProvider.value(value: books),
          ChangeNotifierProvider.value(value: chat),
          ChangeNotifierProvider(
            create: (_) => WorkspaceRuntimeProvider()..register(_Runtime()),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(create: (_) => McpToolService()),
          ChangeNotifierProvider(
            create: (_) => McpProvider(preferences: harness.preferences),
          ),
          ChangeNotifierProvider(
            create: (_) => AssistantProvider(preferences: harness.preferences),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.runAsync(() => context.read<AssistantProvider>().loaded);
    final builder = MessageBuilderService(
      chatService: chat,
      contextProvider: context,
    );
    final streams = _StreamController();
    generation = MessageGenerationService(
      chatService: chat,
      messageBuilderService: builder,
      streamController: streams,
      contextProvider: context,
      generationController: GenerationController(
        chatService: chat,
        chatController: _ChatController(),
        streamController: streams,
        messageBuilderService: builder,
        contextProvider: context,
        onStateChanged: () {},
        getTitleForLocale: (_) => 'Test',
      ),
    );
  }

  Future<UnprocessedRequestContext> assemble(
    Assistant assistant,
    List<String> history, {
    bool workspace = false,
  }) => generation.assembleUnprocessedRequestContext(
    messages: [
      for (final text in history)
        ChatMessage(role: 'user', content: text, conversationId: bound.id),
    ],
    versionSelections: {},
    currentConversation: workspace ? bound : null,
    settings: settings,
    assistant: assistant,
    assistantId: assistant.id,
    providerKey: 'openai',
    modelId: 'gpt-4.1',
    syncWorkspaceAttachments: false,
  );

  for (final lang in ['zh', 'en']) {
    testWidgets('$lang system and tool descriptions match the request golden', (
      tester,
    ) async {
      await mount(tester);
      await tester.runAsync(() async {
        await settings.setAppLocale(const Locale('zh'));
        await settings.setMemoryPromptLang(lang == 'zh' ? 'auto' : 'en');
        final enabled = await assemble(full, [
          'Start editing.',
        ], workspace: true);
        final system = systemText(enabled);
        final tools = descriptions(enabled.toolDefs);
        expect(
          tools.keys,
          containsAll([
            'search_web',
            'memory_read',
            'chat_search',
            'shell',
            'edit_file',
            'view_image',
          ]),
        );
        expect(system, contains('/skills/proofread/SKILL.md'));
        final snapshot = [
          system,
          for (final entry in tools.entries) '[${entry.key}]\n${entry.value}',
        ].join('\n\n');
        final file = File(
          'test/features/home/services/fixtures/built_in_prompts_$lang.txt',
        );
        if (autoUpdateGoldenFiles) {
          await file.parent.create(recursive: true);
          await file.writeAsString('$snapshot\n');
        }
        final expected = (await file.readAsString()).replaceAll('\r\n', '\n');
        expect('$snapshot\n', expected);
        final toolChars = tools.values.fold(0, (n, s) => n + s.runes.length);
        // Same fixture on 00a2b7de: (system, all tool descriptions), in characters.
        final (oldSystem, oldTools) = lang == 'zh'
            ? (3092, 6217)
            : (4403, 8126);
        final saved = oldSystem + oldTools - system.runes.length - toolChars;
        final charsPerToken = lang == 'zh' ? 3 : 4;
        debugPrint(
          '$lang (system + tool descriptions): $oldSystem + $oldTools → '
          '${system.runes.length} + $toolChars characters; saved $saved '
          '(~${(saved / charsPerToken).round()} tokens at $charsPerToken chars/token, estimated). '
          'All off: ${persona.length} + 0 characters in both versions.',
        );
        final disabled = await assemble(plain, ['Hi.']);
        expect(systemText(disabled), persona);
        expect(disabled.toolDefs, isEmpty);
        final search = await assemble(plain.copyWith(searchEnabled: true), [
          'Look it up.',
        ]);
        expect(
          systemText(search),
          '$persona\n\n${SearchToolService.getSystemPrompt()}',
        );
        expect(
          descriptions(search.toolDefs)['search_web'],
          endsWith(
            'Cite supporting results with [cite:id] using the exact id from the tool result.',
          ),
        );
      });
    });
  }

  testWidgets(
    'stable system and tools survive new turns and only selected World Book positions change',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        const first = ['Please edit.'];
        const next = [...first, 'Continue.'];
        final stable = await assemble(full, first, workspace: true);
        final prefix = systemText(stable);
        await books.addBook(
          const WorldBook(
            id: 'positions',
            entries: [
              WorldBookEntry(
                id: 'after',
                content: 'AFTER',
                keywords: ['lighthouse'],
              ),
              WorldBookEntry(
                id: 'before',
                content: 'BEFORE',
                keywords: ['preface'],
                position: WorldBookInjectionPosition.beforeSystemPrompt,
              ),
              WorldBookEntry(
                id: 'path',
                content: 'PATH TRIGGER',
                keywords: ['/workspace/editorial'],
              ),
              WorldBookEntry(
                id: 'skill',
                content: 'SKILL TRIGGER',
                keywords: ['proofread'],
              ),
            ],
          ),
        );
        await books.setActiveBookIds(['positions'], assistantId: full.id);
        final second = await assemble(full, next, workspace: true);
        expect(systemText(second), prefix);
        expect(second.toolDefs, stable.toolDefs);
        final third = await assemble(full, [
          ...next,
          'lighthouse',
        ], workspace: true);
        expect(systemText(third), '$prefix\n\nAFTER');
        expect(third.toolDefs, stable.toolDefs);
        final both = await assemble(full, [
          ...next,
          'preface lighthouse',
        ], workspace: true);
        expect(systemText(both), 'BEFORE\n$prefix\n\nAFTER');
        final tags = ContextSegmentTags.read(both.apiMessages.first);
        expect(tags.map((tag) => tag['source']), [
          for (final source in [
            ContextSource.worldBook,
            ContextSource.systemPrompt,
            ContextSource.memoryRules,
            ContextSource.searchPrompt,
            ContextSource.instructionInjection,
            ContextSource.workspace,
            ContextSource.skills,
            ContextSource.worldBook,
          ])
            source.wireName,
        ]);
        expect(tags.first['meta'], {'position': 'BEFORE_SYSTEM_PROMPT'});
        expect(tags.last['meta'], {'position': 'AFTER_SYSTEM_PROMPT'});
        expect(
          tags.fold(0, (n, tag) => n + (tag['length'] as int)),
          systemText(both).length,
        );

        final noSkills = full.copyWith(skillIds: []);
        final workspaceOnly = await assemble(noSkills, first, workspace: true);
        final workspaceAndAfter = await assemble(noSkills, [
          'lighthouse',
        ], workspace: true);
        expect(systemText(workspaceOnly), endsWith('</workspace>'));
        expect(
          systemText(workspaceAndAfter),
          '${systemText(workspaceOnly)}\n\nAFTER',
        );

        final reference = await generation.compressionReferenceText(
          conversationId: bound.id,
          modelId: 'gpt-4.1',
          assistantId: full.id,
          messages: [
            ChatMessage(
              role: 'user',
              content: 'preface lighthouse',
              conversationId: bound.id,
            ),
          ],
          promptTime: DateTime.utc(2026),
        );
        final texts = ['BEFORE', persona, 'Use short paragraphs.', 'AFTER'];
        var lastIndex = -1;
        for (final text in texts) {
          final index = reference.indexOf(text);
          expect(index, greaterThan(lastIndex), reason: text);
          lastIndex = index;
        }
        expect(reference, isNot(contains('<workspace>')));
        expect(reference, isNot(contains('<available_skills>')));
        await books.setActiveBookIds(['positions'], assistantId: plain.id);
        final justAfter = await assemble(plain.copyWith(systemPrompt: ''), [
          'lighthouse',
        ]);
        expect(systemText(justAfter), 'AFTER');
        final noWorkspace = await assemble(plain, ['preface lighthouse']);
        expect(systemText(noWorkspace), 'BEFORE\n$persona\nAFTER');
      });
    },
  );
  testWidgets(
    'an empty history keeps the system together before bottom-of-chat lore',
    (tester) async {
      await mount(tester);
      await tester.runAsync(() async {
        final base = await assemble(full, [], workspace: true);
        await books.addBook(
          const WorldBook(
            id: 'empty',
            entries: [
              WorldBookEntry(
                id: 'after',
                content: 'AFTER',
                constantActive: true,
              ),
              WorldBookEntry(
                id: 'bottom',
                content: 'BOTTOM',
                constantActive: true,
                position: WorldBookInjectionPosition.bottomOfChat,
              ),
            ],
          ),
        );
        await books.setActiveBookIds(['empty'], assistantId: full.id);
        final request = await assemble(full, [], workspace: true);
        expect(request.apiMessages.map((m) => m['role']), ['system', 'user']);
        expect(systemText(request), '${systemText(base)}\n\nAFTER');
        expect(
          request.apiMessages.last['content'],
          '<system>\nBOTTOM\n</system>',
        );
      });
    },
  );
}

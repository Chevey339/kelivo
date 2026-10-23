import 'dart:async';
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/composer_mention.dart';
import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/providers/mcp_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_tool_service.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/core/services/backup/restore_startup_gate.dart';
import 'package:Kelivo/core/services/backup/restore_receipt.dart';
import 'dart:io';

import '../../../support/business_test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/features/home/widgets/message_list_view.dart';
import 'package:Kelivo/features/chat/widgets/forwarded_messages_card.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/chat_controller.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/features/home/widgets/forward_messages_sheet.dart';
import 'package:Kelivo/features/home/widgets/chat_selection_delete_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/app_directories.dart';

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

class _SpyChatDatabaseRepository extends ChatDatabaseRepository {
  _SpyChatDatabaseRepository(super.db, {super.databaseFile});

  Completer<void>? gateMessageIds;
  int getMessageIdsCalls = 0;
  final List<({int start, int limit})> rangeQueries =
      <({int start, int limit})>[];

  @override
  Future<List<String>> getMessageIds(String conversationId) async {
    getMessageIdsCalls += 1;
    final gate = gateMessageIds;
    if (gate != null) await gate.future;
    return super.getMessageIds(conversationId);
  }

  @override
  Future<List<ChatMessage>> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) async {
    rangeQueries.add((start: start, limit: limit));
    return super.getMessagesRange(conversationId, start: start, limit: limit);
  }
}

class _SelectionFakeChatService extends ChatService {
  _SelectionFakeChatService({
    required this.conversation,
    required List<ChatMessage> seededMessages,
    this.versionSelections = const <String, int>{},
  }) : _messages = seededMessages;

  final Conversation conversation;
  final List<ChatMessage> _messages;
  final Map<String, int> versionSelections;
  final List<({int start, int limit})> rangeQueries =
      <({int start, int limit})>[];
  int fullLoadCalls = 0;
  int getMessageIdsCalls = 0;
  Set<String>? lastDeletedIds;
  bool? lastDeleteAllVersions;
  Completer<void>? gateProjections;
  Object? projectionError;

  List<ChatMessage> _activeProjections() {
    final grouped = <String, List<ChatMessage>>{};
    for (final message in _messages) {
      grouped.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final active = <ChatMessage>[];
    for (final entry in grouped.entries) {
      final selected = versionSelections[entry.key];
      active.add(
        entry.value.firstWhere(
          (message) => selected == null
              ? identical(message, entry.value.last)
              : message.version == selected,
          orElse: () => entry.value.last,
        ),
      );
    }
    return active;
  }

  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;

  @override
  int getMessageCount(String conversationId) => -1;

  @override
  bool isMessageCountKnown(String conversationId) => false;

  @override
  bool debugHasMessageOrderSkeleton(String conversationId) => false;

  @override
  Future<List<String>> getMessageIds(String conversationId) async {
    getMessageIdsCalls += 1;
    return _messages.map((m) => m.id).toList(growable: false);
  }

  @override
  List<ChatMessage> getMessagesRange(
    String conversationId, {
    required int start,
    required int limit,
  }) {
    rangeQueries.add((start: start, limit: limit));
    if (limit < 0) return const <ChatMessage>[];
    final end = (start + limit).clamp(0, _messages.length);
    return _messages.sublist(start.clamp(0, _messages.length), end);
  }

  @override
  Future<List<ChatMessage>> loadMessages(String conversationId) async {
    fullLoadCalls += 1;
    return List<ChatMessage>.of(_messages);
  }

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    final grouped = <String, List<ChatMessage>>{};
    for (final message in _messages) {
      grouped.putIfAbsent(message.groupId ?? message.id, () => []).add(message);
    }
    final active = _activeProjections();
    final start = (active.length - limit).clamp(0, active.length);
    final selected = active.sublist(start);
    final timestamp = DateTime(2026, 8, 10);
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision: 0,
      contextStartRevisionId: null,
      slots: [
        for (final (offset, message) in selected.indexed)
          LoadedTimelineSlot(
            identity: ActiveTimelineSlot(
              slotId: message.groupId ?? message.id,
              revisionId: message.id,
              parentRevisionId: null,
              role: message.role,
              createdAt: timestamp,
              updatedAt: timestamp,
              finalizedAt: timestamp,
              versionCount: grouped[message.groupId ?? message.id]!.length,
              logicalIndex: start + offset,
            ),
            message: message,
          ),
      ],
      hasMoreBefore: start > 0,
      hasMoreAfter: false,
      totalSlotCount: active.length,
    );
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      Map<String, int>.from(versionSelections);

  @override
  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) {
    final targets = groupIds.toSet();
    return _messages
        .where((m) => targets.contains(m.groupId ?? m.id))
        .toList(growable: false);
  }

  @override
  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => getMessagesForGroups(conversationId, groupIds);

  @override
  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => {for (final id in groupIds) id: 0};

  @override
  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => getFirstMessageIndicesForGroups(conversationId, groupIds);

  @override
  Future<List<ChatMessage>> loadMessagesByIds(List<String> ids) async {
    final wanted = ids.toSet();
    return _messages.where((m) => wanted.contains(m.id)).toList();
  }

  @override
  Future<Set<String>> loadMessageIdsForGroups(
    String conversationId,
    Set<String> groupIds,
  ) async {
    return {
      for (final message in _messages)
        if (groupIds.contains(message.groupId ?? message.id)) message.id,
    };
  }

  @override
  Future<List<ChatMessage>> loadSelectedMessageProjections(
    String conversationId,
  ) async {
    // Collapsed selected projections — not a full ID skeleton / getMessageIds.
    fullLoadCalls += 1;
    final error = projectionError;
    projectionError = null;
    final gate = gateProjections;
    if (gate != null) await gate.future;
    if (error != null) throw error;
    return _activeProjections();
  }

  @override
  Future<Set<String>> deleteMessages({
    required String conversationId,
    required Set<String> messageIds,
    required Map<String, int?> versionSelectionChanges,
  }) async {
    lastDeletedIds = Set<String>.of(messageIds);
    return lastDeletedIds!;
  }
}

ChatMessage _msg({
  required String id,
  required String role,
  String? groupId,
  int version = 0,
  String conversationId = 'conversation-1',
}) {
  return ChatMessage(
    id: id,
    role: role,
    content: id,
    conversationId: conversationId,
    groupId: groupId ?? id,
    version: version,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 200 && !ready(); attempt++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue, reason: 'Async controller operation did not finish');
  await tester.pumpAndSettle();
}

Future<void> _pumpIoAndFramesUntil(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var attempt = 0; attempt < 80 && !ready(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    ready(),
    isTrue,
    reason:
        'Public operation did not finish within bounded I/O and frame advancement',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'mentioned reply keeps its author through forwarding restart and ZIP restore',
    (tester) async {
      final previousPaths = PathProviderPlatform.instance;
      final previousHttp = HttpOverrides.current;
      final temp = Directory.systemTemp.createTempSync('forward_sender_');
      final restoredRoot = Directory.systemTemp.createTempSync(
        'forward_sender_restore_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(temp.path);
      HttpOverrides.global = null;
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      final service = ChatService();
      HttpServer? server;
      final requests = <Map<String, dynamic>>[];
      late SettingsProvider settings;
      late AssistantProvider assistants;
      late String recipientId;
      late Conversation source;
      late Conversation target;
      HomePageController? controller;
      try {
        await tester.runAsync(() async {
          server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          server!.listen((request) async {
            final body =
                jsonDecode(await utf8.decoder.bind(request).join())
                    as Map<String, dynamic>;
            requests.add(body);
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.write(
              'data: ${jsonEncode({
                'choices': [
                  {
                    'index': 0,
                    'delta': {'role': 'assistant', 'content': 'Review from B'},
                    'finish_reason': 'stop',
                  },
                ],
              })}\n\ndata: [DONE]\n\n',
            );
            await request.response.close();
          });
          settings = SettingsProvider(createBusinessTestPreferences());
          await settings.loaded;
          await settings.disableTitleGeneration();
          await settings.disableSuggestionGeneration();
          await settings.setProviderConfig(
            'SiliconFlow',
            ProviderConfig(
              id: 'SiliconFlow',
              enabled: true,
              name: 'Local fixture',
              apiKey: 'fixture',
              baseUrl: 'http://127.0.0.1:${server!.port}/v1',
              providerType: ProviderKind.openai,
            ),
          );
          await settings.setCurrentModel('SiliconFlow', 'model-a');
          assistants = AssistantProvider(
            preferences: createBusinessTestPreferences(),
          );
          await assistants.loaded;
          final defaultId = await assistants.addAssistant(name: 'Default A');
          await assistants.setCurrentAssistant(defaultId);
          await assistants.updateAssistant(
            assistants.getById(defaultId)!.copyWith(avatar: 'emoji:A'),
          );
          recipientId = await assistants.addAssistant(name: 'Reviewer B');
          await assistants.updateAssistant(
            assistants
                .getById(recipientId)!
                .copyWith(
                  chatModelProvider: 'SiliconFlow',
                  chatModelId: 'model-b',
                  avatar: 'emoji:B',
                ),
          );
          await service.init();
          source = await service.createConversation(
            title: 'Source',
            assistantId: defaultId,
          );
          target = await service.createConversation(title: 'Destination');
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<AssistantProvider>.value(
                value: assistants,
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    UserProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) =>
                    TtsProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(
                create: (_) => AskUserInteractionService(),
              ),
              ChangeNotifierProvider(create: (_) => ToolApprovalService()),
              ChangeNotifierProvider(
                create: (_) =>
                    McpProvider(preferences: createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider(create: (_) => McpToolService()),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                showTimeline: true,
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await controller!.chatController.setCurrentConversationAndLoad(
            source,
          );
          final result = await controller!.sendMessage(
            ChatInputData(
              text: '@Reviewer B review',
              recipientAssistantId: recipientId,
              mention: ComposerMention(
                assistantId: recipientId,
                label: 'Reviewer B',
                start: 0,
              ),
            ),
          );
          expect(result, ChatInputSubmissionResult.sent);
        });
        await _pumpIoAndFramesUntil(
          tester,
          () =>
              requests.isNotEmpty &&
              !controller!.chatController.isConversationLoading(source.id),
        );
        expect(requests.single['model'], 'model-b');
        final reply = controller!.chatController.messages.last;
        expect(reply.content, 'Review from B');
        expect(reply.senderId, recipientId);
        expect(reply.senderName, 'Reviewer B');
        expect(reply.senderAvatar, 'emoji:B');
        // Configuration changes before forwarding must not rewrite history.
        await tester.runAsync(() async {
          await assistants.updateAssistant(
            assistants
                .getById(recipientId)!
                .copyWith(name: 'Renamed B', avatar: 'emoji:C'),
          );
          await assistants.deleteAssistant(recipientId);
        });
        controller!.startMessageSelection(
          messageIndex: 1,
          messageList: controller!.chatController.collapsedMessages,
          mode: ChatSelectionMode.forward,
        );
        await _pumpIoAndFramesUntil(
          tester,
          () => controller!.selectedItems.length == 2,
        );
        late Future<void> forwarding;
        var done = false;
        await tester.runAsync(() async {
          forwarding = controller!.forwardSelectedMessages();
          unawaited(
            forwarding.then((_) {
              done = true;
            }),
          );
        });
        await _pumpIoAndFramesUntil(
          tester,
          () => find.byType(ForwardMessagesSheet).evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Destination'));
        await tester.pump();
        await tester.tap(find.text('Forward').last);
        await _pumpIoAndFramesUntil(tester, () => done);
        await tester.runAsync(() => forwarding);
        await tester.pumpAndSettle();
        final card = find.descendant(
          of: find.byType(MessageListView),
          matching: find.byType(ForwardedMessagesCard),
        );
        expect(card, findsOneWidget);
        expect(
          find.textContaining('Reviewer B', findRichText: true),
          findsWidgets,
        );
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(ForwardedMessagesDetails), findsOneWidget);
        expect(find.text('Reviewer B'), findsOneWidget);
        expect(find.text('Default A'), findsNothing);
        expect(find.text('Review from B'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          void check(List<ChatMessage> messages) {
            final record = messages.single.parts
                .whereType<ForwardedMessagesPart>()
                .single;
            expect(record.messages, hasLength(2));
            expect(record.messages.last.author, 'Reviewer B');
            expect(record.messages.last.authorId, recipientId);
            expect(record.messages.last.authorAvatar, 'emoji:B');
            expect(record.messages.last.text, 'Review from B');
          }

          await service.close();
          final reopened = ChatService();
          await reopened.init();
          File? archive;
          final business = AppDatabase.open(
            file: File('${temp.path}/business.sqlite'),
          );
          try {
            check(await reopened.loadMessages(target.id));
            PackageInfo.setMockInitialValues(
              appName: 'Kelivo',
              packageName: 'Kelivo',
              version: '1-test',
              buildNumber: '1',
              buildSignature: 'test',
            );
            archive = await DataSync(
              businessRepository: BusinessRepository(business),
              chatService: reopened,
            ).prepareBackupFile(const WebDavConfig());
          } finally {
            await reopened.close();
            await business.close();
          }
          try {
            PathProviderPlatform.instance = _FakePathProviderPlatform(
              restoredRoot.path,
            );
            final restoreDb = AppDatabase.open(
              file: File('${restoredRoot.path}/business.sqlite'),
            );
            try {
              await DataSync(
                businessRepository: BusinessRepository(restoreDb),
                chatService: ChatService(),
              ).restoreFromLocalFile(archive, const WebDavConfig());
            } finally {
              await restoreDb.close();
            }
            final receipt =
                await RestoreStartupGate.recoverAndRequireBusinessReady(
                  appDataDirectory: restoredRoot,
                );
            expect(receipt?.state, RestoreReceiptState.committed);
            final restored = ChatService();
            await restored.init();
            try {
              check(await restored.loadMessages(target.id));
              final original = (await restored.loadMessages(source.id)).last;
              expect(original.senderId, recipientId);
              expect(original.senderName, 'Reviewer B');
              expect(original.senderAvatar, 'emoji:B');
            } finally {
              await restored.close();
            }
          } finally {
            await DataSync.cleanupTemporaryBackupFile(archive);
          }
        });
        expect(requests, hasLength(1));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await server?.close(force: true);
          await service.close();
          await Hive.close();
          await temp.delete(recursive: true);
          await restoredRoot.delete(recursive: true);
        });
        settings.dispose();
        assistants.dispose();
        PathProviderPlatform.instance = previousPaths;
        HttpOverrides.global = previousHttp;
        tester.view.reset();
      }
    },
  );

  testWidgets(
    'forward authors distinguish legacy messages from missing sender snapshots',
    (tester) async {
      late AssistantProvider assistants;
      late String defaultId;
      late String recipientId;
      await tester.runAsync(() async {
        assistants = AssistantProvider(
          preferences: createBusinessTestPreferences(),
        );
        await assistants.loaded;
        defaultId = await assistants.addAssistant(name: 'Default A');
        await assistants.updateAssistant(
          assistants.getById(defaultId)!.copyWith(avatar: 'emoji:A'),
        );
        recipientId = await assistants.addAssistant(name: 'Current B');
        await assistants.updateAssistant(
          assistants.getById(recipientId)!.copyWith(avatar: 'emoji:B'),
        );
      });
      final messages = [
        ChatMessage(
          id: 'question',
          conversationId: 'source',
          role: 'user',
          content: 'Question',
        ),
        ChatMessage(
          id: 'legacy',
          conversationId: 'source',
          role: 'assistant',
          content: 'Legacy',
        ),
        ChatMessage(
          id: 'snapshot',
          conversationId: 'source',
          role: 'assistant',
          content: 'Snapshot',
          senderId: recipientId,
          senderName: 'Original B',
        ),
        ChatMessage(
          id: 'lookup',
          conversationId: 'source',
          role: 'assistant',
          content: 'Lookup',
          senderId: recipientId,
        ),
        ChatMessage(
          id: 'deleted',
          conversationId: 'source',
          role: 'assistant',
          content: 'Deleted',
          senderId: 'deleted-b',
        ),
      ];
      final service = _SelectionFakeChatService(
        conversation: Conversation(
          id: 'source',
          title: 'Source',
          assistantId: defaultId,
        ),
        seededMessages: messages,
      );
      HomePageController? controller;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<AssistantProvider>.value(value: assistants),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(onCreated: (value) => controller = value),
          ),
        ),
      );
      await controller!.chatController.setCurrentConversationAndLoad(
        service.conversation,
      );
      controller!.startMessageSelection(
        messageIndex: 0,
        messageList: messages,
        mode: ChatSelectionMode.forward,
      );
      await tester.pumpAndSettle();
      final preview = controller!.forwardSelectedMessages();
      await tester.pumpAndSettle();
      final sheet = tester.widget<ForwardMessagesSheet>(
        find.byType(ForwardMessagesSheet),
      );
      final record = sheet.record;
      expect(record.messages[1].author, 'Default A');
      expect(record.messages[1].authorId, defaultId);
      expect(record.messages[1].authorAvatar, 'emoji:A');
      expect(record.messages[2].author, 'Original B');
      expect(record.messages[2].authorId, recipientId);
      expect(record.messages[2].authorAvatar, isNull);
      expect(record.messages[3].author, 'Current B');
      expect(record.messages[3].authorId, recipientId);
      expect(record.messages[3].authorAvatar, isNull);
      expect(
        record.messages[4].author,
        AppLocalizations.of(
          tester.element(find.byType(ForwardMessagesSheet)),
        )!.homePageDefaultAssistant,
      );
      expect(record.messages[4].authorId, 'deleted-b');
      expect(record.messages[4].authorAvatar, isNull);
      Navigator.of(tester.element(find.byType(ForwardMessagesSheet))).pop();
      await tester.pumpAndSettle();
      await preview;
      await tester.pumpWidget(const SizedBox.shrink());
      assistants.dispose();
    },
  );

  for (final scenario in [
    (
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      invalidateFirst: false,
    ),
    (
      platform: TargetPlatform.android,
      size: const Size(390, 844),
      invalidateFirst: true,
    ),
    (
      platform: TargetPlatform.macOS,
      size: const Size(1100, 800),
      invalidateFirst: false,
    ),
  ]) {
    testWidgets(
      'forward real timeline and attachments ${scenario.platform.name} invalidateFirst=${scenario.invalidateFirst}',
      (tester) async {
        final previousPlatform = debugDefaultTargetPlatformOverride;
        final previousPaths = PathProviderPlatform.instance;
        debugDefaultTargetPlatformOverride = scenario.platform;
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        final temp = Directory.systemTemp.createTempSync('forward_timeline_');
        final service = ChatService();
        PathProviderPlatform.instance = _FakePathProviderPlatform(temp.path);
        try {
          final image = File(
            'assets/icons/kelivo.png',
          ).copySync('${temp.path}/image.png');
          final document = File('${temp.path}/note.txt')
            ..writeAsStringSync('actual file bytes');
          final source = await tester.runAsync(() async {
            await service.init();
            final source = await service.createConversation(title: 'Source');
            await service.createConversation(title: 'Destination');
            await service.addMessage(
              conversationId: source.id,
              role: 'user',
              content: 'Question',
            );
            await service.addMessage(
              conversationId: source.id,
              role: 'assistant',
              senderId: 'reviewer-b',
              senderName: 'Reviewer B',
              senderAvatar: 'emoji:🔎',
              parts: [
                const TextPart(
                  '<think>hidden-private-reasoning</think>@B historical answer @全部',
                ),
                ImagePart(uri: image.path),
                FilePart(uri: document.path, name: 'note.txt'),
              ],
            );
            return source;
          });
          HomePageController? controller;
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) =>
                      SettingsProvider(createBusinessTestPreferences()),
                ),
                ChangeNotifierProvider(
                  create: (_) => AssistantProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
                ),
                ChangeNotifierProvider(
                  create: (_) => UserProvider(
                    preferences: createBusinessTestPreferences(),
                  ),
                ),
                ChangeNotifierProvider(
                  create: (_) =>
                      TtsProvider(preferences: createBusinessTestPreferences()),
                ),
                ChangeNotifierProvider(
                  create: (_) => AskUserInteractionService(),
                ),
                ChangeNotifierProvider(create: (_) => ToolApprovalService()),
                ChangeNotifierProvider<ChatService>.value(value: service),
              ],
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: _ControllerHarness(
                  showTimeline: true,
                  onCreated: (value) => controller = value,
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => controller!.chatController.setCurrentConversationAndLoad(
              source!,
            ),
          );
          await tester.pumpAndSettle();
          final target = service.getAllConversations().singleWhere(
            (c) => c.title == 'Destination',
          );

          Future<void> select() async {
            controller!.startMessageSelection(
              messageIndex: 1,
              messageList: controller!.chatController.collapsedMessages,
              mode: ChatSelectionMode.forward,
            );
            await _pumpIoAndFramesUntil(
              tester,
              () => controller!.selectedItems.length == 2,
            );
          }

          Future<void> send({required bool invalidate}) async {
            await select();
            late Future<void> forwarding;
            var finished = false;
            await tester.runAsync(() async {
              forwarding = controller!.forwardSelectedMessages();
              unawaited(
                forwarding.then<void>((_) {
                  finished = true;
                }),
              );
            });
            await _pumpIoAndFramesUntil(
              tester,
              () => find.byType(ForwardMessagesSheet).evaluate().isNotEmpty,
            );
            await tester.pumpAndSettle();
            if (invalidate) controller!.cancelSelection();
            await tester.ensureVisible(find.text('Destination'));
            await tester.tap(find.text('Destination'));
            await tester.pump();
            await tester.ensureVisible(find.text('Forward').last);
            await tester.tap(find.text('Forward').last);
            // Mobile switching awaits animations/endOfFrame as well as SQLite.
            await _pumpIoAndFramesUntil(tester, () => finished);
            await tester.runAsync(() => forwarding);
            await tester.pumpAndSettle();
          }

          if (scenario.invalidateFirst) {
            await send(invalidate: true);
            expect(
              await tester.runAsync(() => service.loadMessages(target.id)),
              isEmpty,
            );
            expect(controller!.currentConversation?.id, source!.id);
          }
          await send(invalidate: false);
          expect(controller!.currentConversation?.id, target.id);
          final result = await tester.runAsync(
            () => service.loadMessages(target.id),
          );
          expect(result, hasLength(1));
          final record = result!.single.parts
              .whereType<ForwardedMessagesPart>()
              .single;
          expect(record.messages.last.authorId, 'reviewer-b');
          expect(record.messages.last.author, 'Reviewer B');
          expect(record.messages.last.authorAvatar, 'emoji:🔎');
          expect(record.messages.map((message) => message.text), [
            'Question',
            '@B historical answer @全部',
          ]);
          expect(
            record.encodePayload(),
            isNot(contains('hidden-private-reasoning')),
          );
          expect(
            result.single.contextContent,
            isNot(contains('hidden-private-reasoning')),
          );
          expect(
            record.messages.last.parts.whereType<ImagePart>().single.uri,
            image.path,
          );
          expect(
            record.messages.last.parts.whereType<FilePart>().single.uri,
            document.path,
          );
          expect(find.byType(MessageListView), findsOneWidget);
          final card = find.descendant(
            of: find.byType(MessageListView),
            matching: find.byType(ForwardedMessagesCard),
          );
          expect(card, findsOneWidget);
          expect(find.byType(ExpansionTile), findsNothing);
          await tester.tap(card);
          await tester.pumpAndSettle();
          await _pumpIoAndFramesUntil(
            tester,
            () => tester
                .widgetList<RawImage>(find.byType(RawImage))
                .any((image) => image.image != null),
          );
          expect(find.byType(ForwardedMessagesDetails), findsOneWidget);
          expect(find.text('note.txt'), findsOneWidget);
          expect(find.text('Reviewer B'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          // Restore debug overrides before Flutter's end-of-test invariants.
          try {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(() async {
              await service.close();
              await Hive.close();
              await temp.delete(recursive: true);
            });
          } finally {
            PathProviderPlatform.instance = previousPaths;
            debugDefaultTargetPlatformOverride = previousPlatform;
            tester.view.reset();
          }
        }
      },
    );
  }

  testWidgets('forward selection keeps questions and selects the full suffix', (
    tester,
  ) async {
    final service = _SelectionFakeChatService(
      conversation: Conversation(id: 'conversation-1', title: 'Chat'),
      seededMessages: [
        _msg(id: 'u1', role: 'user'),
        _msg(id: 'a1', role: 'assistant'),
        _msg(id: 'b1', role: 'assistant'),
        _msg(id: 'u2', role: 'user'),
        _msg(id: 'a2', role: 'assistant'),
      ],
    );
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<ChatService>.value(value: service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );
    await controller!.chatController.setCurrentConversationAndLoad(
      service.conversation,
    );
    controller!.startMessageSelection(
      messageIndex: 0,
      messageList: [_msg(id: 'b1', role: 'assistant')],
      mode: ChatSelectionMode.forward,
    );
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u1', 'b1'});
    expect(controller!.lockedSelectionIds, {'u1'});
    service.projectionError = StateError('history unavailable');
    controller!.toggleSelection('a2', true);
    await tester.pumpAndSettle();
    expect(find.textContaining('history unavailable'), findsOneWidget);
    expect(controller!.selectedItems, {'u1', 'b1'});
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    controller!.toggleSelection('u1', false);
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u1', 'b1'});
    controller!.toggleSelection('a2', true);
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u1', 'b1', 'u2', 'a2'});
    controller!.toggleSelection('b1', false);
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u2', 'a2'});
    expect(controller!.lockedSelectionIds, {'u2'});
    controller!.toggleSelection('u1', true);
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u1', 'a1', 'b1', 'u2', 'a2'});
    final oldGate = Completer<void>();
    service.gateProjections = oldGate;
    service.projectionError = StateError('stale failure');
    controller!.toggleSelection('a2', false);
    await tester.pump();
    controller!.cancelSelection();
    service.gateProjections = null;
    controller!.startMessageSelection(
      messageIndex: 0,
      messageList: [_msg(id: 'a2', role: 'assistant')],
      mode: ChatSelectionMode.forward,
    );
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u2', 'a2'});
    oldGate.complete();
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u2', 'a2'});
    expect(find.textContaining('stale failure'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('forward preview waits for pending select all', (tester) async {
    final service = _SelectionFakeChatService(
      conversation: Conversation(id: 'conversation-1', title: 'Chat'),
      seededMessages: [
        _msg(id: 'u1', role: 'user'),
        _msg(id: 'a1', role: 'assistant'),
        _msg(id: 'u2', role: 'user'),
        _msg(id: 'a2', role: 'assistant'),
      ],
    );
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                UserProvider(preferences: createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<ChatService>.value(value: service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );
    await controller!.chatController.setCurrentConversationAndLoad(
      service.conversation,
    );
    controller!.startMessageSelection(
      messageIndex: 0,
      messageList: [_msg(id: 'a2', role: 'assistant')],
      mode: ChatSelectionMode.forward,
    );
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u2', 'a2'});
    final gate = Completer<void>();
    service.gateProjections = gate;
    controller!.toggleSelectAll();
    await tester.pump();
    service.gateProjections = null;
    final preview = controller!.forwardSelectedMessages();
    await tester.pumpAndSettle();
    expect(find.text('a2'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(controller!.selectedItems, {'u1', 'a1', 'u2', 'a2'});
    final picker = tester.widget<ForwardMessagesSheet>(
      find.byType(ForwardMessagesSheet),
    );
    expect(picker.record.messages.map((m) => m.text), ['u1', 'a1', 'u2', 'a2']);
    expect(find.text('a2'), findsNothing);
    Navigator.of(tester.element(find.byType(ForwardMessagesSheet))).pop();
    await tester.pumpAndSettle();
    await preview;
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'forward snapshot follows native reasoning and legacy visible text boundaries',
    (tester) async {
      final messages = [
        ChatMessage(
          id: 'user',
          conversationId: 'conversation-1',
          role: 'user',
          content: '<think>user literal</think>',
        ),
        ChatMessage(
          id: 'native',
          conversationId: 'conversation-1',
          role: 'assistant',
          content: '<think>visible native example</think>',
          reasoningText: 'private native',
        ),
        ChatMessage(
          id: 'segments',
          conversationId: 'conversation-1',
          role: 'assistant',
          content: '<think>visible segment example</think>',
          reasoningSegmentsJson: '{"segments":[{"text":"private segment"}]}',
        ),
        ChatMessage(
          id: 'split',
          conversationId: 'conversation-1',
          role: 'assistant',
          parts: const [
            TextPart(' before<th'),
            ImagePart(uri: 'https://example.com/a.png'),
            TextPart('ink>hidden-private'),
            FilePart(uri: 'https://example.com/a.txt', name: 'a.txt'),
            TextPart('-reasoning</think>after '),
          ],
        ),
        ChatMessage(
          id: 'unclosed',
          conversationId: 'conversation-1',
          role: 'assistant',
          content: 'literal <think>unclosed',
        ),
      ];
      final service = _SelectionFakeChatService(
        conversation: Conversation(id: 'conversation-1', title: 'Chat'),
        seededMessages: messages,
      );
      HomePageController? controller;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(onCreated: (value) => controller = value),
          ),
        ),
      );
      await controller!.chatController.setCurrentConversationAndLoad(
        service.conversation,
      );
      controller!.startMessageSelection(
        messageIndex: 0,
        messageList: messages,
        mode: ChatSelectionMode.forward,
      );
      await tester.pumpAndSettle();
      final preview = controller!.forwardSelectedMessages();
      await tester.pumpAndSettle();
      final record = tester
          .widget<ForwardMessagesSheet>(find.byType(ForwardMessagesSheet))
          .record;
      expect(record.messages[0].text, '<think>user literal</think>');
      expect(record.messages[1].text, '<think>visible native example</think>');
      expect(record.messages[2].text, '<think>visible segment example</think>');
      expect(record.messages[3].parts, const [
        TextPart('before'),
        ImagePart(uri: 'https://example.com/a.png'),
        FilePart(uri: 'https://example.com/a.txt', name: 'a.txt'),
        TextPart('after'),
      ]);
      expect(record.messages[4].text, 'literal <think>unclosed');
      expect(record.encodePayload(), isNot(contains('hidden-private')));
      expect(record.encodePayload(), isNot(contains('private native')));
      expect(record.encodePayload(), isNot(contains('private segment')));
      Navigator.of(tester.element(find.byType(ForwardMessagesSheet))).pop();
      await tester.pumpAndSettle();
      await preview;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('forward inversion and checkbox preserve user action order', (
    tester,
  ) async {
    final service = _SelectionFakeChatService(
      conversation: Conversation(id: 'conversation-1', title: 'Chat'),
      seededMessages: [
        _msg(id: 'u1', role: 'user'),
        _msg(id: 'a1', role: 'assistant'),
        _msg(id: 'u2', role: 'user'),
        _msg(id: 'a2', role: 'assistant'),
      ],
    );
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<ChatService>.value(value: service),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );
    await controller!.chatController.setCurrentConversationAndLoad(
      service.conversation,
    );
    controller!.startMessageSelection(
      messageIndex: 0,
      messageList: [_msg(id: 'a2', role: 'assistant')],
      mode: ChatSelectionMode.forward,
    );
    await tester.pumpAndSettle();
    final gate = Completer<void>();
    service.gateProjections = gate;
    controller!.invertSelection();
    await tester.pump();
    service.gateProjections = null;
    controller!.toggleSelection('a1', false);
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();
    // Invert selects u1/a1, then deselecting a1 leaves only u1.
    expect(controller!.selectedItems, {'u1'});
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final action in ['selectAll', 'toggleSelectAll', 'invertSelection']) {
    testWidgets(
      'forward $action recovers after failure and ignores old epoch',
      (tester) async {
        final service = _SelectionFakeChatService(
          conversation: Conversation(id: 'conversation-1', title: 'Chat'),
          seededMessages: [
            _msg(id: 'u1', role: 'user'),
            _msg(id: 'a1', role: 'assistant'),
            _msg(id: 'u2', role: 'user'),
            _msg(id: 'a2', role: 'assistant'),
          ],
        );
        HomePageController? controller;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await controller!.chatController.setCurrentConversationAndLoad(
          service.conversation,
        );
        void start() => controller!.startMessageSelection(
          messageIndex: 0,
          messageList: [_msg(id: 'a2', role: 'assistant')],
          mode: ChatSelectionMode.forward,
        );
        final apply = switch (action) {
          'selectAll' => controller!.selectAll,
          'toggleSelectAll' => controller!.toggleSelectAll,
          _ => controller!.invertSelection,
        };
        start();
        await tester.pumpAndSettle();
        service.projectionError = StateError('batch unavailable');
        apply();
        await tester.pumpAndSettle();
        expect(controller!.selectedItems, {'u2', 'a2'});
        expect(find.textContaining('batch unavailable'), findsOneWidget);
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        apply();
        await tester.pumpAndSettle();
        expect(
          controller!.selectedItems,
          action == 'invertSelection' ? {'u1', 'a1'} : {'u1', 'a1', 'u2', 'a2'},
        );
        for (final fails in [false, true]) {
          final gate = Completer<void>();
          service.gateProjections = gate;
          if (fails) service.projectionError = StateError('old batch failure');
          apply();
          await tester.pump();
          // Also queue a checkbox behind the delayed old operation.
          controller!.toggleSelection('a1', true);
          controller!.cancelSelection();
          service.gateProjections = null;
          start();
          await tester.pumpAndSettle();
          gate.complete();
          await tester.pumpAndSettle();
          expect(controller!.selectedItems, {'u2', 'a2'});
          expect(find.textContaining('old batch failure'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  group('multi-version selection without full order (Issue 4)', () {
    testWidgets(
      'two-version group shows both delete options after window+group preload',
      (tester) async {
        final service = _SelectionFakeChatService(
          conversation: Conversation(
            id: 'conversation-1',
            title: 'Chat',
            messageIds: const ['user-1', 'a-v0', 'a-v1'],
          ),
          seededMessages: [
            _msg(id: 'user-1', role: 'user'),
            _msg(id: 'a-v0', role: 'assistant', groupId: 'answer', version: 0),
            _msg(id: 'a-v1', role: 'assistant', groupId: 'answer', version: 1),
          ],
          versionSelections: const {'answer': 1},
        );
        HomePageController? controller;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await controller!.chatController.setCurrentConversationAndLoad(
          service.conversation,
        );
        await tester.pumpAndSettle();

        final collapsed = controller!.chatController
            .allCollapsedMessagesForCurrentConversation();
        expect(collapsed.map((m) => m.id), ['user-1', 'a-v1']);

        // Idle cache warm-up may call loadMessages after first paint; that is
        // unrelated to multi-version detection. Snapshot before selection.
        final loadsBeforeSelection = service.fullLoadCalls;

        controller!.startMessageSelection(
          messageIndex: 1,
          messageList: collapsed,
          mode: ChatSelectionMode.delete,
        );
        await tester.pump();

        expect(controller!.selectedMessagesIncludeMultipleVersions, isTrue);
        expect(service.rangeQueries.where((q) => q.limit < 0), isEmpty);
        expect(service.fullLoadCalls, loadsBeforeSelection);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: ChatSelectionDeleteBar(
                  hasMultiVersionSelection:
                      controller!.selectedMessagesIncludeMultipleVersions,
                  onDeleteCurrentVersions: () {},
                  onDeleteAllVersions: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete This Version'), findsOneWidget);
        expect(find.text('Delete All Versions'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('single-version selection shows normal delete only', (
      tester,
    ) async {
      final service = _SelectionFakeChatService(
        conversation: Conversation(
          id: 'conversation-1',
          title: 'Chat',
          messageIds: const ['user-1', 'assistant-1'],
        ),
        seededMessages: [
          _msg(id: 'user-1', role: 'user'),
          _msg(id: 'assistant-1', role: 'assistant'),
        ],
      );
      HomePageController? controller;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(onCreated: (value) => controller = value),
          ),
        ),
      );
      await controller!.chatController.setCurrentConversationAndLoad(
        service.conversation,
      );
      await tester.pumpAndSettle();

      final collapsed = controller!.chatController
          .allCollapsedMessagesForCurrentConversation();
      controller!.startMessageSelection(
        messageIndex: 1,
        messageList: collapsed,
        mode: ChatSelectionMode.delete,
      );
      expect(controller!.selectedMessagesIncludeMultipleVersions, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatSelectionDeleteBar(
              hasMultiVersionSelection:
                  controller!.selectedMessagesIncludeMultipleVersions,
              onDeleteCurrentVersions: () {},
              onDeleteAllVersions: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Delete This Version'), findsNothing);
      expect(find.text('Delete All Versions'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'delete current version vs delete all versions use async group paths',
      (tester) async {
        final service = _SelectionFakeChatService(
          conversation: Conversation(
            id: 'conversation-1',
            title: 'Chat',
            messageIds: const ['user-1', 'a-v0', 'a-v1'],
          ),
          seededMessages: [
            _msg(id: 'user-1', role: 'user'),
            _msg(id: 'a-v0', role: 'assistant', groupId: 'answer', version: 0),
            _msg(id: 'a-v1', role: 'assistant', groupId: 'answer', version: 1),
          ],
          versionSelections: const {'answer': 1},
        );
        HomePageController? controller;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await controller!.chatController.setCurrentConversationAndLoad(
          service.conversation,
        );
        await tester.pumpAndSettle();

        final collapsed = controller!.chatController
            .allCollapsedMessagesForCurrentConversation();
        controller!.startMessageSelection(
          messageIndex: 1,
          messageList: collapsed,
          mode: ChatSelectionMode.delete,
        );
        // startMessageSelection pairs the prior user turn; isolate the
        // multi-version assistant group so delete paths exercise group APIs.
        controller!.toggleSelection('user-1', false);

        await controller!.deleteSelectedMessages(deleteAllVersions: false);
        expect(service.lastDeletedIds, {'a-v1'});

        controller!.startMessageSelection(
          messageIndex: 1,
          messageList: collapsed,
          mode: ChatSelectionMode.delete,
        );
        controller!.toggleSelection('user-1', false);
        await controller!.deleteSelectedMessages(deleteAllVersions: true);
        expect(service.lastDeletedIds, {'a-v0', 'a-v1'});
        expect(service.rangeQueries.where((q) => q.limit < 0), isEmpty);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('selection UI covers full history projection (Issue B)', () {
    testWidgets(
      'select-all outside window keeps multi-version UI and allSelected truth',
      (tester) async {
        final seeded = <ChatMessage>[
          _msg(id: 'user-old', role: 'user'),
          _msg(
            id: 'a-v0',
            role: 'assistant',
            groupId: 'early-answer',
            version: 0,
          ),
          _msg(
            id: 'a-v1',
            role: 'assistant',
            groupId: 'early-answer',
            version: 1,
          ),
          for (var i = 0; i < 42; i++) ...[
            _msg(id: 'u-$i', role: 'user'),
            _msg(id: 'a-$i', role: 'assistant'),
          ],
        ];
        final service = _SelectionFakeChatService(
          conversation: Conversation(
            id: 'conversation-1',
            title: 'Long chat',
            messageIds: seeded.map((m) => m.id).toList(),
          ),
          seededMessages: seeded,
          versionSelections: const {'early-answer': 1},
        );

        HomePageController? controller;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await controller!.chatController.setCurrentConversationAndLoad(
          service.conversation,
        );
        await tester.pumpAndSettle();

        final windowIds = controller!.chatController.collapsedMessages
            .map((m) => m.id)
            .toSet();
        expect(windowIds.contains('a-v1'), isFalse);
        expect(windowIds.length, lessThanOrEqualTo(40));
        expect(
          controller!.chatController.collapsedMessages.length,
          lessThan(seeded.length),
        );

        final idsBeforeSelect = service.getMessageIdsCalls;
        final rangesBeforeSelect = service.rangeQueries.length;

        controller!.startMessageSelection(
          messageIndex: 0,
          messageList: controller!.chatController.collapsedMessages,
          mode: ChatSelectionMode.delete,
        );
        controller!.selectAll();
        await tester.pumpAndSettle();

        expect(controller!.selectedItems.contains('a-v1'), isTrue);
        expect(controller!.selectedMessagesIncludeMultipleVersions, isTrue);
        expect(controller!.allSelectableMessagesSelected, isTrue);

        // Mini-map style deselect of the out-of-window multi-version item.
        controller!.toggleSelection('a-v1', false);
        await tester.pump();
        expect(controller!.allSelectableMessagesSelected, isFalse);
        expect(controller!.selectedItems.contains('a-v1'), isFalse);

        expect(service.getMessageIdsCalls, idsBeforeSelect);
        expect(service.rangeQueries.where((q) => q.limit < 0), isEmpty);
        expect(service.rangeQueries.length, rangesBeforeSelect);
        expect(
          service.debugHasMessageOrderSkeleton(service.conversation.id),
          isFalse,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  group('stale select-all must not pollute next selection (P2)', () {
    testWidgets(
      'select-all incomplete → cancel → new selection → stale query ignored',
      (tester) async {
        final service = _SelectionFakeChatService(
          conversation: Conversation(
            id: 'conversation-1',
            title: 'Chat',
            messageIds: const [
              'user-1',
              'assistant-1',
              'user-2',
              'assistant-2',
            ],
          ),
          seededMessages: [
            _msg(id: 'user-1', role: 'user'),
            _msg(id: 'assistant-1', role: 'assistant'),
            _msg(id: 'user-2', role: 'user'),
            _msg(id: 'assistant-2', role: 'assistant'),
          ],
        );
        service.gateProjections = Completer<void>();

        HomePageController? controller;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) =>
                    SettingsProvider(createBusinessTestPreferences()),
              ),
              ChangeNotifierProvider<ChatService>.value(value: service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: _ControllerHarness(
                onCreated: (value) => controller = value,
              ),
            ),
          ),
        );
        await controller!.chatController.setCurrentConversationAndLoad(
          service.conversation,
        );
        await tester.pumpAndSettle();

        final collapsed = controller!.chatController
            .allCollapsedMessagesForCurrentConversation();
        controller!.startMessageSelection(
          messageIndex: 0,
          messageList: collapsed,
          mode: ChatSelectionMode.delete,
        );
        // Anchor pairing may select user+assistant; isolate a known baseline.
        controller!.toggleSelection('assistant-1', false);
        controller!.toggleSelection('user-2', false);
        controller!.toggleSelection('assistant-2', false);
        expect(controller!.selectedItems, {'user-1'});

        controller!.selectAll();
        await tester.pump();
        expect(service.fullLoadCalls, greaterThan(0));
        // Projection still gated — selection must not jump to full history yet.
        expect(controller!.selectedItems, {'user-1'});

        controller!.cancelSelection();
        expect(controller!.selecting, isFalse);
        expect(controller!.selectedItems, isEmpty);

        controller!.startMessageSelection(
          messageIndex: 2,
          messageList: collapsed,
          mode: ChatSelectionMode.delete,
        );
        // New selection: only the newly chosen pair (user-2 + assistant-2).
        expect(controller!.selectedItems.contains('user-2'), isTrue);
        expect(controller!.selectedItems.contains('user-1'), isFalse);
        final newSelection = Set<String>.of(controller!.selectedItems);

        // Stale select-all finishes — must not merge old conversation ids.
        service.gateProjections!.complete();
        await tester.pumpAndSettle();

        expect(controller!.selectedItems, newSelection);
        expect(controller!.selectedItems.contains('user-1'), isFalse);
        expect(controller!.allSelectableMessagesSelected, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });

  testWidgets(
    'selected history is previewed and forwarded through the controller',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final temp = Directory.systemTemp.createTempSync(
        'kelivo_forward_controller_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(temp.path);
      final service = ChatService();
      addTearDown(
        () => tester.runAsync(() async {
          await service.close();
          await Hive.close();
          await temp.delete(recursive: true);
        }),
      );
      final source = await tester.runAsync(() async {
        await service.init();
        final source = await service.createConversation(title: 'Source');
        await service.createConversation(title: 'Destination');
        await service.addMessage(
          conversationId: source.id,
          role: 'user',
          content: 'Question',
        );
        await service.addMessage(
          conversationId: source.id,
          role: 'assistant',
          parts: const [
            TextPart(
              '<think>hidden-private-reasoning</think>@B historical answer @全部',
            ),
            ImagePart(uri: '/private/source/image.png'),
            FilePart(
              uri: '/private/source/report.pdf',
              name: '/private/source/report.pdf',
            ),
          ],
        );
        return source;
      });
      HomePageController? controller;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(onCreated: (value) => controller = value),
          ),
        ),
      );
      await tester.runAsync(
        () => controller!.chatController.setCurrentConversationAndLoad(
          service.getConversation(source!.id)!,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller!.chatController.collapsedMessages, hasLength(2));
      controller!.startMessageSelection(
        messageIndex: 1,
        messageList: controller!.chatController.collapsedMessages,
        mode: ChatSelectionMode.forward,
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(controller!.selectedItems, hasLength(2));
      late Future<void> forwarding;
      await tester.runAsync(() async {
        forwarding = controller!.forwardSelectedMessages();
        unawaited(controller!.forwardSelectedMessages());
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('Question', skipOffstage: false), findsNothing);
      expect(find.textContaining('@B historical answer @全部'), findsNothing);
      controller!.cancelSelection();
      await tester.ensureVisible(find.text('Destination'));
      await tester.tap(find.text('Destination'));
      await tester.pump();
      await tester.ensureVisible(find.text('Forward').last);
      await tester.tap(find.text('Forward').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() => forwarding);
      final emptyTarget = service.getAllConversations().singleWhere(
        (c) => c.title == 'Destination',
      );
      expect(
        await tester.runAsync(() => service.loadMessages(emptyTarget.id)),
        isEmpty,
      );
      controller!.startMessageSelection(
        messageIndex: 1,
        messageList: controller!.chatController.collapsedMessages,
        mode: ChatSelectionMode.forward,
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        forwarding = controller!.forwardSelectedMessages();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Destination'));
      await tester.tap(find.text('Destination'));
      await tester.pump();
      await tester.ensureVisible(find.text('Forward').last);
      await tester.tap(find.text('Forward').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final target = service.getAllConversations().singleWhere(
        (c) => c.title == 'Destination',
      );
      await _pumpUntil(
        tester,
        () => controller!.currentConversation?.id == target.id,
      );
      final result = await tester.runAsync(
        () => service.loadMessages(target.id),
      );
      expect(result, hasLength(1));
      expect(
        result!.single.parts
            .whereType<ForwardedMessagesPart>()
            .single
            .messages
            .map((m) => m.text),
        ['Question', '@B historical answer @全部'],
      );
      final snapshot = result.single.parts
          .whereType<ForwardedMessagesPart>()
          .single
          .messages
          .last;
      expect(
        snapshot.parts.whereType<ImagePart>().single.uri,
        '/private/source/image.png',
      );
      expect(
        snapshot.parts.whereType<FilePart>().single.uri,
        '/private/source/report.pdf',
      );
      expect(snapshot.parts.whereType<ReasoningPart>(), isEmpty);
      expect(snapshot.parts.whereType<ToolCallPart>(), isEmpty);
      expect(result.single.contextContent, isNot(contains('/private/source')));
      expect(
        result.single.contextContent,
        isNot(contains('hidden-private-reasoning')),
      );
      expect(
        result.single.parts.single.encodePayload(),
        isNot(contains('hidden-private-reasoning')),
      );
      expect(controller!.currentConversation?.id, target.id);
      await tester.runAsync(() => forwarding);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'forward select all includes stored history beyond the loaded window',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final temp = Directory.systemTemp.createTempSync('kelivo_forward_long_');
      PathProviderPlatform.instance = _FakePathProviderPlatform(temp.path);
      final service = ChatService();
      addTearDown(
        () => tester.runAsync(() async {
          await service.close();
          await Hive.close();
          await temp.delete(recursive: true);
        }),
      );
      final source = await tester.runAsync(() async {
        await service.init();
        final source = await service.createConversation(title: 'Long source');
        await service.createConversation(title: 'Long destination');
        for (var round = 0; round < 205; round++) {
          await service.addMessage(
            conversationId: source.id,
            role: 'user',
            content: 'Question $round',
          );
          await service.addMessage(
            conversationId: source.id,
            role: 'assistant',
            content: 'Answer $round',
          );
        }
        return source;
      });
      HomePageController? controller;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => SettingsProvider(createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider(
              create: (_) => AssistantProvider(
                preferences: createBusinessTestPreferences(),
              ),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  UserProvider(preferences: createBusinessTestPreferences()),
            ),
            ChangeNotifierProvider<ChatService>.value(value: service),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(onCreated: (value) => controller = value),
          ),
        ),
      );
      await tester.runAsync(
        () => controller!.chatController.setCurrentConversationAndLoad(
          service.getConversation(source!.id)!,
        ),
      );
      await tester.pumpAndSettle();
      final window = controller!.chatController.collapsedMessages;
      expect(window.length, lessThan(410));
      expect(window.any((m) => m.content == 'Question 0'), isFalse);
      controller!.startMessageSelection(
        messageIndex: window.length - 1,
        messageList: window,
        mode: ChatSelectionMode.forward,
      );
      late Future<void> forwarding;
      await tester.runAsync(() async {
        controller!.toggleSelectAll();
        forwarding = controller!.forwardSelectedMessages();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => find.byType(ForwardMessagesSheet).evaluate().isNotEmpty,
      );
      expect(controller!.selectedItems, hasLength(410));
      expect(find.text('Question 0', skipOffstage: false), findsNothing);
      expect(
        tester
            .widget<ForwardMessagesSheet>(find.byType(ForwardMessagesSheet))
            .record
            .messages
            .length,
        410,
      );
      await tester.ensureVisible(find.text('Long destination'));
      await tester.tap(find.text('Long destination'));
      await tester.pump();
      await tester.ensureVisible(find.text('Forward').last);
      await tester.tap(find.text('Forward').last);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final target = service.getAllConversations().singleWhere(
        (c) => c.title == 'Long destination',
      );
      await _pumpUntil(
        tester,
        () => controller!.currentConversation?.id == target.id,
      );
      final result = await tester.runAsync(
        () => service.loadMessages(target.id),
      );
      expect(result, hasLength(1));
      final record = result!.single.parts
          .whereType<ForwardedMessagesPart>()
          .single;
      expect(record.messages, hasLength(410));
      expect(record.messages.take(4).map((m) => m.text), [
        'Question 0',
        'Answer 0',
        'Question 1',
        'Answer 1',
      ]);
      expect(record.messages.skip(408).map((m) => m.text), [
        'Question 204',
        'Answer 204',
      ]);
      expect(record.messages.map((m) => m.text).toSet(), hasLength(410));
      expect(controller!.currentConversation?.id, target.id);
      await tester.runAsync(() => forwarding);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  group('selection with getMessageIds gate held', () {
    late Directory tempDir;
    final services = <ChatService>[];
    final repositories = <_SpyChatDatabaseRepository>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'kelivo_version_selection_gate_',
      );
      PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    });

    tearDown(() async {
      for (final repository in repositories) {
        final gate = repository.gateMessageIds;
        if (gate != null && !gate.isCompleted) gate.complete();
      }
      for (final service in services) {
        await service.close();
      }
      services.clear();
      for (final repository in repositories) {
        await repository.close();
      }
      repositories.clear();
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<File> databaseFile() async {
      final appDataDir = await AppDirectories.getAppDataDirectory();
      return File('${appDataDir.path}/${AppDatabase.databaseFileName}');
    }

    test(
      'after window+group preload, multi-version selection works while order gated',
      () async {
        final writer = ChatService();
        services.add(writer);
        await writer.init();
        final conversation = await writer.createConversation(title: 'Gated');
        await writer.addMessage(
          conversationId: conversation.id,
          role: 'user',
          content: 'prompt',
        );
        await writer.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'v0',
          groupId: 'answer',
          version: 0,
        );
        final v1 = await writer.addMessage(
          conversationId: conversation.id,
          role: 'assistant',
          content: 'v1',
          groupId: 'answer',
          version: 1,
        );
        await writer.setSelectedVersion(conversation.id, 'answer', 1);
        await writer.close();
        services.remove(writer);

        final file = await databaseFile();
        final spy = _SpyChatDatabaseRepository(
          AppDatabase.open(file: file),
          databaseFile: file,
        );
        await spy.ensureReady();
        repositories.add(spy);
        spy.gateMessageIds = Completer<void>();

        final service = ChatService(existingRepository: spy);
        services.add(service);
        await service.init();

        // Use ChatController directly: HomePageController's widget harness can
        // pump idle frames that start the gated getMessageIds backfill and then
        // deadlock tearDown. Selection UI semantics are covered by the Fake
        // tests above; this case proves the real DB path under an order gate.
        final chatController = ChatController(chatService: service);
        addTearDown(chatController.dispose);

        await chatController
            .setCurrentConversationAndLoad(
              service.getConversation(conversation.id)!,
            )
            .timeout(const Duration(seconds: 5));

        expect(spy.getMessageIdsCalls, 0);
        expect(service.debugHasMessageOrderSkeleton(conversation.id), isFalse);
        expect(chatController.collapsedMessages.map((m) => m.id).last, v1.id);

        final collapsed = chatController
            .allCollapsedMessagesForCurrentConversation();
        expect(collapsed.map((m) => m.id).last, v1.id);

        // The picker gets revision headers; browsing does not load the
        // unselected body or the full order skeleton.
        final groupMessages = chatController.groupedMessages['answer']!;
        expect(
          service.getMessagesForGroups(conversation.id, ['answer']),
          hasLength(1),
        );
        expect(
          groupMessages.firstWhere((m) => m.version == 0).content,
          isEmpty,
        );
        expect(groupMessages.length, 2);
        expect(groupMessages.any((m) => m.id == v1.id), isTrue);
        expect(spy.rangeQueries.where((q) => q.limit < 0), isEmpty);
        expect(spy.getMessageIdsCalls, 0);
        expect(service.debugHasMessageOrderSkeleton(conversation.id), isFalse);

        spy.gateMessageIds!.complete();
      },
    );
  });
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({
    required this.onCreated,
    this.showTimeline = false,
  });

  final ValueChanged<HomePageController> onCreated;
  final bool showTimeline;

  @override
  State<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends State<_ControllerHarness>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputBarKey = GlobalKey();
  final _inputFocus = FocusNode();
  final _inputController = TextEditingController();
  final _mediaController = ChatInputBarController();
  final _scrollController = ChatAutoFollowScrollController();
  final _listController = ListController();
  final _processingFilesMessageId = ValueNotifier<String?>(null);
  late final HomePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: _scaffoldKey,
      inputBarKey: _inputBarKey,
      inputFocus: _inputFocus,
      inputController: _inputController,
      mediaController: _mediaController,
      scrollController: _scrollController,
    );
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _processingFilesMessageId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSnackBarOverlay(
    child: Scaffold(
      key: _scaffoldKey,
      body: !widget.showTimeline
          ? null
          : AnimatedBuilder(
              animation: Listenable.merge([
                _controller,
                _controller.chatController,
              ]),
              builder: (context, _) {
                if (_controller.currentConversation?.title != 'Destination') {
                  return const SizedBox.shrink();
                }
                return MessageListView(
                  scrollController: _scrollController,
                  listController: _listController,
                  messages: _controller.chatController.collapsedMessages,
                  byGroup: const {},
                  versionSelections: const {},
                  reasoning: const {},
                  reasoningSegments: const {},
                  contentSplits: const {},
                  toolParts: const {},
                  translations: const {},
                  selecting: false,
                  selectedItems: const {},
                  dividerPadding: EdgeInsets.zero,
                  processingFilesMessageId: _processingFilesMessageId,
                  showModelIcon: false,
                  showUserAvatar: false,
                );
              },
            ),
    ),
  );
}

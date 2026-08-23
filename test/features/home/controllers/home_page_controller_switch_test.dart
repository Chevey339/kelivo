import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';

class _PageRequest {
  _PageRequest({required this.conversationId, required this.completer});

  final String conversationId;
  final Completer<LoadedTimelinePage?> completer;
}

class _ControlledChatService extends ChatService {
  _ControlledChatService(this._messagesByConversation);

  final Map<String, List<ChatMessage>> _messagesByConversation;
  final Map<String, Conversation> _draftConversations =
      <String, Conversation>{};
  final List<_PageRequest> pageRequests = <_PageRequest>[];
  final List<String?> setCurrentCalls = <String?>[];
  String? _trackedCurrentConversationId;
  int checkpointWrites = 0;

  List<ChatMessage> messagesOf(String id) =>
      _messagesByConversation[id] ?? const <ChatMessage>[];

  @override
  String? get currentConversationId => _trackedCurrentConversationId;

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) {
    final completer = Completer<LoadedTimelinePage?>();
    pageRequests.add(
      _PageRequest(conversationId: conversationId, completer: completer),
    );
    return completer.future;
  }

  void completePage(
    _PageRequest request,
    List<ChatMessage> messages, {
    required int startIndex,
  }) {
    final timestamp = DateTime(2026, 7, 11);
    request.completer.complete(
      LoadedTimelinePage(
        conversationId: request.conversationId,
        stateRevision: 0,
        contextStartRevisionId: null,
        slots: [
          for (final (offset, message) in messages.indexed)
            LoadedTimelineSlot(
              identity: ActiveTimelineSlot(
                slotId: message.groupId ?? message.id,
                revisionId: message.id,
                parentRevisionId: null,
                role: message.role,
                createdAt: timestamp,
                updatedAt: timestamp,
                finalizedAt: timestamp,
                versionCount: 1,
                logicalIndex: startIndex + offset,
              ),
              message: message,
            ),
        ],
        hasMoreBefore: startIndex > 0,
        hasMoreAfter: false,
        totalSlotCount: startIndex + messages.length,
      ),
    );
  }

  @override
  Conversation? getConversation(String id) {
    final draft = _draftConversations[id];
    if (draft != null) return draft;
    final messages = _messagesByConversation[id];
    if (messages == null) return null;
    return Conversation(
      id: id,
      title: 'Conversation $id',
      messageIds: messages.map((message) => message.id).toList(),
    );
  }

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    final conversation = Conversation(
      title: title ?? 'Draft',
      assistantId: assistantId,
    );
    _draftConversations[conversation.id] = conversation;
    _messagesByConversation[conversation.id] = <ChatMessage>[];
    return conversation;
  }

  @override
  int getMessageCount(String conversationId) =>
      _messagesByConversation[conversationId]?.length ?? 0;

  @override
  Map<String, int> getVersionSelections(String conversationId) =>
      const <String, int>{};

  @override
  void setCurrentConversation(String? id) {
    setCurrentCalls.add(id);
    _trackedCurrentConversationId = id;
  }

  @override
  Future<void> updateStreamingCheckpointSilent(
    ChatMessage message,
    List<Map<String, dynamic>> toolEvents, {
    String? generationRunId,
    int? checkpointSeq,
  }) async {
    checkpointWrites++;
  }

  @override
  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => const <ChatMessage>[];

  @override
  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => const <ChatMessage>[];

  @override
  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => const <String, int>{};

  @override
  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => const <String, int>{};
}

ChatMessage _message(String conversationId, int index) {
  return ChatMessage(
    id: '$conversationId-message-$index',
    role: index.isEven ? 'user' : 'assistant',
    content: '$conversationId message $index',
    conversationId: conversationId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [body] with the platform overridden to Android so the mobile
  /// (animated) switching pipeline is exercised. The override must be reset
  /// before the test body ends, so it cannot live in setUp/tearDown.
  Future<void> runAsMobile(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Runs [body] with the platform overridden to macOS so the desktop
  /// (prepare/commit, no fade) switching pipeline is exercised.
  Future<void> runAsDesktop(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<HomePageController> pumpHarness(
    WidgetTester tester,
    _ControlledChatService service,
  ) async {
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider<ChatService>.value(value: service),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return controller!;
  }

  /// Pumps frames until every future in [futures] completes (bounded so a
  /// stuck transition fails the test instead of hanging it).
  Future<void> pumpUntilDone(
    WidgetTester tester,
    List<Future<void>> futures,
  ) async {
    var pending = futures.length;
    for (final future in futures) {
      unawaited(future.then((_) => pending--, onError: (_) => pending--));
    }
    for (var i = 0; i < 40 && pending > 0; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await Future.wait(futures);
  }

  /// Drives a switch to [id] to completion: resolves the pending window
  /// fetch and pumps through fade-out, commit, settle, and fade-in.
  ///
  /// Desktop flushes progress before issuing the fetch, so the page request
  /// may not exist on the first microtask; wait until it appears.
  Future<void> switchAndSettle(
    WidgetTester tester,
    HomePageController controller,
    _ControlledChatService service,
    String id,
  ) async {
    final before = service.pageRequests.length;
    final future = controller.switchConversationAnimated(id);
    for (var i = 0; i < 40 && service.pageRequests.length <= before; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(
      service.pageRequests.length,
      greaterThan(before),
      reason: 'expected a timeline page fetch for $id',
    );
    service.completePage(
      service.pageRequests.last,
      service.messagesOf(id),
      startIndex: 0,
    );
    await pumpUntilDone(tester, [future]);
  }

  group('HomePageController conversation switch pipeline', () {
    testWidgets(
      'notification target waits until the Home route is visible again',
      (tester) async {
        await runAsMobile(() async {
          final service = _ControlledChatService({
            'conv-a': [_message('conv-a', 0)],
            'conv-b': [_message('conv-b', 0)],
          });
          final controller = await pumpHarness(tester, service);
          await switchAndSettle(tester, controller, service, 'conv-a');
          controller.debugSetChatInitialized();

          controller.onDidPushNext();
          controller.debugHandleNotificationConversationTap('conv-b');
          await tester.pump();

          expect(controller.currentConversation?.id, 'conv-a');
          expect(service.pageRequests, hasLength(1));

          controller.onDidPopNext();
          for (var i = 0; i < 40 && service.pageRequests.length < 2; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          expect(service.pageRequests, hasLength(2));
          service.completePage(
            service.pageRequests.last,
            service.messagesOf('conv-b'),
            startIndex: 0,
          );
          for (
            var i = 0;
            i < 40 &&
                (controller.currentConversation?.id != 'conv-b' ||
                    controller.convoFadeController.value != 1.0);
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          expect(controller.currentConversation?.id, 'conv-b');
        });
      },
    );

    testWidgets('same-id tap short-circuits before flush and fetch', (
      tester,
    ) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          // A streaming assistant message makes a flush observable: it would
          // trigger a streaming checkpoint write if it ran.
          'conv-a': [
            _message('conv-a', 0),
            ChatMessage(
              id: 'conv-a-streaming',
              role: 'assistant',
              content: 'streaming reply',
              conversationId: 'conv-a',
              isStreaming: true,
            ),
          ],
          'conv-b': [_message('conv-b', 0)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        expect(controller.currentConversation?.id, 'conv-a');
        expect(service.pageRequests, hasLength(1));

        await controller.switchConversationAnimated('conv-a');
        await tester.pump();

        expect(service.pageRequests, hasLength(1));
        expect(service.checkpointWrites, 0);
        expect(controller.convoFadeController.value, 1.0);
      });
    });

    testWidgets('real switch flushes the previous conversation exactly once', (
      tester,
    ) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [
            _message('conv-a', 0),
            ChatMessage(
              id: 'conv-a-streaming',
              role: 'assistant',
              content: 'streaming reply',
              conversationId: 'conv-a',
              isStreaming: true,
            ),
          ],
          'conv-b': [_message('conv-b', 0)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        expect(service.checkpointWrites, 0);

        await switchAndSettle(tester, controller, service, 'conv-b');

        expect(controller.currentConversation?.id, 'conv-b');
        expect(service.checkpointWrites, 1);
      });
    });

    testWidgets('tap A then B then A during fetch discards B and stays on A', (
      tester,
    ) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [for (var i = 0; i < 3; i++) _message('conv-a', i)],
          'conv-b': [_message('conv-b', 0)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');

        final switchB = controller.switchConversationAnimated('conv-b');
        expect(service.pageRequests, hasLength(2));
        await tester.pump(const Duration(milliseconds: 60));

        // conv-a is still current (nothing committed yet): the same-id branch
        // cancels the in-flight switch and reveals the list again.
        final backToA = controller.switchConversationAnimated('conv-a');
        service.completePage(
          service.pageRequests.last,
          service.messagesOf('conv-b'),
          startIndex: 0,
        );
        await pumpUntilDone(tester, [switchB, backToA]);
        // The same-id branch reveals the list with a fire-and-forget fade-in.
        await tester.pump(const Duration(milliseconds: 300));

        expect(controller.currentConversation?.id, 'conv-a');
        expect(service.setCurrentCalls, isNot(contains('conv-b')));
        expect(controller.messages.map((m) => m.conversationId).toSet(), {
          'conv-a',
        });
        expect(controller.convoFadeController.value, 1.0);
      });
    });

    testWidgets('tap A then B then C: only C commits', (tester) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [for (var i = 0; i < 3; i++) _message('conv-a', i)],
          'conv-b': [_message('conv-b', 0)],
          'conv-c': [_message('conv-c', 0), _message('conv-c', 1)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');

        final switchB = controller.switchConversationAnimated('conv-b');
        expect(service.pageRequests, hasLength(2));
        await tester.pump(const Duration(milliseconds: 60));
        final switchC = controller.switchConversationAnimated('conv-c');
        expect(service.pageRequests, hasLength(3));

        // B's fetch resolves after being superseded; it must not commit.
        service.completePage(
          service.pageRequests[1],
          service.messagesOf('conv-b'),
          startIndex: 0,
        );
        await tester.pump();
        expect(controller.currentConversation?.id, 'conv-a');

        service.completePage(
          service.pageRequests[2],
          service.messagesOf('conv-c'),
          startIndex: 0,
        );
        await pumpUntilDone(tester, [switchB, switchC]);

        expect(controller.currentConversation?.id, 'conv-c');
        expect(service.setCurrentCalls, isNot(contains('conv-b')));
        expect(controller.messages.map((m) => m.conversationId).toSet(), {
          'conv-c',
        });
        expect(controller.messages, hasLength(2));
        expect(controller.convoFadeController.value, 1.0);
      });
    });
  });

  group('selection clears only after successful conversation change', () {
    void enterSelection(HomePageController controller) {
      final messages = controller.messages.toList();
      expect(messages, isNotEmpty);
      controller.startMessageSelection(
        messageIndex: 0,
        messageList: messages,
        mode: ChatSelectionMode.delete,
      );
      expect(controller.selecting, isTrue);
      expect(controller.selectedItems, isNotEmpty);
      expect(controller.selectionMode, ChatSelectionMode.delete);
    }

    testWidgets('successful switch clears selection UI and old ids', (
      tester,
    ) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
          'conv-b': [_message('conv-b', 0)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        enterSelection(controller);
        final previousSelected = Set<String>.of(controller.selectedItems);

        await switchAndSettle(tester, controller, service, 'conv-b');

        expect(controller.currentConversation?.id, 'conv-b');
        expect(controller.selecting, isFalse);
        expect(controller.selectedItems, isEmpty);
        expect(controller.selectionMode, ChatSelectionMode.share);
        expect(
          previousSelected.intersection(controller.selectedItems),
          isEmpty,
        );
      });
    });

    testWidgets('missing target keeps prior selection', (tester) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        enterSelection(controller);
        final selectedBefore = Set<String>.of(controller.selectedItems);

        final future = controller.switchConversationAnimated('missing');
        // prepare returns null when the conversation is gone; still need to
        // complete any queued page request if one was issued.
        if (service.pageRequests.length > 1) {
          service.pageRequests.last.completer.complete(null);
        }
        await pumpUntilDone(tester, [future]);

        expect(controller.currentConversation?.id, 'conv-a');
        expect(controller.selecting, isTrue);
        expect(controller.selectedItems, selectedBefore);
        expect(controller.selectionMode, ChatSelectionMode.delete);
      });
    });

    testWidgets('same-conversation no-op keeps selection', (tester) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        enterSelection(controller);
        final selectedBefore = Set<String>.of(controller.selectedItems);

        await controller.switchConversationAnimated('conv-a');
        await tester.pump();

        expect(controller.currentConversation?.id, 'conv-a');
        expect(controller.selecting, isTrue);
        expect(controller.selectedItems, selectedBefore);
        expect(controller.selectionMode, ChatSelectionMode.delete);
      });
    });

    testWidgets('successful new conversation clears selection', (tester) async {
      await runAsMobile(() async {
        final service = _ControlledChatService({
          'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        enterSelection(controller);

        final future = controller.createNewConversationAnimated();
        await pumpUntilDone(tester, [future]);

        expect(controller.currentConversation?.id, isNot('conv-a'));
        expect(controller.selecting, isFalse);
        expect(controller.selectedItems, isEmpty);
        expect(controller.selectionMode, ChatSelectionMode.share);
      });
    });
  });

  group('desktop conversation switch is atomic (macOS path)', () {
    void enterSelection(HomePageController controller) {
      final messages = controller.messages.toList();
      expect(messages, isNotEmpty);
      controller.startMessageSelection(
        messageIndex: 0,
        messageList: messages,
        mode: ChatSelectionMode.delete,
      );
      expect(controller.selecting, isTrue);
      expect(controller.selectedItems, isNotEmpty);
      expect(controller.selectionMode, ChatSelectionMode.delete);
    }

    testWidgets('successful switch clears selection', (tester) async {
      await runAsDesktop(() async {
        final service = _ControlledChatService({
          'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
          'conv-b': [_message('conv-b', 0)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');
        enterSelection(controller);
        final previousSelected = Set<String>.of(controller.selectedItems);

        await switchAndSettle(tester, controller, service, 'conv-b');

        expect(controller.currentConversation?.id, 'conv-b');
        expect(service.currentConversationId, 'conv-b');
        expect(controller.selecting, isFalse);
        expect(controller.selectedItems, isEmpty);
        expect(controller.selectionMode, ChatSelectionMode.share);
        expect(
          previousSelected.intersection(controller.selectedItems),
          isEmpty,
        );
      });
    });

    testWidgets(
      'loadTimelinePage error keeps conversation, messages, and selection',
      (tester) async {
        await runAsDesktop(() async {
          final service = _ControlledChatService({
            'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
            'conv-b': [_message('conv-b', 0)],
          });
          final controller = await pumpHarness(tester, service);
          await switchAndSettle(tester, controller, service, 'conv-a');
          enterSelection(controller);
          final selectedBefore = Set<String>.of(controller.selectedItems);
          final messagesBefore = controller.messages
              .map((m) => m.id)
              .toList(growable: false);

          final before = service.pageRequests.length;
          final future = controller.switchConversationAnimated('conv-b');
          for (
            var i = 0;
            i < 40 && service.pageRequests.length <= before;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          expect(service.pageRequests.length, greaterThan(before));
          service.pageRequests.last.completer.completeError(
            StateError('desktop_load_failed'),
          );
          await expectLater(future, throwsA(isA<StateError>()));
          await tester.pump();

          expect(controller.currentConversation?.id, 'conv-a');
          expect(service.currentConversationId, 'conv-a');
          expect(service.setCurrentCalls, isNot(contains('conv-b')));
          expect(controller.messages.map((m) => m.id), messagesBefore);
          expect(controller.selecting, isTrue);
          expect(controller.selectedItems, selectedBefore);
          expect(controller.selectionMode, ChatSelectionMode.delete);
        });
      },
    );

    testWidgets(
      'missing target keeps ChatService and ChatController on prior conversation',
      (tester) async {
        await runAsDesktop(() async {
          final service = _ControlledChatService({
            'conv-a': [_message('conv-a', 0), _message('conv-a', 1)],
          });
          final controller = await pumpHarness(tester, service);
          await switchAndSettle(tester, controller, service, 'conv-a');
          expect(service.currentConversationId, 'conv-a');
          expect(controller.currentConversation?.id, 'conv-a');

          final future = controller.switchConversationAnimated('missing');
          await pumpUntilDone(tester, [future]);

          expect(controller.currentConversation?.id, 'conv-a');
          expect(service.currentConversationId, 'conv-a');
          expect(service.setCurrentCalls, isNot(contains('missing')));
          expect(controller.messages.map((m) => m.conversationId).toSet(), {
            'conv-a',
          });
        });
      },
    );

    testWidgets('tap A then B then C: only C commits', (tester) async {
      await runAsDesktop(() async {
        final service = _ControlledChatService({
          'conv-a': [for (var i = 0; i < 3; i++) _message('conv-a', i)],
          'conv-b': [_message('conv-b', 0)],
          'conv-c': [_message('conv-c', 0), _message('conv-c', 1)],
        });
        final controller = await pumpHarness(tester, service);
        await switchAndSettle(tester, controller, service, 'conv-a');

        final afterA = service.pageRequests.length;
        final switchB = controller.switchConversationAnimated('conv-b');
        for (var i = 0; i < 40 && service.pageRequests.length <= afterA; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(service.pageRequests.length, afterA + 1);
        final requestB = service.pageRequests.last;

        final switchC = controller.switchConversationAnimated('conv-c');
        for (
          var i = 0;
          i < 40 && service.pageRequests.length <= afterA + 1;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(service.pageRequests.length, afterA + 2);
        final requestC = service.pageRequests.last;

        service.completePage(
          requestB,
          service.messagesOf('conv-b'),
          startIndex: 0,
        );
        await tester.pump();
        expect(controller.currentConversation?.id, 'conv-a');
        expect(service.currentConversationId, 'conv-a');
        expect(service.setCurrentCalls, isNot(contains('conv-b')));

        service.completePage(
          requestC,
          service.messagesOf('conv-c'),
          startIndex: 0,
        );
        await pumpUntilDone(tester, [switchB, switchC]);

        expect(controller.currentConversation?.id, 'conv-c');
        expect(service.currentConversationId, 'conv-c');
        expect(service.setCurrentCalls, isNot(contains('conv-b')));
        expect(controller.messages.map((m) => m.conversationId).toSet(), {
          'conv-c',
        });
        expect(controller.messages, hasLength(2));
      });
    });
  });
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({required this.onCreated});

  final ValueChanged<HomePageController> onCreated;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(key: _scaffoldKey);
}

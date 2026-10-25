import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _VersionedChatService extends ChatService {
  _VersionedChatService()
    : older = ChatMessage(
        id: 'answer-v0',
        role: 'assistant',
        content: 'old answer',
        conversationId: 'conversation-1',
        groupId: 'answer',
        version: 0,
        reasoningText: 'old reasoning',
        reasoningStartAt: DateTime(2026, 7, 29),
      ),
      newer = ChatMessage(
        id: 'answer-v1',
        role: 'assistant',
        content: 'new answer',
        conversationId: 'conversation-1',
        groupId: 'answer',
        version: 1,
      );

  final ChatMessage older;
  final ChatMessage newer;
  int selectedVersion = 1;

  Conversation get conversation => Conversation(
    id: 'conversation-1',
    title: 'Conversation',
    messageIds: [older.id, newer.id],
  );

  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;

  @override
  int getMessageCount(String conversationId) => 1;

  @override
  bool isConversationFullyCached(String conversationId) => true;

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    final timestamp = DateTime(2026, 7, 29);
    final selected = selectedVersion == 0 ? older : newer;
    return LoadedTimelinePage(
      conversationId: conversationId,
      stateRevision: 0,
      contextStartRevisionId: null,
      slots: [
        LoadedTimelineSlot(
          identity: ActiveTimelineSlot(
            slotId: 'answer',
            revisionId: selected.id,
            parentRevisionId: null,
            role: 'assistant',
            createdAt: timestamp,
            updatedAt: timestamp,
            finalizedAt: timestamp,
            versionCount: 2,
            logicalIndex: 0,
          ),
          message: selected,
        ),
      ],
      hasMoreBefore: false,
      hasMoreAfter: false,
      totalSlotCount: 1,
    );
  }

  @override
  Map<String, int> getVersionSelections(String conversationId) => {
    'answer': selectedVersion,
  };

  @override
  List<ChatMessage> getMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => [older, newer];

  @override
  Future<List<ChatMessage>> loadMessagesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => [older, newer];

  @override
  Map<String, int> getFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) => const {'answer': 0};

  @override
  Future<Map<String, int>> loadFirstMessageIndicesForGroups(
    String conversationId,
    Iterable<String> groupIds,
  ) async => const {'answer': 0};

  @override
  Future<void> setSelectedVersion(
    String conversationId,
    String groupId,
    int version,
  ) async {
    selectedVersion = version;
  }

  @override
  List<Map<String, dynamic>> getToolEvents(String assistantMessageId) {
    if (assistantMessageId != older.id) return const [];
    return [
      {
        'id': 'tool-1',
        'name': 'search',
        'arguments': const {'q': 'Kelivo'},
        'content': 'result',
      },
    ];
  }
}

void main() {
  testWidgets('switching versions restores reasoning and tool cards', (
    tester,
  ) async {
    final service = _VersionedChatService();
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

    expect(controller!.reasoning[service.older.id], isNull);
    expect(controller!.toolParts[service.older.id], isNull);

    await controller!.setSelectedVersion('answer', 0);

    expect(controller!.reasoning[service.older.id]?.text, 'old reasoning');
    expect(controller!.toolParts[service.older.id]?.single.toolName, 'search');

    await tester.pumpWidget(const SizedBox.shrink());
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

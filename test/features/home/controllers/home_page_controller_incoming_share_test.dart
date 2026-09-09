import 'dart:async';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/image_compressor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';

class _DraftService extends ChatService {
  final drafts = <Conversation>[];
  final targets = <Conversation>[];
  bool failLoad = false;
  Completer<void>? createGate;
  @override
  bool isConversationFullyCached(String conversationId) => true;
  @override
  List<Conversation> getAllConversations() => targets;
  @override
  Conversation? getConversation(String id) {
    for (final item in [...targets, ...drafts]) {
      if (item.id == id) return item;
    }
    return null;
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
    if (failLoad) throw StateError('Unable to read conversation');
    return null;
  }

  @override
  Future<Conversation> createDraftConversation({
    String? title,
    String? assistantId,
    bool temporary = false,
  }) async {
    await createGate?.future;
    final draft = Conversation(
      title: title ?? 'Draft',
      assistantId: assistantId,
    );
    drafts.add(draft);
    return draft;
  }

  @override
  int getMessageCount(String conversationId) => 0;
}

class _Media extends ChatInputBarController {
  List<String> images = [];
  List<DocumentAttachment> files = [];
  bool deletesOwnedSources = false;
  @override
  bool get isAttached => true;
  @override
  bool get hasDraftMedia => images.isNotEmpty || files.isNotEmpty;
  @override
  List<Object> get draftMediaIdentity => [...images, ...files];
  @override
  void clearDraft() {
    images.clear();
    files.clear();
  }

  @override
  void addFiles(List<DocumentAttachment> docs) {
    files.addAll(docs);
  }

  @override
  void enqueueImages(
    List<String> paths,
    ImageCompressConfig config, {
    bool deleteSourcesAfterProcessing = false,
  }) {
    images.addAll(paths);
    deletesOwnedSources = deleteSourcesAfterProcessing;
  }
}

Future<void> _pumpUntilDone(WidgetTester tester, Future<void> future) async {
  var done = false;
  unawaited(future.then((_) => done = true));
  for (var index = 0; index < 50 && !done; index++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(done, isTrue);
  await future;
}

void main() {
  testWidgets(
    'incoming content creates a new mobile draft and fills attachments without sending',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final service = _DraftService();
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(_app(service, key));
        final state = key.currentState!;
        const document = DocumentAttachment(
          path: '/upload/report.pdf',
          fileName: 'report.pdf',
          mime: 'application/pdf',
        );
        await _pumpUntilDone(
          tester,
          state.controller.openIncomingShareDraft(
            const ChatInputData(
              text: '分享内容',
              imagePaths: ['/upload/图片.png'],
              documents: [document],
            ),
          ),
        );
        expect(service.drafts, hasLength(1));
        expect(
          state.controller.currentConversation!.id,
          service.drafts.single.id,
        );
        expect(state.controller.messages, isEmpty);
        expect(state.text.text, '分享内容');
        expect(state.media.images, ['/upload/图片.png']);
        expect(state.media.files, [document]);
        expect(state.media.deletesOwnedSources, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'move to new conversation preserves the unsent text and attachments',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final service = _DraftService();
        final key = GlobalKey<_HarnessState>();
        await tester.pumpWidget(_app(service, key));
        final state = key.currentState!;
        const file = DocumentAttachment(
          path: '/upload/archive.zip',
          fileName: 'archive.zip',
          mime: 'application/zip',
        );
        await _pumpUntilDone(
          tester,
          state.controller.openIncomingShareDraft(
            const ChatInputData(text: 'keep this', documents: [file]),
          ),
        );
        final original = state.controller.currentConversation!.id;
        final move = state.controller.moveSharedDraft();
        await tester.pumpAndSettle();
        await tester.tap(find.text('New conversation'));
        await _pumpUntilDone(tester, move);
        expect(state.controller.currentConversation!.id, isNot(original));
        expect(state.controller.messages, isEmpty);
        expect(state.text.text, 'keep this');
        expect(state.media.files, [file]);
        await tester.pumpWidget(const SizedBox.shrink());
        service.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'move to an existing conversation preserves content (load failure: $fail)',
      (tester) async {
        final previousStrategy = tester.binding.schedulingStrategy;
        tester.binding.schedulingStrategy =
            ({required priority, required scheduler}) => true;
        addTearDown(() => tester.binding.schedulingStrategy = previousStrategy);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final service = _DraftService()..failLoad = fail;
          service.targets.add(Conversation(id: 'target', title: 'Code review'));
          final key = GlobalKey<_HarnessState>();
          await tester.pumpWidget(_app(service, key));
          final state = key.currentState!;
          const file = DocumentAttachment(
            path: '/upload/a.zip',
            fileName: 'a.zip',
            mime: 'application/zip',
          );
          await _pumpUntilDone(
            tester,
            state.controller.openIncomingShareDraft(
              const ChatInputData(text: 'unsent', documents: [file]),
            ),
          );
          final original = state.controller.currentConversation!.id;
          final move = state.controller.moveSharedDraft();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Code review'));
          await _pumpUntilDone(tester, move);
          expect(
            state.controller.currentConversation!.id,
            fail ? original : 'target',
          );
          expect(state.text.text, 'unsent');
          expect(state.media.files, [file]);
          expect(state.controller.messages, isEmpty);
          expect(tester.takeException(), isNull);
          if (fail) {
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          }
          await tester.pumpWidget(const SizedBox.shrink());
          service.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets(
    'delivery asks about text typed while an incoming share was being prepared',
    (tester) async {
      final service = _DraftService();
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_app(service, key));
      final state = key.currentState!;
      final prepared = Completer<ChatInputData>();
      final delivery = prepared.future.then(
        state.controller.acceptIncomingShareDraft,
      );
      state.text.text = 'new text typed during import';
      const existing = DocumentAttachment(
        path: '/upload/existing.txt',
        fileName: 'existing.txt',
        mime: 'text/plain',
      );
      state.media.files.add(existing);
      prepared.complete(const ChatInputData(text: 'incoming'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'There is unsent content in the input box. Replace it with the shared content in a new chat?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await delivery, isFalse);
      expect(state.text.text, 'new text typed during import');
      expect(state.media.files, [existing]);
      expect(service.drafts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets('ordinary chat keeps unsupported shared files in the draft', (
    tester,
  ) async {
    final service = _DraftService();
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_app(service, key));
    final state = key.currentState!;
    const input = ChatInputData(
      text: 'inspect this',
      documents: [
        DocumentAttachment(
          path: '/upload/app.apk',
          fileName: 'app.apk',
          mime: 'application/vnd.android.package-archive',
        ),
      ],
    );
    await _pumpUntilDone(
      tester,
      state.controller.openIncomingShareDraft(input),
    );
    expect(
      await state.controller.sendMessage(input),
      ChatInputSubmissionResult.rejected,
    );
    expect(state.text.text, 'inspect this');
    expect(state.media.files, input.documents);
    expect(state.controller.messages, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  for (final confirmReplacement in [false, true]) {
    testWidgets(
      'typing 100ms into the new chat animation requires confirmation ($confirmReplacement)',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final service = _DraftService();
          final key = GlobalKey<_HarnessState>();
          await tester.pumpWidget(_app(service, key));
          final state = key.currentState!;
          final delivery = state.controller.acceptIncomingShareDraft(
            const ChatInputData(text: 'incoming'),
          );
          // Wait until the new conversation exists and its entrance animation
          // has started, then edit the actual text field mid-animation.
          for (var i = 0; i < 50; i++) {
            await tester.pump(const Duration(milliseconds: 10));
            if (state.controller.convoFadeController.status ==
                AnimationStatus.forward) {
              break;
            }
          }
          expect(
            state.controller.convoFadeController.status,
            AnimationStatus.forward,
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.enterText(
            find.byType(TextField),
            'typed during animation',
          );
          await tester.pumpAndSettle();
          expect(state.text.text, 'typed during animation');
          expect(find.text('Shared content'), findsOneWidget);
          final l10n = AppLocalizations.of(state.context)!;
          await tester.tap(
            find.widgetWithText(
              TextButton,
              confirmReplacement
                  ? l10n.modelDetailSheetConfirmButton
                  : l10n.homePageCancel,
            ),
          );
          await tester.pumpAndSettle();
          expect(await delivery, confirmReplacement);
          expect(
            state.text.text,
            confirmReplacement ? 'incoming' : 'typed during animation',
          );
          expect(service.drafts, hasLength(1));
          expect(state.controller.messages, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          service.dispose();
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }

  testWidgets(
    'attachments added while creating the chat survive cancellation',
    (tester) async {
      final gate = Completer<void>();
      final service = _DraftService()..createGate = gate;
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_app(service, key));
      final state = key.currentState!;
      final delivery = state.controller.acceptIncomingShareDraft(
        const ChatInputData(text: 'incoming'),
      );
      await tester.pumpAndSettle();
      expect(service.drafts, isEmpty);
      const addedFile = DocumentAttachment(
        path: '/upload/new.pdf',
        fileName: 'new.pdf',
        mime: 'application/pdf',
      );
      state.media.addFiles([addedFile]);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Shared content'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await delivery, isFalse);
      expect(state.media.files, [addedFile]);
      expect(state.text.text, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets('failed chat creation preserves the approved draft', (
    tester,
  ) async {
    final gate = Completer<void>();
    final service = _DraftService()..createGate = gate;
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_app(service, key));
    final state = key.currentState!;
    await state.controller.startUserMessageEdit(
      ChatMessage(
        role: 'user',
        content: 'original draft',
        conversationId: 'previous-chat',
      ),
    );
    state.media.images.add('/upload/existing.png');
    final delivery = state.controller
        .acceptIncomingShareDraft(const ChatInputData(text: 'incoming'))
        .then<Object?>(
          (accepted) => accepted,
          onError: (Object error) => error,
        );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(
        TextButton,
        AppLocalizations.of(state.context)!.modelDetailSheetConfirmButton,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'edited during creation');
    gate.completeError(StateError('Unable to create a conversation'));
    await tester.pumpAndSettle();
    expect(await delivery, isA<StateError>());
    expect(state.text.text, 'edited during creation');
    expect(state.media.images, ['/upload/existing.png']);
    expect(service.drafts, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  testWidgets(
    'unchanged approved draft does not prompt again after switching',
    (tester) async {
      final service = _DraftService();
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_app(service, key));
      final state = key.currentState!;
      state.text.text = 'old draft';
      state.media.images.add('/upload/existing.png');
      final delivery = state.controller.acceptIncomingShareDraft(
        const ChatInputData(text: 'incoming'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          TextButton,
          AppLocalizations.of(state.context)!.modelDetailSheetConfirmButton,
        ),
      );
      await _pumpUntilDone(tester, delivery);
      expect(await delivery, isTrue);
      expect(find.text('Shared content'), findsNothing);
      expect(state.text.text, 'incoming');
      expect(state.media.images, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets(
    'cancelling replacement keeps existing unsent text and attachments',
    (tester) async {
      final service = _DraftService();
      final key = GlobalKey<_HarnessState>();
      await tester.pumpWidget(_app(service, key));
      final state = key.currentState!;
      state.text.text = 'unfinished';
      state.media.images.add('/upload/existing.png');
      final result = state.controller.confirmIncomingShare();
      await tester.pumpAndSettle();
      expect(find.text('Shared content'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
      expect(state.text.text, 'unfinished');
      expect(state.media.images, ['/upload/existing.png']);
      expect(service.drafts, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );
}

Widget _app(_DraftService service, GlobalKey<_HarnessState> key) =>
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
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: _Harness(key: key),
      ),
    );

class _Harness extends StatefulWidget {
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  final text = TextEditingController();
  final media = _Media();
  final focus = FocusNode();
  final scroll = ChatAutoFollowScrollController();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final HomePageController controller;
  @override
  void initState() {
    super.initState();
    controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: scaffoldKey,
      inputBarKey: GlobalKey(),
      inputFocus: focus,
      inputController: text,
      mediaController: media,
      scrollController: scroll,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    text.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: scaffoldKey,
    body: TextField(controller: text, focusNode: focus),
  );
}

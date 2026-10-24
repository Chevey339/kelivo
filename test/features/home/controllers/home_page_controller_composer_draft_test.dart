import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_draft_request.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_context_chip.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import '../../../support/native_message_input_harness.dart';
import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/composer_draft_store.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../support/business_test_harness.dart';
import '../../../support/commit_gate.dart';
import '../../../support/gated_xfile.dart';

class _DraftChatService extends ChatService {
  _DraftChatService(this.store);
  final ComposerDraftStore store;
  final conversations = {
    for (final id in ['a', 'b', 'c']) id: Conversation(id: id, title: id),
  };
  String? current;
  final unavailableSources = <String>{};
  @override
  Future<bool> isUiContextCurrent(UiContextSource source) async =>
      !unavailableSources.contains(source.revisionId);
  void invalidateUiSource(String id) {
    unavailableSources.add(id);
    notifyListeners();
  }

  @override
  ComposerDraftStore get composerDrafts => store;
  @override
  Conversation? getConversation(String id) => conversations[id];
  @override
  List<Conversation> getAllConversations() => conversations.values.toList();
  @override
  String? get currentConversationId => current;
  @override
  void setCurrentConversation(String? id) => current = id;
  @override
  int getMessageCount(String conversationId) => 0;
  @override
  Map<String, int> getVersionSelections(String conversationId) => {};
  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async => LoadedTimelinePage(
    conversationId: conversationId,
    stateRevision: 0,
    contextStartRevisionId: null,
    slots: const [],
    hasMoreBefore: false,
    hasMoreAfter: false,
    totalSlotCount: 0,
  );
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, this.nativeInput = false});
  final bool nativeInput;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  late final TextEditingController text;
  final media = ChatInputBarController();
  final focus = FocusNode();
  final scroll = ChatAutoFollowScrollController();
  final scaffold = GlobalKey<ScaffoldState>();
  final bar = GlobalKey();
  late final HomePageController controller;
  @override
  void initState() {
    super.initState();
    text = widget.nativeInput
        ? MessageEditingController(nativeInputEnabled: true)
        : TextEditingController();
    controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: scaffold,
      inputBarKey: bar,
      inputFocus: focus,
      inputController: text,
      mediaController: media,
      scrollController: scroll,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      key: scaffold,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: controller.selecting
            ? const SizedBox()
            : ChatInputBar(
                key: bar,
                controller: text,
                mediaController: media,
                focusNode: focus,
                conversationId: controller.currentConversation?.id,
                onSend: controller.sendMessage,
              ),
      ),
    ),
  );
  @override
  void dispose() {
    controller.dispose();
    text.dispose();
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }
}

// Gate attachment preparation without changing the Home recovery implementation.
class _GatedDraftStore extends ComposerDraftStore {
  _GatedDraftStore(super.db, {super.directory});
  final preparationStarted = Completer<void>();
  final releasePreparation = Completer<void>();

  @override
  Future<ChatInputData> prepareSubmissionInput(ChatInputData input) async {
    preparationStarted.complete();
    await releasePreparation.future;
    return input; // Text-only submission has no attachment transformations.
  }
}

void main() {
  late Directory root;
  late AppDatabase db;
  late ComposerDraftStore store;
  late _DraftChatService service;
  late CommitGate commits;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('draft-controller-');
    commits = CommitGate();
    db = AppDatabase(NativeDatabase.memory().interceptWith(commits));
    store = ComposerDraftStore(
      db,
      directory: () async => Directory('${root.path}/drafts'),
    );
    await store.initialize();
    service = _DraftChatService(store);
  });
  tearDown(() async {
    store.dispose();
    await db.close();
    await root.delete(recursive: true);
  });
  Future<_HarnessState> pump(
    WidgetTester tester, {
    bool nativeInput = false,
  }) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatService>.value(value: service),
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                AssistantProvider(preferences: createBusinessTestPreferences()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Harness(key: key, nativeInput: nativeInput),
        ),
      ),
    );
    return key.currentState!;
  }

  Future<void> finish(WidgetTester tester, Future<void> future) async {
    var done = false;
    Object? error;
    future.then<void>(
      (_) {
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    );
    final waiting = Stopwatch()..start();
    while (!done && waiting.elapsed < const Duration(seconds: 10)) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    expect(done, isTrue, reason: 'asynchronous operation did not settle');
    if (error != null) throw error!;
  }

  Future<void> go(WidgetTester tester, _HarnessState state, String id) async {
    await finish(
      tester,
      state.controller.debugViewModel.switchConversation(id),
    );
    for (var i = 0; i < 200 && state.media.draftOwnerId != id; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      state.media.draftOwnerId,
      id,
      reason:
          'current=${state.controller.currentConversation?.id}, errors=${store.errors}',
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await finish(tester, store.flush());
  }

  UiContextAttachment frozen(String value) => UiContextAttachment.attached(
    source: UiContextSource(
      conversationId: 'a',
      revisionId: 'source',
      surfaceKey: '0:0',
      sourceHash: 'a' * 64,
    ),
    text: UiContextText(title: 'Parameters', body: 'value: $value'),
  );
  UiDraftRequest attach(String value, {String text = ''}) => UiDraftRequest(
    conversationId: 'a',
    attachment: frozen(value),
    text: text,
  );

  testWidgets(
    'explicit Attach stages one frozen chip and persists across owner switches',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      await finish(tester, state.controller.stageUiDraft(attach('31')));
      await tester.pumpAndSettle();
      expect(state.media.snapshotInput('').uiContext, frozen('31'));
      expect(state.text.text, isEmpty);
      expect(find.byType(GenUiContextChip), findsOneWidget);
      await go(tester, state, 'b');
      expect(state.media.snapshotInput('').uiContext, isNull);
      await go(tester, state, 'a');
      expect(state.media.snapshotInput('').uiContext, frozen('31'));
      service.invalidateUiSource('source');
      await tester.pumpAndSettle();
      expect(
        tester.widget<GenUiContextChip>(find.byType(GenUiContextChip)).stale,
        isTrue,
      );
      expect(
        state.media.snapshotInput('').uiContext!.text.exactText,
        frozen('31').text.exactText,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'Ask previews append, leaves draft unchanged until confirmation',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'My question';
      final pending = state.controller.stageUiDraft(
        attach('7', text: 'Explain parameters'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add to your draft?'), findsOneWidget);
      expect(state.text.text, 'My question');
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      await tester.tap(find.text('Add').last);
      await finish(tester, pending);
      expect(state.text.text, 'My question\n\nExplain parameters');
      expect(state.media.snapshotInput(state.text.text).uiContext, frozen('7'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'replacement cancellation keeps the original chip; confirmation replaces once',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      await finish(tester, state.controller.stageUiDraft(attach('1')));
      var pending = state.controller.stageUiDraft(attach('2'));
      await tester.pumpAndSettle();
      expect(find.text('Replace attached UI?'), findsOneWidget);
      expect(find.text('value: 1'), findsWidgets);
      expect(find.text('value: 2'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await finish(tester, pending);
      expect(state.media.snapshotInput('').uiContext, frozen('1'));
      pending = state.controller.stageUiDraft(attach('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace').last);
      await finish(tester, pending);
      expect(state.media.snapshotInput('').uiContext, frozen('2'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'typing during preview aborts atomic staging without overwriting text',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'Before';
      final pending = state.controller.stageUiDraft(attach('7'));
      await tester.pumpAndSettle();
      state.text.text = 'New typing';
      await tester.tap(find.text('Add').last);
      await finish(tester, pending);
      expect(state.text.text, 'New typing');
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'switching owner during preview cannot stage into the new composer',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'A draft';
      final pending = state.controller.stageUiDraft(attach('7'));
      await tester.pumpAndSettle();
      await go(tester, state, 'b');
      await tester.tap(find.text('Add').last);
      await finish(tester, pending);
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      expect(store.peek('a')!.active.text, 'A draft');
      expect(store.peek('a')!.active.uiContext, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'native edits accepted during preview drain before atomic staging',
    (tester) async {
      final native = NativeMessageInputHarness(tester);
      addTearDown(native.dispose);
      final state = await pump(tester, nativeInput: true);
      await go(tester, state, 'a');
      final before = 'Before\n' * 300;
      state.text.value = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
      state.focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(native.session, isNotNull);
      final pending = state.controller.stageUiDraft(attach('7'));
      await tester.pumpAndSettle();
      expect(find.text('Add to your draft?'), findsOneWidget);
      native.holdDelivery = true;
      await native.commit('X');
      expect(state.text.text, before);
      await tester.tap(find.text('Add').last);
      await tester.pump();
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      await native.release();
      await finish(tester, pending);
      expect(state.text.text, '${before}X');
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  testWidgets(
    'active composer composition refuses staging and retains composing text',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.value = const TextEditingValue(
        text: 'zhong',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      );
      await finish(tester, state.controller.stageUiDraft(attach('7')));
      expect(state.text.text, 'zhong');
      expect(state.media.snapshotInput(state.text.text).uiContext, isNull);
      expect(
        AppSnackBarManager().activeToasts.map(
          (entry) => entry.notification.message,
        ),
        contains('Finish composing before continuing'),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await unmount(tester);
    },
  );

  for (final operation in ['switch', 'background', 'dispose']) {
    testWidgets('native accepted input drains before draft $operation', (
      tester,
    ) async {
      final native = NativeMessageInputHarness(tester);
      addTearDown(native.dispose);
      final state = await pump(tester, nativeInput: true);
      await go(tester, state, 'a');
      final source = 'original line\n' * 300;
      state.text.value = TextEditingValue(
        text: source,
        selection: TextSelection.collapsed(offset: source.length),
      );
      state.focus.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(native.session, isNotNull);
      native.holdDelivery = true;
      await native.commit('X');
      expect(state.text.text, source);
      if (operation == 'switch') {
        await finish(
          tester,
          state.controller.debugViewModel.switchConversation('b'),
        );
        await tester.pump();
        expect(state.media.draftOwnerId, 'a');
        await native.release();
        await go(tester, state, 'b');
        expect(state.text.text, isEmpty);
        expect(store.peek('a')!.active.text, '${source}X');
        expect(store.peek('a')!.active.selectionExtent, source.length + 1);
        await go(tester, state, 'a');
        expect(state.text.text, '${source}X');
        await unmount(tester);
      } else if (operation == 'background') {
        state.controller.onAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        await native.release();
        await finish(tester, store.flush());
        expect(store.peek('a')!.active.text, '${source}X');
        await unmount(tester);
      } else {
        await tester.pumpWidget(const SizedBox());
        await native.release();
        await finish(
          tester,
          (state.text as MessageEditingController).disposeAfterInput(),
        );
        await finish(tester, store.flush());
        expect(store.peek('a')!.active.text, '${source}X');
        expect(store.peek('a')!.active.selectionExtent, source.length + 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final operation in ['switch', 'dispose']) {
    for (final mode in ['short', 'long', 'file']) {
      testWidgets(
        'accepted $mode paste finishes in the original draft during $operation',
        (tester) async {
          final native = NativeMessageInputHarness(tester);
          addTearDown(native.dispose);
          final clipboard = Completer<Map<String, String>>();
          final requested = Completer<void>();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.getData') {
                if (!requested.isCompleted) requested.complete();
                return clipboard.future;
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final state = await pump(tester, nativeInput: true);
          await go(tester, state, 'a');
          final source = mode == 'short'
              ? 'short draft'
              : 'original line\n' * 300;
          final pasted = mode == 'file' ? 'P' * 6000 : 'PASTE';
          final expected = mode == 'file' ? source : '$source$pasted';
          state.text.value = TextEditingValue(
            text: source,
            selection: TextSelection.collapsed(offset: source.length),
          );
          state.focus.requestFocus();
          await tester.pump();
          await tester.pump();
          final document = state.text as MessageEditingController;
          final pasting = document.performCommand('paste');
          await finish(tester, requested.future);
          if (operation == 'switch') {
            await finish(
              tester,
              state.controller.debugViewModel.switchConversation('b'),
            );
            await tester.pump();
            expect(state.media.draftOwnerId, 'a');
            clipboard.complete({'text': pasted});
            await finish(tester, pasting);
            await go(tester, state, 'b');
            expect(state.text.text, isEmpty);
            expect(store.peek('a')!.active.text, expected);
            await unmount(tester);
          } else {
            await tester.pumpWidget(const SizedBox());
            clipboard.complete({'text': pasted});
            await finish(tester, pasting);
            await finish(tester, document.disposeAfterInput());
            await finish(tester, store.flush());
            expect(store.peek('a')!.active.text, expected);
          }
          if (mode == 'file') {
            final attachment = store.peek('a')!.active.documents.single;
            expect(
              await tester.runAsync(() => File(attachment.path).readAsString()),
              pasted,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('queued submit during a draft switch keeps the original draft', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    addTearDown(native.dispose);
    final state = await pump(tester, nativeInput: true);
    await go(tester, state, 'a');
    final source = 'original line\n' * 300;
    state.text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: source.length),
    );
    state.focus.requestFocus();
    await tester.pump();
    await tester.pump();
    native.holdDelivery = true;
    await native.commit('X');
    await finish(
      tester,
      state.controller.debugViewModel.switchConversation('b'),
    );
    expect(state.media.draftOwnerId, 'a');
    await native.deliver(
      NativeMessageInputHarness.codec.encodeMethodCall(
        MethodCall('command', {'session': native.session, 'command': 'submit'}),
      ),
    );
    await native.release();
    await go(tester, state, 'b');
    expect(store.peek('a')!.active.text, '${source}X');
    expect(store.peek('a')!.submissionId, isNull);
    expect(state.text.text, isEmpty);
    await unmount(tester);
  });

  testWidgets('clipboard failure does not disable later native input', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    addTearDown(native.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final state = await pump(tester, nativeInput: true);
    await go(tester, state, 'a');
    final source = 'original line\n' * 300;
    state.text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: source.length),
    );
    state.focus.requestFocus();
    await tester.pump();
    await tester.pump();
    final document = state.text as MessageEditingController;
    await finish(tester, document.performCommand('paste'));
    await native.commit('X');
    await finish(tester, document.flushInput());
    expect(document.text, '${source}X');
    await go(tester, state, 'b');
    expect(store.peek('a')!.active.text, '${source}X');
    await unmount(tester);
  });

  testWidgets('native undo while selecting is saved before changing drafts', (
    tester,
  ) async {
    final native = NativeMessageInputHarness(tester);
    addTearDown(native.dispose);
    final state = await pump(tester, nativeInput: true);
    await go(tester, state, 'a');
    final source = 'original line\n' * 300;
    state.text.value = TextEditingValue(
      text: source,
      selection: TextSelection.collapsed(offset: source.length),
    );
    state.focus.requestFocus();
    await tester.pump(const Duration(milliseconds: 600));
    await native.commit('X');
    await tester.pump(const Duration(milliseconds: 600));
    state.controller.shareMessage(-1, const []);
    await tester.pumpAndSettle();
    expect(state.media.isAttached, isFalse);
    await native.deliver(
      NativeMessageInputHarness.codec.encodeMethodCall(
        MethodCall('command', {'session': native.session, 'command': 'undo'}),
      ),
    );
    await finish(tester, (state.text as MessageEditingController).flushInput());
    expect(state.text.text, source);
    state.controller.onAppLifecycleStateChanged(AppLifecycleState.inactive);
    await finish(tester, store.flush());
    expect(store.peek('a')!.active.text, source);
    state.controller.cancelSelection();
    await tester.pumpAndSettle();
    await go(tester, state, 'b');
    await go(tester, state, 'a');
    expect(state.text.text, source);
    expect(state.text.selection.extentOffset, source.length);
    await unmount(tester);
  });

  testWidgets('real binder isolates A/B text, attachments and selection', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    state.text.value = const TextEditingValue(
      text: '  A\n😀 ',
      selection: TextSelection(baseOffset: 2, extentOffset: 3),
    );
    final file = await tester.runAsync(
      () => File('${root.path}/note.txt').writeAsString('a'),
    );
    state.media.addFiles([
      DocumentAttachment(
        path: file!.path,
        fileName: 'note.txt',
        mime: 'text/plain',
      ),
    ]);
    await go(tester, state, 'b');
    expect(state.text.text, isEmpty);
    expect(state.media.hasDraftMedia, isFalse);
    state.text.text = 'B';
    await go(tester, state, 'a');
    expect(state.text.text, '  A\n😀 ');
    expect(state.text.selection.baseOffset, 2);
    expect(
      state.media.snapshotInput(state.text.text).documents.single.fileName,
      'note.txt',
    );
    await go(tester, state, 'b');
    expect(state.text.text, 'B');
    await unmount(tester);
  });

  testWidgets('late attachment result belongs to its captured conversation', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    final target = state.media.capture();
    state.text.text = 'A';
    await go(tester, state, 'b');
    state.text.text = 'B';
    target.addFiles([
      const DocumentAttachment(
        path: '/unavailable.txt',
        fileName: 'late.txt',
        mime: 'text/plain',
      ),
    ]);
    await tester.pump();
    expect(state.text.text, 'B');
    expect(state.media.hasDraftMedia, isFalse);
    await go(tester, state, 'a');
    expect(
      state.media.snapshotInput(state.text.text).documents.single.fileName,
      'late.txt',
    );
    await unmount(tester);
  });

  testWidgets(
    'cancel an old message edit restores the ordinary compose draft',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'next question';
      await state.controller.startUserMessageEdit(
        ChatMessage(
          id: 'old',
          conversationId: 'a',
          role: 'user',
          content: 'previous question',
        ),
      );
      await tester.pumpAndSettle();
      state.text.text = 'changed previous';
      await go(tester, state, 'b');
      await go(tester, state, 'a');
      expect(state.text.text, 'changed previous');
      state.controller.cancelUserMessageEdit();
      await tester.pump();
      expect(state.text.text, 'next question');
      await unmount(tester);
    },
  );

  for (final action in ['cancel', 'copy during edit', 'clear edit']) {
    testWidgets('ordinary file import survives $action', (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'ordinary draft';
      final source = await tester.runAsync(
        () => File(
          '${root.path}/ordinary.txt',
        ).writeAsString('ordinary attachment'),
      );
      final file = GatedXFile(source!.path);
      final importing = state.controller.onFilesDroppedDesktop([file]);
      await finish(tester, file.started.future);
      await state.controller.startUserMessageEdit(
        ChatMessage(
          id: 'old',
          conversationId: 'a',
          role: 'user',
          content: 'old message',
        ),
      );
      await tester.pumpAndSettle();
      if (action == 'clear edit') state.media.clearDraft();
      if (action == 'cancel') state.controller.cancelUserMessageEdit();
      file.release.complete();
      await finish(tester, importing);
      if (action != 'cancel') {
        expect(state.media.hasDraftMedia, isFalse);
        expect(store.peek('a')!.compose.documents, hasLength(1));
        state.controller.cancelUserMessageEdit();
      }
      expect(state.text.text, 'ordinary draft');
      final docs = state.media.snapshotDraft(state.text.text).documents;
      expect(docs, hasLength(1));
      expect(docs.single.fileName, 'ordinary.txt');
      expect(
        await tester.runAsync(() => File(docs.single.path).readAsString()),
        'ordinary attachment',
      );
      await unmount(tester);
      final reopened = ComposerDraftStore(
        db,
        directory: () async => Directory('${root.path}/drafts'),
      );
      late ComposerDraft persisted;
      await finish(tester, () async {
        persisted = await reopened.load('a');
      }());
      reopened.dispose();
      expect(persisted.compose.documents.single.fileName, 'ordinary.txt');
      expect(persisted.compose.text, 'ordinary draft');
      expect(persisted.edit, isNull);
    });
  }

  testWidgets(
    'cancelled edit import cannot reappear when the same message is reopened',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'ordinary draft';
      final source = await tester.runAsync(
        () => File('${root.path}/edit.txt').writeAsString('cancel me'),
      );
      final message = ChatMessage(
        id: 'old',
        conversationId: 'a',
        role: 'user',
        content: 'old message',
      );
      await state.controller.startUserMessageEdit(message);
      await tester.pumpAndSettle();
      final file = GatedXFile(source!.path);
      final importing = state.controller.onFilesDroppedDesktop([file]);
      await finish(tester, file.started.future);
      state.controller.cancelUserMessageEdit();
      await state.controller.startUserMessageEdit(message);
      file.release.complete();
      await finish(tester, importing);
      expect(state.text.text, 'old message');
      expect(state.media.hasDraftMedia, isFalse);
      expect(store.peek('a')!.edit!.documents, isEmpty);
      state.controller.cancelUserMessageEdit();
      expect(state.text.text, 'ordinary draft');
      expect(store.peek('a')!.compose.documents, isEmpty);
      await unmount(tester);
    },
  );

  for (final editing in [false, true]) {
    for (final restore in ['replace', 'append', 'empty']) {
      final append = restore == 'append';
      final keepImport = restore != 'replace';
      testWidgets(
        'recovery handles in-flight import (edit: $editing, restore: $restore)',
        (tester) async {
          final state = await pump(tester);
          await go(tester, state, 'a');
          state.text.text = 'ordinary draft';
          if (editing) {
            await state.controller.startUserMessageEdit(
              ChatMessage(
                id: 'old',
                conversationId: 'a',
                role: 'user',
                content: 'old message',
              ),
            );
            await tester.pumpAndSettle();
          }
          state.text.text = 'pending message';
          await finish(
            tester,
            store
                .beginSubmission(
                  'a',
                  state.media.snapshotDraft(state.text.text),
                )
                .then<void>((_) {}),
          );
          store.submissionIdle('a');
          state.text.text = restore == 'empty' ? '' : 'current draft';
          final source = await tester.runAsync(
            () => File(
              '${root.path}/current.txt',
            ).writeAsString('current attachment'),
          );
          final file = GatedXFile(source!.path);
          final importing = state.controller.onFilesDroppedDesktop([file]);
          await finish(tester, file.started.future);
          final l10n = AppLocalizations.of(state.context)!;
          state.media.onRecoverDraft!();
          await tester.pumpAndSettle();
          if (restore == 'empty') {
            expect(find.text(l10n.composerDraftConflictTitle), findsNothing);
          } else {
            final choice = find.text(
              append ? l10n.composerDraftAppend : l10n.composerDraftReplace,
            );
            expect(choice, findsOneWidget);
            await tester.tap(choice);
            await tester.pumpAndSettle();
          }
          expect(store.peek('a')!.pending, isNull);
          file.release.complete();
          await finish(tester, importing);
          final expectedText = append
              ? 'current draft\n\npending message'
              : 'pending message';
          expect(state.text.text, expectedText);
          final documents = state.media
              .snapshotDraft(state.text.text)
              .documents;
          expect(documents, hasLength(keepImport ? 1 : 0));
          if (keepImport) {
            expect(
              await tester.runAsync(
                () => File(documents.single.path).readAsString(),
              ),
              'current attachment',
            );
          }
          await unmount(tester);
          final reopened = ComposerDraftStore(
            db,
            directory: () async => Directory('${root.path}/drafts'),
          );
          late ComposerDraft persisted;
          await finish(tester, () async {
            persisted = await reopened.load('a');
          }());
          reopened.dispose();
          expect(persisted.active.text, expectedText);
          expect(persisted.active.documents, hasLength(keepImport ? 1 : 0));
          if (editing) {
            expect(persisted.editMessageId, 'old');
            expect(persisted.compose.text, 'ordinary draft');
            expect(persisted.compose.documents, isEmpty);
          }
        },
      );
    }
  }

  testWidgets('failed move refreshes the visible source with its late import', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    state.text.text = 'source';
    await finish(tester, () async {
      await store.load('b');
      store.setInput('b', const ComposerDraftInput(text: 'target'));
      await store.flush();
    }());
    final source = await tester.runAsync(
      () => File('${root.path}/arriving.txt').writeAsString('late attachment'),
    );
    final file = GatedXFile(source!.path);
    final importing = state.controller.onFilesDroppedDesktop([file]);
    await finish(tester, file.started.future);
    final moving = state.controller.moveSharedDraft();
    await tester.pumpAndSettle();
    await tester.tap(find.text('b'));
    final l10n = AppLocalizations.of(state.context)!;
    final append = find.text(l10n.composerDraftAppend);
    for (var i = 0; i < 200 && append.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
    }
    await tester.pumpAndSettle();
    expect(append, findsOneWidget);
    final reached = Completer<void>();
    final release = Completer<void>();
    commits.afterCommit = true;
    commits.onNextCommit = () async {
      reached.complete();
      await release.future;
    };
    await tester.tap(append);
    await finish(tester, reached.future);
    expect(state.media.restoringDraft, isTrue);
    file.release.complete();
    await finish(tester, importing);
    expect(store.peek('a')!.compose.documents, hasLength(1));
    release.complete();
    await finish(tester, moving);
    expect(state.controller.currentConversation?.id, 'a');
    expect(state.media.restoringDraft, isFalse);
    expect(state.text.text, 'source');
    expect(state.media.snapshotDraft(state.text.text).documents, hasLength(1));
    state.text.text = 'source continued';
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await unmount(tester);
    final reopened = ComposerDraftStore(
      db,
      directory: () async => Directory('${root.path}/drafts'),
    );
    late ComposerDraft persisted;
    await finish(tester, () async {
      persisted = await reopened.load('a');
    }());
    reopened.dispose();
    expect(persisted.compose.text, 'source continued');
    expect(persisted.compose.documents, hasLength(1));
    expect(store.peek('b')!.compose.text, 'target');
    expect(store.peek('b')!.compose.documents, isEmpty);
  });

  testWidgets('move completion preserves later conversation selection', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    state.text.text = 'source';
    await finish(tester, () async {
      await store.load('b');
      await store.load('c');
      await store.flush();
    }());
    final moving = state.controller.moveSharedDraft();
    await tester.pumpAndSettle();
    final reached = Completer<void>();
    final release = Completer<void>();
    commits.afterCommit = true;
    commits.onNextCommit = () async {
      reached.complete();
      await release.future;
    };
    await tester.tap(find.text('b'));
    await finish(tester, reached.future);
    await go(tester, state, 'c');
    state.text.text = 'continue C';
    release.complete();
    await finish(tester, moving);
    expect(state.controller.currentConversation?.id, 'c');
    expect(state.media.draftOwnerId, 'c');
    expect(state.media.restoringDraft, isFalse);
    expect(state.text.text, 'continue C');
    expect(store.peek('a')!.active.isEmpty, isTrue);
    expect(store.peek('b')!.compose.text, 'source');
    await unmount(tester);
    expect(store.peek('c')!.compose.text, 'continue C');
  });

  testWidgets('clear invalidates already captured attachment imports', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    final target = state.media.capture();
    state.text.text = 'erase';
    state.media.clearDraft();
    target.insertText('late import');
    await tester.pump();
    expect(state.text.text, isEmpty);
    expect(store.peek('a')!.active.isEmpty, isTrue);
    await unmount(tester);
  });

  testWidgets('selection and backgrounding preserve the unmounted composer', (
    tester,
  ) async {
    final state = await pump(tester);
    await go(tester, state, 'a');
    state.text.value = const TextEditingValue(
      text: 'unsent with attachments',
      selection: TextSelection(baseOffset: 2, extentOffset: 6),
    );
    final file = await tester.runAsync(
      () => File('${root.path}/note.txt').writeAsString('keep me'),
    );
    state.media.restoreDraft(
      ComposerDraftInput(
        images: const [DraftImage(path: '/missing-image.png', failed: true)],
        documents: [
          DocumentAttachment(
            path: file!.path,
            fileName: 'note.txt',
            mime: 'text/plain',
          ),
        ],
      ),
    );
    await finish(tester, store.flush());
    state.controller.shareMessage(-1, const []);
    await tester.pumpAndSettle();
    expect(state.media.isAttached, isFalse);
    state.controller.onAppLifecycleStateChanged(AppLifecycleState.inactive);
    await finish(tester, store.flush());

    final reopened = ComposerDraftStore(
      db,
      directory: () async => Directory('${root.path}/drafts'),
    );
    late ComposerDraft restored;
    await finish(tester, () async {
      restored = await reopened.load('a');
    }());
    reopened.dispose();
    expect(restored.active.text, 'unsent with attachments');
    expect(restored.active.images, hasLength(1));
    expect(restored.active.documents, hasLength(1));
    expect(restored.active.selectionBase, 2);
    expect(restored.active.selectionExtent, 6);
    expect(restored.active.images.single.failed, isTrue);
    expect(restored.active.documents.single.fileName, 'note.txt');
    expect(File(restored.active.documents.single.path).existsSync(), isTrue);

    state.controller.cancelSelection();
    await tester.pumpAndSettle();
    final visible = state.media.snapshotDraft(state.text.text);
    expect(visible.images.single.failed, isTrue);
    expect(visible.documents.single.fileName, 'note.txt');
    expect(state.media.hasUnreadyImages, isTrue);
    await unmount(tester);
  });

  testWidgets(
    'attachment completion while selecting survives background save',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      final target = state.media.capture();
      state.text.text = 'keep text';
      state.controller.shareMessage(-1, const []);
      await tester.pumpAndSettle();
      target.addFiles([
        const DocumentAttachment(
          path: '/late.txt',
          fileName: 'late.txt',
          mime: 'text/plain',
        ),
      ]);
      state.controller.onAppLifecycleStateChanged(AppLifecycleState.inactive);
      await finish(tester, store.flush());
      state.controller.cancelSelection();
      await tester.pumpAndSettle();
      expect(state.text.text, 'keep text');
      expect(
        state.media.snapshotDraft(state.text.text).documents.single.fileName,
        'late.txt',
      );
      expect(store.peek('a')!.active.documents.single.fileName, 'late.txt');
      await unmount(tester);
    },
  );

  testWidgets(
    'failed overwrite unlocks the original draft without navigation',
    (tester) async {
      final state = await pump(tester);
      await go(tester, state, 'a');
      state.text.text = 'original draft';
      final hold = Completer<void>();
      var started = false;
      Object? failure;
      final overwrite = store
          .overwrite<void>(() async {
            started = true;
            await hold.future;
            throw StateError('restore failed');
          })
          .then<void>(
            (_) => fail('overwrite should fail'),
            onError: (Object error) {
              failure = error;
            },
          );
      await finish(tester, () async {
        while (!started) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }());
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isTrue,
      );
      hold.complete();
      await finish(tester, overwrite);
      expect(failure, isStateError);
      await tester.pumpAndSettle();
      expect(store.suspended, isFalse);
      expect(state.media.restoringDraft, isFalse);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).readOnly,
        isFalse,
      );
      expect(state.text.text, 'original draft');
      await tester.enterText(find.byType(EditableText), 'continue editing');
      await finish(tester, store.flush());
      expect(store.peek('a')!.active.text, 'continue editing');
      await unmount(tester);
    },
  );

  testWidgets('failed overwrite does not unlock an unreadable draft', (
    tester,
  ) async {
    final state = await pump(tester);
    await tester.runAsync(
      () => db.customStatement(
        'INSERT INTO extension_entity_rows(kind, id, sort_order, payload, updated_at) VALUES (?, ?, ?, ?, ?)',
        [ComposerDraftStore.kind, 'a', 0, 'invalid JSON', 0],
      ),
    );
    await finish(
      tester,
      state.controller.debugViewModel.switchConversation('a'),
    );
    await finish(tester, () async {
      while (!store.errors.containsKey('a')) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }());
    expect(state.media.restoringDraft, isTrue);
    expect(state.media.draftOwnerId, isNull);
    Object? failure;
    await finish(
      tester,
      store
          .overwrite<void>(() async {
            throw StateError('restore failed');
          })
          .catchError((Object error) {
            failure = error;
          }),
    );
    expect(failure, isStateError);
    expect(store.suspended, isFalse);
    expect(state.media.restoringDraft, isTrue);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).readOnly,
      isTrue,
    );
    expect(store.peek('a'), isNull);
    expect(store.errors, contains('a'));
    await unmount(tester);
  });

  for (final closeDuringRecovery in [false, true]) {
    testWidgets(
      'durable rejected submission survives retirement; close=$closeDuringRecovery',
      (tester) async {
        store.dispose();
        final gatedStore = _GatedDraftStore(
          db,
          directory: () async => Directory('${root.path}/drafts'),
        );
        store = gatedStore;
        await finish(tester, store.initialize());
        service = _DraftChatService(store);
        final native = NativeMessageInputHarness(tester);
        addTearDown(native.dispose);
        final state = await pump(tester, nativeInput: true);
        await go(tester, state, 'a');
        final document = state.text as MessageEditingController;
        final source = 'original line\n' * 300;
        document.value = TextEditingValue(
          text: source,
          selection: TextSelection.collapsed(offset: source.length),
        );
        state.focus.requestFocus();
        await tester.pump();
        await tester.pump();
        expect(document.hasNativeInput, isTrue);
        await document.performCommand('submit');
        await finish(tester, gatedStore.preparationStarted.future);
        expect(store.peek('a')!.pending, isNotNull);
        expect(document.text, isEmpty);

        native.holdDelivery = true;
        await native.commit('X');
        final retirement = document.retireInput();
        expect(document.isDraining, isTrue);
        gatedStore.releasePreparation.complete();
        // Default fixture has no selected provider/model, so actual Home sending
        // rejects and invokes its durable _recoverComposerSubmission path.
        for (var i = 0; i < 20 && store.submitting.contains('a'); i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(document.isDraining, isTrue);
        if (closeDuringRecovery) {
          // Recovery already awaits input; disposal must save its final snapshot
          // before recovery is allowed to consume the pending submission.
          expect(store.submitting, contains('a'));
          await tester.pump(const Duration(seconds: 4));
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpWidget(const SizedBox());
        }
        await native.release();
        await retirement;
        for (var i = 0; i < 200 && store.submitting.contains('a'); i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
        }
        expect(store.submitting, isNot(contains('a')));
        // Allow the actual rejection toast to dispose its animation before unmount.
        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(milliseconds: 400));
        final visible = document.text;
        final errors = <Object>[];
        Object? error;
        while ((error = tester.takeException()) != null) {
          errors.add(error!);
        }
        await unmount(tester);
        final reopened = ComposerDraftStore(
          db,
          directory: () async => Directory('${root.path}/drafts'),
        );
        late ComposerDraft persisted;
        await finish(tester, () async {
          persisted = await reopened.load('a');
        }());
        reopened.dispose();
        expect(errors, isEmpty);
        expect(
          persisted.active.text == visible,
          isTrue,
          reason:
              'Visible accepted input and the durable active draft must agree',
        );
        final allRetained =
            persisted.active.text + (persisted.pending?.text ?? '');
        expect(
          allRetained.contains(source),
          isTrue,
          reason:
              'The rejected submission remains in active or recoverable pending',
        );
        expect(
          allRetained.contains('X'),
          isTrue,
          reason: 'The later accepted native edit must also survive close',
        );
      },
    );
  }
}

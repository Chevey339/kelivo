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
  const _Harness({super.key});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with TickerProviderStateMixin {
  final text = TextEditingController();
  final media = ChatInputBarController();
  final focus = FocusNode();
  final scroll = ChatAutoFollowScrollController();
  final scaffold = GlobalKey<ScaffoldState>();
  final bar = GlobalKey();
  late final HomePageController controller;
  @override
  void initState() {
    super.initState();
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
  Future<_HarnessState> pump(WidgetTester tester) async {
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
          home: _Harness(key: key),
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
    for (var i = 0; i < 200 && !done; i++) {
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
}

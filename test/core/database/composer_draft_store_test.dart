import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show ApplyInterceptor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/composer_draft_store.dart';
import 'package:Kelivo/core/models/composer_draft.dart';
import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';

import '../../support/commit_gate.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late ComposerDraftStore store;
  late CommitGate commits;
  Future<void> open() async {
    commits = CommitGate();
    db = AppDatabase(
      NativeDatabase(File('${root.path}/drafts.db')).interceptWith(commits),
    );
    store = ComposerDraftStore(
      db,
      directory: () async => Directory('${root.path}/files'),
    );
    await store.initialize();
  }

  Future<void> reopen() async {
    store.dispose();
    await db.close();
    await open();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('composer-draft-');
    await open();
  });
  tearDown(() async {
    store.dispose();
    await db.close();
    await root.delete(recursive: true);
  });

  test('A and B retain exact independent text after database reopen', () async {
    await store.load('a');
    await store.load('b');
    const text = '  你好 😀\n\n    code\r\n ';
    store.setInput(
      'a',
      const ComposerDraftInput(
        text: text,
        selectionBase: 2,
        selectionExtent: 5,
      ),
    );
    store.setInput('b', const ComposerDraftInput(text: 'B'));
    await store.flush();
    await reopen();
    expect((await store.load('a')).active.text, text);
    expect((await store.load('a')).active.selectionExtent, 5);
    expect((await store.load('b')).active.text, 'B');
  });

  test('new entry preserves identity and seed with the draft', () async {
    final conversation = Conversation(
      id: 'new-id',
      title: 'New',
      assistantId: 'assistant',
      chatModelId: 'model',
      chatModelProvider: 'provider',
    );
    store.registerNewEntry(conversation);
    await store.load(conversation.id, assistantId: conversation.assistantId);
    store.setInput(conversation.id, const ComposerDraftInput(text: 'unsent'));
    await store.flush();
    await reopen();
    expect(store.newEntry('assistant')?.id, 'new-id');
    expect(store.newEntry('assistant')?.chatModelId, 'model');
    expect((await store.load('new-id')).active.text, 'unsent');
  });

  test(
    'attachments are recoverable after the selected original disappears',
    () async {
      final source = File('${root.path}/report.txt');
      await source.writeAsString('report');
      await store.load('a');
      store.setInput(
        'a',
        ComposerDraftInput(
          documents: [
            DocumentAttachment(
              path: source.path,
              fileName: 'report.txt',
              mime: 'text/plain',
            ),
          ],
        ),
      );
      await store.flush();
      await source.delete();
      await reopen();
      final doc = (await store.load('a')).active.documents.single;
      expect(doc.fileName, 'report.txt');
      expect(await File(doc.path).readAsString(), 'report');
    },
  );

  test(
    'submission and subsequently typed text both survive interruption',
    () async {
      await store.load('a');
      store.setInput('a', const ComposerDraftInput(text: 'first'));
      final submission = await store.beginSubmission(
        'a',
        store.peek('a')!.active,
      );
      store.setInput('a', const ComposerDraftInput(text: 'second'));
      await store.flush();
      await reopen();
      final draft = await store.load('a');
      expect(draft.compose.text, 'second');
      expect(draft.pending?.text, 'first');
      expect(draft.submissionId, submission.id);
      store.restorePending('a');
      expect(draft.compose.text, 'second');
      expect(draft.pending?.text, 'first');
      store.restorePending('a', append: true);
      expect(draft.compose.text, 'second\n\nfirst');
      expect(draft.pending, isNull);
    },
  );

  test(
    'editing suspends ordinary input and preserves message identity',
    () async {
      await store.load('a');
      store.setInput('a', const ComposerDraftInput(text: 'next question'));
      store.beginEdit(
        'a',
        'old-message',
        const ComposerDraftInput(text: 'edited question'),
      );
      await store.flush();
      await reopen();
      final draft = await store.load('a');
      expect(draft.active.text, 'edited question');
      expect(draft.editMessageId, 'old-message');
      store.endEdit('a');
      expect(draft.active.text, 'next question');
    },
  );

  test(
    'deletion invalidates pending saves and cannot resurrect a draft',
    () async {
      await store.load('a');
      store.setInput('a', const ComposerDraftInput(text: 'delete me'));
      final generation = store.epoch('a');
      await store.delete('a');
      store.setInput('a', const ComposerDraftInput(text: 'late result'));
      await store.flush();
      expect(store.isCurrent('a', generation), isFalse);
      await reopen();
      expect(store.draftIds, isEmpty);
    },
  );
  test('new entry persists configuration without any text', () async {
    store.registerNewEntry(
      Conversation(
        id: 'new',
        title: 'New',
        assistantId: 'assistant',
        chatModelId: 'chosen',
      ),
    );
    await store.flush();
    await reopen();
    expect(store.newEntry('assistant')?.chatModelId, 'chosen');
    expect(store.hasDraft('new'), isFalse);
  });

  test(
    'share receipt survives deletion until native acknowledgement',
    () async {
      await store.load('a');
      await store.acceptShare('a', const ComposerDraftInput(text: 'share'), [
        'share-id',
      ]);
      await reopen();
      expect(await store.hasShareReceipt('share-id'), isTrue);
      expect((await store.load('a')).active.text, 'share');
      await store.delete('a');
      await reopen();
      expect(await store.hasShareReceipt('share-id'), isTrue);
      await store.acknowledgeShares(['share-id']);
      expect(await store.hasShareReceipt('share-id'), isFalse);
    },
  );

  test(
    'transfer commits both owners and makes independent file copies',
    () async {
      await store.load('a');
      await store.load('b');
      final file = await File(
        '${root.path}/source.txt',
      ).writeAsString('attachment');
      store.setInput(
        'a',
        ComposerDraftInput(
          text: 'A',
          documents: [
            DocumentAttachment(
              path: file.path,
              fileName: 'source.txt',
              mime: 'text/plain',
            ),
          ],
        ),
      );
      store.setInput('b', const ComposerDraftInput(text: 'B'));
      final oldEpoch = store.epoch('a');
      await store.transfer('a', 'b', append: true);
      expect(store.isCurrent('a', oldEpoch), isFalse);
      await store.delete('a');
      await reopen();
      final b = await store.load('b');
      expect(b.active.text, 'B\n\nA');
      expect(
        await File(b.active.documents.single.path).readAsString(),
        'attachment',
      );
    },
  );

  test(
    'failed overwrite keeps saved drafts and rejects old captured operations',
    () async {
      await store.load('a');
      store.setInput('a', const ComposerDraftInput(text: 'keep'));
      final epoch = store.inputEpoch('a', editMessageId: null);
      await expectLater(
        store.overwrite(() async => throw StateError('restore failed')),
        throwsStateError,
      );
      expect(store.suspended, isFalse);
      store.mutateCaptured(
        'a',
        epoch,
        null,
        (_) => const ComposerDraftInput(text: 'late'),
      );
      await reopen();
      expect((await store.load('a')).active.text, 'keep');
    },
  );

  test(
    'a corrupt row can be retried without overwriting the stored record',
    () async {
      await db.customStatement(
        "INSERT INTO extension_entity_rows(kind,id,sort_order,payload,updated_at) VALUES('composerDraft','a',0,'broken',0)",
      );
      await expectLater(store.load('a'), throwsFormatException);
      expect(store.errors.containsKey('a'), isTrue);
      await db.customStatement(
        "DELETE FROM extension_entity_rows WHERE id='a'",
      );
      expect((await store.load('a')).active.isEmpty, isTrue);
      expect(store.errors.containsKey('a'), isFalse);
    },
  );
  test(
    'imported conversation IDs cannot escape the private directory',
    () async {
      final victim = await File('${root.path}/keep.txt').writeAsString('keep');
      final dir = await store.directoryFor('../');
      expect(dir.path.startsWith('${root.path}/files/'), isTrue);
      await store.removePrivateDirectory('../');
      expect(await victim.readAsString(), 'keep');
    },
  );
  test(
    'changing an unloaded entry seed does not replace its saved input',
    () async {
      final seed = Conversation(
        id: 'new',
        title: 'New',
        assistantId: 'assistant',
        chatModelId: 'before',
      );
      store.registerNewEntry(seed);
      store.setInput('new', const ComposerDraftInput(text: 'must survive'));
      await store.flush();
      await reopen();
      store.updateSeed(seed.copyWith(chatModelId: 'after'));
      await store.flush();
      await reopen();
      expect(store.newEntry('assistant')?.chatModelId, 'after');
      expect((await store.load('new')).active.text, 'must survive');
    },
  );
  test(
    'recovering an ordinary send keeps a newer message edit independent',
    () async {
      await store.load('a');
      await store.beginSubmission(
        'a',
        const ComposerDraftInput(text: 'unsent ordinary'),
      );
      store.beginEdit(
        'a',
        'other-message',
        const ComposerDraftInput(text: 'edit newer'),
      );
      store.restorePending('a');
      expect(store.peek('a')!.compose.text, 'unsent ordinary');
      expect(store.peek('a')!.edit?.text, 'edit newer');
      expect(store.peek('a')!.editMessageId, 'other-message');
    },
  );

  test(
    'an older failed edit cannot close or replace a new empty edit',
    () async {
      await store.load('a');
      store.beginEdit(
        'a',
        'old-message',
        const ComposerDraftInput(text: 'old edit'),
      );
      await store.beginSubmission('a', store.peek('a')!.active);
      store.beginEdit('a', 'new-message', const ComposerDraftInput());
      store.restorePending('a');
      expect(store.peek('a')!.pending?.text, 'old edit');
      expect(store.peek('a')!.editMessageId, 'new-message');
    },
  );

  test('submitting an edit only cancels captures from that input', () async {
    await store.load('a');
    store.setInput('a', const ComposerDraftInput(text: 'ordinary'));
    final media = ChatInputBarController()
      ..draftStore = store
      ..draftOwnerId = 'a';
    final ordinary = media.capture();
    store.beginEdit('a', 'old', const ComposerDraftInput(text: 'edited'));
    final editing = media.capture();
    await store.beginSubmission('a', store.peek('a')!.active);
    ordinary.addFiles([
      const DocumentAttachment(
        path: '/ordinary.txt',
        fileName: 'ordinary.txt',
        mime: 'text/plain',
      ),
    ]);
    editing.addFiles([
      const DocumentAttachment(
        path: '/stale.txt',
        fileName: 'stale.txt',
        mime: 'text/plain',
      ),
    ]);
    expect(ordinary.isValid, isTrue);
    expect(editing.isValid, isFalse);
    expect(store.peek('a')!.compose.documents.single.fileName, 'ordinary.txt');
    expect(store.peek('a')!.edit!.documents, isEmpty);
    store.restorePending('a');
    store.submissionIdle('a');
    await store.flush();
    await reopen();
    final restored = await store.load('a');
    expect(restored.compose.documents.single.fileName, 'ordinary.txt');
    expect(restored.edit!.text, 'edited');
    expect(restored.edit!.documents, isEmpty);
  });

  test(
    'replacing the same edit rejects its previous import without cancelling compose',
    () async {
      await store.load('a');
      final media = ChatInputBarController()
        ..draftStore = store
        ..draftOwnerId = 'a';
      final ordinary = media.capture();
      store.beginEdit('a', 'old', const ComposerDraftInput(text: 'first edit'));
      final previousEdit = media.capture();
      store.beginEdit(
        'a',
        'old',
        const ComposerDraftInput(text: 'replacement'),
      );
      previousEdit.insertText(' stale result');
      ordinary.insertText('ordinary result');
      expect(previousEdit.isValid, isFalse);
      expect(ordinary.isValid, isTrue);
      expect(store.peek('a')!.edit!.text, 'replacement');
      expect(store.peek('a')!.compose.text, 'ordinary result');
      await store.flush();
    },
  );

  for (final action in ['delete', 'failed overwrite']) {
    test('$action invalidates both compose and edit captures', () async {
      await store.load('a');
      final media = ChatInputBarController()
        ..draftStore = store
        ..draftOwnerId = 'a';
      final ordinary = media.capture();
      store.beginEdit('a', 'old', const ComposerDraftInput(text: 'keep edit'));
      final editing = media.capture();
      if (action == 'delete') {
        await store.delete('a');
      } else {
        await expectLater(
          store.overwrite<void>(() async {
            throw StateError('failed');
          }),
          throwsStateError,
        );
      }
      ordinary.insertText('stale ordinary');
      editing.insertText('stale edit');
      expect(ordinary.isValid, isFalse);
      expect(editing.isValid, isFalse);
      if (action == 'delete') {
        expect(store.peek('a'), isNull);
      } else {
        expect(store.peek('a')!.compose.text, isEmpty);
        expect(store.peek('a')!.edit!.text, 'keep edit');
      }
      await store.flush();
    });
  }

  for (final append in [false, true]) {
    test(
      'moving an edit preserves ordinary imports in both conversations (append: $append)',
      () async {
        await store.load('a');
        await store.load('b');
        final mediaA = ChatInputBarController()
          ..draftStore = store
          ..draftOwnerId = 'a';
        final mediaB = ChatInputBarController()
          ..draftStore = store
          ..draftOwnerId = 'b';
        final ordinaryA = mediaA.capture();
        final ordinaryB = mediaB.capture();
        store.beginEdit(
          'a',
          'a-old',
          const ComposerDraftInput(text: 'moved edit'),
        );
        store.beginEdit(
          'b',
          'b-old',
          const ComposerDraftInput(text: 'target edit'),
        );
        final editingA = mediaA.capture();
        final editingB = mediaB.capture();
        await store.transfer('a', 'b', append: append);
        ordinaryA.insertText('ordinary A');
        ordinaryB.insertText('ordinary B');
        editingA.insertText('stale source result');
        editingB.insertText(' target result');
        expect(store.peek('a')!.compose.text, 'ordinary A');
        expect(store.peek('b')!.compose.text, 'ordinary B');
        expect(store.peek('a')!.edit!.isEmpty, isTrue);
        expect(
          store.peek('b')!.edit!.text,
          append ? 'target edit\n\nmoved edit target result' : 'moved edit',
        );
        await store.flush();
      },
    );
  }

  for (final editing in [false, true]) {
    test(
      'recovery replacement invalidates only its input (edit: $editing)',
      () async {
        await store.load('a');
        final media = ChatInputBarController()
          ..draftStore = store
          ..draftOwnerId = 'a';
        final ordinary = media.capture();
        if (editing) {
          store.beginEdit('a', 'old', const ComposerDraftInput());
        }
        await store.beginSubmission(
          'a',
          const ComposerDraftInput(text: 'pending'),
        );
        store.submissionIdle('a');
        final replaced = media.capture();
        if (!editing) {
          store.beginEdit('a', 'other', const ComposerDraftInput());
        }
        final independent = editing ? ordinary : media.capture();
        store.restorePending('a', replace: true);
        replaced.insertText('stale result');
        independent.insertText('independent result');
        expect(replaced.isValid, isFalse);
        expect(independent.isValid, isTrue);
        final draft = store.peek('a')!;
        expect(editing ? draft.edit!.text : draft.compose.text, 'pending');
        expect(
          editing ? draft.compose.text : draft.edit!.text,
          'independent result',
        );
        await store.flush();
      },
    );
  }

  for (final scenario in [
    (owner: 'b', editing: false, afterCommit: false, fail: false),
    (owner: 'b', editing: false, afterCommit: true, fail: false),
    (owner: 'a', editing: false, afterCommit: true, fail: false),
    (owner: 'b', editing: true, afterCommit: true, fail: false),
    (owner: 'b', editing: false, afterCommit: false, fail: true),
  ]) {
    test('transfer preserves imports across commit: $scenario', () async {
      await store.load('a');
      await store.load('b');
      store.setInput('a', const ComposerDraftInput(text: 'source'));
      store.setInput('b', const ComposerDraftInput(text: 'target'));
      if (scenario.editing) {
        store.beginEdit(
          'a',
          'a-old',
          const ComposerDraftInput(text: 'source edit'),
        );
        store.beginEdit(
          'b',
          'b-old',
          const ComposerDraftInput(text: 'target edit'),
        );
      }
      await store.flush();
      final originalSource = store.peek('a')!.active.text;
      final originalTarget = store.peek('b')!.active.text;
      final media = ChatInputBarController()
        ..draftStore = store
        ..draftOwnerId = scenario.owner;
      final importer = media.capture();
      final file = await File(
        '${root.path}/arriving.txt',
      ).writeAsString('arriving attachment');
      final reached = Completer<void>();
      final release = Completer<void>();
      commits.afterCommit = scenario.afterCommit;
      commits.onNextCommit = () async {
        reached.complete();
        await release.future;
        if (scenario.fail) throw StateError('commit failed');
      };
      final moving = store
          .transfer('a', 'b', append: true)
          .then<Object?>((_) => null, onError: (Object error) => error);
      await reached.future;
      importer.addFiles([
        DocumentAttachment(
          path: file.path,
          fileName: 'arriving.txt',
          mime: 'text/plain',
        ),
      ]);
      expect(store.peek(scenario.owner)!.active.documents, hasLength(1));
      release.complete();
      final error = await moving;
      expect(
        store.peek(scenario.owner)!.active.documents,
        hasLength(1),
        reason:
            'The committed snapshot must not erase an import that just arrived',
      );
      expect(error, isA<StateError>());
      expect(store.peek('a')!.active.text, originalSource);
      expect(store.peek('b')!.active.text, originalTarget);
      expect(importer.isValid, isTrue);
      await reopen();
      final source = await store.load('a');
      final target = await store.load('b');
      expect(source.active.text, originalSource);
      expect(target.active.text, originalTarget);
      final recovered = store.peek(scenario.owner)!.active.documents.single;
      expect(await File(recovered.path).readAsString(), 'arriving attachment');

      // A retry moves once after the concurrent change is safely persisted.
      await store.transfer('a', 'b', append: true);
      await reopen();
      expect((await store.load('a')).active.isEmpty, isTrue);
      final moved = await store.load('b');
      expect(moved.active.text, '$originalTarget\n\n$originalSource');
      expect(moved.active.documents, hasLength(1));
      expect(
        await File(moved.active.documents.single.path).readAsString(),
        'arriving attachment',
      );
      if (scenario.editing) {
        expect((await store.load('a')).compose.text, 'source');
        expect(moved.compose.text, 'target');
      }
    });
  }
}

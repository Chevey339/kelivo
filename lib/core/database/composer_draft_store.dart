import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../utils/app_directories.dart';
import '../../utils/sandbox_path_resolver.dart';
import '../models/chat_input_data.dart';
import '../models/composer_draft.dart';
import '../models/conversation.dart';
import 'app_database.dart';

/// Device-local editor state. All mutations have an owner, including writes
/// completing after navigation. Files live outside the portable backup roots.
class ComposerDraftStore extends ChangeNotifier {
  ComposerDraftStore(this._db, {Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  static const kind = 'composerDraft';
  static const entryKind = 'composerNewEntry';
  static const receiptKind = 'composerShareReceipt';
  static const privateFileKind = 'composerPrivateFile';
  static const publishedFileKind = 'composerPublishedFile';
  final AppDatabase _db;
  // Persistence timers belong to the store's lifetime, not a caller's short
  // lived zone (for example a debounced calculation or a scoped fake clock).
  final Zone _timerZone = Zone.current;
  final Future<Directory> Function() _directory;
  final Map<String, ComposerDraft> _drafts = {};
  final Map<String, Future<ComposerDraft>> _loads = {};
  final Map<String, Conversation> _entries = {};
  final Set<String> _ids = {};
  final Set<String> _dirty = {};
  final Set<String> _deleted = {};
  final Map<String, int> _epochs = {};
  final Map<(String, bool), int> _inputEpochs = {};
  final Map<String, Future<String>> _imports = {};
  final Map<String, String> _ownedPaths = {};
  final Map<String, Set<String>> _shareReceipts = {};
  final Map<String, Object> errors = {};
  Future<void> _tail = Future.value();
  int _pendingOperations = 0;
  Future<void>? _initializing;
  Timer? _debounce;
  Timer? _maximumWait;
  bool _disposed = false;
  bool suspended = false;
  int resetRevision = 0;
  final Set<String> submitting = {};
  String? externalOwner;
  int externalRevision = 0;

  void mutateCaptured(
    String id,
    int generation,
    String? editMessageId,
    ComposerDraftInput Function(ComposerDraftInput) transform,
  ) {
    if (!isInputCurrent(id, generation, editMessageId: editMessageId)) return;
    final draft = _drafts[id];
    if (draft == null) return;
    if (editMessageId != null) {
      if (draft.editMessageId != editMessageId || draft.edit == null) return;
      final next = transform(draft.edit!);
      if (next.sameValue(draft.edit!)) return;
      draft.edit = next;
    } else {
      final next = transform(draft.compose);
      if (next.sameValue(draft.compose)) return;
      draft.compose = next;
    }
    _changed(draft);
    externalOwner = id;
    externalRevision++;
    if (!_disposed) notifyListeners();
  }

  void invalidateOperations(String id) {
    _epochs[id] = epoch(id) + 1;
    _advanceInputEpoch(id, editing: false);
    _advanceInputEpoch(id, editing: true);
  }

  void invalidateInputOperations(String id, {required String? editMessageId}) {
    // Fence a stale full-draft write while keeping imports for the other input
    // alive. Delete/overwrite use invalidateOperations to invalidate both.
    _epochs[id] = epoch(id) + 1;
    _advanceInputEpoch(id, editing: editMessageId != null);
  }

  void _advanceInputEpoch(String id, {required bool editing}) {
    final key = (id, editing);
    _inputEpochs[key] = (_inputEpochs[key] ?? 0) + 1;
  }

  int inputEpoch(String id, {required String? editMessageId}) =>
      _inputEpochs[(id, editMessageId != null)] ?? 0;

  bool isInputCurrent(
    String id,
    int generation, {
    required String? editMessageId,
  }) =>
      !_disposed &&
      !suspended &&
      !_deleted.contains(id) &&
      inputEpoch(id, editMessageId: editMessageId) == generation &&
      (editMessageId == null ||
          (_drafts[id]?.editMessageId == editMessageId &&
              _drafts[id]?.edit != null));

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await AppDirectories.getAppDataDirectory()).path, 'drafts'),
  );

  static String _directoryName(String owner) =>
      sha256.convert(utf8.encode(owner)).toString();

  Future<Directory> directoryFor(String owner) async {
    final dir = Directory(
      p.join((await _directory()).path, _directoryName(owner)),
    );
    await dir.create(recursive: true);
    return dir;
  }

  Set<String> get draftIds => Set.unmodifiable(_ids);
  bool hasDraft(String id) => _ids.contains(id);
  ComposerDraft? peek(String id) => _drafts[id];
  int epoch(String id) => _epochs[id] ?? 0;
  bool isCurrent(String id, int epoch) =>
      !_disposed && !_deleted.contains(id) && this.epoch(id) == epoch;

  Future<void> initialize() => _initializing ??= () async {
    final ids = await _db
        .customSelect(
          'SELECT id FROM extension_entity_rows WHERE kind = ?',
          variables: [const Variable(kind)],
        )
        .get();
    _ids.addAll(ids.map((row) => row.read<String>('id')));
    final rows = await _db
        .customSelect(
          'SELECT id, payload FROM extension_entity_rows WHERE kind = ?',
          variables: [const Variable(entryKind)],
        )
        .get();
    for (final row in rows) {
      try {
        _entries[row.read<String>('id')] = Conversation.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          ),
        );
      } catch (error) {
        // A damaged entry must not prevent other conversations from opening.
        errors[row.read<String>('id')] = error;
      }
    }
    // No imports are running during initialization. Remove only our private
    // directories, including temporary conversations left by a killed process.
    final root = await _directory();
    try {
      if (await root.exists()) {
        final owners = {
          ..._ids,
          ..._entries.values.map((entry) => entry.id),
        }.map(_directoryName).toSet();
        await for (final entity in root.list(followLinks: false)) {
          if (entity is Directory &&
              !owners.contains(p.basename(entity.path))) {
            await entity.delete(recursive: true);
          }
        }
      }
    } on FileSystemException {
      /* Retry housekeeping on the next startup. */
    }
    await _reclaimUnsubmittedUploads();
  }();

  Future<void> _reclaimUnsubmittedUploads() async {
    final rows = await _db
        .customSelect(
          'SELECT id, owner_id FROM extension_entity_rows WHERE kind = ?',
          variables: [const Variable(privateFileKind)],
        )
        .get();
    if (rows.isEmpty) return;
    final upload = await AppDirectories.getUploadDirectory();
    for (final row in rows) {
      final uri = row.read<String>('id');
      final submissionId = row.readNullable<String>('owner_id');
      if (submissionId == null || await wasSubmitted(submissionId)) continue;
      final file = File(SandboxPathResolver.fix(uri));
      // Only our prepared copies inside the upload root are eligible.
      if (!p.equals(p.dirname(file.absolute.path), upload.absolute.path) ||
          !p.basename(file.path).startsWith('draft-$submissionId-')) {
        continue;
      }
      try {
        if (await file.exists()) await file.delete();
        await _deleteRow(privateFileKind, uri);
      } on FileSystemException {
        /* Retry next startup. */
      }
    }
  }

  static String entryId(String? assistantId) => assistantId ?? '__default__';
  Conversation? newEntry(String? assistantId) => _entries[entryId(assistantId)];
  bool isNewEntry(String id) => _entries.values.any((entry) => entry.id == id);
  void registerNewEntry(Conversation conversation) {
    _entries.removeWhere((_, entry) => entry.id == conversation.id);
    _entries[entryId(conversation.assistantId)] = conversation.copyWith();
    if (!_ids.contains(conversation.id) &&
        !_loads.containsKey(conversation.id)) {
      _drafts.putIfAbsent(
        conversation.id,
        () => ComposerDraft(
          conversationId: conversation.id,
          assistantId: conversation.assistantId,
        ),
      );
    }
    final draft = _drafts[conversation.id];
    if (draft != null) draft.revision++;
    _schedule(conversation.id);
  }

  void updateSeed(Conversation conversation) {
    if (!isNewEntry(conversation.id)) return;
    registerNewEntry(conversation);
  }

  Future<ComposerDraft> load(String id, {String? assistantId}) async {
    await initialize();
    if (_deleted.contains(id)) throw StateError('composer_owner_deleted');
    if (_drafts[id] case final draft?) return draft;
    try {
      return await _loads.putIfAbsent(id, () async {
        final generation = epoch(id);
        final row = await _db
            .customSelect(
              'SELECT payload FROM extension_entity_rows WHERE kind = ? AND id = ?',
              variables: [const Variable(kind), Variable(id)],
            )
            .getSingleOrNull();
        final draft = row == null
            ? ComposerDraft(conversationId: id, assistantId: assistantId)
            : ComposerDraft.fromJson(
                Map<String, dynamic>.from(
                  jsonDecode(row.read<String>('payload')) as Map,
                ),
              );
        if (draft.conversationId != id) {
          throw StateError('composer_owner_mismatch');
        }
        await _removeCommittedSubmission(draft);
        if (!isCurrent(id, generation)) {
          throw StateError('composer_owner_deleted');
        }
        await _pruneOwnerFiles(id, draft);
        if (!isCurrent(id, generation)) {
          throw StateError('composer_owner_deleted');
        }
        _drafts[id] = draft;
        errors.remove(id);
        return draft;
      });
    } catch (error) {
      errors[id] = error;
      if (!_disposed) notifyListeners();
      rethrow;
    } finally {
      _loads.remove(id);
    }
  }

  void setInput(String id, ComposerDraftInput input) {
    if (suspended || _deleted.contains(id)) return;
    final draft = _drafts[id];
    if (draft == null || draft.active.sameValue(input)) return;
    if (draft.edit != null) {
      draft.edit = input;
    } else {
      draft.compose = input;
    }
    _changed(draft);
  }

  void _changed(ComposerDraft draft) {
    draft.revision++;
    final had = _ids.contains(draft.conversationId);
    if (draft.hasContent) {
      _ids.add(draft.conversationId);
    } else {
      _ids.remove(draft.conversationId);
    }
    _schedule(draft.conversationId);
    if (had != draft.hasContent && !_disposed) notifyListeners();
  }

  void _schedule(String id) {
    if (_disposed || _deleted.contains(id)) return;
    _dirty.add(id);
    _debounce?.cancel();
    _debounce = _timerZone.run(
      () => Timer(const Duration(milliseconds: 300), _saveSoon),
    );
    _maximumWait ??= _timerZone.run(
      () => Timer(const Duration(seconds: 1), _saveSoon),
    );
  }

  void _saveSoon() {
    unawaited(flush().catchError((Object _) {}));
  }

  Future<void> flush() {
    if (_disposed) return Future.value();
    _debounce?.cancel();
    _maximumWait?.cancel();
    _maximumWait = null;
    if (_dirty.isEmpty && _pendingOperations == 0) return Future.value();
    return _serialize(() async {
      final ids = _dirty.toList();
      Object? firstError;
      StackTrace? firstStack;
      for (final id in ids) {
        if (_deleted.contains(id)) {
          _dirty.remove(id);
          continue;
        }
        try {
          final draft = _drafts[id] ?? await load(id);
          final revision = draft.revision;
          final generation = epoch(id);
          final receipts = Set<String>.of(_shareReceipts[id] ?? {});
          final snapshot = ComposerDraft.fromJson(draft.toJson());
          snapshot.compose = await _ownInput(id, snapshot.compose);
          if (snapshot.edit != null) {
            snapshot.edit = await _ownInput(id, snapshot.edit!);
          }
          if (snapshot.pending != null) {
            snapshot.pending = await _ownInput(id, snapshot.pending!);
          }
          if (!isCurrent(id, generation)) continue;
          var committed = false;
          await _db.transaction(() async {
            committed =
                snapshot.submissionId != null &&
                await wasSubmitted(snapshot.submissionId!);
            await _removeCommittedSubmission(snapshot);
            if (snapshot.hasContent) {
              await _put(
                kind,
                id,
                snapshot.toJson(),
                ownerId: draft.assistantId,
              );
            } else {
              await _deleteRow(kind, id);
            }
            for (final entry
                in _entries.entries
                    .where((entry) => entry.value.id == id && !committed)
                    .toList()) {
              await _put(
                entryKind,
                entry.key,
                entry.value.toJson(),
                ownerId: id,
              );
            }
            for (final shareId in receipts) {
              await _put(receiptKind, shareId, {}, ownerId: id);
            }
          });
          if (committed) {
            _entries.removeWhere((_, entry) => entry.id == id);
          }
          _shareReceipts[id]?.removeAll(receipts);
          if (_shareReceipts[id]?.isEmpty ?? false) _shareReceipts.remove(id);
          final hadError = errors.remove(id) != null;
          if (draft.revision == revision) {
            // Durable reconciliation may run before the send callback returns.
            // Keep the live editor's slot until finishSubmission, or typing
            // into an emptied edit could overwrite the ordinary compose draft.
            if (!committed || !submitting.contains(id)) {
              draft.compose = snapshot.compose;
              draft.edit = snapshot.edit;
              draft.pending = snapshot.pending;
              draft.submissionId = snapshot.submissionId;
              draft.submissionEditId = snapshot.submissionEditId;
              draft.editMessageId = snapshot.editMessageId;
            }
            _dirty.remove(id);
          }
          if (hadError && !_disposed) notifyListeners();
        } catch (error, stack) {
          errors[id] = error;
          firstError ??= error;
          firstStack ??= stack;
          if (!_disposed) notifyListeners();
        }
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
    });
  }

  Future<T> _serialize<T>(Future<T> Function() action) {
    _pendingOperations++;
    final future = _tail.then((_) async {
      try {
        return await action();
      } finally {
        _pendingOperations--;
      }
    });
    _tail = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  Future<ComposerDraftInput> _ownInput(
    String id,
    ComposerDraftInput input,
  ) async {
    final paths = <String, String>{};
    for (final path in input.paths) {
      paths[path] = await ownFile(id, path);
    }
    return input.copyWith(
      images: [
        for (final image in input.images)
          DraftImage(
            path: paths[image.path]!,
            processing: image.processing,
            failed: image.failed,
          ),
      ],
      documents: [
        for (final doc in input.documents)
          DocumentAttachment(
            path: paths[doc.path]!,
            fileName: doc.fileName,
            mime: doc.mime,
          ),
      ],
    );
  }

  bool sameOwnedFile(String id, String stored, String source) =>
      stored == source ||
      stored == _ownedPaths['$id\u0000${SandboxPathResolver.fix(source)}'];

  Future<String> ownFile(String id, String path) async {
    if (path.startsWith('data:') ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }
    final source = File(SandboxPathResolver.fix(path));
    final dir = await directoryFor(id);
    if (p.isWithin(dir.path, source.absolute.path)) return source.path;
    final sourceKey = '$id\u0000${source.path}';
    final stat = await source.stat();
    if (stat.type != FileSystemEntityType.file) {
      return _ownedPaths[sourceKey] ??
          path; // Keep an unavailable attachment visible.
    }
    final key =
        '$id\u0000${source.path}\u0000${stat.modified.microsecondsSinceEpoch}\u0000${stat.size}';
    try {
      return await _imports.putIfAbsent(key, () async {
        final target = File(
          p.join(dir.path, '${const Uuid().v4()}${p.extension(source.path)}'),
        );
        final staging = File('${target.path}.part');
        await source.copy(staging.path);
        await staging.rename(target.path);
        _ownedPaths[sourceKey] = target.path;
        return target.path;
      });
    } catch (_) {
      _imports.remove(key);
      rethrow;
    }
  }

  Future<DraftSubmission> beginSubmission(String id, ComposerDraftInput input) {
    final draft = _drafts[id];
    if (draft == null || suspended || _deleted.contains(id)) {
      throw StateError('composer_owner_deleted');
    }
    if (draft.pending != null) throw StateError('composer_submission_pending');
    invalidateInputOperations(id, editMessageId: draft.editMessageId);
    submitting.add(id);
    final submission = DraftSubmission(
      conversationId: id,
      id: const Uuid().v4(),
      editMessageId: draft.editMessageId,
    );
    draft.pending = input;
    draft.submissionId = submission.id;
    draft.submissionEditId = submission.editMessageId;
    if (draft.edit != null) {
      draft.edit = const ComposerDraftInput();
    } else {
      draft.compose = const ComposerDraftInput();
    }
    _changed(draft);
    return flush().then(
      (_) => submission,
      onError: (Object error, StackTrace stack) {
        submissionIdle(id);
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  void submissionIdle(String id) {
    submitting.remove(id);
    if (!_disposed) notifyListeners();
  }

  Future<bool> wasSubmitted(String id) async =>
      (await _db
          .customSelect(
            'SELECT 1 FROM message_rows WHERE id = ?',
            variables: [Variable(id)],
          )
          .getSingleOrNull()) !=
      null;

  Future<void> _removeCommittedSubmission(
    ComposerDraft draft, {
    bool preserveEdit = false,
  }) async {
    final id = draft.submissionId;
    if (id == null || !await wasSubmitted(id)) return;
    final submittedEditId = draft.submissionEditId;
    draft.pending = null;
    draft.submissionId = null;
    draft.submissionEditId = null;
    if (!preserveEdit &&
        draft.edit != null &&
        draft.edit!.isEmpty &&
        draft.editMessageId == submittedEditId) {
      draft.edit = null;
      draft.editMessageId = null;
    }
  }

  /// Called inside the transaction that creates the message/version.
  Future<void> consumeInTransaction(DraftSubmission submission) async {
    final row = await _db
        .customSelect(
          'SELECT payload FROM extension_entity_rows WHERE kind = ? AND id = ?',
          variables: [
            const Variable(kind),
            Variable(submission.conversationId),
          ],
        )
        .getSingleOrNull();
    if (suspended || _deleted.contains(submission.conversationId)) {
      throw StateError('composer_owner_deleted');
    }
    if (row == null) throw StateError('composer_submission_missing');
    {
      final draft = ComposerDraft.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(row.read<String>('payload')) as Map,
        ),
      );
      if (draft.conversationId != submission.conversationId ||
          draft.submissionId != submission.id ||
          draft.submissionEditId != submission.editMessageId) {
        throw StateError('composer_submission_replaced');
      }
      {
        await _removeCommittedSubmission(draft);
        if (draft.hasContent) {
          await _put(
            kind,
            draft.conversationId,
            draft.toJson(),
            ownerId: draft.assistantId,
          );
        } else {
          await _deleteRow(kind, draft.conversationId);
        }
      }
    }
    await _db.customStatement(
      'DELETE FROM extension_entity_rows WHERE kind = ? AND owner_id = ?',
      [entryKind, submission.conversationId],
    );
    await _db.customStatement(
      '''
      INSERT OR IGNORE INTO extension_entity_rows(kind,id,sort_order,owner_id,payload,updated_at)
      SELECT ?,id,sort_order,owner_id,payload,updated_at FROM extension_entity_rows
      WHERE kind = ? AND owner_id = ?
    ''',
      [publishedFileKind, privateFileKind, submission.id],
    );
    await _db.customStatement(
      'DELETE FROM extension_entity_rows WHERE kind = ? AND owner_id = ?',
      [privateFileKind, submission.id],
    );
  }

  Future<void> finishSubmission(
    DraftSubmission submission, {
    bool preserveEdit = false,
  }) async {
    final draft = _drafts[submission.conversationId];
    if (draft == null) return;
    if (await wasSubmitted(submission.id)) {
      await _removeCommittedSubmission(draft, preserveEdit: preserveEdit);
      _entries.removeWhere((_, entry) => entry.id == submission.conversationId);
    }
    _changed(draft);
    await flush();
  }

  /// Only explicit submission publishes a private attachment into upload/.
  /// The marker is committed before the file appears and consumed together
  /// with the message, so interrupted sends remain excluded from backups.
  Future<ChatInputData> prepareSubmissionInput(ChatInputData input) async {
    final submission = input.draftSubmission;
    if (submission == null) return input;
    void checkOwner() {
      if (_disposed ||
          suspended ||
          _deleted.contains(submission.conversationId)) {
        throw StateError('composer_owner_deleted');
      }
      // Pending is an immutable third input: changing or cancelling a later
      // compose/edit must not cancel the attachment copy already submitted.
      final draft = _drafts[submission.conversationId];
      if (draft?.submissionId != submission.id ||
          draft?.submissionEditId != submission.editMessageId) {
        throw StateError('composer_submission_replaced');
      }
    }

    checkOwner();

    final dir = await AppDirectories.getUploadDirectory();
    await dir.create(recursive: true);
    final paths = <String, String>{};
    var index = 0;
    for (final raw in [
      ...input.imagePaths,
      ...input.documents.map((doc) => doc.path),
    ]) {
      if (paths.containsKey(raw)) continue;
      if (raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('data:')) {
        paths[raw] = raw;
        continue;
      }
      final source = File(
        SandboxPathResolver.fix(await ownFile(submission.conversationId, raw)),
      );
      if (!await source.exists()) {
        throw StateError('composer_attachment_missing');
      }
      final target = File(
        p.join(
          dir.path,
          'draft-${submission.id}-${index++}${p.extension(source.path)}',
        ),
      );
      checkOwner();
      await _put(
        privateFileKind,
        SandboxPathResolver.canonicalize(target.path),
        {},
        ownerId: submission.id,
      );
      final staging = File(
        p.join(
          (await directoryFor(submission.conversationId)).path,
          '${p.basename(target.path)}.part',
        ),
      );
      await source.copy(staging.path);
      checkOwner();
      await staging.rename(target.path);
      paths[raw] = target.path;
    }
    checkOwner();
    return ChatInputData(
      text: input.text,
      imagePaths: [for (final path in input.imagePaths) paths[path]!],
      documents: [
        for (final doc in input.documents)
          DocumentAttachment(
            path: paths[doc.path]!,
            fileName: doc.fileName,
            mime: doc.mime,
          ),
      ],
      allowImagesApiRouting: input.allowImagesApiRouting,
      draftSubmission: submission,
    );
  }

  void restorePending(String id, {bool append = false, bool replace = false}) {
    final draft = _drafts[id];
    if (draft == null || _deleted.contains(id)) return;
    final pending = draft.pending;
    if (pending == null) return;
    if (draft.hasRecoveryConflict && !append && !replace) return;
    final restored = append ? merge(draft.recoveryTarget, pending) : pending;
    if (replace && !append) {
      invalidateInputOperations(id, editMessageId: draft.submissionEditId);
    }
    if (draft.submissionEditId != null) {
      draft.edit = restored;
      draft.editMessageId = draft.submissionEditId;
    } else {
      draft.compose = restored;
    }
    draft.pending = null;
    draft.submissionId = null;
    draft.submissionEditId = null;
    _changed(draft);
  }

  void discardPending(String id) {
    if (submitting.contains(id)) return;
    final draft = _drafts[id];
    if (draft == null) return;
    draft.pending = null;
    draft.submissionId = null;
    draft.submissionEditId = null;
    _changed(draft);
  }

  void beginEdit(String id, String messageId, ComposerDraftInput input) {
    final draft = _drafts[id]!;
    // Reopening the same message starts a new edit, not a continuation of an
    // attachment import belonging to the replaced edit.
    _advanceInputEpoch(id, editing: true);
    draft.edit = input;
    draft.editMessageId = messageId;
    _changed(draft);
  }

  void endEdit(String id) {
    final draft = _drafts[id];
    if (draft == null || draft.edit == null) return;
    invalidateInputOperations(id, editMessageId: draft.editMessageId);
    draft.edit = null;
    draft.editMessageId = null;
    _changed(draft);
  }

  static ComposerDraftInput merge(
    ComposerDraftInput first,
    ComposerDraftInput second,
  ) {
    final text = first.text.isEmpty
        ? second.text
        : second.text.isEmpty
        ? first.text
        : '${first.text}\n\n${second.text}';
    return first.copyWith(
      text: text,
      selectionBase: text.length,
      selectionExtent: text.length,
      images: [...first.images, ...second.images],
      documents: [...first.documents, ...second.documents],
    );
  }

  Future<bool> hasShareReceipt(String shareId) async {
    if (_shareReceipts.values.any((ids) => ids.contains(shareId))) {
      await flush();
    }
    return await _db
            .customSelect(
              'SELECT 1 FROM extension_entity_rows WHERE kind = ? AND id = ?',
              variables: [const Variable(receiptKind), Variable(shareId)],
            )
            .getSingleOrNull() !=
        null;
  }

  Future<void> acceptShare(
    String id,
    ComposerDraftInput input,
    Iterable<String> shareIds,
  ) {
    _shareReceipts.putIfAbsent(id, () => {}).addAll(shareIds);
    setInput(id, input);
    _schedule(id);
    return flush();
  }

  Future<void> acknowledgeShares(Iterable<String> shareIds) =>
      _serialize(() async {
        for (final id in shareIds) {
          await _deleteRow(receiptKind, id);
        }
      });

  /// Copy first; release the source only when both snapshots can be committed.
  /// A concurrent edit/compression completion aborts without changing either.
  Future<void> transfer(
    String sourceId,
    String targetId, {
    required bool append,
  }) async {
    if (sourceId == targetId) return;
    final source = await load(sourceId);
    final target = await load(targetId);
    final sourceRevision = source.revision;
    final targetRevision = target.revision;
    final moved = await _ownInput(targetId, source.active);
    await flush();
    try {
      await _serialize(() async {
        void check() {
          if (_deleted.contains(sourceId) ||
              _deleted.contains(targetId) ||
              source.revision != sourceRevision ||
              target.revision != targetRevision) {
            throw StateError('composer_transfer_changed');
          }
        }

        Future<void> persist(ComposerDraft draft) async {
          if (draft.hasContent) {
            await _put(
              kind,
              draft.conversationId,
              draft.toJson(),
              ownerId: draft.assistantId,
            );
          } else {
            await _deleteRow(kind, draft.conversationId);
          }
        }

        check();
        final from = ComposerDraft.fromJson(source.toJson());
        final to = ComposerDraft.fromJson(target.toJson());
        final value = append ? merge(to.active, moved) : moved;
        if (to.edit != null) {
          to.edit = value;
        } else {
          to.compose = value;
        }
        if (from.edit != null) {
          from.edit = const ComposerDraftInput();
        } else {
          from.compose = const ComposerDraftInput();
        }
        await _db.transaction(() async {
          await persist(to);
          await persist(from);
          check();
        });
        try {
          // COMMIT itself yields: imports or editor changes can arrive after
          // the last check inside the transaction. Never publish a stale move.
          check();
        } on StateError {
          _schedule(sourceId);
          _schedule(targetId);
          // The database already committed, but live inputs are untouched.
          // Restore both together before reporting a conflict; queued deletes
          // still own removal of a conversation deleted during the commit.
          await _db.transaction(() async {
            if (!_deleted.contains(sourceId)) await persist(source);
            if (!_deleted.contains(targetId)) await persist(target);
          });
          rethrow;
        }
        source.compose = from.compose;
        source.edit = from.edit;
        target.compose = to.compose;
        target.edit = to.edit;
        invalidateInputOperations(
          sourceId,
          editMessageId: source.editMessageId,
        );
        if (!append) {
          invalidateInputOperations(
            targetId,
            editMessageId: target.editMessageId,
          );
        }
        _changed(source);
        _changed(target);
      });
    } finally {
      await flush();
    }
  }

  Future<void> _pruneOwnerFiles(String id, ComposerDraft draft) async {
    final dir = Directory(
      p.join((await _directory()).path, _directoryName(id)),
    );
    if (!await dir.exists()) return;
    final live = draft.paths
        .map((path) => p.normalize(SandboxPathResolver.fix(path)))
        .toSet();
    try {
      await for (final entry in dir.list(followLinks: false)) {
        if (entry is File && !live.contains(p.normalize(entry.path))) {
          await entry.delete();
        }
      }
    } on FileSystemException {
      // Cleanup is best effort; a readable draft remains recoverable.
    }
  }

  Future<void> removePrivateDirectory(String id) async {
    invalidateOperations(id);
    final dir = Directory(
      p.join((await _directory()).path, _directoryName(id)),
    );
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Called before changing a conversation's assistant. An occupied new-entry
  /// slot is not silently replaced; the caller keeps both conversations.
  Future<bool> moveAssistant(
    String id,
    String assistantId, {
    Future<bool> Function()? moveConversation,
  }) async {
    final other = newEntry(assistantId);
    if (isNewEntry(id) && other != null && other.id != id) return false;
    final draft = await load(id);
    await flush();
    return _serialize(() async {
      if (_deleted.contains(id) || suspended) return false;
      final oldEntries = _entries.entries
          .where((entry) => entry.value.id == id)
          .toList();
      final snapshot = ComposerDraft.fromJson(draft.toJson())
        ..assistantId = assistantId;
      final moved = await _db.transaction(() async {
        if (moveConversation != null && !await moveConversation()) return false;
        if (snapshot.hasContent) {
          await _put(kind, id, snapshot.toJson(), ownerId: assistantId);
        }
        await _db.customStatement(
          'DELETE FROM extension_entity_rows WHERE kind = ? AND owner_id = ?',
          [entryKind, id],
        );
        for (final old in oldEntries) {
          await _put(
            entryKind,
            entryId(assistantId),
            old.value.copyWith(assistantId: assistantId).toJson(),
            ownerId: id,
          );
        }
        return true;
      });
      if (!moved) return false;
      draft.assistantId = assistantId;
      for (final old in oldEntries) {
        _entries.remove(old.key);
        _entries[entryId(assistantId)] = old.value.copyWith(
          assistantId: assistantId,
        );
      }
      _changed(draft);
      return true;
    });
  }

  Future<void> delete(
    String id, {
    Future<void> Function()? deleteConversation,
  }) async {
    final hadPrivateFiles = _drafts.containsKey(id) || _ids.contains(id);
    _deleted.add(id);
    invalidateOperations(id);
    try {
      await _serialize(
        () => _db.transaction(() async {
          if (deleteConversation != null) await deleteConversation();
          await _deleteRow(kind, id);
          await _db.customStatement(
            'DELETE FROM extension_entity_rows WHERE kind = ? AND owner_id = ?',
            [entryKind, id],
          );
        }),
      );
    } catch (_) {
      _deleted.remove(id);
      if (_drafts.containsKey(id)) _schedule(id);
      rethrow;
    }
    _dirty.remove(id);
    _drafts.remove(id);
    _loads.remove(id);
    _ids.remove(id);
    _entries.removeWhere((_, entry) => entry.id == id);
    errors.remove(id);
    submitting.remove(id);
    // Share receipts intentionally outlive deletion until the native inbox ack.
    if (hadPrivateFiles) {
      try {
        await removePrivateDirectory(id);
      } on FileSystemException {
        /* Reclaim on next start. */
      }
    }
    // The chat mutation publishes once after its whole delete batch finishes.
  }

  Iterable<String> newEntriesForAssistant(String assistantId) => _entries.values
      .where((entry) => entry.assistantId == assistantId)
      .map((entry) => entry.id)
      .toList();

  /// Fence old asynchronous work before replacing chat data. Failed restores
  /// leave the old durable drafts intact; successful restores drop their cache.
  Future<T> overwrite<T>(Future<T> Function() action) async {
    await flush();
    suspended = true;
    for (final id in {..._ids, ..._drafts.keys}) {
      invalidateOperations(id);
    }
    if (!_disposed) notifyListeners();
    try {
      final result = await _serialize(action);
      _drafts.clear();
      _loads.clear();
      _ids.clear();
      _entries.clear();
      _dirty.clear();
      _imports.clear();
      _ownedPaths.clear();
      submitting.clear();
      errors.clear();
      resetRevision++;
      try {
        final root = await _directory();
        if (await root.exists()) await root.delete(recursive: true);
      } on FileSystemException {
        /* Reclaim after restart; the data transaction succeeded. */
      }
      return result;
    } finally {
      suspended = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<Set<String>> publishedFiles() async => {
    for (final row
        in await _db
            .customSelect(
              'SELECT id FROM extension_entity_rows WHERE kind = ?',
              variables: [const Variable(publishedFileKind)],
            )
            .get())
      row.read<String>('id'),
  };

  Future<void> _put(
    String type,
    String id,
    Map<String, dynamic> value, {
    String? ownerId,
  }) => _db.customStatement(
    '''INSERT INTO extension_entity_rows(kind,id,sort_order,owner_id,payload,updated_at)
       VALUES(?,?,0,?,?,?) ON CONFLICT(kind,id) DO UPDATE SET
       owner_id=excluded.owner_id,payload=excluded.payload,updated_at=excluded.updated_at''',
    [
      type,
      id,
      ownerId,
      jsonEncode(value),
      DateTime.now().microsecondsSinceEpoch,
    ],
  );
  Future<void> _deleteRow(String type, String id) => _db.customStatement(
    'DELETE FROM extension_entity_rows WHERE kind = ? AND id = ?',
    [type, id],
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    _maximumWait?.cancel();
    super.dispose();
  }
}

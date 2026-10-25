import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/compress_context_options.dart';
import '../../models/context_operation.dart';
import '../../models/context_compression_task.dart';
export '../../models/context_compression_task.dart';
import '../../utils/token_estimator.dart';
import '../../../utils/utf16_safe_cut.dart';
import '../api/chat_api_service.dart';
import 'chat_service.dart';

/// Owns only compression work. User input stays in HomeViewModel's existing
/// QueuedChatInput/DraftSubmission path and is never copied into this service.
class ContextCompressionService extends ChangeNotifier {
  ContextCompressionService(this.chat);
  final ChatService chat;
  final Map<String, ContextCompressionTask> _tasks = {};
  final Map<String, Future<void>> _writes = {};
  final Map<String, Future<void>> _runs = {};
  final Map<String, int> _contextChanges = {};
  final Map<String, List<Completer<void>>> _idleWaiters = {};
  void Function(String id, bool applied)? onContextChangeFinished;

  Future<void> runContextChange(
    String id,
    Future<void> Function() change,
  ) async {
    _contextChanges.update(id, (n) => n + 1, ifAbsent: () => 1);
    notifyListeners();
    var applied = false;
    try {
      if (taskFor(id)?.phase == CompressionPhase.applying) await _runs[id];
      await cancel(id);
      if (isConversationBusy?.call(id) ?? false) {
        final waiter = Completer<void>();
        _idleWaiters.putIfAbsent(id, () => []).add(waiter);
        await waiter.future;
      }
      if (_disposed || chat.getConversation(id) == null) {
        throw StateError('conversation_not_found');
      }
      await change();
      applied = true;
    } finally {
      final count = (_contextChanges[id] ?? 1) - 1;
      if (count == 0) {
        _contextChanges.remove(id);
      } else {
        _contextChanges[id] = count;
      }
      if (!_disposed) {
        notifyListeners();
        onContextChangeFinished?.call(id, applied);
        resumeIfReady(id);
      }
    }
  }

  bool Function(String conversationId)? isConversationBusy;
  // The existing HomeViewModel queue owns this state; this is only a view for
  // sidebar indicators, never another pending-input store.
  bool Function(String conversationId)? isInputPaused;
  void refreshInputStatus() => notifyListeners();
  Future<CompressionBudget> Function(String id, List<ChatMessage> history)?
  estimateCandidate;
  bool _disposed = false;
  Iterable<ContextCompressionTask> get tasks => _tasks.values;
  ContextCompressionTask? taskFor(String id) => _tasks[id];
  bool blocksSending(String id) =>
      (_tasks[id]?.active ?? false) || _contextChanges.containsKey(id);

  Future<void> restore() async {
    _tasks.clear();
    final saved = await chat.readCompressionTaskRecords();
    for (final entry in saved.entries) {
      final value = entry.value;
      final phase = CompressionPhase.values.byName(value['phase'] as String);
      if (phase == CompressionPhase.completed ||
          phase == CompressionPhase.cancelled) {
        continue;
      }
      final task =
          ContextCompressionTask(
              id: value['id'] as String,
              conversationId: entry.key,
              options: CompressContextOptions.fromJson(
                Map<String, dynamic>.from(value['options'] as Map),
              ),
              phase: CompressionPhase.interrupted,
            )
            ..summary = value['summary'] as String? ?? ''
            ..anchorGroupId = value['anchorGroupId'] as String?;
      if (value['startedAt'] case final String startedAt) {
        task.startedAt = DateTime.parse(startedAt);
      }
      if (value['candidate'] case final Map candidate) {
        task.candidate = ContextOperation.fromJson(
          Map<String, dynamic>.from(candidate),
        );
      }
      _tasks[entry.key] = task;
    }
  }

  Future<void> _publish(ContextCompressionTask task) async {
    if (_disposed || !identical(_tasks[task.conversationId], task)) return;
    final record = task.toJson();
    final previous = _writes[task.conversationId] ?? Future<void>.value();
    final write = previous
        .catchError((Object _) {})
        .then(
          (_) => chat.saveCompressionTaskRecord(task.conversationId, record),
        );
    _writes[task.conversationId] = write;
    notifyListeners();
    try {
      await write;
    } finally {
      if (identical(_writes[task.conversationId], write)) {
        _writes.remove(task.conversationId);
      }
    }
  }

  Future<void> start(String id, CompressionRequest request) async {
    if (taskFor(id)?.phase == CompressionPhase.review) await cancel(id);
    if (blocksSending(id)) throw StateError('in_flight');
    if (chat.getConversation(id) == null) {
      throw StateError('conversation_not_found');
    }
    final task = ContextCompressionTask(
      id: const Uuid().v4(),
      conversationId: id,
      options: request.options,
      request: request,
    );
    _tasks[id] = task;
    try {
      await _publish(task);
      if (!task.active) return;
      resumeIfReady(id);
    } catch (error) {
      task.phase = CompressionPhase.failed;
      task.error = error.toString();
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  void resumeIfReady(String id) {
    if (!(isConversationBusy?.call(id) ?? false)) {
      for (final waiter in _idleWaiters.remove(id) ?? <Completer<void>>[]) {
        waiter.complete();
      }
    }
    if (_contextChanges.containsKey(id)) return;
    final task = _tasks[id];
    if (_disposed ||
        task == null ||
        task.phase != CompressionPhase.waiting ||
        (isConversationBusy?.call(id) ?? false)) {
      return;
    }
    task.phase = CompressionPhase.preparing;
    final run = _run(task);
    _runs[id] = run;
    unawaited(
      run.whenComplete(() {
        if (identical(_runs[id], run)) _runs.remove(id);
      }),
    );
  }

  Future<void> cancel(String id, {String? reason}) async {
    final task = _tasks[id];
    if (task == null ||
        (!task.active &&
            (reason == null || task.phase == CompressionPhase.completed)) ||
        task.phase == CompressionPhase.applying) {
      return;
    }
    task.phase = CompressionPhase.cancelled;
    task.error = reason;
    task.request = null;
    ChatApiService.cancelRequest(task.id);
    await _publish(task);
  }

  void _check(ContextCompressionTask task) {
    if (_disposed ||
        !task.active ||
        !identical(_tasks[task.conversationId], task) ||
        chat.getConversation(task.conversationId) == null) {
      throw StateError('cancelled');
    }
  }

  Future<void> _run(ContextCompressionTask task) async {
    try {
      _check(task);
      await _publish(task);
      final request = task.request!;
      final snapshot = await chat.loadContextSnapshot(task.conversationId);
      _check(task);
      if (snapshot.messages.any((message) => message.isStreaming)) {
        throw StateError('in_flight');
      }
      final selection = selectCompressionHistory(
        snapshot.messages,
        snapshot.operations,
        task.options,
      );
      if (selection.covered.isEmpty || selection.needsRegeneration) {
        throw StateError('no_messages');
      }
      final retained = selection.retained;
      final covered = selection.covered;
      final dependencies = selection.dependencies;
      task.anchorGroupId = ContextHistory.group(covered.last);
      try {
        task.previousBudget = await estimateCandidate?.call(
          task.conversationId,
          selection.effective,
        );
      } catch (_) {
        /* An unavailable before-estimate must not fail compression. */
      }
      final textMessages = await chat.messagesForCompression(
        selection.input,
        includeAttachmentsAndTools: task.options.includeAttachmentsAndTools,
      );
      _check(task);
      final budget = compressRequestCharBudget(
        contextWindowTokens: request.contextWindowTokens,
      );
      final chunks = buildCompressRequestContents(
        textMessages,
        task.options,
        safeRequestChars: budget,
      );
      if (chunks.isEmpty) throw StateError('no_messages');
      final inputTokens = chunks.fold<int>(
        0,
        (sum, part) => sum + estimateTokens(part),
      );

      Future<String> summarize(String text) => summarizeWithContextRetry(
        text,
        summarize: (part) async {
          _check(task);
          final result = (await request.generate(part, task.id)).trim();
          _check(task);
          if (result.isEmpty) throw StateError('empty_summary');
          return result;
        },
      );

      task.phase = CompressionPhase.summarizing;
      task.totalParts = chunks.length;
      await _publish(task);
      var pending = <String>[];
      for (final chunk in chunks) {
        pending.add(await summarize(chunk));
        task.summary = pending.join('\n\n');
        task.completedParts++;
        await _publish(task);
      }
      for (var round = 0; pending.length > 1 && round < 8; round++) {
        task.phase = CompressionPhase.merging;
        final packed = chunkPlainTexts(pending, maxChars: budget);
        task.totalParts = packed.length;
        task.completedParts = 0;
        await _publish(task);
        final next = <String>[];
        for (final part in packed) {
          next.add(await summarize(part));
          task.completedParts++;
          await _publish(task);
        }
        pending = next;
      }
      final summary = pending.length == 1
          ? pending.single
          : await summarize(
              truncateHeadUtf16Safe(pending.join('\n\n'), budget),
            );
      _check(task);
      task.summary = summary;
      task.sourceFingerprint = snapshot.fingerprint;
      task.candidate = ContextOperation(
        id: task.id,
        kind: ContextOperationKind.compress,
        anchorGroupId: ContextHistory.group(covered.last),
        appliedAfterGroupId: ContextHistory.group(snapshot.messages.last),
        sourceGroups: covered.map(ContextHistory.group).toList(),
        dependencies: dependencies,
        createdAt: DateTime.now(),
        summary: summary,
        originalSummary: summary,
        keepUserMessages: countUserMessages(retained),
        model: request.model,
        inputTokens: inputTokens,
        inputMode: task.options.mode.name,
        inputMaxChars: task.options.maxChars,
        historySource: task.options.historySource,
        includedEditedSummaries: task.options.includeEditedSummaries,
        includedAttachmentsAndTools: task.options.includeAttachmentsAndTools,
        inputParts: chunks.length,
      );
      if ((await chat.loadContextSnapshot(task.conversationId)).fingerprint !=
          snapshot.fingerprint) {
        throw StateError('context_changed');
      }
      final fitsBudget = await _checkBudget(task, snapshot);
      _check(task);
      if (estimateTokens(summary) >= inputTokens || !fitsBudget) {
        task.phase = CompressionPhase.review;
        task.error = fitsBudget
            ? 'summary_not_smaller'
            : 'context_budget_exceeded';
        await _publish(task);
        return;
      }
      await _apply(task, retained: retained);
    } catch (error, stack) {
      if (_disposed ||
          task.phase == CompressionPhase.cancelled ||
          task.phase == CompressionPhase.interrupted ||
          task.phase == CompressionPhase.completed ||
          !identical(_tasks[task.conversationId], task)) {
        return;
      }
      task.phase = CompressionPhase.failed;
      task.error = error.toString();
      debugPrint('[ContextCompression] $error\n$stack');
      try {
        await _publish(task);
      } catch (_) {
        if (!_disposed) notifyListeners();
      }
    } finally {
      task.request = null;
    }
  }

  Future<void> applyReviewed(String id, String summary) async {
    final task = _tasks[id];
    if (task == null ||
        task.phase != CompressionPhase.review ||
        summary.trim().isEmpty) {
      return;
    }
    // Claim the review before awaiting estimates; double saves cannot apply twice.
    task.phase = CompressionPhase.preparing;
    final run = () async {
      try {
        task.candidate = task.candidate!.copyWith(summary: summary);
        task.summary = summary;
        final snapshot = await chat.loadContextSnapshot(id);
        _check(task);
        if (snapshot.fingerprint != task.sourceFingerprint) {
          throw StateError('context_changed');
        }
        final fits = await _checkBudget(task, snapshot);
        _check(task);
        if (!fits) throw StateError('context_budget_exceeded');
        final effective = ContextHistory.resolve(
          snapshot.messages,
          snapshot.operations,
        );
        final retained =
            task.options.mode == CompressContextLimitMode.keepRecent
            ? selectKeepRecentMessages(
                effective,
                task.options.keepUserMessages ?? 6,
              )
            : <ChatMessage>[];
        await _apply(task, retained: retained);
      } catch (error) {
        if (task.phase != CompressionPhase.cancelled && !_disposed) {
          task.phase = CompressionPhase.review;
          task.error = error.toString();
          await _publish(task);
        }
        rethrow;
      }
    }();
    _runs[id] = run;
    try {
      await run;
    } finally {
      if (identical(_runs[id], run)) _runs.remove(id);
    }
  }

  Future<void> _apply(
    ContextCompressionTask task, {
    required List<ChatMessage> retained,
  }) async {
    _check(task);
    if ((isConversationBusy?.call(task.conversationId) ?? false)) {
      throw StateError('in_flight');
    }
    task.phase = CompressionPhase.applying;
    await _publish(task);
    if (task.options.newConversation) {
      final created = await chat.createCompressedConversation(
        task.conversationId,
        task.candidate!,
        expectedFingerprint: task.sourceFingerprint!,
        retained: retained,
      );
      task.resultConversationId = created.id;
    } else {
      await chat.appendContextOperation(
        task.conversationId,
        task.candidate!,
        expectedFingerprint: task.sourceFingerprint!,
      );
    }
    task.phase = CompressionPhase.completed;
    try {
      await _publish(task);
    } catch (error) {
      // The history commit succeeded. A job-status write cannot undo it or
      // turn the completed operation into a retryable compression failure.
      debugPrint('[ContextCompression] completion status: $error');
    }
  }

  Future<bool> _checkBudget(
    ContextCompressionTask task,
    ConversationContextSnapshot snapshot,
  ) async {
    if (task.options.newConversation) return true;
    final estimate = estimateCandidate;
    if (estimate == null) return false;
    final projected = ContextHistory.resolve(snapshot.messages, [
      ...snapshot.operations,
      task.candidate!,
    ]);
    task.budget = await estimate(task.conversationId, projected);
    final limit = task.budget!.contextWindow;
    return limit == null || task.budget!.usedTokens <= limit;
  }

  Future<void> dismiss(String id) async {
    final task = _tasks[id];
    if (task == null || task.active) return;
    task.phase = CompressionPhase.cancelled;
    await _publish(task);
    if (identical(_tasks[id], task)) _tasks.remove(id);
    if (!_disposed) notifyListeners();
  }

  void forget(String id) {
    for (final waiter in _idleWaiters.remove(id) ?? <Completer<void>>[]) {
      waiter.complete();
    }
    final task = _tasks.remove(id);
    if (task != null) {
      task.phase = CompressionPhase.cancelled;
      ChatApiService.cancelRequest(task.id);
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> cancelAll({bool interrupted = false}) async {
    for (final waiters in _idleWaiters.values) {
      for (final waiter in waiters) {
        waiter.completeError(StateError('cancelled'));
      }
    }
    _idleWaiters.clear();
    final applying = <Future<void>>[];
    for (final task in _tasks.values.toList()) {
      if (task.phase == CompressionPhase.applying) {
        final run = _runs[task.conversationId];
        if (run != null) applying.add(run);
      } else {
        final wasActive = task.active;
        await cancel(task.conversationId);
        if (interrupted && wasActive) {
          task.phase = CompressionPhase.interrupted;
          await _publish(task);
        }
      }
    }
    await Future.wait(applying);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final waiters in _idleWaiters.values) {
      for (final waiter in waiters) {
        waiter.complete();
      }
    }
    _idleWaiters.clear();
    for (final task in _tasks.values) {
      ChatApiService.cancelRequest(task.id);
    }
    super.dispose();
  }
}

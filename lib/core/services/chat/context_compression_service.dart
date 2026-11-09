import '../../models/compression_config.dart';
import '../../models/message_part.dart';
import '../api/request_image_context.dart';
import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/compress_context_options.dart';
import '../../models/context_operation.dart';
import '../../models/context_compression_task.dart';
export '../../models/context_compression_task.dart';
import '../../utils/token_estimator.dart';
import 'compression_engine.dart';
import '../../models/token_usage.dart';
import '../api/chat_api_service.dart';
import 'chat_service.dart';

/// Owns only compression work. User input stays in HomeViewModel's existing
/// QueuedChatInput/DraftSubmission path and is never copied into this service.
class ContextCompressionService extends ChangeNotifier {
  ContextCompressionService(this.chat);
  final ChatService chat;
  final Map<String, ContextCompressionTask> _tasks = {};
  final _skipNextTurn = <String>{};
  void skipNextAutomaticTurn(String id) => _skipNextTurn.add(id);
  bool consumeAutomaticSkip(String id) => _skipNextTurn.remove(id);
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
  Future<CompressionBudget> Function(
    String id,
    List<ChatMessage> history, {
    bool? fixedContextStart,
  })?
  estimateCandidate;
  bool _disposed = false;
  Iterable<ContextCompressionTask> get tasks => _tasks.values;
  ContextCompressionTask? taskFor(String id) => _tasks[id];

  void _releaseRequest(ContextCompressionTask task) {
    task.request = null;
    // The validator closes over the request and the full source selection.
    task.validateReferences = null;
  }

  bool blocksSending(String id) =>
      ((_tasks[id]?.active ?? false) && !(_tasks[id]?.automatic ?? false)) ||
      _contextChanges.containsKey(id);

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
      task
        ..requestAttempts = value['requestAttempts'] as int? ?? 0
        ..unknownUsageAttempts = value['unknownUsageAttempts'] as int? ?? 0
        ..completedParts = value['completedParts'] as int? ?? 0
        ..totalParts = value['totalParts'] as int? ?? 0
        ..protectedMessageId = value['protectedMessageId'] as String?
        ..effectiveMessageIds = (value['effectiveMessageIds'] as List?)
            ?.cast<String>()
            .toSet()
        ..ownsContinuation = value['ownsContinuation'] == true
        ..automatic = value['automatic'] == true
        ..referenceFingerprint = value['referenceFingerprint'] as String?
        ..sourceFingerprint = value['sourceFingerprint'] as String?
        ..templateSnapshot = (value['template'] as Map?)
            ?.cast<String, dynamic>()
        ..settingsSnapshot = (value['settings'] as Map?)
            ?.cast<String, dynamic>();
      task.finishReasons.addAll(
        (value['finishReasons'] as List? ?? const []).cast<String?>(),
      );
      if (value['usage'] case final Map usage) {
        task.usage = TokenUsage.fromJson(usage.cast<String, dynamic>());
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
    if (taskFor(id)?.active == true || _contextChanges.containsKey(id)) {
      throw StateError('in_flight');
    }
    if (chat.getConversation(id) == null) {
      throw StateError('conversation_not_found');
    }
    final task =
        ContextCompressionTask(
            id: const Uuid().v4(),
            conversationId: id,
            options: request.options,
            request: request,
          )
          ..ownsContinuation = request.ownsContinuation
          ..automatic = request.automatic
          ..protectedMessageId = request.beforeMessageId
          ..effectiveMessageIds = request.effectiveMessageIds == null
              ? null
              : Set.unmodifiable(request.effectiveMessageIds!)
          ..templateSnapshot = request.resolvedTemplate.toJson()
          ..settingsSnapshot = request.config.toJson();
    _tasks[id] = task;
    try {
      await _publish(task);
      if (!task.active) return;
      resumeIfReady(id);
    } catch (error) {
      task.phase = CompressionPhase.failed;
      task.error = error.toString();
      _releaseRequest(task);
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  /// The original send/tool loop owns continuation and awaits this safe point.
  /// It must not enqueue a task that waits for that same loop to become idle.
  Future<ContextCompressionTask> runAtSafePoint(
    String id,
    CompressionRequest request,
  ) async {
    if (request.beforeMessageId == null) {
      throw ArgumentError('protected user required');
    }
    if (taskFor(id)?.active == true || _contextChanges.containsKey(id)) {
      throw StateError('in_flight');
    }
    final task =
        ContextCompressionTask(
            id: const Uuid().v4(),
            conversationId: id,
            options: request.options,
            request: request,
            phase: CompressionPhase.preparing,
          )
          ..ownsContinuation = request.ownsContinuation
          ..automatic = request.automatic
          ..protectedMessageId = request.beforeMessageId
          ..effectiveMessageIds = request.effectiveMessageIds == null
              ? null
              : Set.unmodifiable(request.effectiveMessageIds!)
          ..templateSnapshot = request.resolvedTemplate.toJson()
          ..settingsSnapshot = request.config.toJson();
    _tasks[id] = task;
    final run = _run(task);
    _runs[id] = run;
    try {
      await run;
    } finally {
      if (identical(_runs[id], run)) _runs.remove(id);
    }
    return task;
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
    if (task?.phase == CompressionPhase.applying) {
      task!.cancelRequested = true;
      ChatApiService.cancelRequest(task.id);
      return;
    }
    if (task == null ||
        (!task.active &&
            (reason == null || task.phase == CompressionPhase.completed)) ||
        task.phase == CompressionPhase.applying) {
      return;
    }
    task.phase = CompressionPhase.cancelled;
    task.error = reason;
    _releaseRequest(task);
    ChatApiService.cancelRequest(task.id);
    try {
      await _publish(task);
    } catch (error) {
      // Cancellation already stopped the request. Do not revive it when the
      // status write fails; retain an actionable, inactive task for dismissal.
      if (identical(_tasks[id], task) &&
          task.phase == CompressionPhase.cancelled) {
        task.phase = CompressionPhase.interrupted;
        task.error = error.toString();
        if (!_disposed) notifyListeners();
      }
      rethrow;
    }
  }

  void _check(ContextCompressionTask task) {
    if (_disposed ||
        !task.active ||
        task.cancelRequested ||
        (task.request?.isCancelled?.call() ?? false) ||
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
      final sourceMessages = ContextHistory.throughMessage(
        snapshot.messages,
        request.beforeMessageId,
      );
      if (sourceMessages.any((message) => message.isStreaming)) {
        throw StateError('in_flight');
      }
      final selection = selectCompressionHistory(
        sourceMessages,
        snapshot.operations,
        task.options,
        protectedMessageId: request.beforeMessageId,
        effectiveMessageIds: task.effectiveMessageIds,
      );
      if (selection.missingOriginals) {
        throw StateError('native_compaction_originals_unavailable');
      }
      if (selection.covered.isEmpty || selection.needsRegeneration) {
        throw StateError('no_messages');
      }
      final retained = selection.retained;
      final covered = selection.covered;
      final dependencies = selection.dependencies;
      task.anchorGroupId = ContextHistory.group(covered.last);
      if (task.options.native) {
        await _runNative(task, snapshot, sourceMessages, selection);
        return;
      }
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
        quoteMarker: request.quoteMarker,
      );
      _check(task);
      final background = await request.loadReference?.call(selection) ?? '';
      task.referenceFingerprint = sha256
          .convert(utf8.encode(background))
          .toString();
      if (request.loadReference != null) {
        task.validateReferences = () async {
          final latest = await request.loadReference!(selection);
          if (sha256.convert(utf8.encode(latest)).toString() !=
              task.referenceFingerprint) {
            throw StateError('compression_reference_changed');
          }
        };
      }
      final previousSummary = textMessages
          .where(ContextOperation.isSummary)
          .map((m) => m.content)
          .join('\n\n');
      final chunks = buildCompressRequestContents(
        textMessages.where((m) => !ContextOperation.isSummary(m)).toList(),
        task.options,
        quoteMarker: request.quoteMarker,
      );
      if (chunks.isEmpty && previousSummary.isEmpty) {
        throw StateError('no_messages');
      }
      final inputTokens =
          estimateTokens(previousSummary) +
          chunks.fold<int>(0, (sum, part) => sum + estimateTokens(part));
      final summary = await const CompressionEngine().run(
        task: task,
        request: request,
        materials: chunks,
        previousSummary: previousSummary,
        background: background,
        continuation:
            await request.loadContinuation?.call(selection) ??
            request.continuation,
        check: () => _check(task),
        publish: () => _publish(task),
      );
      _check(task);
      task.summary = summary;
      task.sourceFingerprint = ContextHistory.fingerprint(
        sourceMessages,
        snapshot.operations,
      );
      final sourceImages = await RequestImageContext.collectHistory(
        covered,
        parseMarkdownImages: true,
        allowRemoteImages: true,
      );
      _check(task);
      task.candidate = ContextOperation(
        id: task.id,
        kind: ContextOperationKind.compress,
        anchorGroupId: ContextHistory.group(covered.last),
        appliedAfterGroupId: ContextHistory.group(sourceMessages.last),
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
        inputParts: task.completedParts,
        compressionDetails: {
          'envelope': 'history-v1',
          'sourceRevisionIds': covered.map((m) => m.id).toList(),
          'imageSources': {
            for (final image in sourceImages)
              image.handle: {
                'messageId': image.identity.messageId,
                'slot': image.identity.slot,
                'imageIndex': image.identity.imageIndex,
              },
          },
          'toolSources': _toolSources(covered),
          'template': task.templateSnapshot,
          'settings': task.settingsSnapshot,
          'referenceFingerprint': task.referenceFingerprint,
          'referenceUsed': background.isNotEmpty,
          'automatic': task.automatic,
          'requestAttempts': task.requestAttempts,
          'usage': task.usage?.toJson(),
          'unknownUsageAttempts': task.unknownUsageAttempts,
          'finishReasons': task.finishReasons,
          'durationMs': DateTime.now()
              .difference(task.startedAt)
              .inMilliseconds,
          'estimatedBefore': task.previousBudget?.usedTokens,
        },
      );
      final latest = await chat.loadContextSnapshot(task.conversationId);
      if (ContextHistory.fingerprint(
            ContextHistory.throughMessage(
              latest.messages,
              task.protectedMessageId,
            ),
            latest.operations,
          ) !=
          task.sourceFingerprint) {
        throw StateError('context_changed');
      }
      if (request.loadReference != null &&
          sha256
                  .convert(utf8.encode(await request.loadReference!(selection)))
                  .toString() !=
              task.referenceFingerprint) {
        task.phase = CompressionPhase.review;
        task.error = 'compression_reference_changed';
        await _publish(task);
        return;
      }
      final withinWindow = await _checkBudget(task, (
        messages: sourceMessages,
        operations: snapshot.operations,
        fingerprint: task.sourceFingerprint!,
      ));
      _check(task);
      final accepted =
          await request.acceptCandidate?.call(task.candidate!) ?? true;
      // In-turn acceptance uses the full provider request, including its live
      // suffix and image projection. The generic UI estimate is informational.
      final fitsBudget =
          (request.automatic && request.acceptCandidate != null) ||
          withinWindow;
      _check(task);
      task.candidate = task.candidate!.copyWith(
        compressionDetails: {
          ...task.candidate!.compressionDetails,
          'estimatedAfter': task.budget?.usedTokens,
        },
      );
      if (task.options.previewOnly ||
          estimateTokens(summary) >= inputTokens ||
          !fitsBudget ||
          !accepted) {
        task.phase = CompressionPhase.review;
        task.error = task.options.previewOnly
            ? null
            : !accepted
            ? 'compression_target_not_reached'
            : fitsBudget
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
      task.phase = task.cancelRequested || requestCancelled(task)
          ? CompressionPhase.cancelled
          : error.toString().contains('compression_reference_changed') &&
                task.candidate != null &&
                !task.options.native
          ? CompressionPhase.review
          : CompressionPhase.failed;
      task.error = error.toString();
      debugPrint('[ContextCompression] $error\n$stack');
      try {
        await _publish(task);
      } catch (_) {
        if (!_disposed) notifyListeners();
      }
    } finally {
      // Review applies the saved candidate with a fresh source fingerprint;
      // it does not need the generation callbacks or their source snapshot.
      _releaseRequest(task);
    }
  }

  Map<String, dynamic> _toolSources(List<ChatMessage> messages) {
    final sources = <String, dynamic>{};
    for (final message in messages) {
      for (final (ordinal, part) in message.parts.indexed) {
        if (part is! ToolCallPart) continue;
        try {
          final tool = jsonDecode(part.payloadJson);
          if (tool is! Map || tool['id'] is! String) continue;
          final call = tool['id'] as String;
          sources[contextTextReference(message.id, ordinal, call)] = {
            'messageId': message.id,
            'ordinal': ordinal,
            'callId': call,
          };
        } on FormatException {
          /* An unreadable record has no recall handle. */
        }
      }
    }
    return sources;
  }

  bool requestCancelled(ContextCompressionTask task) =>
      task.request?.isCancelled?.call() ?? false;

  Future<void> _runNative(
    ContextCompressionTask task,
    ConversationContextSnapshot snapshot,
    List<ChatMessage> source,
    CompressionSelection selection,
  ) async {
    final request = task.request!;
    if (request.compactNative == null) {
      throw StateError('native_compaction_unavailable');
    }
    task.sourceFingerprint = ContextHistory.fingerprint(
      source,
      snapshot.operations,
    );
    final reference = await request.loadReference?.call(selection);
    if (reference != null) {
      task.validateReferences = () async {
        if (await request.loadReference!(selection) != reference) {
          throw StateError('compression_reference_changed');
        }
      };
    }
    _check(task);
    task.phase = CompressionPhase.summarizing;
    task.totalParts = 1;
    task.requestAttempts = 1;
    await _publish(task);
    final result = await request.compactNative!(selection, task.id);
    _check(task);
    task.completedParts = 1;
    task.usage = result.usage;
    task.unknownUsageAttempts = result.usage == null ? 1 : 0;
    task.candidate = ContextOperation(
      id: task.id,
      kind: ContextOperationKind.compress,
      anchorGroupId: ContextHistory.group(selection.covered.last),
      appliedAfterGroupId: ContextHistory.group(source.last),
      sourceGroups: selection.covered.map(ContextHistory.group).toList(),
      dependencies: selection.dependencies,
      createdAt: DateTime.now(),
      keepUserMessages: countUserMessages(selection.retained),
      model: request.model,
      inputMode: task.options.mode.name,
      inputParts: 1,
      compressionDetails: {
        'nativeCompaction': result.toJson(),
        'sourceRevisionIds': selection.covered.map((m) => m.id).toList(),
        'automatic': request.automatic,
        'requestAttempts': task.requestAttempts,
        'usage': result.usage?.toJson(),
        'unknownUsageAttempts': task.unknownUsageAttempts,
        'durationMs': DateTime.now().difference(task.startedAt).inMilliseconds,
      },
    );
    await task.validateReferences?.call();
    _check(task);
    if (!(await request.acceptCandidate?.call(task.candidate!) ?? true)) {
      throw StateError('native_compaction_incomplete');
    }
    _check(task);
    // Native output is opaque. Text length and summary-token heuristics cannot
    // validate it; the provider's complete result is committed atomically.
    await _apply(task, retained: selection.retained);
  }

  Future<void> applyReviewed(String id, String summary) async {
    final task = _tasks[id];
    if (task == null ||
        task.phase != CompressionPhase.review ||
        task.options.native ||
        task.candidate?.isNative == true ||
        summary.trim().isEmpty) {
      return;
    }
    if (isConversationBusy?.call(id) ?? false) throw StateError('in_flight');
    _releaseRequest(task);
    task.automatic = false;
    task.cancelRequested = false;
    // Claim the review before awaiting estimates; double saves cannot apply twice.
    task.phase = CompressionPhase.preparing;
    final run = () async {
      try {
        task.candidate = task.candidate!.copyWith(summary: summary);
        task.summary = summary;
        final snapshot = await chat.loadContextSnapshot(id);
        _check(task);
        final sourceMessages = ContextHistory.throughMessage(
          snapshot.messages,
          task.protectedMessageId,
        );
        if (ContextHistory.fingerprint(sourceMessages, snapshot.operations) !=
            task.sourceFingerprint) {
          throw StateError('context_changed');
        }
        await _checkBudget(task, snapshot);
        _check(task);
        final selection = selectCompressionHistory(
          sourceMessages,
          snapshot.operations,
          task.options,
          protectedMessageId: task.protectedMessageId,
          effectiveMessageIds: task.effectiveMessageIds,
        );
        await _apply(task, retained: selection.retained);
      } catch (error) {
        if (!_disposed &&
            identical(_tasks[id], task) &&
            task.phase != CompressionPhase.cancelled &&
            task.phase != CompressionPhase.interrupted &&
            task.phase != CompressionPhase.completed) {
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
    if (task.protectedMessageId == null &&
        (isConversationBusy?.call(task.conversationId) ?? false)) {
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
        validateBeforeCommit: task.validateReferences,
        checkBeforeCommit: () => _check(task),
      );
      task.resultConversationId = created.id;
    } else {
      await chat.appendContextOperation(
        task.conversationId,
        task.candidate!,
        expectedFingerprint: task.sourceFingerprint!,
        fingerprintThroughId: task.protectedMessageId,
        checkBeforeCommit: () => _check(task),
        validateBeforeCommit: task.validateReferences,
      );
    }
    task.phase = CompressionPhase.completed;
    task.completedAt = DateTime.now();
    _releaseRequest(task);
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
    final previousPhase = task.phase;
    task.phase = CompressionPhase.cancelled;
    try {
      await _publish(task);
    } catch (_) {
      if (identical(_tasks[id], task) &&
          task.phase == CompressionPhase.cancelled) {
        task.phase = previousPhase;
        if (!_disposed) notifyListeners();
      }
      rethrow;
    }
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
      _releaseRequest(task);
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
      _releaseRequest(task);
      ChatApiService.cancelRequest(task.id);
    }
    super.dispose();
  }
}

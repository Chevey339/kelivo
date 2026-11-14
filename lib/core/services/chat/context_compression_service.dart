import 'dart:isolate';
import '../../models/compression_config.dart';
import '../../models/native_compaction.dart';
import '../../models/carried_original.dart';
import '../api/request_history_context.dart';
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
  void clearAutomaticSkip(String id) => _skipNextTurn.remove(id);
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

  /// Shared by the manual preview and the task, including native wire estimates.
  Future<CarrySelection> previewCarried(
    String id,
    CompressionRequest request, {
    ConversationContextSnapshot? snapshot,
  }) async {
    if (snapshot == null) return _previewCarriedPages(id, request);
    final source = ContextHistory.throughMessage(
      snapshot.messages,
      request.beforeMessageId,
    );
    final selection = selectCompressionHistory(
      source,
      snapshot.operations,
      request.options,
      protectedMessageId: request.beforeMessageId,
      effectiveMessageIds: request.effectiveMessageIds,
    );
    return _selectCarried(id, request, source, snapshot.operations, selection);
  }

  /// Read candidate bodies in pages instead of hydrating all the old assistant
  /// and tool output. Range selection continues to use the original metadata.
  Future<CarrySelection> _previewCarriedPages(
    String id,
    CompressionRequest request,
  ) async {
    final options = request.options;
    final setting = _carrySetting(request);
    if (!_carryEnabled(request, setting)) return const CarrySelection();
    final history = await chat.loadCompressionHistory(id);
    final range = selectCompressionRange(
      history.messages,
      history.operations,
      options,
      protectedMessageId: request.beforeMessageId,
      effectiveMessageIds: request.effectiveMessageIds,
    );
    if (range.covered.isEmpty) return const CarrySelection();

    // Native media projection depends on the whole selected prefix (the last
    // user and image eviction can both change if each page is sent separately).
    if (request.codex) {
      return previewCarried(
        id,
        request,
        snapshot: await chat.loadContextSnapshot(id),
      );
    }
    final metadata = history.messages;
    final positions = {for (final (i, m) in metadata.indexed) m.id: i};
    final loaded = <String, ChatMessage>{};
    Future<void> load(Iterable<String> ids) async {
      final needed = ids
          .where((m) => positions.containsKey(m) && !loaded.containsKey(m))
          .toSet();
      if (needed.isEmpty) return;
      for (final message in await chat.loadMessagesByIds(needed.toList())) {
        loaded[message.id] = message;
      }
    }

    final tail = range.retained.map((m) => m.id).toSet();
    final deps = range.dependencies.toSet();
    // Old native windows have no source IDs. Only the users in their covered
    // groups are needed to recover them.
    final legacyGroups = {
      for (final op in history.operations)
        if (deps.contains(op.id) &&
            op.nativePayload?.output.any((w) => w['role'] == 'user') == true)
          ...op.sourceGroups,
    };
    await load(
      metadata
          .where((m) => m.isUserMessage && legacyGroups.contains(m.groupId))
          .map((m) => m.id),
    );
    final inherited = await _inheritedCarry(
      [
        for (final m in metadata)
          if (loaded[m.id] case final original?) original,
      ],
      history.operations,
      range.dependencies,
      availableRevisionIds: positions.keys.toSet(),
    );
    final copies = {
      for (final list in inherited.values)
        for (final item in list) item.sourceMessageId: item,
    };
    final order = orderedCarryIds(
      messages: metadata,
      operations: history.operations,
      dependencies: range.dependencies,
      direct: range.effective.where((m) => m.isUserMessage).map((m) => m.id),
      covered: range.covered,
      retained: tail,
      fromSummaries: options.carryFromSummaries,
      inherited: inherited,
    );
    if (order.isEmpty) return const CarrySelection();

    await load(tail);
    for (final op in history.operations.where(
      (op) => tail.contains(op.summaryMessageId),
    )) {
      await load(
        (op.carried?.items ?? const <CarriedOriginal>[])
            .where((i) => i.imageHandles.isNotEmpty)
            .map((i) => i.sourceMessageId),
      );
    }
    // Budget assembly needs physical anchor positions and the retained bodies.
    // The newly summarized prefix itself is replaced by a reservation.
    final source = [
      for (final m in metadata)
        loaded[m.id] ??
            ChatMessage(
              id: m.id,
              groupId: m.groupId,
              role: m.role,
              content: '',
              conversationId: id,
            ),
    ];
    final budget = await _carryBudget(
      id,
      request,
      source,
      history.operations,
      range.covered.map((m) => m.groupId).toList(),
      range.dependencies,
    );
    final excluded = options.carryExcluded.toSet();
    final all = setting.mode == CarryMode.all;
    final limit = all ? order.length : setting.count.clamp(0, order.length);
    final tailReplies = range.retained
        .where((m) => m.role == 'assistant')
        .map((m) => m.id)
        .toSet();
    final items = <CarriedOriginal>[];
    final rows = <CarryRow>[];
    var total = 0;
    var fitCount = 0;
    var notFit = 0;
    var exhausted = false;
    for (var offset = 0; offset < limit; offset += 50) {
      final end = (offset + 50).clamp(0, limit);
      final page = order.sublist(offset, end);
      final needed = <String>{...page};
      for (final id in page) {
        final position = positions[id];
        if (position == null) continue;
        for (
          var i = position + 1;
          i < metadata.length && !metadata[i].isUserMessage;
          i++
        ) {
          if (metadata[i].role == 'assistant') needed.add(metadata[i].id);
        }
      }
      await load(needed);
      final local = needed.where(loaded.containsKey).toList()
        ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
      final messages = local.map((id) => loaded[id]!).toList();
      final pageIds = page.toSet();
      final selection = (
        effective: messages,
        covered: messages,
        input: messages.where((m) => pageIds.contains(m.id)).toList(),
        retained: messages.where((m) => tailReplies.contains(m.id)).toList(),
        dependencies: range.dependencies,
        needsRegeneration: false,
        missingOriginals: false,
      );
      final subset = <String, List<CarriedOriginal>>{};
      for (final id in page) {
        if (copies[id] case final copy?) {
          (subset[copy.fromOperationId!] ??= []).add(copy);
        }
      }
      final next = await _selectCarried(
        id,
        request,
        messages,
        history.operations,
        selection,
        orderedIds: page,
        inherited: subset,
        pageBudget: budget == null ? null : budget - total,
        isPage: true,
      );
      if (fitCount == offset) fitCount += next.fitCount;
      items.addAll(next.items.reversed);
      rows.addAll(next.rows);
      total += next.totalTokens;
      if (next.reachedBudget) {
        notFit =
            next.notFit +
            order.skip(end).where((id) => !excluded.contains(id)).length;
        exhausted = true;
        break;
      }
    }
    return CarrySelection(
      rows: rows,
      items: items.reversed.toList(),
      totalTokens: total,
      fitCount: fitCount,
      notFit: notFit,
      reachedBudget: exhausted,
      overBudget: !all && items.isNotEmpty && budget != null && total > budget,
    );
  }

  CarrySetting _carrySetting(CompressionRequest request) =>
      request.options.carry ??
      (request.options.native
          ? request.config.nativeCarryOriginals
          : request.config.carryOriginals);

  bool _carryEnabled(CompressionRequest request, CarrySetting setting) =>
      (!request.options.native || request.codex) &&
      setting.mode != CarryMode.off &&
      (setting.mode != CarryMode.unset || request.codex);

  Future<int?> _carryBudget(
    String id,
    CompressionRequest request,
    List<ChatMessage> source,
    List<ContextOperation> operations,
    List<String> covered,
    List<String> dependencies,
  ) async {
    final setting = _carrySetting(request);
    if (request.codex && setting.mode == CarryMode.unset) return 64000;
    int? budget = request.carryBudgetTokens;
    if (budget == null && estimateCandidate != null) {
      final empty = ContextOperation(
        id: 'carry-planning',
        kind: ContextOperationKind.compress,
        anchorGroupId: covered.last,
        appliedAfterGroupId: ContextHistory.group(source.last),
        sourceGroups: covered,
        dependencies: dependencies,
        createdAt: DateTime.now(),
        compressionDetails: const {'envelope': 'history-v1'},
      );
      final estimate = await estimateCandidate!(
        id,
        ContextHistory.resolve(source, [...operations, empty]),
      );
      if (estimate.contextWindow case final window?) {
        budget =
            window -
            estimate.usedTokens -
            (request.options.native ? 0 : request.config.summaryTokens);
      }
    }
    if (request.codex) return (budget ?? 64000).clamp(0, 64000);
    return budget ?? (setting.mode == CarryMode.all ? 64000 : null);
  }

  Future<Map<String, List<CarriedOriginal>>> _inheritedCarry(
    List<ChatMessage> source,
    List<ContextOperation> operations,
    List<String> dependencies, {
    List<ChatMessage> input = const [],
    Set<String>? availableRevisionIds,
  }) async {
    final legacy = operations
        .where(
          (op) =>
              dependencies.contains(op.id) &&
              op.nativePayload?.output.any((item) => item['role'] == 'user') ==
                  true,
        )
        .toList();
    if (legacy.isEmpty) {
      return inheritedCarryItems(source, operations, dependencies);
    }
    final groups = {for (final op in legacy) ...op.sourceGroups};
    final prompts = await chat.legacyCarryPrompts(
      source
          .where(
            (m) => m.role == 'user' && groups.contains(ContextHistory.group(m)),
          )
          .map((m) => m.id),
    );
    final summaries = {
      for (final message in input)
        if (ContextOperation.isSummary(message)) message.id: message,
    };
    for (final op in legacy) {
      final summary = summaries[op.summaryMessageId];
      if (summary == null) continue;
      final keys = op.legacyUserSources(source, frozenPrompts: prompts);
      summary.hydrateProviderArtifacts({
        ...summary.providerArtifactSnapshot,
        nativeUserSourcesKey: jsonEncode({
          for (final entry in keys.entries) entry.key.toString(): entry.value,
        }),
      });
    }
    return inheritedCarryItems(
      source,
      operations,
      dependencies,
      frozenPrompts: prompts,
      availableRevisionIds: availableRevisionIds,
    );
  }

  Future<CarrySelection> _selectCarried(
    String id,
    CompressionRequest request,
    List<ChatMessage> source,
    List<ContextOperation> operations,
    CompressionSelection selection, {
    List<String>? orderedIds,
    Map<String, List<CarriedOriginal>>? inherited,
    bool isPage = false,
    int? pageBudget,
  }) async {
    final options = request.options;
    final setting = _carrySetting(request);
    if (!_carryEnabled(request, setting) ||
        (!isPage && selection.covered.isEmpty)) {
      return const CarrySelection();
    }
    final automaticWire = request.codex && setting.mode == CarryMode.unset;
    final budget = isPage
        ? pageBudget
        : await _carryBudget(
            id,
            request,
            source,
            operations,
            selection.covered.map(ContextHistory.group).toList(),
            selection.dependencies,
          );
    final copies =
        inherited ??
        await _inheritedCarry(
          source,
          operations,
          selection.dependencies,
          input: selection.input,
        );
    final order =
        orderedIds ??
        orderedCarryIds(
          messages: source.map(ContextMessageMetadata.fromMessage).toList(),
          operations: operations,
          dependencies: selection.dependencies,
          direct: selection.effective
              .where(isCompressionUserMessage)
              .map((m) => m.id),
          covered: selection.covered.map(ContextMessageMetadata.fromMessage),
          retained: selection.retained.map((m) => m.id).toSet(),
          fromSummaries: !request.automatic && options.carryFromSummaries,
          inherited: copies,
        );
    final ids =
        (setting.mode == CarryMode.count ? order.take(setting.count) : order)
            .toSet();
    final candidates = source.where((m) => ids.contains(m.id)).toList();
    final wires = <String, Map<String, dynamic>>{};
    if (options.native && request.prepareNative != null) {
      // Explicit choices use the original user text while borrowing the
      // provider's media representation. Unset preserves the exact input.
      final frozen = {
        for (final list in copies.values)
          for (final item in list)
            if (item.wire != null) item.sourceMessageId,
      };
      final wireSelection = automaticWire
          ? selection
          : (
              effective: selection.effective,
              covered: selection.covered,
              input: candidates.where((m) => !frozen.contains(m.id)).toList(),
              retained: selection.retained,
              dependencies: selection.dependencies,
              needsRegeneration: false,
              missingOriginals: false,
            );
      final body = await request.prepareNative!(wireSelection);
      for (final raw in (body['input'] as List? ?? const []).whereType<Map>()) {
        if (raw['role'] != 'user' || raw[historySourceKey] is! String) continue;
        final key = carriedSourceId(raw[historySourceKey] as String);
        if (!ids.contains(key)) continue;
        wires[key] = Map<String, dynamic>.from(
          (RequestHistoryContext.stripSources({
                        'input': [raw],
                      })['input']
                      as List)
                  .single
              as Map,
        );
      }
    }
    final attachmentTexts = await chat.carriedUserTexts(
      candidates,
      includeAttachments: options.includeAttachmentsAndTools,
      quoteMarker: request.quoteMarker,
    );
    final images = <String, List<CarrySourceImage>>{};
    if (options.includeAttachmentsAndTools) {
      for (final image in await RequestImageContext.collectHistory(
        candidates,
        parseMarkdownImages: true,
        allowRemoteImages: true,
      )) {
        (images[image.identity.messageId] ??= []).add((
          handle: image.handle,
          uri: image.uri,
          available: !image.unavailable,
        ));
      }
    }
    final job = CarriedSelectionJob(
      messages: source,
      operations: operations,
      selection: selection,
      options: options,
      setting: automaticWire
          ? const CarrySetting(mode: CarryMode.all)
          : setting,
      budgetTokens: budget,
      kind: request.carryProviderKind,
      wires: wires,
      automaticWire: automaticWire,
      attachmentTexts: attachmentTexts,
      plainTexts: {
        for (final m in candidates) m.id: m.quotedContent(request.quoteMarker),
      },
      orderedIds: automaticWire && request.prepareNative != null
          ? wires.keys.toList().reversed.toList()
          : order,
      inheritedItems: copies,
      images: images,
      automatic: request.automatic,
    );
    var selected = await Isolate.run(job.call);
    if (request.automatic && selected.overBudget) {
      var total = selected.totalTokens;
      var dropped = 0;
      while (dropped < selected.items.length && total > (budget ?? total)) {
        total -= selected.items[dropped++].estimatedTokens;
      }
      selected = CarrySelection(
        items: selected.items.sublist(dropped),
        totalTokens: total,
        notFit: selected.notFit + dropped,
      );
    }
    return selected;
  }

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
      if (value['dismissed'] == true ||
          phase == CompressionPhase.completed ||
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

  Future<void> _publish(
    ContextCompressionTask task, {
    bool dismissed = false,
  }) async {
    if (_disposed || !identical(_tasks[task.conversationId], task)) return;
    final record = {...task.toJson(), if (dismissed) 'dismissed': true};
    final previous = _writes[task.conversationId] ?? Future<void>.value();
    final write = previous
        .catchError((Object _) {})
        .then(
          (_) => chat.saveCompressionTaskRecord(task.conversationId, record),
        );
    _writes[task.conversationId] = write;
    if (!dismissed) notifyListeners();
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
      final carry = await _selectCarried(
        task.conversationId,
        request,
        sourceMessages,
        snapshot.operations,
        selection,
      );
      _check(task);
      if (carry.overBudget) throw StateError('compression_carry_over_budget');
      final setting =
          task.options.carry ??
          (task.options.native
              ? request.config.nativeCarryOriginals
              : request.config.carryOriginals);
      final carried = carry.freeze(
        setting,
        fromSummaries: task.options.carryFromSummaries,
        origin: request.codex && setting.mode == CarryMode.unset
            ? 'auto'
            : 'explicit',
      );
      if (task.options.native) {
        await _runNative(task, snapshot, sourceMessages, selection, carried);
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
        summaryTokens: request.automatic && request.carryBudgetTokens != null
            ? (request.carryBudgetTokens! + 128 - carry.totalTokens).clamp(
                128,
                request.config.summaryTokens,
              )
            : null,
        materials: chunks,
        previousSummary: previousSummary,
        background: background,
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
          if (carried.items.isNotEmpty || carried.notFit > 0)
            'carried': carried.toJson(),
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
      var accepted =
          await request.acceptCandidate?.call(task.candidate!) ?? true;
      final originalCandidate = task.candidate!;
      final originals = originalCandidate.carried;
      if (request.automatic &&
          !accepted &&
          originals != null &&
          originals.items.isNotEmpty) {
        // The live request includes calibrated usage and its active tool suffix.
        // If that last check is stricter, keep the largest fitting newest suffix
        // without spending another summary request.
        var low = 0;
        var high = originals.items.length - 1;
        ContextOperation? best;
        while (low <= high) {
          _check(task);
          final keep = (low + high) ~/ 2;
          final dropped = originals.items.length - keep;
          final candidate = originalCandidate.withCarried(
            originals.withItems(
              originals.items.skip(dropped).toList(),
              notFit: originals.notFit + dropped,
            ),
          );
          if (await request.acceptCandidate!(candidate)) {
            best = candidate;
            low = keep + 1;
          } else {
            high = keep - 1;
          }
        }
        if (best != null) {
          task.candidate = best;
          accepted = await request.acceptCandidate!(best);
          await _checkBudget(task, (
            messages: sourceMessages,
            operations: snapshot.operations,
            fingerprint: task.sourceFingerprint!,
          ));
        }
      }
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
    CarriedOriginals carried,
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
    final nativeResult = await request.compactNative!(selection, task.id);
    final result = nativeResult.payload;
    if (carried.origin == 'auto') {
      // The response-side retention was computed on the exact submitted input.
      // Key the frozen wire by source so even a boundary change never reassigns
      // a user's reply, edits or link to another message.
      final originals = {for (final m in source) m.id: m};
      final copies = {
        for (final list in inheritedCarryItems(
          source,
          snapshot.operations,
          selection.dependencies,
        ).values)
          for (final item in list) item.sourceMessageId: item,
        for (final item in carried.items) item.sourceMessageId: item,
      };
      final actual = <CarriedOriginal>[];
      for (final entry in nativeResult.retained) {
        final id = carriedSourceId(entry.sourceKey);
        final original = originals[id];
        final base =
            copies[id] ??
            (original != null ? carriedFromMessage(original) : null);
        if (base == null) continue;
        final text = carriedWireText(entry.wire);
        var item = base.copyWith(
          wire: entry.wire,
          text: text,
          clearEdit: true,
          removeReply: true,
          truncated:
              base.truncated ||
              text.contains('\n[…truncated…]\n') && text != base.text,
        );
        if (task.options.newConversation) item = item.textOnly();
        actual.add(
          item.copyWith(
            estimatedTokens: countCarriedTokens(
              item,
              request.carryProviderKind,
            ),
          ),
        );
      }
      carried = carried.withItems(
        actual,
        notFit: (carried.items.length + carried.notFit - actual.length).clamp(
          0,
          1 << 30,
        ),
      );
    }
    _check(task);
    final sourceImages = await RequestImageContext.collectHistory(
      selection.covered,
      parseMarkdownImages: true,
      allowRemoteImages: true,
    );
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
        if (carried.items.isNotEmpty)
          'imageSources': {
            for (final image in sourceImages)
              image.handle: {
                'messageId': image.identity.messageId,
                'slot': image.identity.slot,
                'imageIndex': image.identity.imageIndex,
              },
          },
        if (carried.items.isNotEmpty || carried.notFit > 0)
          'carried': carried.toJson(),
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
        final withinWindow = await _checkBudget(task, snapshot);
        _check(task);
        if (!withinWindow) throw StateError('context_budget_exceeded');
        task.error = null;
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
    // Acknowledging a terminal status does not cancel or undo its result.
    // Persist before removing it so a failed write leaves the status retryable.
    await _publish(task, dismissed: true);
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

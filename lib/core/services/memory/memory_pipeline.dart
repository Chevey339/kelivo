import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../database/chat_database_repository.dart';
import '../../models/assistant.dart';
import '../../models/chat_message.dart';
import '../../models/memory_entry.dart';
import '../../models/message_part.dart';
import '../../providers/assistant_provider.dart';
import '../../providers/memory_provider_v2.dart';
import '../../providers/settings_provider.dart';
import '../api/chat_api_service.dart';
import '../chat/chat_service.dart';
import 'memory_block_builder.dart';
import 'memory_extractor.dart';
import 'memory_gatekeeper.dart';
import 'memory_profile_distiller.dart';
import 'memory_prompts.dart';
import 'memory_repository.dart';
import 'memory_smart_add.dart';
import 'memory_trace.dart';

/// Result of a background organize run (§12 / §13.6).
class MemoryOrganizeResult {
  const MemoryOrganizeResult({
    required this.advanced,
    required this.gate,
    this.extractedCount = 0,
    this.error,
    this.forcedAdvance = false,
    this.windowSize = 0,
  });

  final bool advanced;
  final MemoryGateParseResult? gate;
  final int extractedCount;
  final String? error;
  final bool forcedAdvance;

  /// Messages in the processed window; 0 when the run stopped before building
  /// one.
  final int windowSize;
}

class MemoryOrganizeStatus {
  const MemoryOrganizeStatus({this.lastAt, this.lastResult});

  final DateTime? lastAt;
  final MemoryOrganizeResult? lastResult;
}

class _PipelineJob {
  _PipelineJob({
    required this.conversationId,
    required this.assistantId,
    required this.force,
    this.completer,
    this.onError,
  });

  final String conversationId;
  final String assistantId;
  final bool force;
  final Completer<MemoryOrganizeResult>? completer;
  final void Function(String error)? onError;
}

/// Background memory pipeline: Gatekeeper → Extract → Smart Add → Distiller.
///
/// Process-wide single-concurrency queue (max 8; drop oldest when full) (§12.8).
class MemoryPipelineService {
  MemoryPipelineService({
    required this.chatService,
    required this.repository,
    required this.chatRepository,
    required this._settings,
    required this._assistants,
    required this._memoryV2,
    MemoryTraceRecorder? traceRecorder,
    Future<String> Function({
      required ProviderConfig config,
      required String modelId,
      required String prompt,
      String? conversationId,
      int? thinkingBudget,
    })?
    generateText,
  }) : traceRecorder = traceRecorder ?? MemoryTraceRecorder.instance,
       _generateText = generateText ?? _defaultGenerateText,
       smartAdd = MemorySmartAdd(
         repository: repository,
         chatRepository: chatRepository,
       ),
       distiller = MemoryProfileDistiller(
         repository: repository,
         chatRepository: chatRepository,
       );

  static Future<String> _defaultGenerateText({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
    String? conversationId,
    int? thinkingBudget,
  }) {
    return ChatApiService.generateText(
      conversationId: conversationId,
      config: config,
      modelId: modelId,
      prompt: prompt,
      thinkingBudget: thinkingBudget,
    );
  }

  final ChatService chatService;
  final MemoryRepository repository;
  final ChatDatabaseRepository chatRepository;
  final MemorySmartAdd smartAdd;
  final MemoryProfileDistiller distiller;

  /// Collects step-by-step traces of every background run (§debug viewer).
  final MemoryTraceRecorder traceRecorder;

  final SettingsProvider Function() _settings;
  final AssistantProvider Function() _assistants;
  final MemoryProviderV2 Function() _memoryV2;
  final Future<String> Function({
    required ProviderConfig config,
    required String modelId,
    required String prompt,
    String? conversationId,
    int? thinkingBudget,
  })
  _generateText;

  static const int queueLimit = 8;
  static const int firstWindowCap = 20;
  static const int maxWindowFailures = 3;

  final Queue<_PipelineJob> _queue = Queue<_PipelineJob>();
  bool _running = false;

  /// Failures keyed by `(conversationId, watermark, windowEndOrder)`.
  final Map<String, int> _windowFailures = {};

  MemoryOrganizeStatus _lastStatus = const MemoryOrganizeStatus();
  MemoryOrganizeStatus get lastStatus => _lastStatus;

  /// Collapse to the selected version chain (same rules as title generation).
  static List<ChatMessage> collapseSelectedVersions(
    List<ChatMessage> messages,
    Map<String, int> selections,
  ) {
    final byGroup = <String, List<ChatMessage>>{};
    final order = <String>[];
    for (final message in messages) {
      final groupId = message.groupId ?? message.id;
      byGroup
          .putIfAbsent(groupId, () {
            order.add(groupId);
            return <ChatMessage>[];
          })
          .add(message);
    }
    for (final list in byGroup.values) {
      list.sort((a, b) => a.version.compareTo(b.version));
    }
    return [
      for (final groupId in order)
        () {
          final versions = byGroup[groupId]!;
          final sel = selections[groupId];
          if (sel != null) {
            for (final c in versions) {
              if (c.version == sel) return c;
            }
          }
          return versions.last;
        }(),
    ];
  }

  /// Build `buildConversationText(window)` (§12.3).
  static String buildConversationText(
    List<ChatMessage> window,
    MemoryPromptLang lang,
  ) {
    final userPrefix = lang == MemoryPromptLang.zh ? '用户：' : 'User: ';
    final assistantPrefix = lang == MemoryPromptLang.zh ? '助手：' : 'Assistant: ';
    final lines = <String>[];
    for (final m in window) {
      String prefix;
      if (m.role == 'user') {
        prefix = userPrefix;
      } else if (m.role == 'assistant') {
        prefix = assistantPrefix;
      } else {
        continue;
      }
      // TextPart bodies only — image/file attachments live as structured parts.
      var text = m.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join()
          .trim();
      if (text.isEmpty) continue;
      if (text.length > 2000) {
        text = '${text.substring(0, 2000)}…';
      }
      lines.add('$prefix$text');
    }
    var out = lines.join('\n\n');
    if (out.length > 12000) {
      out = '…${out.substring(out.length - 12000)}';
    }
    return out;
  }

  /// Whether conversation summary generation is allowed (§12.10 / D-27).
  static bool shouldGenerateConversationSummary({
    required bool allowPastConversationRecall,
    required bool generateConversationSummary,
  }) {
    return allowPastConversationRecall && generateConversationSummary;
  }

  /// Schedule after an assistant finalize. Never awaits; never throws to chat.
  void scheduleIfNeeded({
    required String conversationId,
    required String assistantId,
    void Function(String error)? onError,
  }) {
    try {
      _enqueue(
        _PipelineJob(
          conversationId: conversationId,
          assistantId: assistantId,
          force: false,
          onError: onError,
        ),
      );
    } catch (e, st) {
      debugPrint('MemoryPipeline.scheduleIfNeeded: $e\n$st');
      onError?.call(e.toString());
    }
  }

  /// Manual "整理记忆" — bypasses autoOrganize + N-turns; still needs model.
  Future<MemoryOrganizeResult> runNow({
    required String conversationId,
    required String assistantId,
  }) {
    final completer = Completer<MemoryOrganizeResult>();
    _enqueue(
      _PipelineJob(
        conversationId: conversationId,
        assistantId: assistantId,
        force: true,
        completer: completer,
      ),
    );
    return completer.future;
  }

  void _enqueue(_PipelineJob job) {
    // A temporary conversation is discarded when the user leaves it and never
    // reaches the database. Distilling it into long-term memory would outlive
    // the conversation the user asked to be throwaway.
    if (chatService.isTemporaryConversation(job.conversationId)) {
      job.completer?.complete(
        const MemoryOrganizeResult(
          advanced: false,
          gate: null,
          error: 'temporary_conversation',
        ),
      );
      return;
    }

    // Coalesce pending (not running) jobs for the same conversation.
    _queue.removeWhere(
      (j) =>
          j.conversationId == job.conversationId &&
          j.completer == null &&
          job.completer == null,
    );
    _queue.addLast(job);
    while (_queue.length > queueLimit) {
      final dropped = _queue.removeFirst();
      dropped.onError?.call('queue_overflow');
      dropped.completer?.complete(
        const MemoryOrganizeResult(
          advanced: false,
          gate: null,
          error: 'queue_overflow',
        ),
      );
    }
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_running) return;
    _running = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeFirst();
        MemoryOrganizeResult result;
        try {
          result = await _runJob(job);
        } catch (e, st) {
          debugPrint('MemoryPipeline job failed: $e\n$st');
          result = MemoryOrganizeResult(
            advanced: false,
            gate: null,
            error: e.toString(),
          );
        }
        _lastStatus = MemoryOrganizeStatus(
          lastAt: DateTime.now(),
          lastResult: result,
        );
        if (result.error != null && _isTaskFailure(result.error!)) {
          job.onError?.call(result.error!);
        }
        job.completer?.complete(result);
      }
    } finally {
      _running = false;
    }
  }

  /// Outcome codes that skip organize without counting as a task failure.
  static const Set<String> skipReasonCodes = {
    'temporary_conversation',
    'memory_disabled',
    'auto_organize_off',
    'streaming',
    'below_threshold',
    'empty_window',
  };

  static bool _isTaskFailure(String error) => !skipReasonCodes.contains(error);

  /// Open a trace for [job]. Returns null when recording is off or fails.
  MemoryTraceHandle? _beginJobTrace(_PipelineJob job) {
    // Temporary chats are discarded on exit; keep their traces out of the UI.
    if (chatService.isTemporaryConversation(job.conversationId)) {
      return null;
    }
    try {
      final assistant = _assistants().getById(job.assistantId);
      final convo = chatService.getConversation(job.conversationId);
      return traceRecorder.begin(
        trigger: job.force
            ? MemoryTraceTrigger.manual
            : MemoryTraceTrigger.autoTurns,
        scope: assistant == null
            ? MemoryTraceScope.global
            : memoryTraceScopeOf(assistant.memoryWriteScope),
        conversationId: job.conversationId,
        conversationTitle: convo?.title,
        assistantId: assistant?.id ?? job.assistantId,
        assistantName: assistant?.name,
      );
    } catch (_) {
      return null;
    }
  }

  Future<MemoryOrganizeResult> _runJob(_PipelineJob job) async {
    final handle = _beginJobTrace(job);
    MemoryOrganizeResult result;
    try {
      result = await _runJobBody(job, handle);
    } catch (e) {
      handle?.commit(error: e.toString());
      rethrow;
    }
    handle?.commit(
      advanced: result.advanced,
      forcedAdvance: result.forcedAdvance,
      error: result.error,
    );
    return result;
  }

  Future<MemoryOrganizeResult> _runJobBody(
    _PipelineJob job,
    MemoryTraceHandle? handle,
  ) async {
    final settings = _settings();
    final assistants = _assistants();
    final assistant = assistants.getById(job.assistantId);
    if (assistant == null) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'assistant_missing',
      );
    }
    if (!assistant.enableMemory) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'memory_disabled',
      );
    }
    if (!job.force && !assistant.autoOrganizeMemory) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'auto_organize_off',
      );
    }

    final provKey = settings.memoryModelProvider;
    final mdlId = settings.memoryModelId;
    if (provKey == null || mdlId == null) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'memory_model_unset',
      );
    }
    // Provider/model must still exist (D-20).
    final cfg = settings.getProviderConfig(provKey);
    if (cfg.models.isNotEmpty &&
        !cfg.models.contains(mdlId) &&
        cfg.modelOverrides[mdlId] == null) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'memory_model_missing',
      );
    }

    final convo = chatService.getConversation(job.conversationId);
    if (convo == null) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'conversation_missing',
      );
    }

    // Skip while this conversation still has a streaming message (§12.1).
    // Finalize already ran after the turn; a racing stream is rare — the next
    // successful finalize will re-trigger, so do not re-enqueue here (avoids
    // draining the same job forever).
    if (chatService.getMessages(job.conversationId).any((m) => m.isStreaming)) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'streaming',
      );
    }

    final all = await chatService.loadMessages(job.conversationId);
    final selected = collapseSelectedVersions(
      all,
      chatService.getVersionSelections(job.conversationId),
    );

    final watermark = convo.lastMemoryExtractedOrder;
    final withOrder = <({ChatMessage message, int order})>[];
    for (final m in selected) {
      if (m.isStreaming) continue;
      final order = chatService.getMessageIndex(job.conversationId, m.id);
      if (order < 0) continue;
      if (order <= watermark) continue;
      withOrder.add((message: m, order: order));
    }
    withOrder.sort((a, b) => a.order.compareTo(b.order));

    final pendingTurns = withOrder
        .where((e) => e.message.role == 'assistant')
        .length;
    if (!job.force &&
        pendingTurns < assistant.memoryOrganizeEveryNTurns.clamp(1, 20)) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'below_threshold',
      );
    }
    if (withOrder.isEmpty) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'empty_window',
      );
    }

    var window = withOrder;
    if (watermark == -1 && window.length > firstWindowCap) {
      window = window.sublist(window.length - firstWindowCap);
    }
    final thinkingBudget = settings.memoryModelThinkingEnabled
        ? (assistant.thinkingBudget ?? settings.thinkingBudget)
        : 0;

    return processWindow(
      conversationId: job.conversationId,
      assistant: assistant,
      settings: settings,
      watermark: watermark,
      window: window,
      trace: handle,
      llmCall: (prompt) => _generateText(
        conversationId: job.conversationId,
        config: cfg,
        modelId: mdlId,
        prompt: prompt,
        thinkingBudget: thinkingBudget,
      ),
    );
  }

  /// Gatekeeper → Extract → Smart Add → Distiller for a prepared window.
  ///
  /// Exposed for tests (§18.1 / watermark / short-circuit).
  ///
  /// When [trace] is null a trace is opened and committed here, so direct
  /// callers are recorded too.
  @visibleForTesting
  Future<MemoryOrganizeResult> processWindow({
    required String conversationId,
    required Assistant assistant,
    required SettingsProvider settings,
    required int watermark,
    required List<({ChatMessage message, int order})> window,
    required Future<String> Function(String prompt) llmCall,
    MemoryTraceHandle? trace,
  }) async {
    final ownsTrace = trace == null;
    MemoryTraceHandle? handle = trace;
    if (ownsTrace) {
      if (chatService.isTemporaryConversation(conversationId)) {
        handle = null;
      } else {
        try {
          handle = traceRecorder.begin(
            trigger: MemoryTraceTrigger.manual,
            scope: memoryTraceScopeOf(assistant.memoryWriteScope),
            conversationId: conversationId,
            conversationTitle: chatService
                .getConversation(conversationId)
                ?.title,
            assistantId: assistant.id,
            assistantName: assistant.name,
          );
        } catch (_) {
          handle = null;
        }
      }
    }
    MemoryOrganizeResult result;
    try {
      result = await _processWindowBody(
        conversationId: conversationId,
        assistant: assistant,
        settings: settings,
        watermark: watermark,
        window: window,
        llmCall: llmCall,
        handle: handle,
      );
    } catch (e) {
      if (ownsTrace) handle?.commit(error: e.toString());
      rethrow;
    }
    if (ownsTrace) {
      handle?.commit(
        advanced: result.advanced,
        forcedAdvance: result.forcedAdvance,
        error: result.error,
      );
    }
    return result;
  }

  Future<MemoryOrganizeResult> _processWindowBody({
    required String conversationId,
    required Assistant assistant,
    required SettingsProvider settings,
    required int watermark,
    required List<({ChatMessage message, int order})> window,
    required Future<String> Function(String prompt) llmCall,
    required MemoryTraceHandle? handle,
  }) async {
    if (window.isEmpty) {
      return const MemoryOrganizeResult(
        advanced: false,
        gate: null,
        error: 'empty_window',
      );
    }
    final windowEnd = window.last.order;
    final failureKey = '$conversationId|$watermark|$windowEnd';
    final lang = settings.resolvedMemoryPromptLang;
    final conversationText = buildConversationText([
      for (final e in window) e.message,
    ], lang);
    handle?.setWindow(
      watermark: watermark,
      startOrder: window.first.order,
      endOrder: windowEnd,
      size: window.length,
    );

    // ── Gatekeeper ────────────────────────────────────────────────────────
    final gateStep = handle?.beginStep(MemoryTraceStepKind.gatekeeper);
    final gatePrompt = MemoryGatekeeper.buildPrompt(
      lang: lang,
      conversation: conversationText,
      overrideZh: settings.memoryGatePromptZh,
      overrideEn: settings.memoryGatePromptEn,
    );
    gateStep?.appendPrompt(gatePrompt);
    final String gateRaw;
    try {
      gateRaw = await llmCall(gatePrompt);
    } catch (e) {
      gateStep?.finish(
        MemoryTraceStepStatus.failed,
        error: 'gate_request_failed:$e',
      );
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.extract);
      return _failWindow(
        failureKey: failureKey,
        conversationId: conversationId,
        windowEnd: windowEnd,
        assistantId: assistant.id,
        windowSize: window.length,
        gate: null,
        error: 'gate_request_failed:$e',
      );
    }
    gateStep?.appendResponse(gateRaw);
    final gate = MemoryGatekeeper.parse(gateRaw);
    gateStep?.parsedResult = gate.name;
    if (gate == MemoryGateParseResult.malformed) {
      gateStep?.finish(
        MemoryTraceStepStatus.failed,
        error: 'gate_parse_failed',
      );
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.extract);
      return _failWindow(
        failureKey: failureKey,
        conversationId: conversationId,
        windowEnd: windowEnd,
        assistantId: assistant.id,
        windowSize: window.length,
        gate: gate,
        error: 'gate_parse_failed',
      );
    }
    gateStep?.finish(MemoryTraceStepStatus.success);
    if (gate == MemoryGateParseResult.skip) {
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.extract);
      await _advance(conversationId, windowEnd);
      _windowFailures.remove(failureKey);
      return MemoryOrganizeResult(
        advanced: true,
        gate: gate,
        extractedCount: 0,
        windowSize: window.length,
      );
    }

    // ── Extract ───────────────────────────────────────────────────────────
    final extractStep = handle?.beginStep(MemoryTraceStepKind.extract);
    final visible = await chatRepository.queryVisibleMemories(
      assistantId: assistant.id,
    );
    final totals = await chatRepository.countVisibleMemoriesByType(
      assistantId: assistant.id,
    );
    final existingMemory = MemoryBlockBuilder.buildMemoryBlock(
      visible: visible,
      totalByType: totals,
      lang: lang,
      maxItems: settings.memoryInjectionMaxItems,
    );
    final extractPrompt = MemoryExtractor.buildPrompt(
      lang: lang,
      conversation: conversationText,
      existingMemory: existingMemory,
      writeScope: assistant.memoryWriteScope,
      overrideZh: settings.memoryExtractPromptZh,
      overrideEn: settings.memoryExtractPromptEn,
    );
    extractStep?.appendPrompt(extractPrompt);
    final String extractRaw;
    try {
      extractRaw = await llmCall(extractPrompt);
    } catch (e) {
      extractStep?.finish(
        MemoryTraceStepStatus.failed,
        error: 'extract_request_failed:$e',
      );
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.smartAdd);
      return _failWindow(
        failureKey: failureKey,
        conversationId: conversationId,
        windowEnd: windowEnd,
        assistantId: assistant.id,
        windowSize: window.length,
        gate: gate,
        error: 'extract_request_failed:$e',
      );
    }
    extractStep?.appendResponse(extractRaw);
    final extracted = MemoryExtractor.parse(extractRaw);
    if (!extracted.ok) {
      extractStep?.finish(
        MemoryTraceStepStatus.failed,
        error: 'extract_parse_failed',
      );
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.smartAdd);
      return _failWindow(
        failureKey: failureKey,
        conversationId: conversationId,
        windowEnd: windowEnd,
        assistantId: assistant.id,
        windowSize: window.length,
        gate: gate,
        error: 'extract_parse_failed',
      );
    }
    extractStep?.setParsedJson({
      'items': [
        for (final item in extracted.items)
          {
            'type': MemoryEntry.typeToString(item.type),
            if (item.scopeAttr != null) 'scope': item.scopeAttr,
            'content': item.content,
          },
      ],
    });
    extractStep?.finish(MemoryTraceStepStatus.success);
    if (extracted.items.isEmpty) {
      _skipRemainingSteps(handle, from: MemoryTraceStepKind.smartAdd);
      await _advance(conversationId, windowEnd);
      _windowFailures.remove(failureKey);
      return MemoryOrganizeResult(
        advanced: true,
        gate: gate,
        extractedCount: 0,
        windowSize: window.length,
      );
    }

    // ── Smart Add ─────────────────────────────────────────────────────────
    final smartItems = <SmartAddItem>[
      for (final item in extracted.items)
        () {
          final scope = MemorySmartAdd.resolveScopeForExtracted(
            policy: assistant.memoryWriteScope,
            scopeAttr: item.scopeAttr,
          );
          return SmartAddItem(
            type: item.type,
            content: item.content,
            scope: scope,
            assistantId: scope == MemoryScope.assistant ? assistant.id : null,
          );
        }(),
    ];

    final smartStep = handle?.beginStep(MemoryTraceStepKind.smartAdd);
    final smart = await smartAdd.addMany(
      items: smartItems,
      visibilityAssistantId: assistant.id,
      source: MemorySource.extracted,
      lang: lang,
      mode: assistant.memorySmartAddMode,
      llmCall: llmCall,
      perItemOverrideZh: settings.memorySmartAddPromptZh,
      perItemOverrideEn: settings.memorySmartAddPromptEn,
      batchOverrideZh: settings.memorySmartAddBatchPromptZh,
      batchOverrideEn: settings.memorySmartAddBatchPromptEn,
      traceStep: smartStep,
    );
    smartStep?.setParsedJson({
      'identityChanged': smart.identityChanged,
      'results': [for (final r in smart.results) r.toToolJson()],
    });
    smartStep?.finish(MemoryTraceStepStatus.success);

    // ── Profile Distiller (identity changes only) ─────────────────────────
    if (smart.identityChanged) {
      final distillStep = handle?.beginStep(
        MemoryTraceStepKind.profileDistiller,
      );
      try {
        final ok = await distiller.run(
          lang: lang,
          assistantId: assistant.id,
          llmCall: llmCall,
          overrideZh: settings.memoryProfileDistillPromptZh,
          overrideEn: settings.memoryProfileDistillPromptEn,
          traceStep: distillStep,
        );
        distillStep?.finish(
          ok ? MemoryTraceStepStatus.success : MemoryTraceStepStatus.failed,
          error: ok ? null : 'distill_failed',
        );
      } catch (e) {
        debugPrint('MemoryPipeline distiller failed: $e');
        distillStep?.finish(MemoryTraceStepStatus.failed, error: e.toString());
      }
    } else {
      _skipStep(handle, MemoryTraceStepKind.profileDistiller);
    }

    // Smart Add (including degraded) and Distiller failure both advance (§12.8).
    await _advance(conversationId, windowEnd);
    _windowFailures.remove(failureKey);
    return MemoryOrganizeResult(
      advanced: true,
      gate: gate,
      extractedCount: extracted.items.length,
      windowSize: window.length,
    );
  }

  /// Record a stage the run never reached, so the viewer shows the full chain.
  void _skipStep(MemoryTraceHandle? handle, MemoryTraceStepKind kind) {
    handle?.beginStep(kind)?.finish(MemoryTraceStepStatus.skipped);
  }

  static const List<MemoryTraceStepKind> _organizeStages = [
    MemoryTraceStepKind.gatekeeper,
    MemoryTraceStepKind.extract,
    MemoryTraceStepKind.smartAdd,
    MemoryTraceStepKind.profileDistiller,
  ];

  void _skipRemainingSteps(
    MemoryTraceHandle? handle, {
    required MemoryTraceStepKind from,
  }) {
    if (handle == null) return;
    final start = _organizeStages.indexOf(from);
    if (start < 0) return;
    for (var i = start; i < _organizeStages.length; i++) {
      _skipStep(handle, _organizeStages[i]);
    }
  }

  Future<MemoryOrganizeResult> _failWindow({
    required String failureKey,
    required String conversationId,
    required int windowEnd,
    required String assistantId,
    required int windowSize,
    required MemoryGateParseResult? gate,
    required String error,
  }) async {
    final count = (_windowFailures[failureKey] ?? 0) + 1;
    _windowFailures[failureKey] = count;
    if (count >= maxWindowFailures) {
      await _advance(conversationId, windowEnd);
      _windowFailures.remove(failureKey);
      return MemoryOrganizeResult(
        advanced: true,
        gate: gate,
        error: error,
        forcedAdvance: true,
        windowSize: windowSize,
      );
    }
    return MemoryOrganizeResult(
      advanced: false,
      gate: gate,
      error: error,
      windowSize: windowSize,
    );
  }

  Future<void> _advance(String conversationId, int order) async {
    await chatRepository.setConversationLastMemoryExtractedOrder(
      conversationId,
      order,
    );
    // Keep in-memory Conversation in sync when present.
    final convo = chatService.getConversation(conversationId);
    if (convo != null) {
      convo.lastMemoryExtractedOrder = order;
    }
    try {
      await _memoryV2().reloadCurrentScope();
    } catch (_) {}
  }
}

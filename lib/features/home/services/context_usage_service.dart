import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/utils/token_estimator.dart';
import '../utils/model_display_helper.dart';
import 'context_assembly.dart';

enum ContextUsageState { none, computing, exact, estimated, stale }

class ContextUsageBuckets {
  const ContextUsageBuckets({
    this.system = 0,
    this.injections = 0,
    this.history = 0,
    this.tools = 0,
    this.attachments = 0,
    this.draft = 0,
  });

  final int system;
  final int injections;
  final int history;
  final int tools;
  final int attachments;
  final int draft;

  int get total => system + injections + history + tools + attachments + draft;

  ContextUsageBuckets copyWith({
    int? system,
    int? injections,
    int? history,
    int? tools,
    int? attachments,
    int? draft,
  }) {
    return ContextUsageBuckets(
      system: system ?? this.system,
      injections: injections ?? this.injections,
      history: history ?? this.history,
      tools: tools ?? this.tools,
      attachments: attachments ?? this.attachments,
      draft: draft ?? this.draft,
    );
  }
}

class ContextUsageSnapshot {
  const ContextUsageSnapshot({
    required this.state,
    required this.buckets,
    required this.usedTokens,
    required this.contextWindow,
    required this.conversationId,
    required this.revision,
    required this.providerKey,
    required this.modelId,
    required this.assistantId,
    required this.computedAt,
  });

  final ContextUsageState state;
  final ContextUsageBuckets buckets;
  final int usedTokens;
  final int? contextWindow;
  final String conversationId;
  final int revision;
  final String providerKey;
  final String modelId;
  final String? assistantId;
  final DateTime computedAt;

  double? get ratio {
    final window = contextWindow;
    if (window == null || window <= 0) return null;
    return usedTokens / window;
  }

  ContextUsageSnapshot copyWith({
    ContextUsageState? state,
    ContextUsageBuckets? buckets,
    int? usedTokens,
    int? contextWindow,
    String? conversationId,
    int? revision,
    String? providerKey,
    String? modelId,
    String? assistantId,
    DateTime? computedAt,
  }) {
    return ContextUsageSnapshot(
      state: state ?? this.state,
      buckets: buckets ?? this.buckets,
      usedTokens: usedTokens ?? this.usedTokens,
      contextWindow: contextWindow ?? this.contextWindow,
      conversationId: conversationId ?? this.conversationId,
      revision: revision ?? this.revision,
      providerKey: providerKey ?? this.providerKey,
      modelId: modelId ?? this.modelId,
      assistantId: assistantId ?? this.assistantId,
      computedAt: computedAt ?? this.computedAt,
    );
  }
}

class ContextUsageService extends ChangeNotifier {
  ContextUsageService({
    required this._chatService,
    required this._settings,
    required this._assistants,
    this._assemble,
    this._staleRefreshDelay = const Duration(milliseconds: 800),
    Future<T> Function<T>(T Function() computation)? runEstimate,
  }) : _runEstimate = runEstimate ?? Isolate.run {
    _settings.addListener(_onSettingsOrAssistantChanged);
    _assistants.addListener(_onSettingsOrAssistantChanged);
  }

  final ChatService _chatService;
  final SettingsProvider _settings;
  final AssistantProvider _assistants;
  ContextAssemblyPreviewFn? _assemble;
  final Duration _staleRefreshDelay;
  final Future<T> Function<T>(T Function() computation) _runEstimate;

  final Map<String, ContextUsageSnapshot> _snapshots =
      <String, ContextUsageSnapshot>{};
  final Map<String, int> _inFlight = <String, int>{};
  final Map<String, Timer> _debounce = <String, Timer>{};

  String? _activeConversationId;
  VoidCallback? _revisionListener;
  ValueListenable<int>? _revisionListenable;

  String? get activeConversationId => _activeConversationId;

  ContextUsageSnapshot? get current {
    final id = _activeConversationId;
    if (id == null) return null;
    return _snapshots[id];
  }

  ContextUsageSnapshot? snapshot(String conversationId) =>
      _snapshots[conversationId];

  void bindAssembler(ContextAssemblyPreviewFn assemble) {
    _assemble = assemble;
  }

  void setActiveConversation(String? conversationId) {
    if (_activeConversationId == conversationId) {
      _syncResolvedIdentity();
      notifyListeners();
      return;
    }
    _unlistenRevision();
    _activeConversationId = conversationId;
    if (conversationId != null) {
      _listenRevision(conversationId);
      final snap = _snapshots[conversationId];
      final revision = _chatService.contextRevision(conversationId);
      if (snap != null &&
          snap.revision != revision &&
          snap.state != ContextUsageState.none) {
        _snapshots[conversationId] = snap.copyWith(
          state: ContextUsageState.stale,
        );
        _scheduleRefresh(conversationId);
      }
      _syncResolvedIdentity();
    }
    notifyListeners();
  }

  void recordUsage({
    required String conversationId,
    required String providerKey,
    required String modelId,
    required String? assistantId,
    required TokenUsage usage,
    required ChatMessage assistantMessage,
  }) {
    if (usage.promptTokens <= 0) return;
    final cfg = _settings.getProviderConfig(providerKey);
    final spec = ModelSpecResolver.instance.spec(cfg, modelId);
    final extra = estimateAssistantTurnTokens(
      assistantMessage: assistantMessage,
      replay: spec.reasoning.replay,
      toolEvents: _chatService.getToolEvents(assistantMessage.id),
    );
    final window = spec.contextWindow;
    final used = usage.promptTokens + extra;
    final previous = _snapshots[conversationId];
    _snapshots[conversationId] = ContextUsageSnapshot(
      state: ContextUsageState.exact,
      buckets: (previous?.buckets ?? const ContextUsageBuckets()).copyWith(
        draft: previous?.buckets.draft ?? 0,
      ),
      usedTokens: used + (previous?.buckets.draft ?? 0),
      contextWindow: window,
      conversationId: conversationId,
      revision: _chatService.contextRevision(conversationId),
      providerKey: providerKey,
      modelId: modelId,
      assistantId: assistantId,
      computedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> refresh(
    String conversationId, {
    String draftText = '',
    bool force = false,
  }) async {
    final resolved = _resolvedIdentity(conversationId);
    if (resolved == null) return;
    final existing = _snapshots[conversationId];
    if (!force &&
        existing != null &&
        _isFresh(existing, conversationId, resolved)) {
      _foldDraft(conversationId, existing, draftText);
      return;
    }

    final revision = _chatService.contextRevision(conversationId);
    final generation = (_inFlight[conversationId] ?? 0) + 1;
    _inFlight[conversationId] = generation;
    _snapshots[conversationId] = ContextUsageSnapshot(
      state: ContextUsageState.computing,
      buckets: existing?.buckets ?? const ContextUsageBuckets(),
      usedTokens: existing?.usedTokens ?? 0,
      contextWindow: resolved.contextWindow,
      conversationId: conversationId,
      revision: revision,
      providerKey: resolved.providerKey,
      modelId: resolved.modelId,
      assistantId: resolved.assistantId,
      computedAt: existing?.computedAt ?? DateTime.now(),
    );
    notifyListeners();

    try {
      final assemble = _assemble;
      final preview = assemble == null
          ? const ContextAssemblyPreview(
              systemText: '',
              injectionsText: '',
              historyText: '',
              tools: [],
              images: [],
            )
          : await assemble(
              conversationId: conversationId,
              providerKey: resolved.providerKey,
              modelId: resolved.modelId,
              assistantId: resolved.assistantId,
            );
      if (_inFlight[conversationId] != generation) return;
      final job = ContextEstimateJob(
        systemText: preview.systemText,
        injectionsText: preview.injectionsText,
        historyText: preview.historyText,
        draftText: draftText,
        tools: preview.tools,
        images: preview.images,
        kind: resolved.kind,
      );
      final estimated = await _runEstimate(() => estimateContextBuckets(job));
      if (_inFlight[conversationId] != generation) return;
      if (_chatService.contextRevision(conversationId) != revision) return;
      final buckets = ContextUsageBuckets(
        system: estimated.system,
        injections: estimated.injections,
        history: estimated.history,
        tools: estimated.tools,
        attachments: estimated.attachments,
        draft: estimated.draft,
      );
      _snapshots[conversationId] = ContextUsageSnapshot(
        state: ContextUsageState.estimated,
        buckets: buckets,
        usedTokens: buckets.total,
        contextWindow: resolved.contextWindow,
        conversationId: conversationId,
        revision: revision,
        providerKey: resolved.providerKey,
        modelId: resolved.modelId,
        assistantId: resolved.assistantId,
        computedAt: DateTime.now(),
      );
      notifyListeners();
    } catch (_) {
      if (_inFlight[conversationId] != generation) return;
      final fallback = _snapshots[conversationId];
      if (fallback != null && fallback.state == ContextUsageState.computing) {
        _snapshots[conversationId] = fallback.copyWith(
          state: ContextUsageState.stale,
        );
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsOrAssistantChanged);
    _assistants.removeListener(_onSettingsOrAssistantChanged);
    _unlistenRevision();
    for (final timer in _debounce.values) {
      timer.cancel();
    }
    _debounce.clear();
    super.dispose();
  }

  void _foldDraft(
    String conversationId,
    ContextUsageSnapshot existing,
    String draftText,
  ) {
    final draftTokens = estimateTokens(draftText);
    if (existing.buckets.draft == draftTokens) return;
    final usedWithoutDraft = existing.usedTokens - existing.buckets.draft;
    _snapshots[conversationId] = existing.copyWith(
      buckets: existing.buckets.copyWith(draft: draftTokens),
      usedTokens: usedWithoutDraft + draftTokens,
    );
    notifyListeners();
  }

  bool _isFresh(
    ContextUsageSnapshot snapshot,
    String conversationId,
    _ResolvedIdentity resolved,
  ) {
    if (snapshot.state != ContextUsageState.exact &&
        snapshot.state != ContextUsageState.estimated) {
      return false;
    }
    return snapshot.revision == _chatService.contextRevision(conversationId) &&
        snapshot.providerKey == resolved.providerKey &&
        snapshot.modelId == resolved.modelId &&
        snapshot.assistantId == resolved.assistantId;
  }

  void _listenRevision(String conversationId) {
    final listenable = _chatService.contextRevisionListenable(conversationId);
    void listener() => _onActiveRevisionChanged(conversationId);
    listenable.addListener(listener);
    _revisionListenable = listenable;
    _revisionListener = listener;
  }

  void _unlistenRevision() {
    final listenable = _revisionListenable;
    final listener = _revisionListener;
    if (listenable != null && listener != null) {
      listenable.removeListener(listener);
    }
    _revisionListenable = null;
    _revisionListener = null;
  }

  void _onActiveRevisionChanged(String conversationId) {
    if (_activeConversationId != conversationId) return;
    final snap = _snapshots[conversationId];
    final revision = _chatService.contextRevision(conversationId);
    if (snap != null &&
        snap.revision != revision &&
        snap.state != ContextUsageState.none) {
      _snapshots[conversationId] = snap.copyWith(
        state: ContextUsageState.stale,
      );
      notifyListeners();
    }
    _scheduleRefresh(conversationId);
  }

  void _onSettingsOrAssistantChanged() {
    final id = _activeConversationId;
    if (id == null) return;
    _syncResolvedIdentity();
  }

  void _syncResolvedIdentity() {
    final id = _activeConversationId;
    if (id == null) return;
    final resolved = _resolvedIdentity(id);
    final snap = _snapshots[id];
    if (resolved == null || snap == null) return;
    if (snap.providerKey == resolved.providerKey &&
        snap.modelId == resolved.modelId &&
        snap.assistantId == resolved.assistantId) {
      return;
    }
    _snapshots[id] = snap.copyWith(state: ContextUsageState.stale);
    notifyListeners();
    _scheduleRefresh(id);
  }

  void _scheduleRefresh(String conversationId) {
    if (_activeConversationId != conversationId) return;
    _debounce[conversationId]?.cancel();
    _debounce[conversationId] = Timer(_staleRefreshDelay, () {
      _debounce.remove(conversationId);
      if (_activeConversationId != conversationId) return;
      unawaited(refresh(conversationId));
    });
  }

  _ResolvedIdentity? _resolvedIdentity(String conversationId) {
    final conversation = _chatService.getConversation(conversationId);
    if (conversation == null) return null;
    final assistantId = conversation.assistantId;
    final assistant = assistantId == null
        ? _assistants.currentAssistant
        : _assistants.getById(assistantId);
    final model = resolveChatModel(
      _settings,
      conversation: conversation,
      assistant: assistant,
    );
    final providerKey = model.providerKey;
    final modelId = model.modelId;
    if (providerKey == null || modelId == null) return null;
    final cfg = _settings.getProviderConfig(providerKey);
    final spec = ModelSpecResolver.instance.spec(cfg, modelId);
    return _ResolvedIdentity(
      providerKey: providerKey,
      modelId: modelId,
      assistantId: assistant?.id ?? assistantId,
      kind: ProviderConfig.classify(
        providerKey,
        explicitType: cfg.providerType,
      ),
      contextWindow: spec.contextWindow,
    );
  }
}

class _ResolvedIdentity {
  const _ResolvedIdentity({
    required this.providerKey,
    required this.modelId,
    required this.assistantId,
    required this.kind,
    required this.contextWindow,
  });

  final String providerKey;
  final String modelId;
  final String? assistantId;
  final ProviderKind kind;
  final int? contextWindow;
}

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../../core/models/assistant.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/conversation.dart';
import '../../../core/models/conversation_prompt_settings.dart';
import '../../../core/models/model_spec.dart';
import '../../../core/models/token_usage.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/instruction_injection_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/world_book_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/model_catalog/model_catalog_service.dart';
import '../../../core/services/model_spec/model_spec_resolver.dart';
import '../../../core/utils/token_estimator.dart';
import '../utils/model_display_helper.dart';
import 'context_assembly.dart';

enum ContextUsageState { none, computing, exact, estimated, stale }

/// Capture before assembling a request. Only matching request-time settings
/// can anchor the current context to that response's usage.
Object contextUsageConfiguration({
  required SettingsProvider settings,
  required ProviderConfig config,
  required String providerKey,
  required String modelId,
  required Assistant? assistant,
  required InstructionInjectionProvider? instructions,
  required WorldBookProvider? worldBooks,
  Conversation? conversation,
  String? assistantId,
}) => (
  providerKey,
  modelId,
  assistant?.id ?? assistantId,
  ProviderConfig.classify(providerKey, explicitType: config.providerType),
  ModelSpecResolver.instance.spec(config, modelId),
  jsonEncode(assistant?.toJson()),
  settings.legacyMemoryMode,
  settings.resolvedMemoryPromptLang,
  settings.memoryRulesPromptEn,
  settings.memoryRulesPromptZh,
  settings.legacyMemoryPromptEn,
  settings.legacyMemoryPromptZh,
  instructions?.promptFor(
        assistant?.id ?? assistantId,
        instructionIds: assistant?.allowConversationPromptInjection == true
            ? ConversationPromptSettings.fromExtras(
                conversation?.extras ?? const {},
              ).instructionIds
            : null,
      ) ??
      '',
  jsonEncode(
    worldBooks
            ?.activeBooksFor(
              assistant?.id ?? assistantId,
              bookIds: assistant?.allowConversationPromptInjection == true
                  ? ConversationPromptSettings.fromExtras(
                      conversation?.extras ?? const {},
                    ).worldBookIds
                  : null,
            )
            .map((book) => book.toJson())
            .toList() ??
        const [],
  ),
);

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

  int get nonDraftTotal => system + injections + history + tools + attachments;

  int get total => nonDraftTotal + draft;

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

/// Scales non-draft buckets so they sum to [anchorTotal], keeping proportions.
/// Returns null when there is nothing to scale (single "used" presentation).
ContextUsageBuckets? calibrateContextUsageBuckets({
  required ContextUsageBuckets estimated,
  required int anchorTotal,
}) {
  final values = <int>[
    estimated.system,
    estimated.injections,
    estimated.history,
    estimated.tools,
    estimated.attachments,
  ];
  final estimatedNonDraft = values.fold<int>(0, (sum, value) => sum + value);
  if (estimatedNonDraft <= 0) return null;
  final scaled = [
    for (final value in values)
      (value * anchorTotal / estimatedNonDraft).round(),
  ];
  var residual = anchorTotal - scaled.fold<int>(0, (sum, value) => sum + value);
  if (residual != 0) {
    var largest = 0;
    for (var i = 1; i < scaled.length; i++) {
      if (scaled[i] > scaled[largest]) largest = i;
    }
    scaled[largest] += residual;
  }
  return ContextUsageBuckets(
    system: scaled[0],
    injections: scaled[1],
    history: scaled[2],
    tools: scaled[3],
    attachments: scaled[4],
    draft: estimated.draft,
  );
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
    this.calibrated = false,
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
  final bool calibrated;

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
    bool? calibrated,
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
      calibrated: calibrated ?? this.calibrated,
    );
  }
}

class ContextUsageService extends ChangeNotifier {
  ContextUsageService({
    required this._chatService,
    required this._settings,
    required this._assistants,
    required this._instructions,
    required this._worldBooks,
    this._assemble,
    this._staleRefreshDelay = const Duration(milliseconds: 800),
    Future<T> Function<T>(T Function() computation)? runEstimate,
  }) : _runEstimate = runEstimate ?? Isolate.run {
    _settings.addListener(_onSettingsOrAssistantChanged);
    _assistants.addListener(_onSettingsOrAssistantChanged);
    _instructions.addListener(_onSettingsOrAssistantChanged);
    _worldBooks.addListener(_onSettingsOrAssistantChanged);
    ModelCatalogService.instance.addListener(_onSettingsOrAssistantChanged);
  }

  final ChatService _chatService;
  final SettingsProvider _settings;
  final AssistantProvider _assistants;
  final InstructionInjectionProvider _instructions;
  final WorldBookProvider _worldBooks;
  ContextAssemblyPreviewFn? _assemble;
  final Duration _staleRefreshDelay;
  final Future<T> Function<T>(T Function() computation) _runEstimate;

  final Map<String, ContextUsageSnapshot> _snapshots =
      <String, ContextUsageSnapshot>{};
  final Map<String, int> _inFlight = <String, int>{};
  final Map<String, Timer> _debounce = <String, Timer>{};
  final Map<String, _ExactAnchor> _anchors = <String, _ExactAnchor>{};
  final Map<String, Object?> _snapshotConfigurations = <String, Object?>{};

  String? _activeConversationId;
  VoidCallback? _revisionListener;
  ValueListenable<int>? _revisionListenable;
  bool _disposed = false;

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
        _clearExactAnchor(conversationId);
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
    Object? requestConfiguration,
    int? requestRevision,
  }) {
    if (usage.promptTokens <= 0) return;
    final revision = _chatService.contextRevision(conversationId);
    final resolved = _resolvedIdentity(conversationId);
    if (requestRevision != revision ||
        requestConfiguration == null ||
        resolved == null ||
        resolved.providerKey != providerKey ||
        resolved.modelId != modelId ||
        resolved.configuration != requestConfiguration) {
      _clearExactAnchor(conversationId);
      unawaited(refresh(conversationId, force: true));
      return;
    }
    final spec = resolved.spec;
    final used = contextTokensAfterTurn(
      usage: usage,
      assistantMessage: assistantMessage,
      replay: spec.reasoning.replay,
      toolEvents: _chatService.getToolEvents(assistantMessage.id),
    );
    final window = spec.contextWindow;
    final previous = _snapshots[conversationId];
    final draft = previous?.buckets.draft ?? 0;
    final computedAt = DateTime.now();
    final storedAssistantId = resolved.assistantId;
    final configuration = requestConfiguration;
    _snapshotConfigurations[conversationId] = configuration;
    _anchors[conversationId] = _ExactAnchor(
      total: used,
      revision: revision,
      computedAt: computedAt,
      providerKey: providerKey,
      modelId: modelId,
      assistantId: storedAssistantId,
      configuration: configuration,
    );
    _snapshots[conversationId] = ContextUsageSnapshot(
      state: ContextUsageState.exact,
      buckets: (previous?.buckets ?? const ContextUsageBuckets()).copyWith(
        draft: draft,
      ),
      usedTokens: used + draft,
      contextWindow: window,
      conversationId: conversationId,
      revision: revision,
      providerKey: providerKey,
      modelId: modelId,
      assistantId: storedAssistantId,
      computedAt: computedAt,
    );
    notifyListeners();
    unawaited(refresh(conversationId, force: true));
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
    final keepExact = _anchorMatches(conversationId, revision, resolved);
    _snapshotConfigurations[conversationId] = resolved.configuration;
    if (!keepExact) {
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
    }

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
      if (_disposed || _inFlight[conversationId] != generation) return;
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
      if (_disposed || _inFlight[conversationId] != generation) return;
      if (_chatService.contextRevision(conversationId) != revision) return;
      if (_resolvedIdentity(conversationId)?.configuration !=
          resolved.configuration) {
        return;
      }
      final buckets = ContextUsageBuckets(
        system: estimated.system,
        injections: estimated.injections,
        history: estimated.history,
        tools: estimated.tools,
        attachments: estimated.attachments,
        draft: estimated.draft,
      );
      _snapshots[conversationId] = _snapshotFromEstimate(
        conversationId: conversationId,
        revision: revision,
        resolved: resolved,
        buckets: buckets,
      );
      notifyListeners();
    } catch (_) {
      if (_disposed || _inFlight[conversationId] != generation) return;
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
    _disposed = true;
    _settings.removeListener(_onSettingsOrAssistantChanged);
    _assistants.removeListener(_onSettingsOrAssistantChanged);
    _instructions.removeListener(_onSettingsOrAssistantChanged);
    _worldBooks.removeListener(_onSettingsOrAssistantChanged);
    ModelCatalogService.instance.removeListener(_onSettingsOrAssistantChanged);
    _unlistenRevision();
    for (final timer in _debounce.values) {
      timer.cancel();
    }
    _debounce.clear();
    super.dispose();
  }

  ContextUsageSnapshot _snapshotFromEstimate({
    required String conversationId,
    required int revision,
    required _ResolvedIdentity resolved,
    required ContextUsageBuckets buckets,
  }) {
    final anchor = _anchors[conversationId];
    if (anchor != null && _anchorMatches(conversationId, revision, resolved)) {
      final calibrated = calibrateContextUsageBuckets(
        estimated: buckets,
        anchorTotal: anchor.total,
      );
      if (calibrated != null) {
        return ContextUsageSnapshot(
          state: ContextUsageState.exact,
          buckets: calibrated,
          usedTokens: anchor.total + calibrated.draft,
          contextWindow: resolved.contextWindow,
          conversationId: conversationId,
          revision: revision,
          providerKey: resolved.providerKey,
          modelId: resolved.modelId,
          assistantId: resolved.assistantId,
          computedAt: anchor.computedAt,
          calibrated: true,
        );
      }
      return ContextUsageSnapshot(
        state: ContextUsageState.exact,
        buckets: ContextUsageBuckets(draft: buckets.draft),
        usedTokens: anchor.total + buckets.draft,
        contextWindow: resolved.contextWindow,
        conversationId: conversationId,
        revision: revision,
        providerKey: resolved.providerKey,
        modelId: resolved.modelId,
        assistantId: resolved.assistantId,
        computedAt: anchor.computedAt,
      );
    }
    _clearExactAnchor(conversationId);
    return ContextUsageSnapshot(
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
  }

  bool _anchorMatches(
    String conversationId,
    int revision,
    _ResolvedIdentity resolved,
  ) {
    final anchor = _anchors[conversationId];
    return anchor != null &&
        anchor.revision == revision &&
        anchor.providerKey == resolved.providerKey &&
        anchor.modelId == resolved.modelId &&
        anchor.assistantId == resolved.assistantId &&
        anchor.configuration == resolved.configuration;
  }

  void _clearExactAnchor(String conversationId) {
    _anchors.remove(conversationId);
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
        snapshot.assistantId == resolved.assistantId &&
        _snapshotConfigurations[conversationId] == resolved.configuration;
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
      _clearExactAnchor(conversationId);
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
        snap.assistantId == resolved.assistantId &&
        _snapshotConfigurations[id] == resolved.configuration) {
      return;
    }
    _clearExactAnchor(id);
    _inFlight[id] = (_inFlight[id] ?? 0) + 1;
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
      spec: spec,
      configuration: contextUsageConfiguration(
        settings: _settings,
        config: cfg,
        providerKey: providerKey,
        modelId: modelId,
        assistant: assistant,
        assistantId: assistantId,
        instructions: _instructions,
        worldBooks: _worldBooks,
        conversation: conversation,
      ),
    );
  }
}

class _ExactAnchor {
  const _ExactAnchor({
    required this.total,
    required this.revision,
    required this.computedAt,
    required this.providerKey,
    required this.modelId,
    required this.assistantId,
    required this.configuration,
  });

  final int total;
  final int revision;
  final DateTime computedAt;
  final String providerKey;
  final String modelId;
  final String? assistantId;
  final Object? configuration;
}

class _ResolvedIdentity {
  const _ResolvedIdentity({
    required this.providerKey,
    required this.modelId,
    required this.assistantId,
    required this.kind,
    required this.spec,
    required this.configuration,
  });

  final String providerKey;
  final String modelId;
  final String? assistantId;
  final ProviderKind kind;
  final ModelSpec spec;
  final Object configuration;

  int? get contextWindow => spec.contextWindow;
}

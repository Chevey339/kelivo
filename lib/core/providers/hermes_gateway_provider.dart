import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../hermes/hermes_stream_adapter.dart';
import '../../hermes/hermes_auth.dart';
import '../../hermes/hermes_config.dart';
import '../../hermes/hermes_event_bus.dart';
import '../../hermes/hermes_gateway.dart';
import '../../hermes/hermes_models.dart';
import '../../hermes/hermes_rest_client.dart';
import '../../hermes/hermes_rpc.dart';
import '../../hermes/hermes_usage.dart';
import '../../hermes/hermes_terminal_adapter.dart';

/// A pending handoff request awaiting user confirmation.
class HandoffPendingRequest {
  final String sessionId;
  final String fromAgentId;
  final String fromAgentName;
  final String suggestedAgentId;
  final String suggestedAgentName;
  final DateTime createdAt;

  HandoffPendingRequest({
    required this.sessionId,
    required this.fromAgentId,
    required this.fromAgentName,
    required this.suggestedAgentId,
    required this.suggestedAgentName,
  }) : createdAt = DateTime.now();
}

/// Immutable handoff state for the active session.
class HermesHandoffState {
  final HermesHandoffStatus status;
  final String? fromAgentId;
  final String? fromAgentName;
  final String? toAgentId;
  final String? toAgentName;
  final String? reason;

  const HermesHandoffState({
    this.status = HermesHandoffStatus.idle,
    this.fromAgentId,
    this.fromAgentName,
    this.toAgentId,
    this.toAgentName,
    this.reason,
  });

  HermesHandoffState copyWith({
    HermesHandoffStatus? status,
    String? fromAgentId,
    String? fromAgentName,
    String? toAgentId,
    String? toAgentName,
    String? reason,
  }) {
    return HermesHandoffState(
      status: status ?? this.status,
      fromAgentId: fromAgentId ?? this.fromAgentId,
      fromAgentName: fromAgentName ?? this.fromAgentName,
      toAgentId: toAgentId ?? this.toAgentId,
      toAgentName: toAgentName ?? this.toAgentName,
      reason: reason ?? this.reason,
    );
  }
}

enum HermesHandoffStatus {
  /// No handoff in progress.
  idle,

  /// Handoff requested — waiting for completion.
  inProgress,

  /// Handoff completed — agent switched.
  completed,

  /// Handoff failed or cancelled.
  failed,
}

/// Pending interactive request (approval, clarify, sudo, secret).
class HermesPendingRequest {
  final String sessionId;
  final HermesStreamEvent event;
  final DateTime createdAt = DateTime.now();
  HermesPendingRequest({required this.sessionId, required this.event});
}

/// Top-level provider that owns the [HermesGateway] singleton.
///
/// Wraps [HermesGateway] as a Flutter [ChangeNotifier] so the UI can
/// react to connection state changes without importing Hermes internals.
class HermesGatewayProvider extends ChangeNotifier {
  late final HermesConfig _config;
  late final HermesEventBus _eventBus;
  late final HermesGateway _gateway;

  HermesConnectionState _state = HermesConnectionState.initializing;
  HermesBackendBox? _currentBackend;
  String? _lastError;

  /// Active Hermes session ID (null when not connected).
  String? _activeSessionId;

  /// Pending interactive requests (approval, clarify, sudo, secret).
  final List<HermesPendingRequest> _pendingRequests = [];

  /// Stream adapter for Hermes chat events (managed by HermesChatProviderX).
  HermesStreamAdapter? _hermesStreamAdapter;

  /// Gets the current stream adapter.
  HermesStreamAdapter? get streamAdapter => _hermesStreamAdapter;

  /// Sets the stream adapter. Disposes the previous one if any.
  set streamAdapter(HermesStreamAdapter? adapter) {
    if (adapter != _hermesStreamAdapter) {
      _hermesStreamAdapter?.dispose();
      _hermesStreamAdapter = adapter;
      notifyListeners();
    }
  }

  /// Stream subscription for forwarding interactive events to the UI.
  StreamSubscription<HermesStreamEvent>? _eventSubscription;

  HermesGatewayProvider() {
    _config = HermesConfig();
    _eventBus = HermesEventBus();
    _gateway = HermesGateway(eventBus: _eventBus, config: _config);
    _listenToEvents();
  }

  void _listenToEvents() {
    _eventSubscription = _eventBus.allEvents.listen(_onEvent);
  }

  void _onEvent(HermesStreamEvent event) {
    if (event is ApprovalRequest) {
      _pendingRequests.add(
        HermesPendingRequest(sessionId: event.sessionId, event: event),
      );
      notifyListeners();
    } else if (event is ClarifyRequest) {
      _pendingRequests.add(
        HermesPendingRequest(sessionId: event.sessionId, event: event),
      );
      notifyListeners();
    } else if (event is SudoRequest) {
      _pendingRequests.add(
        HermesPendingRequest(sessionId: event.sessionId, event: event),
      );
      notifyListeners();
    } else if (event is SecretRequest) {
      _pendingRequests.add(
        HermesPendingRequest(sessionId: event.sessionId, event: event),
      );
      notifyListeners();
    } else if (event is HandoffRequested) {
      _pendingHandoff = HandoffPendingRequest(
        sessionId: event.sessionId,
        fromAgentId: event.fromAgentId,
        fromAgentName: event.fromAgentName,
        suggestedAgentId: event.toAgentId,
        suggestedAgentName: event.toAgentName,
      );
      _handoffState = HermesHandoffState(
        status: HermesHandoffStatus.inProgress,
        fromAgentId: event.fromAgentId,
        fromAgentName: event.fromAgentName,
        toAgentId: event.toAgentId,
        toAgentName: event.toAgentName,
      );
      notifyListeners();
      // Load agent list in background for the handoff sheet
      loadAgents();
    } else if (event is HandoffCompleted) {
      _pendingHandoff = null;
      _handoffState = HermesHandoffState(
        status: HermesHandoffStatus.completed,
        fromAgentId: _handoffState.fromAgentId,
        fromAgentName: _handoffState.fromAgentName,
        toAgentId: event.agentId,
        toAgentName: event.agentName,
      );
      notifyListeners();
      // Reset to idle after a short delay so the UI can show "completed" briefly
      Future<void>.delayed(const Duration(seconds: 3), () {
        _handoffState = const HermesHandoffState();
        notifyListeners();
      });
    } else if (event is HandoffFailed) {
      _pendingHandoff = null;
      _handoffState = HermesHandoffState(
        status: HermesHandoffStatus.failed,
        reason: event.reason,
      );
      notifyListeners();
      // Reset to idle after a delay
      Future<void>.delayed(const Duration(seconds: 5), () {
        _handoffState = const HermesHandoffState();
        notifyListeners();
      });
    }
  }

  HermesConnectionState get state => _state;
  HermesBackendBox? get currentBackend => _currentBackend;
  HermesEventBus get eventBus => _eventBus;
  HermesGateway get gateway => _gateway;
  HermesConfig get config => _config;
  HermesRestClient? get restClient => _gateway.restClient;
  String? get lastError => _lastError;

  /// Initialize Hive config and load persisted backends.
  Future<void> init() async {
    await _config.init();
    // Auto-connect to last active backend if any
    final active = _config.activeBackend;
    if (active != null) {
      await connectBackend(active.id);
    }
  }

  /// Connect to a backend by its id.
  Future<void> connectBackend(String id) async {
    final backend = _config.box.get(id);
    if (backend == null) {
      _lastError = 'Backend not found: $id';
      _state = HermesConnectionState.error;
      notifyListeners();
      return;
    }

    _currentBackend = backend;
    _lastError = null;
    _state = HermesConnectionState.connecting;
    notifyListeners();

    try {
      await _gateway.connect(backend);
      await _config.markConnected(backend.id);
      _currentBackend = backend;
      _state = HermesConnectionState.ready;
    } on HermesAuthException catch (e) {
      _lastError = e.message;
      _state = HermesConnectionState.error;
      await _config.markError(backend.id, e.message);
    } catch (e) {
      _lastError = e.toString();
      _state = HermesConnectionState.error;
      await _config.markError(backend.id, e.toString());
    }

    notifyListeners();
  }

  /// Disconnect from the current backend.
  Future<void> disconnect() async {
    await _gateway.disconnect();
    _state = HermesConnectionState.disconnected;
    _currentBackend = null;
    notifyListeners();
  }

  /// Add a new backend and optionally connect to it.
  Future<void> addBackend({
    required String name,
    required String url,
    String? token,
    String? profile,
    String authMode = 'auto',
    bool connectImmediately = false,
  }) async {
    final backend = HermesBackendBox(
      id: const Uuid().v4(),
      name: name,
      url: url,
      authMode: authMode,
      token: token,
      profile: profile,
      addedAt: DateTime.now(),
    );
    await _config.addBackend(backend);

    if (connectImmediately) {
      await connectBackend(backend.id);
    } else {
      notifyListeners();
    }
  }

  /// Remove a backend by id.
  Future<void> removeBackend(String id) async {
    if (_currentBackend?.id == id) {
      await disconnect();
    }
    await _config.removeBackend(id);
    notifyListeners();
  }

  /// Send a JSON-RPC call through the gateway.
  Future<dynamic> sendRpc(String method, [Map<String, dynamic>? params]) {
    return _gateway.sendRpc(method, params);
  }

  // ── Session Management ───────────────────────────────────────────────

  /// The currently active Hermes session ID.
  String? get activeSessionId => _activeSessionId;

  /// Set the active session ID (called after session.create / session.resume).
  void setActiveSessionId(String? id) {
    _activeSessionId = id;
    notifyListeners();
  }

  /// Create a new Hermes session and set it as active.
  Future<String> createSession({String? cwd}) async {
    final id = await _gateway.sessionCreate(cwd: cwd);
    _activeSessionId = id;
    notifyListeners();
    return id;
  }

  /// Resume an existing Hermes session and set it as active.
  Future<String> resumeSession(String id) async {
    final sessionId = await _gateway.sessionResume(id);
    _activeSessionId = sessionId;
    notifyListeners();
    return sessionId;
  }

  /// Resume the most recent session and set it as active.
  Future<String> resumeMostRecentSession() async {
    final id = await _gateway.sessionMostRecent();
    _activeSessionId = id;
    notifyListeners();
    return id;
  }

  /// Interrupt the active generation.
  Future<void> interrupt() async {
    if (_activeSessionId != null) {
      await _gateway.sessionInterrupt(_activeSessionId!);
    }
  }

  /// Branch (fork) the current session at the current point.
  Future<String> branchSession({String? label}) async {
    if (_activeSessionId == null) throw StateError('No active session');
    return _gateway.sessionBranch(_activeSessionId!, label: label);
  }

  /// Undo the last turn(s) in the session.
  Future<void> undoSession({int? count}) async {
    if (_activeSessionId == null) return;
    await _gateway.sessionUndo(_activeSessionId!, count: count);
  }

  /// Compress / summarize conversation history.
  Future<void> compressSession() async {
    if (_activeSessionId == null) return;
    await _gateway.sessionCompress(_activeSessionId!);
  }

  /// Interrupt the active generation in the current session.
  Future<void> interruptSession() async {
    if (_activeSessionId == null) return;
    await _gateway.sessionInterrupt(_activeSessionId!);
  }

  /// Close the active session.
  Future<void> closeSession() async {
    if (_activeSessionId != null) {
      await _gateway.sessionClose(_activeSessionId!);
      _activeSessionId = null;
      notifyListeners();
    }
  }

  // ── Pending Interactive Requests ────────────────────────────────────

  /// All currently pending interactive requests.
  List<HermesPendingRequest> get pendingRequests =>
      List.unmodifiable(_pendingRequests);

  /// Pop and consume a pending request for a session.
  HermesPendingRequest? takePendingRequest(String sessionId) {
    final idx = _pendingRequests.indexWhere((r) => r.sessionId == sessionId);
    if (idx < 0) return null;
    final req = _pendingRequests.removeAt(idx);
    notifyListeners();
    return req;
  }

  /// Clear all pending requests.
  void clearPendingRequests() {
    _pendingRequests.clear();
    notifyListeners();
  }

  // ── Session List ───────────────────────────────────────────────────

  /// All known Hermes sessions (loaded from backend).
  List<HermesSessionSummary> _sessions = [];
  List<HermesSessionSummary> get sessions => List.unmodifiable(_sessions);

  /// Whether a session list load is in progress.
  bool _loadingSessions = false;
  bool get loadingSessions => _loadingSessions;

  /// Last session list load error, if any.
  String? _sessionsError;
  String? get sessionsError => _sessionsError;

  /// Load the session list from the backend.
  Future<void> loadSessions({int? limit, int? offset}) async {
    if (_state != HermesConnectionState.ready) return;
    _loadingSessions = true;
    _sessionsError = null;
    notifyListeners();

    try {
      _sessions = await _gateway.sessionList(limit: limit, offset: offset);
      _sessionsError = null;
    } catch (e) {
      _sessionsError = e.toString();
    } finally {
      _loadingSessions = false;
      notifyListeners();
    }
  }

  /// Search sessions by query.
  Future<List<HermesSessionSummary>> searchSessions(
    String query, {
    int? limit,
  }) async {
    if (_state != HermesConnectionState.ready) return [];
    try {
      return await _gateway.sessionSearch(query, limit: limit);
    } catch (_) {
      return [];
    }
  }

  /// Delete a session from the backend.
  Future<void> deleteSession(String sessionId) async {
    if (_state != HermesConnectionState.ready) return;
    await _gateway.sessionDelete(sessionId);
    _sessions.removeWhere((s) => s.sessionId == sessionId);
    if (_activeSessionId == sessionId) {
      _activeSessionId = null;
    }
    notifyListeners();
  }

  /// Rename a session.
  Future<void> renameSession(String sessionId, String title) async {
    if (_state != HermesConnectionState.ready) return;
    await _gateway.sessionTitle(sessionId, title);
    final idx = _sessions.indexWhere((s) => s.sessionId == sessionId);
    if (idx >= 0) {
      // Replace with updated entry (title changed)
      _sessions[idx] = HermesSessionSummary(
        sessionId: _sessions[idx].sessionId,
        title: title,
        createdAt: _sessions[idx].createdAt,
        lastActiveAt: _sessions[idx].lastActiveAt,
        messageCount: _sessions[idx].messageCount,
        agentId: _sessions[idx].agentId,
        agentName: _sessions[idx].agentName,
      );
      notifyListeners();
    }
  }

  // ── Session Usage ─────────────────────────────────────────────────

  /// Fetch token usage and credits for a session.
  Future<HermesUsage?> fetchSessionUsage(String sessionId) async {
    if (_state != HermesConnectionState.ready) return null;
    try {
      final raw = await _gateway.sessionUsage(sessionId);
      return HermesUsage.fromJson(raw);
    } catch (_) {}
    return null;
  }

  // ── Session Bulk Operations ────────────────────────────────────────

  /// Export a session as markdown text.
  Future<String> exportSession(
    String sessionId, {
    String format = 'markdown',
  }) async {
    if (_state != HermesConnectionState.ready) return '';
    try {
      return await _gateway.sessionExport(sessionId, format: format);
    } catch (_) {
      return '';
    }
  }

  /// Prune (delete) all empty sessions.
  Future<int> pruneEmptySessions() async {
    if (_state != HermesConnectionState.ready) return 0;
    final count = await _gateway.sessionPrune();
    if (count > 0) {
      await loadSessions();
    }
    return count;
  }

  /// Empty (clear messages from) a session.
  Future<void> emptySession(String sessionId) async {
    if (_state != HermesConnectionState.ready) return;
    await _gateway.sessionEmpty(sessionId);
    notifyListeners();
  }

  /// Bulk-delete sessions.
  Future<int> bulkDeleteSessions(List<String> sessionIds) async {
    if (_state != HermesConnectionState.ready) return 0;
    final count = await _gateway.sessionBulkDelete(sessionIds);
    if (count > 0) {
      _sessions.removeWhere((s) => sessionIds.contains(s.sessionId));
      if (_activeSessionId != null && sessionIds.contains(_activeSessionId)) {
        _activeSessionId = null;
      }
      notifyListeners();
    }
    return count;
  }

  /// Activate a session (bring to front of active list).
  Future<void> activateSession(String sessionId) async {
    if (_state != HermesConnectionState.ready) return;
    await _gateway.sessionActivate(sessionId);
    _activeSessionId = sessionId;
    notifyListeners();
  }

  // ── Billing / Credits ─────────────────────────────────────────────

  /// Get current credits balance.
  Future<double> fetchCredits() async {
    if (_state != HermesConnectionState.ready) return 0.0;
    try {
      return await _gateway.billingCredits();
    } catch (_) {
      return 0.0;
    }
  }

  /// Get available billing packages.
  Future<List<Map<String, dynamic>>> fetchBillingPackages() async {
    if (_state != HermesConnectionState.ready) return [];
    try {
      final list = await _gateway.billingPackages();
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Trigger a credit purchase.
  Future<Map<String, dynamic>> purchaseCredits(String packageId) async {
    if (_state != HermesConnectionState.ready) return {};
    try {
      return await _gateway.billingCharge(packageId);
    } catch (_) {
      return {};
    }
  }

  /// Get charge status.
  Future<Map<String, dynamic>> fetchChargeStatus(String chargeId) async {
    if (_state != HermesConnectionState.ready) return {};
    try {
      return await _gateway.billingChargeStatus(chargeId);
    } catch (_) {
      return {};
    }
  }

  /// Update auto-reload setting.
  Future<void> setAutoReload({required bool enabled, double? threshold}) async {
    if (_state != HermesConnectionState.ready) return;
    await _gateway.billingAutoReload(enabled: enabled, threshold: threshold);
  }

  // ── Handoff State ─────────────────────────────────────────────────

  /// Current handoff state for the active session.
  HermesHandoffState _handoffState = const HermesHandoffState();
  HermesHandoffState get handoffState => _handoffState;

  /// Pending handoff request awaiting user confirmation.
  /// Cleared after confirm/cancel.
  HandoffPendingRequest? _pendingHandoff;
  HandoffPendingRequest? get pendingHandoff => _pendingHandoff;

  /// Confirm a handoff with the selected agent id.
  Future<void> confirmHandoff(String agentId, {String? reason}) async {
    if (_activeSessionId == null) return;
    await _gateway.handoffRespond(_activeSessionId!, agentId, reason: reason);
    _pendingHandoff = null;
    notifyListeners();
  }

  /// Cancel the pending handoff.
  Future<void> cancelHandoff({String? reason}) async {
    if (_activeSessionId == null) return;
    await _gateway.handoffCancel(_activeSessionId!, reason: reason);
    _pendingHandoff = null;
    _handoffState = const HermesHandoffState();
    notifyListeners();
  }

  // ── Agent Management ───────────────────────────────────────────────

  /// All known agents from the Hermes backend.
  List<HermesAgent> _agents = [];
  List<HermesAgent> get agents => List.unmodifiable(_agents);

  /// Whether agent list is loading.
  bool _loadingAgents = false;
  bool get loadingAgents => _loadingAgents;

  /// Load the agent list from the backend.
  Future<void> loadAgents() async {
    if (_state != HermesConnectionState.ready) return;
    _loadingAgents = true;
    notifyListeners();

    try {
      _agents = await _gateway.agentList();
    } catch (_) {
      _agents = [];
    } finally {
      _loadingAgents = false;
      notifyListeners();
    }
  }

  /// Get an agent by id.
  HermesAgent? getAgent(String id) {
    try {
      return _agents.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Terminal ──────────────────────────────────────────────────────

  /// Current terminal adapter (null when terminal is closed).
  HermesTerminalAdapter? _terminalAdapter;
  HermesTerminalAdapter? get terminalAdapter => _terminalAdapter;

  /// Whether the terminal sheet is currently visible.
  bool _terminalVisible = false;
  bool get terminalVisible => _terminalVisible;

  /// Open a terminal for the active session.
  /// Returns null if no active session.
  HermesTerminalAdapter? openTerminal() {
    if (_activeSessionId == null) return null;
    closeTerminal();

    _terminalAdapter = HermesTerminalAdapter(
      eventBus: _eventBus,
      sessionId: _activeSessionId!,
      gateway: _gateway,
    );
    _terminalVisible = true;
    notifyListeners();
    return _terminalAdapter;
  }

  /// Close the current terminal.
  void closeTerminal() {
    _terminalAdapter?.dispose();
    _terminalAdapter = null;
    _terminalVisible = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _hermesStreamAdapter?.dispose();
    _eventSubscription?.cancel();
    _gateway.dispose();
    super.dispose();
  }
}

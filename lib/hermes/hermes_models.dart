/// Hermes streaming events — mapped from `gateway/stream_events.py`
/// and `tui_gateway/server.py` `_emit()` calls.

/// Union of all Hermes stream events.
sealed class HermesStreamEvent {
  const HermesStreamEvent();
}

// ── Message events ───────────────────────────────────────────────

/// Assistant text fragment (delta).
class MessageDelta extends HermesStreamEvent {
  final String sessionId;
  final String text;

  const MessageDelta({required this.sessionId, required this.text});

  factory MessageDelta.fromJson(Map<String, dynamic> json) => MessageDelta(
    sessionId: json['session_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'text': text};

  MessageDelta copyWith({String? sessionId, String? text}) => MessageDelta(
    sessionId: sessionId ?? this.sessionId,
    text: text ?? this.text,
  );
}

/// Assistant message segment complete.
class MessageComplete extends HermesStreamEvent {
  final String sessionId;
  final String? text;

  /// Raw payload from Hermes (may contain usage, finish_reason, etc.).
  final Map<String, dynamic>? payload;

  const MessageComplete({required this.sessionId, this.text, this.payload});

  factory MessageComplete.fromJson(Map<String, dynamic> json) =>
      MessageComplete(
        sessionId: json['session_id'] as String? ?? '',
        text: json['text'] as String?,
        payload: (json['payload'] as Map<String, dynamic>?)
            ?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    if (text != null) 'text': text,
    if (payload != null) 'payload': payload,
  };
}

/// Assistant message start.
class MessageStart extends HermesStreamEvent {
  final String sessionId;

  const MessageStart({required this.sessionId});

  factory MessageStart.fromJson(Map<String, dynamic> json) =>
      MessageStart(sessionId: json['session_id'] as String? ?? '');

  Map<String, dynamic> toJson() => {'session_id': sessionId};
}

// ── Reasoning / Thinking events ──────────────────────────────────

/// Reasoning content fragment.
class ReasoningDelta extends HermesStreamEvent {
  final String sessionId;
  final String text;

  const ReasoningDelta({required this.sessionId, required this.text});

  factory ReasoningDelta.fromJson(Map<String, dynamic> json) => ReasoningDelta(
    sessionId: json['session_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'text': text};
}

/// Reasoning block available.
class ReasoningAvailable extends HermesStreamEvent {
  final String sessionId;

  const ReasoningAvailable({required this.sessionId});

  factory ReasoningAvailable.fromJson(Map<String, dynamic> json) =>
      ReasoningAvailable(sessionId: json['session_id'] as String? ?? '');

  Map<String, dynamic> toJson() => {'session_id': sessionId};
}

/// Thinking content fragment.
class ThinkingDelta extends HermesStreamEvent {
  final String sessionId;
  final String text;

  const ThinkingDelta({required this.sessionId, required this.text});

  factory ThinkingDelta.fromJson(Map<String, dynamic> json) => ThinkingDelta(
    sessionId: json['session_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'text': text};
}

// ── Tool events ─────────────────────────────────────────────────

/// Tool invocation started.
class ToolStart extends HermesStreamEvent {
  final String sessionId;
  final String name;
  final String? preview;
  final Map<String, dynamic>? args;
  final int index;

  const ToolStart({
    required this.sessionId,
    required this.name,
    this.preview,
    this.args,
    this.index = 0,
  });

  factory ToolStart.fromJson(Map<String, dynamic> json) => ToolStart(
    sessionId: json['session_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    preview: json['preview'] as String?,
    args: (json['args'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
    index: (json['index'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'name': name,
    if (preview != null) 'preview': preview,
    if (args != null) 'args': args,
    'index': index,
  };
}

/// Tool is generating / in progress (tool.use output in flight).
class ToolGenerating extends HermesStreamEvent {
  final String sessionId;
  final String name;

  const ToolGenerating({required this.sessionId, required this.name});

  factory ToolGenerating.fromJson(Map<String, dynamic> json) => ToolGenerating(
    sessionId: json['session_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'name': name};
}

/// Tool incremental output (streaming progress).
class ToolProgress extends HermesStreamEvent {
  final String sessionId;
  final String name;
  final String? content;

  const ToolProgress({
    required this.sessionId,
    required this.name,
    this.content,
  });

  factory ToolProgress.fromJson(Map<String, dynamic> json) => ToolProgress(
    sessionId: json['session_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    content: json['content'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'name': name,
    if (content != null) 'content': content,
  };
}

/// Tool invocation finished.
class ToolComplete extends HermesStreamEvent {
  final String sessionId;
  final String name;
  final double duration;
  final bool ok;
  final Map<String, dynamic>? openTool;
  final int index;

  const ToolComplete({
    required this.sessionId,
    required this.name,
    this.duration = 0.0,
    this.ok = true,
    this.openTool,
    this.index = 0,
  });

  factory ToolComplete.fromJson(Map<String, dynamic> json) => ToolComplete(
    sessionId: json['session_id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
    ok: json['ok'] as bool? ?? true,
    openTool: (json['open_tool'] as Map<String, dynamic>?)
        ?.cast<String, dynamic>(),
    index: (json['index'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'name': name,
    'duration': duration,
    'ok': ok,
    if (openTool != null) 'open_tool': openTool,
    'index': index,
  };
}

// ── Gateway control events ───────────────────────────────────────

/// Gateway is ready after connect.
class GatewayReady extends HermesStreamEvent {
  final String? skin;

  const GatewayReady({this.skin});

  factory GatewayReady.fromJson(Map<String, dynamic> json) =>
      GatewayReady(skin: json['skin']?.toString());

  Map<String, dynamic> toJson() => {'skin': skin};
}

/// Status update (idle, thinking, running, compacting, etc.).
class StatusUpdate extends HermesStreamEvent {
  final String sessionId;
  final String kind;
  final String? text;

  const StatusUpdate({required this.sessionId, required this.kind, this.text});

  factory StatusUpdate.fromJson(Map<String, dynamic> json) => StatusUpdate(
    sessionId: json['session_id'] as String? ?? '',
    kind: json['kind'] as String? ?? '',
    text: json['text'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'kind': kind,
    if (text != null) 'text': text,
  };
}

/// Approval request from the agent.
class ApprovalRequest extends HermesStreamEvent {
  final String sessionId;
  final Map<String, dynamic> payload;

  const ApprovalRequest({required this.sessionId, required this.payload});

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) =>
      ApprovalRequest(
        sessionId: json['session_id'] as String? ?? '',
        payload:
            (json['payload'] as Map<String, dynamic>?)
                ?.cast<String, dynamic>() ??
            {},
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'payload': payload,
  };
}

/// Session metadata update.
class SessionInfo extends HermesStreamEvent {
  final String sessionId;
  final Map<String, dynamic> info;

  const SessionInfo({required this.sessionId, required this.info});

  factory SessionInfo.fromJson(Map<String, dynamic> json) => SessionInfo(
    sessionId: json['session_id'] as String? ?? '',
    info:
        (json['info'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? {},
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'info': info};
}

/// Clarify request from the agent (needs user input to proceed).
class ClarifyRequest extends HermesStreamEvent {
  final String sessionId;
  final Map<String, dynamic> payload;

  const ClarifyRequest({required this.sessionId, required this.payload});

  factory ClarifyRequest.fromJson(Map<String, dynamic> json) => ClarifyRequest(
    sessionId: json['session_id'] as String? ?? '',
    payload:
        (json['payload'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
        {},
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'payload': payload,
  };
}

/// Sudo escalation request (needs user to grant elevated permissions).
class SudoRequest extends HermesStreamEvent {
  final String sessionId;
  final Map<String, dynamic> payload;

  const SudoRequest({required this.sessionId, required this.payload});

  factory SudoRequest.fromJson(Map<String, dynamic> json) => SudoRequest(
    sessionId: json['session_id'] as String? ?? '',
    payload:
        (json['payload'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
        {},
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'payload': payload,
  };
}

/// Secret reveal request (needs user to provide a secret/API key).
class SecretRequest extends HermesStreamEvent {
  final String sessionId;
  final Map<String, dynamic> payload;

  const SecretRequest({required this.sessionId, required this.payload});

  factory SecretRequest.fromJson(Map<String, dynamic> json) => SecretRequest(
    sessionId: json['session_id'] as String? ?? '',
    payload:
        (json['payload'] as Map<String, dynamic>?)?.cast<String, dynamic>() ??
        {},
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'payload': payload,
  };
}

/// Error from gateway or agent.
class HermesError extends HermesStreamEvent {
  final String sessionId;
  final String message;

  const HermesError({required this.sessionId, required this.message});

  factory HermesError.fromJson(Map<String, dynamic> json) => HermesError(
    sessionId: json['session_id'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'message': message,
  };
}

/// Skin/theme changed.
class SkinChanged extends HermesStreamEvent {
  final Map<String, dynamic> skin;

  const SkinChanged({required this.skin});

  factory SkinChanged.fromJson(Map<String, dynamic> json) => SkinChanged(
    skin:
        (json['skin'] as Map<String, dynamic>?)?.cast<String, dynamic>() ?? {},
  );

  Map<String, dynamic> toJson() => {'skin': skin};
}

/// Gateway notice (restart, online, long_run, etc.).
class GatewayNotice extends HermesStreamEvent {
  final String kind;
  final String? text;
  final Map<String, dynamic>? extra;

  const GatewayNotice({required this.kind, this.text, this.extra});

  factory GatewayNotice.fromJson(Map<String, dynamic> json) => GatewayNotice(
    kind: json['kind'] as String? ?? '',
    text: json['text'] as String?,
    extra: (json['extra'] as Map<String, dynamic>?)?.cast<String, dynamic>(),
  );

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (text != null) 'text': text,
    if (extra != null) 'extra': extra,
  };
}

// ── Preview / Restart events ──────────────────────────────────────

/// Preview restart progress.
class PreviewRestartProgress extends HermesStreamEvent {
  final String sessionId;
  final String taskId;
  final int level;
  final String? text;

  const PreviewRestartProgress({
    required this.sessionId,
    required this.taskId,
    this.level = 0,
    this.text,
  });

  factory PreviewRestartProgress.fromJson(Map<String, dynamic> json) =>
      PreviewRestartProgress(
        sessionId: json['session_id'] as String? ?? '',
        taskId: json['task_id'] as String? ?? '',
        level: (json['level'] as num?)?.toInt() ?? 0,
        text: json['text'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'task_id': taskId,
    'level': level,
    if (text != null) 'text': text,
  };
}

/// Preview restart complete.
class PreviewRestartComplete extends HermesStreamEvent {
  final String sessionId;
  final String taskId;
  final String? text;

  const PreviewRestartComplete({
    required this.sessionId,
    required this.taskId,
    this.text,
  });

  factory PreviewRestartComplete.fromJson(Map<String, dynamic> json) =>
      PreviewRestartComplete(
        sessionId: json['session_id'] as String? ?? '',
        taskId: json['task_id'] as String? ?? '',
        text: json['text'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'task_id': taskId,
    if (text != null) 'text': text,
  };
}

// ── Commentary ────────────────────────────────────────────────────

/// Interim assistant commentary between tool iterations.
class Commentary extends HermesStreamEvent {
  final String sessionId;
  final String text;

  const Commentary({required this.sessionId, required this.text});

  factory Commentary.fromJson(Map<String, dynamic> json) => Commentary(
    sessionId: json['session_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'text': text};
}

// ── Handoff events ─────────────────────────────────────────────────

/// Handoff request initiated (agent wants to transfer to another agent).
class HandoffRequested extends HermesStreamEvent {
  final String sessionId;
  final String fromAgentId;
  final String fromAgentName;
  final String toAgentId;
  final String toAgentName;

  const HandoffRequested({
    required this.sessionId,
    required this.fromAgentId,
    required this.fromAgentName,
    required this.toAgentId,
    required this.toAgentName,
  });

  factory HandoffRequested.fromJson(Map<String, dynamic> json) =>
      HandoffRequested(
        sessionId: json['session_id'] as String? ?? '',
        fromAgentId: json['from_agent_id'] as String? ?? '',
        fromAgentName: json['from_agent_name'] as String? ?? '',
        toAgentId: json['to_agent_id'] as String? ?? '',
        toAgentName: json['to_agent_name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'from_agent_id': fromAgentId,
    'from_agent_name': fromAgentName,
    'to_agent_id': toAgentId,
    'to_agent_name': toAgentName,
  };
}

/// Handoff completed — agent has switched.
class HandoffCompleted extends HermesStreamEvent {
  final String sessionId;
  final String agentId;
  final String agentName;

  const HandoffCompleted({
    required this.sessionId,
    required this.agentId,
    required this.agentName,
  });

  factory HandoffCompleted.fromJson(Map<String, dynamic> json) =>
      HandoffCompleted(
        sessionId: json['session_id'] as String? ?? '',
        agentId: json['agent_id'] as String? ?? '',
        agentName: json['agent_name'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'agent_id': agentId,
    'agent_name': agentName,
  };
}

/// Handoff failed or was cancelled.
class HandoffFailed extends HermesStreamEvent {
  final String sessionId;
  final String reason;

  const HandoffFailed({required this.sessionId, required this.reason});

  factory HandoffFailed.fromJson(Map<String, dynamic> json) => HandoffFailed(
    sessionId: json['session_id'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {'session_id': sessionId, 'reason': reason};
}

// ── Terminal events ────────────────────────────────────────────────

/// Terminal output (stdout / stderr from the backend process).
class TerminalOutput extends HermesStreamEvent {
  final String sessionId;
  final String text;
  final bool isError;

  const TerminalOutput({
    required this.sessionId,
    required this.text,
    this.isError = false,
  });

  factory TerminalOutput.fromJson(Map<String, dynamic> json) => TerminalOutput(
    sessionId: json['session_id'] as String? ?? '',
    text: json['text'] as String? ?? '',
    isError: json['is_error'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'text': text,
    'is_error': isError,
  };
}

/// Backend is waiting for terminal input (stdin).
class TerminalReadRequest extends HermesStreamEvent {
  final String sessionId;
  final String prompt;

  const TerminalReadRequest({
    required this.sessionId,
    this.prompt = '',
  });

  factory TerminalReadRequest.fromJson(Map<String, dynamic> json) =>
      TerminalReadRequest(
        sessionId: json['session_id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'prompt': prompt,
  };
}

/// Terminal session closed.
class TerminalClosed extends HermesStreamEvent {
  final String sessionId;
  final int? exitCode;

  const TerminalClosed({required this.sessionId, this.exitCode});

  factory TerminalClosed.fromJson(Map<String, dynamic> json) => TerminalClosed(
    sessionId: json['session_id'] as String? ?? '',
    exitCode: (json['exit_code'] as num?)?.toInt(),
  );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    if (exitCode != null) 'exit_code': exitCode,
  };
}

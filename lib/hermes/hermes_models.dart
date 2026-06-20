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

  const MessageComplete({required this.sessionId, this.text});

  factory MessageComplete.fromJson(Map<String, dynamic> json) =>
      MessageComplete(
        sessionId: json['session_id'] as String? ?? '',
        text: json['text'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    if (text != null) 'text': text,
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

/// Tool is generating / in progress.
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

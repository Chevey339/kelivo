/// Typed wrappers for Hermes JSON-RPC calls.
/// All methods forward to [HermesGateway.sendRpc].

import 'hermes_gateway.dart';

/// Session management.
extension HermesSessionRpc on HermesGateway {
  /// Create a new session.
  Future<String> sessionCreate({
    String? cwd,
    Map<String, dynamic>? extra,
  }) async {
    final result = await sendRpc('session.create', {
      if (cwd != null) 'cwd': cwd,
      if (extra != null) ...extra,
    });
    return (result as Map<String, dynamic>)['session_id'] as String? ?? '';
  }

  /// Resume an existing session.
  Future<String> sessionResume(String sessionId) async {
    final result = await sendRpc('session.resume', {'session_id': sessionId});
    return (result as Map<String, dynamic>)['session_id'] as String? ?? '';
  }

  /// Get the most recent session.
  Future<String> sessionMostRecent() async {
    final result = await sendRpc('session.most_recent');
    return (result as Map<String, dynamic>)['session_id'] as String? ?? '';
  }

  /// Close a session.
  Future<void> sessionClose(String sessionId) async {
    await sendRpc('session.close', {'session_id': sessionId});
  }

  /// Delete a session.
  Future<void> sessionDelete(String sessionId) async {
    await sendRpc('session.delete', {'session_id': sessionId});
  }

  /// Set session title.
  Future<void> sessionTitle(String sessionId, String title) async {
    await sendRpc('session.title', {'session_id': sessionId, 'title': title});
  }

  /// Interrupt the active generation in a session.
  Future<void> sessionInterrupt(String sessionId) async {
    await sendRpc('session.interrupt', {'session_id': sessionId});
  }

  /// Steer / nudge the model (modify system prompt or behaviour).
  Future<void> sessionSteer(String sessionId, String instruction) async {
    await sendRpc('session.steer', {
      'session_id': sessionId,
      'instruction': instruction,
    });
  }

  /// Branch (fork) a session at the current point.
  Future<String> sessionBranch(String sessionId, {String? label}) async {
    final result = await sendRpc('session.branch', {
      'session_id': sessionId,
      if (label != null) 'label': label,
    });
    return (result as Map<String, dynamic>)['session_id'] as String? ?? '';
  }

  /// Compress / summarize conversation history.
  Future<void> sessionCompress(String sessionId) async {
    await sendRpc('session.compress', {'session_id': sessionId});
  }

  /// Undo the last user or assistant turn.
  Future<void> sessionUndo(String sessionId, {int? count}) async {
    await sendRpc('session.undo', {
      'session_id': sessionId,
      if (count != null) 'count': count,
    });
  }

  /// Force-save session state.
  Future<void> sessionSave(String sessionId) async {
    await sendRpc('session.save', {'session_id': sessionId});
  }

  /// Set working directory for a session.
  Future<void> sessionCwdSet(String sessionId, String cwd) async {
    await sendRpc('session.cwd.set', {'session_id': sessionId, 'cwd': cwd});
  }

  /// Get session status (idle, thinking, running, etc.).
  Future<String> sessionStatus(String sessionId) async {
    final result = await sendRpc('session.status', {'session_id': sessionId});
    return (result as Map<String, dynamic>)['status'] as String? ?? '';
  }

  /// Get session message history.
  Future<List<Map<String, dynamic>>> sessionHistory(
    String sessionId, {
    int? limit,
    int? before,
  }) async {
    final result = await sendRpc('session.history', {
      'session_id': sessionId,
      if (limit != null) 'limit': limit,
      if (before != null) 'before': before,
    });
    final list = result as List<dynamic>? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Get token usage for a session.
  Future<Map<String, dynamic>> sessionUsage(String sessionId) async {
    final result = await sendRpc('session.usage', {'session_id': sessionId});
    return (result as Map<String, dynamic>? ?? {});
  }
}

/// Prompt / generation.
extension HermesPromptRpc on HermesGateway {
  /// Submit a new prompt (starts a new generation).
  Future<void> promptSubmit({
    required String sessionId,
    required String prompt,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? options,
  }) async {
    await sendRpc('prompt.submit', {
      'session_id': sessionId,
      'prompt': prompt,
      if (attachments != null) 'attachments': attachments,
      if (options != null) 'options': options,
    });
  }

  /// Submit a prompt for background processing (no streaming response).
  Future<void> promptBackground({
    required String sessionId,
    required String prompt,
    List<Map<String, dynamic>>? attachments,
    Map<String, dynamic>? options,
  }) async {
    await sendRpc('prompt.background', {
      'session_id': sessionId,
      'prompt': prompt,
      if (attachments != null) 'attachments': attachments,
      if (options != null) 'options': options,
    });
  }

  /// Restart a previous prompt (preview mode).
  Future<void> previewRestart({
    required String sessionId,
    required String taskId,
  }) async {
    await sendRpc('preview.restart', {
      'session_id': sessionId,
      'task_id': taskId,
    });
  }
}

/// Interactive responses (approval, clarify, sudo, secret).
extension HermesInteractiveRpc on HermesGateway {
  /// Respond to a clarify request.
  Future<void> clarifyRespond(
    String sessionId,
    Map<String, dynamic> response,
  ) async {
    await sendRpc('clarify.respond', {
      'session_id': sessionId,
      'response': response,
    });
  }

  /// Respond to a sudo escalation (approve or deny).
  Future<void> sudoRespond(
    String sessionId,
    bool approved, {
    String? reason,
  }) async {
    await sendRpc('sudo.respond', {
      'session_id': sessionId,
      'approved': approved,
      if (reason != null) 'reason': reason,
    });
  }

  /// Provide a secret / API key.
  Future<void> secretRespond(String sessionId, String secret) async {
    await sendRpc('secret.respond', {
      'session_id': sessionId,
      'secret': secret,
    });
  }

  /// Respond to an approval request.
  Future<void> approvalRespond(
    String sessionId,
    bool approved, {
    String? reason,
  }) async {
    await sendRpc('approval.respond', {
      'session_id': sessionId,
      'approved': approved,
      if (reason != null) 'reason': reason,
    });
  }
}

/// File / media attachments.
extension HermesAttachmentRpc on HermesGateway {
  /// Attach a file.
  Future<String> fileAttach(String sessionId, String path) async {
    final result = await sendRpc('file.attach', {
      'session_id': sessionId,
      'path': path,
    });
    return (result as Map<String, dynamic>)['attachment_id'] as String? ?? '';
  }

  /// Attach an image from URL.
  Future<String> imageAttach(
    String sessionId,
    String url, {
    String? mimeType,
  }) async {
    final result = await sendRpc('image.attach', {
      'session_id': sessionId,
      'url': url,
      if (mimeType != null) 'mime_type': mimeType,
    });
    return (result as Map<String, dynamic>)['attachment_id'] as String? ?? '';
  }

  /// Attach an image from raw bytes (base64).
  Future<String> imageAttachBytes(
    String sessionId,
    String base64Bytes, {
    String? mimeType,
  }) async {
    final result = await sendRpc('image.attach_bytes', {
      'session_id': sessionId,
      'bytes': base64Bytes,
      if (mimeType != null) 'mime_type': mimeType,
    });
    return (result as Map<String, dynamic>)['attachment_id'] as String? ?? '';
  }

  /// Attach a PDF.
  Future<String> pdfAttach(String sessionId, String path) async {
    final result = await sendRpc('pdf.attach', {
      'session_id': sessionId,
      'path': path,
    });
    return (result as Map<String, dynamic>)['attachment_id'] as String? ?? '';
  }

  /// Detach an image by attachment ID.
  Future<void> imageDetach(String sessionId, String attachmentId) async {
    await sendRpc('image.detach', {
      'session_id': sessionId,
      'attachment_id': attachmentId,
    });
  }

  /// Paste clipboard contents.
  Future<void> clipboardPaste(String sessionId, String content) async {
    await sendRpc('clipboard.paste', {
      'session_id': sessionId,
      'content': content,
    });
  }

  /// Report a file drop on the input area.
  Future<void> inputDetectDrop(String sessionId, List<String> paths) async {
    await sendRpc('input.detect_drop', {
      'session_id': sessionId,
      'paths': paths,
    });
  }
}

/// Delegation / sub-agent.
extension HermesDelegationRpc on HermesGateway {
  /// Get delegation status.
  Future<Map<String, dynamic>> delegationStatus(String sessionId) async {
    final result = await sendRpc('delegation.status', {
      'session_id': sessionId,
    });
    return (result as Map<String, dynamic>? ?? {});
  }

  /// Pause a sub-agent.
  Future<void> delegationPause(String sessionId, String agentId) async {
    await sendRpc('delegation.pause', {
      'session_id': sessionId,
      'agent_id': agentId,
    });
  }

  /// Interrupt a sub-agent.
  Future<void> subagentInterrupt(String sessionId, String agentId) async {
    await sendRpc('subagent.interrupt', {
      'session_id': sessionId,
      'agent_id': agentId,
    });
  }
}

/// Handoff (agent-to-agent transfer).
extension HermesHandoffRpc on HermesGateway {
  /// Request a handoff.
  Future<void> handoffRequest(String sessionId, String targetAgent) async {
    await sendRpc('handoff.request', {
      'session_id': sessionId,
      'target_agent': targetAgent,
    });
  }

  /// Get current handoff state.
  Future<Map<String, dynamic>> handoffState(String sessionId) async {
    final result = await sendRpc('handoff.state', {'session_id': sessionId});
    return (result as Map<String, dynamic>? ?? {});
  }

  /// Report a handoff failure.
  Future<void> handoffFail(String sessionId, String reason) async {
    await sendRpc('handoff.fail', {'session_id': sessionId, 'reason': reason});
  }
}

/// Terminal.
extension HermesTerminalRpc on HermesGateway {
  /// Resize terminal.
  Future<void> terminalResize(String sessionId, int cols, int rows) async {
    await sendRpc('terminal.resize', {
      'session_id': sessionId,
      'cols': cols,
      'rows': rows,
    });
  }

  /// Respond to terminal read (stdin).
  Future<void> terminalReadRespond(String sessionId, String input) async {
    await sendRpc('terminal.read.respond', {
      'session_id': sessionId,
      'input': input,
    });
  }
}

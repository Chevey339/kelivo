class WorkspaceBinding {
  static const String keyId = 'workspace.id';
  static const String keyCwd = 'workspace.cwd';
  static const String keyToolsUsed = 'workspace.tools_used';
  static const String keyAllowAll = 'workspace.allowAll';

  final String? workspaceId;
  final String cwd;
  final bool toolsUsed;
  final bool allowAll;

  const WorkspaceBinding({
    this.workspaceId,
    this.cwd = '',
    this.toolsUsed = false,
    this.allowAll = false,
  });

  bool get isBound => workspaceId != null && workspaceId!.isNotEmpty;

  /// True when extras name a workspace that [exists] still finds.
  static bool extrasHaveWorkspace(
    Map<String, dynamic>? extras,
    bool Function(String id) exists,
  ) {
    final binding = WorkspaceBinding.fromExtras(
      extras ?? const <String, dynamic>{},
    );
    return binding.isBound && exists(binding.workspaceId!);
  }

  factory WorkspaceBinding.fromExtras(Map<String, dynamic> extras) {
    return WorkspaceBinding(
      workspaceId: extras[keyId] as String?,
      cwd: (extras[keyCwd] as String?) ?? '',
      toolsUsed: extras[keyToolsUsed] as bool? ?? false,
      allowAll: extras[keyAllowAll] as bool? ?? false,
    );
  }

  /// Returns a new map with this binding written. Unbound bindings remove the
  /// workspace keys instead of leaving empty values behind.
  Map<String, dynamic> applyTo(Map<String, dynamic> extras) {
    final next = Map<String, dynamic>.from(extras);
    if (!isBound) {
      next.remove(keyId);
      next.remove(keyCwd);
      next.remove(keyToolsUsed);
      next.remove(keyAllowAll);
      return next;
    }
    next[keyId] = workspaceId;
    next[keyCwd] = cwd;
    next[keyToolsUsed] = toolsUsed;
    next[keyAllowAll] = allowAll;
    return next;
  }
}

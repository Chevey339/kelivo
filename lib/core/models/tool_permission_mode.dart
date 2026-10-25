enum ToolPermissionMode {
  requestApproval,
  fullAccess;

  static const extrasKey = 'tools.permission_mode';
  static ToolPermissionMode fromExtras(Map<String, dynamic> extras) =>
      extras[extrasKey] == fullAccess.name ? fullAccess : requestApproval;

  Map<String, dynamic> applyTo(Map<String, dynamic> extras) => {
    ...withoutGrant(extras),
    extrasKey: name,
  };

  static Map<String, dynamic> withoutGrant(Map<String, dynamic> extras) =>
      Map<String, dynamic>.from(extras)
        ..remove(extrasKey)
        ..remove('workspace.allowAll');
}

class ToolPermissionState {
  const ToolPermissionState({
    this.mode = ToolPermissionMode.requestApproval,
    this.workspaceId,
    this.assistantId,
  });
  final ToolPermissionMode mode;
  final String? workspaceId;
  final String? assistantId;
}

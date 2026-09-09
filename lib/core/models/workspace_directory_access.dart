/// Device-specific authorization returned by the system directory picker.
/// A saved host path alone does not grant access on mobile platforms.
class WorkspaceDirectoryAccess {
  const WorkspaceDirectoryAccess({required this.platform, required this.token});

  final String platform;
  final String token;

  Map<String, dynamic> toJson() => {'platform': platform, 'token': token};

  factory WorkspaceDirectoryAccess.fromJson(Map<String, dynamic> json) =>
      WorkspaceDirectoryAccess(
        platform: json['platform'] as String,
        token: json['token'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is WorkspaceDirectoryAccess &&
      other.platform == platform &&
      other.token == token;

  @override
  int get hashCode => Object.hash(platform, token);
}

class WorkspaceDirectory {
  const WorkspaceDirectory({required this.path, required this.access});

  final String path;
  final WorkspaceDirectoryAccess access;
}

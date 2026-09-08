enum WorkspaceFileRole { referenced, created, modified, log }

/// A tool's file identity and operation travel together through persistence/UI.
class WorkspaceToolFile {
  const WorkspaceToolFile({
    required this.path,
    this.link,
    this.isDirectory = false,
    this.role = WorkspaceFileRole.referenced,
    this.temporary = false,
  });

  final String path;
  final String? link;
  final bool isDirectory;
  final WorkspaceFileRole role;
  final bool temporary;

  String get identity => link?.isNotEmpty == true ? link! : path;
  bool get isChanged =>
      role == WorkspaceFileRole.created || role == WorkspaceFileRole.modified;
  bool get isProduced => isChanged && !isDirectory && !temporary;

  Map<String, dynamic> toJson() => {
    'path': path,
    'link': link,
    'isDirectory': isDirectory,
    'role': role.name,
    'temporary': temporary,
  };

  factory WorkspaceToolFile.fromJson(Map<String, dynamic> json) =>
      WorkspaceToolFile(
        path: json['path'] as String,
        link: json['link'] as String?,
        isDirectory: json['isDirectory'] == true,
        role: WorkspaceFileRole.values.byName(json['role'] as String),
        temporary: json['temporary'] == true,
      );
}

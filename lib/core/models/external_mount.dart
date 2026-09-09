import 'workspace_directory_access.dart';

class ExternalMount {
  const ExternalMount({
    required this.id,
    required this.name,
    required this.access,
    required this.sourcePath,
    this.readOnly = false,
  });

  static const root = '/mounts';
  final String id;
  final String name;
  final WorkspaceDirectoryAccess access;
  final String sourcePath;
  final bool readOnly;
  String get guestPath => '$root/$name';

  ExternalMount copyWith({
    String? name,
    WorkspaceDirectoryAccess? access,
    String? sourcePath,
    bool? readOnly,
  }) => ExternalMount(
    id: id,
    name: name ?? this.name,
    access: access ?? this.access,
    sourcePath: sourcePath ?? this.sourcePath,
    readOnly: readOnly ?? this.readOnly,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'access': access.toJson(),
    'sourcePath': sourcePath,
    'readOnly': readOnly,
  };

  factory ExternalMount.fromJson(Map<String, dynamic> json) => ExternalMount(
    id: json['id'] as String,
    name: json['name'] as String,
    access: WorkspaceDirectoryAccess.fromJson(
      Map<String, dynamic>.from(json['access'] as Map),
    ),
    sourcePath: json['sourcePath'] as String,
    readOnly: json['readOnly'] as bool,
  );

  static bool validName(String name) =>
      name.isNotEmpty &&
      name == name.trim() &&
      name != '.' &&
      name != '..' &&
      name.runes.length <= 64 &&
      !name.contains(RegExp(r'[/\\:\x00-\x1f\x7f]'));
}

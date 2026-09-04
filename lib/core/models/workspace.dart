enum WorkspaceKind { managed, linked }

class Workspace {
  final String id;
  final String name;
  final WorkspaceKind kind;
  final String? hostPath;
  final bool shellNeedsApproval;
  final String defaultCwd;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.kind,
    this.hostPath,
    this.shellNeedsApproval = false,
    this.defaultCwd = '',
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  Workspace copyWith({
    String? id,
    String? name,
    WorkspaceKind? kind,
    String? hostPath,
    bool? shellNeedsApproval,
    String? defaultCwd,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    bool clearHostPath = false,
    bool clearLastUsedAt = false,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      hostPath: clearHostPath ? null : (hostPath ?? this.hostPath),
      shellNeedsApproval: shellNeedsApproval ?? this.shellNeedsApproval,
      defaultCwd: defaultCwd ?? this.defaultCwd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: clearLastUsedAt ? null : (lastUsedAt ?? this.lastUsedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'hostPath': hostPath,
    'shellNeedsApproval': shellNeedsApproval,
    'defaultCwd': defaultCwd,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
  };

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      kind: workspaceKindFromString(json['kind'] as String?),
      hostPath: json['hostPath'] as String?,
      shellNeedsApproval: json['shellNeedsApproval'] as bool? ?? false,
      defaultCwd: (json['defaultCwd'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String),
    );
  }

  static WorkspaceKind workspaceKindFromString(String? value) {
    switch (value) {
      case 'linked':
        return WorkspaceKind.linked;
      case 'managed':
      default:
        return WorkspaceKind.managed;
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Workspace &&
            other.id == id &&
            other.name == name &&
            other.kind == kind &&
            other.hostPath == hostPath &&
            other.shellNeedsApproval == shellNeedsApproval &&
            other.defaultCwd == defaultCwd &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.lastUsedAt == lastUsedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    hostPath,
    shellNeedsApproval,
    defaultCwd,
    createdAt,
    updatedAt,
    lastUsedAt,
  );
}

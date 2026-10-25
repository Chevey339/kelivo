enum BackupCategory {
  chats,
  files,
  assistants,
  providers,
  mcp,
  environmentVariables,
  skills,
  worldBooks,
  memories,
  quickPhrases,
  instructions,
  workspaces,
  searchServices,
  speechServices,
  settings,
}

/// Shared selection for export and import. New categories are enabled by default.
final class BackupScope {
  const BackupScope({this.excluded = const {}});

  final Set<BackupCategory> excluded;

  bool includes(BackupCategory category) => !excluded.contains(category);

  BackupScope withCategory(BackupCategory category, bool enabled) =>
      BackupScope(
        excluded: Set.unmodifiable({
          ...excluded.where((value) => value != category),
          if (!enabled) category,
        }),
      );

  BackupScope intersect(BackupScope other) =>
      BackupScope(excluded: Set.unmodifiable({...excluded, ...other.excluded}));

  Map<String, bool> toJson() => {
    for (final category in BackupCategory.values)
      category.name: includes(category),
  };

  factory BackupScope.fromJson(Object? value) {
    if (value == null) return const BackupScope();
    if (value is! Map || value.values.any((enabled) => enabled is! bool)) {
      throw const FormatException('backup_scope');
    }
    return BackupScope(
      excluded: Set.unmodifiable({
        for (final category in BackupCategory.values)
          if (value[category.name] == false) category,
      }),
    );
  }

  Set<String> get assetRoots => {
    if (includes(BackupCategory.files)) ...{
      'upload',
      'images',
      'avatars',
      'fonts',
      'sessions',
    },
    if (includes(BackupCategory.skills)) 'skills',
    if (includes(BackupCategory.workspaces)) 'workspaces',
  };
}

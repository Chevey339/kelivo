import '../models/backup_scope.dart';
import 'business_data.dart';

/// Assigns each portable business key to exactly one backup category.
final class BackupContentFilter {
  BackupContentFilter._();

  static BackupCategory categoryForKey(String key) {
    if (key == 'environment_variables_v1') {
      return BackupCategory.environmentVariables;
    }
    if (key == 'assistants_v1' ||
        key == 'current_assistant_id_v1' ||
        key.startsWith('assistant_tag')) {
      return BackupCategory.assistants;
    }
    if (key.startsWith('provider') ||
        key == 'selected_model_v1' ||
        key == 'pinned_models_v1' ||
        key == 'reasoning_choice_by_model_v1') {
      return BackupCategory.providers;
    }
    if (key.startsWith('mcp_')) return BackupCategory.mcp;
    if (key.startsWith('world_books_')) return BackupCategory.worldBooks;
    if (key == 'assistant_memories_v1' ||
        key.startsWith('memory_') ||
        key == 'user_profile_fields_v1') {
      return BackupCategory.memories;
    }
    if (key.startsWith('skills_')) return BackupCategory.skills;
    if (key.startsWith('workspaces_')) return BackupCategory.workspaces;
    if (key.startsWith('quick_phrases_')) return BackupCategory.quickPhrases;
    if (key.startsWith('instruction_injection')) {
      return BackupCategory.instructions;
    }
    if (key.startsWith('search_')) return BackupCategory.searchServices;
    if (key.startsWith('tts_') || key.startsWith('asr_')) {
      return BackupCategory.speechServices;
    }
    return BackupCategory.settings;
  }

  static Map<String, T> select<T>(Map<String, T> values, BackupScope scope) => {
    for (final entry in values.entries)
      if (scope.includes(categoryForKey(entry.key))) entry.key: entry.value,
  };

  static BusinessSnapshot selectSnapshot(
    BusinessSnapshot snapshot,
    BackupScope scope,
  ) => BusinessSnapshot(
    entities: {
      for (final entry in snapshot.entities.entries)
        if (scope.includes(categoryForKey(entry.key.sourceKey)))
          entry.key: entry.value,
    },
    preferences: select(snapshot.preferences, scope),
  );

  static BusinessSnapshot preserveUnselected(
    BusinessSnapshot incoming,
    BusinessSnapshot local,
    BackupScope scope,
  ) => BusinessSnapshot(
    entities: {
      for (final kind in BusinessEntityKind.values)
        kind: scope.includes(categoryForKey(kind.sourceKey))
            ? incoming.entities[kind]!
            : local.entities[kind]!,
    },
    preferences: {
      ...select(incoming.preferences, scope),
      for (final entry in local.preferences.entries)
        if (!scope.includes(categoryForKey(entry.key))) entry.key: entry.value,
    },
  );
}

part of 'chat_database_repository.dart';

extension ChatCompressionRepository on ChatDatabaseRepository {
  Future<Map<String, dynamic>> _compressionSettingsFrom(
    String schema,
    String id,
  ) async {
    if (schema != 'main' && schema != 'merge_source') {
      throw ArgumentError('schema');
    }
    final row = await _db
        .customSelect(
          'SELECT payload FROM $schema.extension_entity_rows WHERE kind=? AND id=?',
          variables: [
            Variable<String>(CompressionConfig.conversationKind),
            Variable<String>(id),
          ],
        )
        .getSingleOrNull();
    final defaultsRow = await _db
        .customSelect(
          'SELECT value FROM $schema.preference_rows WHERE key=?',
          variables: [const Variable<String>('compression_defaults_v1')],
        )
        .getSingleOrNull();
    dynamic defaults = defaultsRow == null
        ? null
        : jsonDecode(defaultsRow.read<String>('value'));
    if (defaults is String) defaults = jsonDecode(defaults);
    return {
      ...const CompressionConfig().toJson(),
      if (defaults is Map) ...defaults.cast<String, dynamic>(),
      if (row != null)
        ...Map<String, dynamic>.from(
          jsonDecode(row.read<String>('payload')) as Map,
        ),
    };
  }

  Future<Map<String, String>> _importCompressionLibrary() async {
    final ids = <String, String>{};
    final rows = await _db
        .customSelect(
          'SELECT id,payload FROM merge_source.extension_entity_rows WHERE kind=?',
          variables: [const Variable<String>(CompressionTemplate.entityKind)],
        )
        .get();
    for (final row in rows) {
      final raw = row.read<String>('payload');
      final id = _deterministicMergeId(
        'compression-template',
        row.read<String>('id'),
        raw,
      );
      ids[row.read<String>('id')] = id;
      final template = CompressionTemplate.fromJson({
        ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
        'id': id,
      });
      await compression.saveTemplate(template);
    }
    final recipes = await _db
        .customSelect(
          'SELECT id,payload FROM merge_source.extension_entity_rows WHERE kind=?',
          variables: [const Variable<String>(CompressionRecipe.entityKind)],
        )
        .get();
    for (final row in recipes) {
      final raw = row.read<String>('payload');
      final recipe = CompressionRecipe.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      final template = CompressionTemplate.fromJson({
        ...recipe.template.toJson(),
        'id': ids[recipe.template.id] ?? recipe.template.id,
      });
      await compression.saveRecipe(
        CompressionRecipe(
          id: _deterministicMergeId(
            'compression-recipe',
            row.read<String>('id'),
            raw,
          ),
          name: recipe.name,
          template: template,
          focus: recipe.focus,
          settings: recipe.settings.withOverrides({
            'templateId': template.id,
            'mode': 'off',
          }),
        ),
      );
    }
    return ids;
  }

  Future<Object> _compressionFingerprint(String schema, String id) async {
    final settings = await _compressionSettingsFrom(schema, id);
    // External imports always turn automation off and remap custom template IDs.
    // Compare the template contents, not transport identities or automation mode.
    settings.remove('mode');
    final template = settings.remove('templateId');
    final row = await _db
        .customSelect(
          'SELECT payload FROM $schema.extension_entity_rows WHERE kind=? AND id=?',
          variables: [
            const Variable<String>(CompressionTemplate.entityKind),
            Variable<String>(template as String),
          ],
        )
        .getSingleOrNull();
    settings['template'] = row == null
        ? template
        : (Map<String, dynamic>.from(
            jsonDecode(row.read<String>('payload')) as Map,
          )..remove('id'));
    return settings;
  }
}

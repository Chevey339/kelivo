import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/compression_config.dart';
import '../services/chat/compression_templates.dart';
import 'extension_entity_store.dart';

class CompressionRepository {
  CompressionRepository(this.store);
  final ExtensionEntityStore store;

  Future<List<CompressionTemplate>> templates({String locale = 'en'}) async {
    final templates = {
      for (final template in builtInCompressionTemplatesForLocale(locale))
        template.id: template,
    };
    for (final row in await store.listByKind(CompressionTemplate.entityKind)) {
      templates[row.id] = CompressionTemplate.fromJson(
        row.payload,
        builtIn: templates[row.id]?.builtIn ?? false,
      );
    }
    return templates.values.toList();
  }

  Future<Map<String, DateTime>> templateLastUsed() async {
    final result = <String, DateTime>{};
    for (final row in await store.listByKind('contextCompressionTask')) {
      final snapshot = row.payload['template'];
      final id = snapshot is Map ? snapshot['id'] : null;
      final started = DateTime.tryParse(
        row.payload['startedAt']?.toString() ?? '',
      );
      if (id is String &&
          started != null &&
          (result[id] == null || started.isAfter(result[id]!))) {
        result[id] = started;
      }
    }
    return result;
  }

  Future<CompressionTemplate> template(
    String id, {
    String locale = 'en',
  }) async {
    final builtIn = builtInCompressionTemplatesForLocale(
      locale,
    ).where((t) => t.id == id).firstOrNull;
    final row = await store.get(CompressionTemplate.entityKind, id);
    if (row != null) {
      return CompressionTemplate.fromJson(
        row.payload,
        builtIn: builtIn != null,
      );
    }
    if (builtIn != null) return builtIn;
    throw StateError('compression_template_missing');
  }

  Future<void> saveTemplate(
    CompressionTemplate template, {
    String locale = 'en',
  }) async {
    CompressionTemplate.fromJson(template.toJson());
    final original = builtInCompressionTemplatesForLocale(
      locale,
    ).where((item) => item.id == template.id).firstOrNull;
    if (original != null &&
        template.name == original.name &&
        template.prompt == original.prompt &&
        template.scene == original.scene &&
        template.outputLanguage == original.outputLanguage) {
      // Restoring a built-in removes its override so it can follow the UI
      // language again. Custom templates and recipe snapshots retain their text.
      await store.delete(CompressionTemplate.entityKind, template.id);
      return;
    }
    await store.upsert(
      CompressionTemplate.entityKind,
      template.id,
      template.toJson(),
    );
  }

  Future<void> importOriginalPrompt(String prompt) async {
    await store.transaction(() async {
      if (await store.get('compressionMigration', 'originalPrompt') != null) {
        return;
      }
      if (await store.get(CompressionTemplate.entityKind, 'original') == null) {
        await saveTemplate(
          CompressionTemplate(
            id: 'original',
            name: 'My original prompt',
            prompt: prompt,
            outputLanguage: 'legacy',
          ),
        );
      }
      await store.upsert('compressionMigration', 'originalPrompt', {
        'imported': true,
      });
    });
  }

  Future<Map<String, dynamic>> overrides(String id) async =>
      (await store.get(CompressionConfig.conversationKind, id))?.payload ?? {};

  Future<void> saveOverrides(String id, Map<String, dynamic> values) async {
    await store.upsert(
      CompressionConfig.conversationKind,
      id,
      values,
      ownerId: id,
    );
  }

  Future<List<String>> conversationsUsing(String templateId) async => [
    for (final row in await store.listByKind(
      CompressionConfig.conversationKind,
    ))
      if (row.payload['templateId'] == templateId) row.id,
  ];

  /// Recipes own independent template snapshots. Accepted summaries and running
  /// tasks likewise remain readable after deleting a library entry.
  Future<void> deleteTemplate(
    String id, {
    required String replacementId,
  }) async {
    if (builtInCompressionTemplates.any((t) => t.id == id) ||
        id == replacementId) {
      throw ArgumentError('invalid template replacement');
    }
    await template(replacementId);
    await store.transaction(() async {
      for (final row in await store.listByKind(
        CompressionConfig.conversationKind,
      )) {
        if (row.payload['templateId'] == id) {
          await saveOverrides(row.id, {
            ...row.payload,
            'templateId': replacementId,
          });
        }
      }
      await store.delete(CompressionTemplate.entityKind, id);
    });
  }

  Future<List<CompressionRecipe>> recipes() async => [
    for (final row in await store.listByKind(CompressionRecipe.entityKind))
      CompressionRecipe.fromJson(row.payload),
  ];

  Future<void> saveRecipe(CompressionRecipe recipe) =>
      store.upsert(CompressionRecipe.entityKind, recipe.id, recipe.toJson());
  Future<void> deleteRecipe(String id) =>
      store.delete(CompressionRecipe.entityKind, id);

  String exportTemplate(CompressionTemplate template) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'type': 'kelivo-compression-template', ...template.toJson()});
  String exportRecipe(CompressionRecipe recipe) => const JsonEncoder.withIndent(
    '  ',
  ).convert({'type': 'kelivo-compression-recipe', ...recipe.toJson()});

  /// Imports only add library entries. Caller chooses whether to apply later.
  /// IDs are always local, even for same-name/same-ID imported templates.
  Future<String> importJson(String text) async {
    final json = Map<String, dynamic>.from(jsonDecode(text) as Map);
    if (json['type'] == 'kelivo-compression-template') {
      final template = CompressionTemplate.fromJson({
        ...json,
        'id': const Uuid().v4(),
      });
      await saveTemplate(template);
      return template.id;
    }
    if (json['type'] != 'kelivo-compression-recipe') {
      throw const FormatException('Unsupported compression file');
    }
    final recipe = CompressionRecipe.fromJson(json);
    final template = CompressionTemplate.fromJson({
      ...recipe.template.toJson(),
      'id': const Uuid().v4(),
    });
    final id = const Uuid().v4();
    await store.transaction(() async {
      await saveTemplate(template);
      await saveRecipe(
        CompressionRecipe(
          id: id,
          name: recipe.name,
          template: template,
          settings: recipe.settings.withOverrides({
            'templateId': template.id,
            'mode': 'off',
          }),
          focus: recipe.focus,
        ),
      );
    });
    return id;
  }
}

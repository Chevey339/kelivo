import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../../models/api_keys.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/world_book.dart';
import '../../providers/settings_provider.dart';
import '../chat/chat_service.dart';

enum RikkaMergeConflictPolicy { mergeSameItem, duplicateOnConflict }

class RikkaHubImportResult {
  final int providers;
  final int assistants;
  final int conversations;
  final int messages;
  final int files;
  final int modeInjections;
  final int lorebooks;
  final List<String> warnings;

  const RikkaHubImportResult({
    required this.providers,
    required this.assistants,
    required this.conversations,
    required this.messages,
    required this.files,
    required this.modeInjections,
    required this.lorebooks,
    this.warnings = const <String>[],
  });
}

class RikkaHubImportException implements Exception {
  final String message;
  const RikkaHubImportException(this.message);
  @override
  String toString() => message;
}

class RikkaHubImporter {
  RikkaHubImporter._();

  static const String _providersKey = 'provider_configs_v1';
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _assistantsKey = 'assistants_v1';

  static const String _injectionsKey = 'instruction_injections_v1';
  static const String _injectionsActiveIdKey =
      'instruction_injections_active_id_v1';
  static const String _injectionsActiveIdsKey =
      'instruction_injections_active_ids_v1';
  static const String _injectionsActiveByAssistantKey =
      'instruction_injections_active_ids_by_assistant_v1';

  static const String _worldBooksKey = 'world_books_v1';
  static const String _worldBooksActiveByAssistantKey =
      'world_books_active_ids_by_assistant_v1';

  static const String _defaultAssistantKey = '__global__';

  static Future<RikkaHubImportResult> importFromRikkaHub({
    required File file,
    required RestoreMode mode,
    required SettingsProvider settings,
    required ChatService chatService,
    RikkaMergeConflictPolicy mergeConflictPolicy =
        RikkaMergeConflictPolicy.mergeSameItem,
  }) async {
    if (!await file.exists()) {
      throw const RikkaHubImportException('RikkaHub backup file not found.');
    }
    final ext = p.extension(file.path).toLowerCase();
    if (ext != '.zip') {
      throw const RikkaHubImportException(
        'RikkaHub import only supports .zip files.',
      );
    }

    final warnings = <String>[];
    final warningSeen = <String>{};
    void addWarning(String text) {
      final msg = text.trim();
      if (msg.isEmpty) return;
      if (!warningSeen.add(msg)) return;
      if (warnings.length < 200) warnings.add(msg);
    }

    final archive = await _readZipArchive(file);
    final settingsEntry = _findArchiveFile(
      archive,
      (n) => n.toLowerCase().endsWith('settings.json'),
    );
    if (settingsEntry == null) {
      throw const RikkaHubImportException(
        'Invalid RikkaHub backup: missing settings.json.',
      );
    }

    final root = _decodeJsonObject(
      utf8.decode(_archiveFileBytes(settingsEntry), allowMalformed: true),
      fallbackMessage: 'Unable to parse settings.json',
    );
    final settingsRoot = _extractSettingsRoot(root);
    final mergedSettingsRoot = <String, dynamic>{...root, ...settingsRoot};
    final prefs = await SharedPreferences.getInstance();

    final providerCtx = await _importProviders(
      settingsRoot: mergedSettingsRoot,
      prefs: prefs,
      settingsProvider: settings,
      mode: mode,
      mergePolicy: mergeConflictPolicy,
      addWarning: addWarning,
    );

    final assistantCtx = await _importAssistants(
      settingsRoot: mergedSettingsRoot,
      prefs: prefs,
      mode: mode,
      mergePolicy: mergeConflictPolicy,
      modelRefByToken: providerCtx.modelRefByToken,
      providerAliasMap: providerCtx.providerAliasMap,
      addWarning: addWarning,
    );

    final modeInjectionCount = await _importInstructionInjections(
      settingsRoot: mergedSettingsRoot,
      prefs: prefs,
      mode: mode,
      mergePolicy: mergeConflictPolicy,
      assistantIdMap: assistantCtx.oldToNewAssistantId,
      addWarning: addWarning,
    );

    final lorebookCount = await _importWorldBooks(
      settingsRoot: mergedSettingsRoot,
      prefs: prefs,
      mode: mode,
      mergePolicy: mergeConflictPolicy,
      assistantIdMap: assistantCtx.oldToNewAssistantId,
      addWarning: addWarning,
    );

    if (!chatService.initialized) await chatService.init();
    if (mode == RestoreMode.overwrite) {
      await chatService.clearAllData();
    }

    final uploadIndex = const _UploadFileIndex.empty();

    int convCount = 0;
    int msgCount = 0;
    final tempDir = await Directory.systemTemp.createTemp('kelivo_rikkahub_');
    try {
      final dbPath = await _extractSqliteDatabase(archive, tempDir);
      if (dbPath == null) {
        addWarning('rikka_hub.db not found, skipped conversation import.');
      } else {
        final convResult = await _importConversationsFromDb(
          dbPath: dbPath,
          chatService: chatService,
          mode: mode,
          mergePolicy: mergeConflictPolicy,
          assistantIdMap: assistantCtx.oldToNewAssistantId,
          validAssistantIds: assistantCtx.finalAssistantIds,
          uploadIndex: uploadIndex,
          addWarning: addWarning,
        );
        convCount = convResult.$1;
        msgCount = convResult.$2;
      }
    } finally {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }

    return RikkaHubImportResult(
      providers: providerCtx.importedCount,
      assistants: assistantCtx.importedCount,
      conversations: convCount,
      messages: msgCount,
      files: uploadIndex.copiedFiles,
      modeInjections: modeInjectionCount,
      lorebooks: lorebookCount,
      warnings: warnings,
    );
  }

  @visibleForTesting
  static ({
    Map<String, dynamic> provider,
    Map<String, Map<String, String>> modelMap,
  })
  buildProviderPayloadForTest(Map<String, dynamic> raw, {int index = 0}) {
    final prepared = _prepareProvider(raw, index: index);
    if (prepared == null) {
      return (
        provider: <String, dynamic>{},
        modelMap: <String, Map<String, String>>{},
      );
    }
    final modelMap = <String, Map<String, String>>{};
    for (final token in prepared.modelTokens) {
      modelMap[token.token] = <String, String>{
        'providerKey': prepared.suggestedKey,
        'modelId': token.modelId,
      };
    }
    return (
      provider: Map<String, dynamic>.from(prepared.providerData),
      modelMap: modelMap,
    );
  }

  @visibleForTesting
  static Map<String, dynamic> buildAssistantPayloadForTest(
    Map<String, dynamic> raw, {
    Map<String, Map<String, String>> modelMap =
        const <String, Map<String, String>>{},
    Map<String, String> providerAliasMap = const <String, String>{},
  }) {
    final refs = <String, _ResolvedModelRef>{};
    modelMap.forEach((key, value) {
      final provider = (value['providerKey'] ?? '').trim();
      final modelId = (value['modelId'] ?? '').trim();
      if (provider.isEmpty || modelId.isEmpty) return;
      refs[key] = _ResolvedModelRef(providerKey: provider, modelId: modelId);
      refs[key.toLowerCase()] = _ResolvedModelRef(
        providerKey: provider,
        modelId: modelId,
      );
    });
    final prepared = _prepareAssistant(
      raw,
      modelRefByToken: refs,
      providerAliasMap: providerAliasMap,
      index: 0,
    );
    return prepared == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(prepared.assistantData);
  }

  @visibleForTesting
  static ({List<ChatMessage> messages, Map<String, int> versionSelections})
  convertMessageNodesForTest({
    required List<Map<String, dynamic>> nodeRows,
    required String conversationId,
    DateTime? fallbackTimestamp,
    Map<String, String> basenameToPath = const <String, String>{},
    Map<String, String> relativeToPath = const <String, String>{},
  }) {
    final index = _UploadFileIndex(
      byBasename: _normalizeStringMapKeys(basenameToPath),
      byRelative: _normalizeStringMapKeys(relativeToPath),
      copiedFiles: 0,
    );
    final sortedNodes = <_NodeRecord>[];
    for (var i = 0; i < nodeRows.length; i++) {
      final row = nodeRows[i];
      final nodeId = (_pickString(row, <String>['id', 'nodeId', 'uuid']) ?? '')
          .trim();
      final nodeIndex =
          _asInt(_pickValue(row, <String>['node_index', 'nodeIndex'])) ?? i;
      final selectIndex =
          _asInt(_pickValue(row, <String>['select_index', 'selectIndex'])) ?? 0;
      final msgRaw = _pickValue(row, <String>[
        'messages',
        'messageList',
        'message_list',
        'items',
      ]);
      final messages = _decodeListOfMaps(msgRaw);
      sortedNodes.add(
        _NodeRecord(
          id: nodeId.isEmpty ? const Uuid().v4() : nodeId,
          index: nodeIndex,
          selectIndex: selectIndex,
          messages: messages,
        ),
      );
    }
    sortedNodes.sort((a, b) => a.index.compareTo(b.index));

    final out = <ChatMessage>[];
    final selections = <String, int>{};
    final usedIds = <String>{};
    final fallback = fallbackTimestamp ?? DateTime.now();
    for (final node in sortedNodes) {
      var version = 0;
      for (final raw in node.messages) {
        final converted = _convertUiMessageToChatMessage(
          uiMessage: raw,
          conversationId: conversationId,
          groupId: node.id,
          version: version,
          fallbackTimestamp: fallback,
          uploadIndex: index,
          addWarning: (_) {},
        );
        if (converted == null) continue;
        var msgId = converted.id;
        if (usedIds.contains(msgId)) {
          msgId = _newUuid(usedIds);
        }
        usedIds.add(msgId);
        out.add(converted.copyWith(id: msgId));
        version += 1;
      }
      if (version > 0) {
        var selected = node.selectIndex;
        if (selected < 0) selected = 0;
        if (selected >= version) selected = version - 1;
        selections[node.id] = selected;
      }
    }
    return (messages: out, versionSelections: selections);
  }

  @visibleForTesting
  static String rewriteFileReferenceForTest(
    String rawPath, {
    Map<String, String> basenameToPath = const <String, String>{},
    Map<String, String> relativeToPath = const <String, String>{},
  }) {
    final idx = _UploadFileIndex(
      byBasename: _normalizeStringMapKeys(basenameToPath),
      byRelative: _normalizeStringMapKeys(relativeToPath),
      copiedFiles: 0,
    );
    return _rewriteFileReference(rawPath, uploadIndex: idx, addWarning: (_) {});
  }

  @visibleForTesting
  static Map<String, dynamic> mergeProviderKeepLocalForTest(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    return _mergeProviderKeepLocal(local, incoming);
  }

  @visibleForTesting
  static String uniqueKeyForTest(
    String base,
    Set<String> used, {
    bool forceRikkaSuffix = false,
  }) {
    return _uniqueKey(base, used, forceRikkaSuffix: forceRikkaSuffix);
  }

  @visibleForTesting
  static String uniqueDisplayNameForTest(
    String base,
    Set<String> used, {
    bool forceRikkaSuffix = false,
  }) {
    return _uniqueDisplayName(base, used, forceRikkaSuffix: forceRikkaSuffix);
  }

  static Future<Archive> _readZipArchive(File file) async {
    final bytes = await file.readAsBytes();
    try {
      return ZipDecoder().decodeBytes(bytes, verify: false);
    } catch (e) {
      throw RikkaHubImportException('Unable to read zip: $e');
    }
  }

  static ArchiveFile? _findArchiveFile(
    Archive archive,
    bool Function(String name) matcher,
  ) {
    for (final e in archive) {
      if (!e.isFile) continue;
      final name = e.name.replaceAll('\\', '/');
      if (matcher(name)) return e;
    }
    return null;
  }

  static Uint8List _archiveFileBytes(ArchiveFile file) {
    final c = file.content;
    if (c is Uint8List) return c;
    if (c is List<int>) return Uint8List.fromList(c);
    if (c != null) {
      try {
        final dyn = c as dynamic;
        final bytes = dyn.toUint8List() as List<int>;
        return Uint8List.fromList(bytes);
      } catch (_) {}
    }
    return Uint8List(0);
  }

  static Map<String, dynamic> _decodeJsonObject(
    String source, {
    required String fallbackMessage,
  }) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    throw RikkaHubImportException(fallbackMessage);
  }

  static Map<String, dynamic> _extractSettingsRoot(Map<String, dynamic> root) {
    final nested = root['settings'];
    if (nested is Map) {
      return nested.map((k, v) => MapEntry(k.toString(), v));
    }
    return root;
  }

  static Future<_ProviderImportContext> _importProviders({
    required Map<String, dynamic> settingsRoot,
    required SharedPreferences prefs,
    required SettingsProvider settingsProvider,
    required RestoreMode mode,
    required RikkaMergeConflictPolicy mergePolicy,
    required void Function(String) addWarning,
  }) async {
    final providersRaw = settingsRoot['providers'];
    final incoming = _asMapList(providersRaw, mapKeyId: 'id');

    Map<String, dynamic> existingMap = _loadJsonMap(
      prefs.getString(_providersKey),
    );
    if (existingMap.isEmpty && settingsProvider.providerConfigs.isNotEmpty) {
      existingMap = <String, dynamic>{
        for (final entry in settingsProvider.providerConfigs.entries)
          entry.key: entry.value.toJson(),
      };
    }
    final existingOrder =
        prefs.getStringList(_providersOrderKey) ??
        existingMap.keys.toList(growable: false);

    final nextMap = mode == RestoreMode.overwrite
        ? <String, dynamic>{}
        : <String, dynamic>{...existingMap};
    final nextOrder = mode == RestoreMode.overwrite
        ? <String>[]
        : <String>[...existingOrder];
    final usedKeys = mode == RestoreMode.overwrite
        ? <String>{}
        : nextMap.keys.toSet();

    final modelRefByToken = <String, _ResolvedModelRef>{};
    final providerAliasMap = <String, String>{};
    var importedCount = 0;

    for (var i = 0; i < incoming.length; i++) {
      final prepared = _prepareProvider(incoming[i], index: i);
      if (prepared == null) continue;

      if (mode == RestoreMode.merge &&
          mergePolicy == RikkaMergeConflictPolicy.mergeSameItem) {
        final match = _findSameProviderKey(nextMap, prepared.providerData);
        if (match != null) {
          final local = _toStringDynamicMap(nextMap[match]);
          final merged = _mergeProviderKeepLocal(local, prepared.providerData)
            ..['id'] = match
            ..['name'] = (local['name']?.toString().trim().isNotEmpty ?? false)
                ? local['name']
                : match;
          nextMap[match] = merged;
          _registerProviderAliases(providerAliasMap, prepared, match);
          _registerModelRefs(modelRefByToken, prepared.modelTokens, match);
          importedCount += 1;
          continue;
        }
      }

      var finalKey = prepared.suggestedKey;
      final conflictWithKey = usedKeys.contains(finalKey);
      final conflictWithItem =
          mode == RestoreMode.merge &&
          mergePolicy == RikkaMergeConflictPolicy.duplicateOnConflict &&
          _findSameProviderKey(nextMap, prepared.providerData) != null;
      final forceRikkaSuffix = conflictWithKey || conflictWithItem;
      finalKey = _uniqueKey(
        finalKey,
        usedKeys,
        forceRikkaSuffix:
            forceRikkaSuffix &&
            mergePolicy == RikkaMergeConflictPolicy.duplicateOnConflict,
      );

      final payload = Map<String, dynamic>.from(prepared.providerData)
        ..['id'] = finalKey
        ..['name'] = finalKey;
      nextMap[finalKey] = payload;
      usedKeys.add(finalKey);
      if (!nextOrder.contains(finalKey)) nextOrder.add(finalKey);

      _registerProviderAliases(providerAliasMap, prepared, finalKey);
      _registerModelRefs(modelRefByToken, prepared.modelTokens, finalKey);
      importedCount += 1;
    }

    await prefs.setString(_providersKey, jsonEncode(nextMap));
    await prefs.setStringList(_providersOrderKey, nextOrder);

    if (incoming.isEmpty) {
      addWarning('No providers found in settings.json.');
    }

    return _ProviderImportContext(
      importedCount: importedCount,
      modelRefByToken: modelRefByToken,
      providerAliasMap: providerAliasMap,
    );
  }

  static _PreparedProvider? _prepareProvider(
    Map<String, dynamic> raw, {
    required int index,
  }) {
    final sourceId =
        (_pickString(raw, <String>[
                  'id',
                  'uuid',
                  'providerId',
                  'provider_id',
                ]) ??
                '')
            .trim();
    final sourceName =
        (_pickString(raw, <String>['name', 'displayName', 'providerName']) ??
                '')
            .trim();
    final sourceType =
        (_pickString(raw, <String>[
          'type',
          'providerType',
          'provider_type',
          'kind',
        ]) ??
        'openai');
    final kind = _providerKindFromRikka(sourceType);
    final baseUrl = _normalizeBaseUrl(
      (_pickString(raw, <String>['baseUrl', 'apiHost', 'endpoint', 'url']) ??
              '')
          .trim(),
    );

    final keyBase = _sanitizeKey(
      sourceName.isNotEmpty
          ? sourceName
          : sourceId.isNotEmpty
          ? sourceId
          : 'RikkaHub Provider ${index + 1}',
    );
    final apiKey = _extractPrimaryApiKey(raw);
    final allKeys = _extractApiKeys(raw);
    final models = <String>[];
    final modelTokens = <_ModelToken>[];
    final modelItems = _asMapList(
      _pickValue(raw, <String>['models', 'modelList', 'model_list']),
    );
    for (final m in modelItems) {
      final modelId =
          (_pickString(m, <String>[
                    'modelId',
                    'id',
                    'name',
                    'model',
                    'value',
                  ]) ??
                  '')
              .trim();
      if (modelId.isNotEmpty && !models.contains(modelId)) models.add(modelId);

      final tokenCandidates = <String>{
        ..._nonEmptyStrings(<String?>[
          _pickString(m, <String>['uuid', 'modelUuid', 'model_uuid', 'id']),
          _pickString(m, <String>['modelId', 'model_id', 'name']),
        ]),
      };
      for (final token in tokenCandidates) {
        if (modelId.isEmpty) continue;
        modelTokens.add(_ModelToken(token: token, modelId: modelId));
      }
    }

    final providerData = <String, dynamic>{
      'id': keyBase,
      'enabled':
          _asBool(_pickValue(raw, <String>['enabled', 'isEnabled'])) ??
          apiKey.isNotEmpty,
      'name': keyBase,
      'apiKey': apiKey,
      'baseUrl': baseUrl.isNotEmpty
          ? baseUrl
          : ProviderConfig.defaultsFor(keyBase, displayName: keyBase).baseUrl,
      'providerType': kind.name,
      'chatPath': kind == ProviderKind.openai ? '/chat/completions' : null,
      'useResponseApi': kind == ProviderKind.openai ? false : null,
      'vertexAI': kind == ProviderKind.google ? false : null,
      'location': null,
      'projectId': null,
      'serviceAccountJson': null,
      'models': models,
      'modelOverrides': const <String, dynamic>{},
      'proxyEnabled': false,
      'proxyHost': '',
      'proxyPort': '8080',
      'proxyUsername': '',
      'proxyPassword': '',
      'multiKeyEnabled': allKeys.length > 1,
      'apiKeys': allKeys.length > 1
          ? allKeys
                .map((e) => ApiKeyConfig.create(e).toJson())
                .toList(growable: false)
          : const <dynamic>[],
      'keyManagement': const <String, dynamic>{},
    };

    return _PreparedProvider(
      sourceId: sourceId,
      sourceName: sourceName,
      suggestedKey: keyBase,
      providerData: providerData,
      modelTokens: modelTokens,
    );
  }

  static ProviderKind _providerKindFromRikka(String rawType) {
    final t = rawType.toLowerCase();
    if (t.contains('google') || t.contains('gemini'))
      return ProviderKind.google;
    if (t.contains('claude') || t.contains('anthropic'))
      return ProviderKind.claude;
    return ProviderKind.openai;
  }

  static Map<String, dynamic> _mergeProviderKeepLocal(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final next = <String, dynamic>{...local};
    for (final entry in incoming.entries) {
      final k = entry.key;
      final v = entry.value;
      if (k == 'id' || k == 'name') continue;
      if (!next.containsKey(k) || _isEmpty(next[k])) {
        next[k] = v;
        continue;
      }
      if (k == 'models') {
        final localModels = _stringList(next[k]);
        final incomingModels = _stringList(v);
        final merged = <String>{
          ...localModels,
          ...incomingModels,
        }.toList(growable: false);
        next[k] = merged;
      }
    }
    return next;
  }

  static String _extractPrimaryApiKey(Map<String, dynamic> raw) {
    final direct =
        (_pickString(raw, <String>['apiKey', 'key', 'token', 'api_token']) ??
                '')
            .trim();
    if (direct.isNotEmpty) return direct;

    final list = _extractApiKeys(raw);
    return list.isNotEmpty ? list.first : '';
  }

  static List<String> _extractApiKeys(Map<String, dynamic> raw) {
    final fromList = _pickValue(raw, <String>[
      'apiKeys',
      'keys',
      'keyList',
      'key_list',
    ]);
    final out = <String>[];
    if (fromList is List) {
      for (final item in fromList) {
        if (item is Map) {
          final k =
              (_pickString(
                        item.map(
                          (key, value) => MapEntry(key.toString(), value),
                        ),
                        <String>['key', 'value', 'apiKey'],
                      ) ??
                      '')
                  .trim();
          if (k.isNotEmpty && !out.contains(k)) out.add(k);
        } else {
          final k = item.toString().trim();
          if (k.isNotEmpty && !out.contains(k)) out.add(k);
        }
      }
    }

    final fromString =
        (_pickString(raw, <String>['apiKey', 'key', 'token', 'api_token']) ??
                '')
            .trim();
    if (fromString.isNotEmpty) {
      final split = fromString.split(',');
      for (final item in split) {
        final s = item.trim();
        if (s.isNotEmpty && !out.contains(s)) out.add(s);
      }
    }
    return out;
  }

  static String? _findSameProviderKey(
    Map<String, dynamic> existing,
    Map<String, dynamic> incoming,
  ) {
    final incomingType = _providerTypeName(incoming);
    final incomingName = _normalizeName(
      _pickString(incoming, <String>['name', 'id']) ?? '',
    );
    final incomingBase = _normalizeBaseUrl(
      (_pickString(incoming, <String>['baseUrl']) ?? '').trim(),
    );

    for (final entry in existing.entries) {
      final map = _toStringDynamicMap(entry.value);
      final localType = _providerTypeName(map);
      if (localType != incomingType) continue;

      final localName = _normalizeName(
        _pickString(map, <String>['name', 'id']) ?? '',
      );
      if (incomingName.isNotEmpty && localName == incomingName) {
        return entry.key;
      }

      final localBase = _normalizeBaseUrl(
        (_pickString(map, <String>['baseUrl']) ?? '').trim(),
      );
      if (incomingBase.isNotEmpty && localBase == incomingBase) {
        return entry.key;
      }
    }
    return null;
  }

  static String _providerTypeName(Map<String, dynamic> map) {
    final type = (_pickString(map, <String>['providerType']) ?? '').trim();
    if (type.isNotEmpty) return type.toLowerCase();
    final id = (_pickString(map, <String>['id']) ?? '').trim();
    return ProviderConfig.classify(id).name;
  }

  static void _registerProviderAliases(
    Map<String, String> aliasMap,
    _PreparedProvider provider,
    String finalKey,
  ) {
    for (final alias in <String>{
      provider.sourceId,
      provider.sourceName,
      provider.suggestedKey,
    }) {
      final v = alias.trim();
      if (v.isEmpty) continue;
      aliasMap[v] = finalKey;
      aliasMap[v.toLowerCase()] = finalKey;
    }
  }

  static void _registerModelRefs(
    Map<String, _ResolvedModelRef> refs,
    List<_ModelToken> tokens,
    String providerKey,
  ) {
    for (final token in tokens) {
      final normalized = token.token.trim();
      if (normalized.isEmpty) continue;
      final ref = _ResolvedModelRef(
        providerKey: providerKey,
        modelId: token.modelId,
      );
      refs.putIfAbsent(normalized, () => ref);
      refs.putIfAbsent(normalized.toLowerCase(), () => ref);
    }
  }

  static Future<_AssistantImportContext> _importAssistants({
    required Map<String, dynamic> settingsRoot,
    required SharedPreferences prefs,
    required RestoreMode mode,
    required RikkaMergeConflictPolicy mergePolicy,
    required Map<String, _ResolvedModelRef> modelRefByToken,
    required Map<String, String> providerAliasMap,
    required void Function(String) addWarning,
  }) async {
    final assistantsRaw = settingsRoot['assistants'];
    final incoming = _asMapList(assistantsRaw, mapKeyId: 'id');
    final existing = mode == RestoreMode.overwrite
        ? <Map<String, dynamic>>[]
        : _loadJsonList(prefs.getString(_assistantsKey));

    final next = <Map<String, dynamic>>[...existing];
    final usedIds = next
        .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final oldToNew = <String, String>{};
    var importedCount = 0;

    for (var i = 0; i < incoming.length; i++) {
      final prepared = _prepareAssistant(
        incoming[i],
        modelRefByToken: modelRefByToken,
        providerAliasMap: providerAliasMap,
        index: i,
      );
      if (prepared == null) continue;

      final oldId = prepared.sourceId.isNotEmpty
          ? prepared.sourceId
          : '__assistant_$i';

      if (mode == RestoreMode.merge &&
          mergePolicy == RikkaMergeConflictPolicy.mergeSameItem) {
        final matchIdx = _findExistingAssistantIndex(next, prepared);
        if (matchIdx != -1) {
          final local = next[matchIdx];
          final merged = _mergeAssistantKeepLocal(
            local,
            prepared.assistantData,
          );
          next[matchIdx] = merged;
          final matchId = (_pickString(merged, <String>['id']) ?? '').trim();
          if (matchId.isNotEmpty) oldToNew[oldId] = matchId;
          importedCount += 1;
          continue;
        }
      }

      var newId = prepared.sourceId.trim();
      if (newId.isEmpty || usedIds.contains(newId)) {
        newId = _newUuid(usedIds);
      }
      usedIds.add(newId);

      final payload = Map<String, dynamic>.from(prepared.assistantData)
        ..['id'] = newId;

      if (mergePolicy == RikkaMergeConflictPolicy.duplicateOnConflict &&
          mode == RestoreMode.merge) {
        final existingNames = next
            .map((e) => (_pickString(e, <String>['name']) ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toSet();
        payload['name'] = _uniqueDisplayName(
          (_pickString(payload, <String>['name']) ?? 'Assistant').trim(),
          existingNames,
          forceRikkaSuffix: existingNames.contains(
            (_pickString(payload, <String>['name']) ?? '').trim(),
          ),
        );
      }

      next.add(payload);
      oldToNew[oldId] = newId;
      importedCount += 1;
    }

    await prefs.setString(_assistantsKey, jsonEncode(next));
    final finalAssistantIds = next
        .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    if (incoming.isEmpty) {
      addWarning('No assistants found in settings.json.');
    }

    return _AssistantImportContext(
      importedCount: importedCount,
      oldToNewAssistantId: oldToNew,
      finalAssistantIds: finalAssistantIds,
    );
  }

  static _PreparedAssistant? _prepareAssistant(
    Map<String, dynamic> raw, {
    required Map<String, _ResolvedModelRef> modelRefByToken,
    required Map<String, String> providerAliasMap,
    required int index,
  }) {
    final sourceId =
        (_pickString(raw, <String>[
                  'id',
                  'uuid',
                  'assistantId',
                  'assistant_id',
                ]) ??
                '')
            .trim();
    final sourceName =
        (_pickString(raw, <String>['name', 'title', 'displayName']) ?? '')
            .trim();
    final resolvedName = sourceName.isNotEmpty
        ? sourceName
        : 'RikkaHub Assistant ${index + 1}';

    final resolvedModel = _resolveAssistantModel(
      raw,
      modelRefByToken: modelRefByToken,
      providerAliasMap: providerAliasMap,
    );

    final avatar = _mapAssistantAvatar(raw['avatar']);
    final contextSize =
        _asInt(
          _pickValue(raw, <String>[
            'contextMessageSize',
            'contextCount',
            'context_size',
          ]),
        ) ??
        64;

    final assistantData = <String, dynamic>{
      'id': sourceId.isNotEmpty ? sourceId : const Uuid().v4(),
      'name': resolvedName,
      'avatar': avatar,
      'useAssistantAvatar': avatar != null,
      'chatModelProvider': resolvedModel?.providerKey,
      'chatModelId': resolvedModel?.modelId,
      'temperature': _asDouble(_pickValue(raw, <String>['temperature'])),
      'topP': _asDouble(_pickValue(raw, <String>['topP', 'top_p'])),
      'contextMessageSize': contextSize.clamp(1, 4096),
      'limitContextMessages': true,
      'streamOutput':
          _asBool(_pickValue(raw, <String>['streamOutput', 'stream'])) ?? true,
      'thinkingBudget': _asInt(
        _pickValue(raw, <String>['thinkingBudget', 'reasoningBudget']),
      ),
      'maxTokens': _asInt(_pickValue(raw, <String>['maxTokens', 'max_tokens'])),
      'systemPrompt':
          (_pickString(raw, <String>['systemPrompt', 'prompt', 'system']) ?? '')
              .trim(),
      'messageTemplate':
          (_pickString(raw, <String>['messageTemplate', 'template']) ??
                  '{{ message }}')
              .trim(),
      'mcpServerIds': const <String>[],
      'background':
          (_pickString(raw, <String>['background']) ?? '').trim().isEmpty
          ? null
          : (_pickString(raw, <String>['background']) ?? '').trim(),
      'deletable': true,
      'customHeaders': const <Map<String, String>>[],
      'customBody': const <Map<String, String>>[],
      'enableMemory':
          _asBool(_pickValue(raw, <String>['enableMemory', 'memoryEnabled'])) ??
          false,
      'enableRecentChatsReference':
          _asBool(
            _pickValue(raw, <String>[
              'enableRecentChatsReference',
              'recentChatsReference',
            ]),
          ) ??
          false,
      'presetMessages': const <dynamic>[],
      'regexRules': const <dynamic>[],
    };

    return _PreparedAssistant(
      sourceId: sourceId,
      sourceName: resolvedName,
      assistantData: assistantData,
    );
  }

  static _ResolvedModelRef? _resolveAssistantModel(
    Map<String, dynamic> raw, {
    required Map<String, _ResolvedModelRef> modelRefByToken,
    required Map<String, String> providerAliasMap,
  }) {
    final tokenCandidates = <String>{
      ..._nonEmptyStrings(<String?>[
        _pickString(raw, <String>['chatModelUuid', 'chat_model_uuid']),
        _pickString(raw, <String>['modelUuid', 'model_uuid']),
        _pickString(raw, <String>['chatModelId', 'chat_model_id']),
        _pickString(raw, <String>['modelId', 'model_id']),
      ]),
    };
    final nestedModel = _pickValue(raw, <String>['model', 'chatModel']);
    if (nestedModel is Map) {
      final m = _toStringDynamicMap(nestedModel);
      tokenCandidates.addAll(
        _nonEmptyStrings(<String?>[
          _pickString(m, <String>['uuid', 'modelUuid', 'id', 'modelId']),
        ]),
      );
      final providerToken =
          (_pickString(m, <String>['provider', 'providerId', 'providerKey']) ??
                  '')
              .trim();
      final modelId = (_pickString(m, <String>['modelId', 'id', 'name']) ?? '')
          .trim();
      if (providerToken.isNotEmpty && modelId.isNotEmpty) {
        final provider =
            providerAliasMap[providerToken] ??
            providerAliasMap[providerToken.toLowerCase()];
        return _ResolvedModelRef(
          providerKey: provider ?? providerToken,
          modelId: modelId,
        );
      }
    }

    for (final token in tokenCandidates) {
      final ref =
          modelRefByToken[token] ?? modelRefByToken[token.toLowerCase()];
      if (ref != null) return ref;
    }

    final providerToken =
        (_pickString(raw, <String>[
                  'chatModelProvider',
                  'provider',
                  'providerId',
                ]) ??
                '')
            .trim();
    final modelId =
        (_pickString(raw, <String>['chatModelId', 'modelId', 'model']) ?? '')
            .trim();
    if (providerToken.isNotEmpty && modelId.isNotEmpty) {
      final provider =
          providerAliasMap[providerToken] ??
          providerAliasMap[providerToken.toLowerCase()];
      return _ResolvedModelRef(
        providerKey: provider ?? providerToken,
        modelId: modelId,
      );
    }
    return null;
  }

  static String? _mapAssistantAvatar(dynamic rawAvatar) {
    if (rawAvatar == null) return null;
    if (rawAvatar is String) {
      final v = rawAvatar.trim();
      return v.isEmpty ? null : v;
    }
    if (rawAvatar is! Map) return null;
    final avatar = _toStringDynamicMap(rawAvatar);
    final type = (_pickString(avatar, <String>['type', 'runtimeType']) ?? '')
        .trim()
        .toLowerCase();
    if (type.contains('dummy')) return null;
    if (type.contains('emoji')) {
      final emoji =
          (_pickString(avatar, <String>['emoji', 'value', 'char']) ?? '')
              .trim();
      return emoji.isEmpty ? null : emoji;
    }
    if (type.contains('image')) {
      final url = (_pickString(avatar, <String>['url', 'value', 'path']) ?? '')
          .trim();
      return url.isEmpty ? null : url;
    }
    final fallback =
        (_pickString(avatar, <String>['url', 'emoji', 'value', 'path']) ?? '')
            .trim();
    return fallback.isEmpty ? null : fallback;
  }

  static int _findExistingAssistantIndex(
    List<Map<String, dynamic>> existing,
    _PreparedAssistant incoming,
  ) {
    final incomingId = incoming.sourceId.trim();
    if (incomingId.isNotEmpty) {
      final idx = existing.indexWhere(
        (e) => (_pickString(e, <String>['id']) ?? '').trim() == incomingId,
      );
      if (idx != -1) return idx;
    }

    final incomingName = _normalizeName(incoming.sourceName);
    if (incomingName.isEmpty) return -1;
    return existing.indexWhere(
      (e) =>
          _normalizeName((_pickString(e, <String>['name']) ?? '')) ==
          incomingName,
    );
  }

  static Map<String, dynamic> _mergeAssistantKeepLocal(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final next = <String, dynamic>{...local};
    for (final entry in incoming.entries) {
      final k = entry.key;
      if (k == 'id' || k == 'name') continue;
      final lv = next[k];
      if (_isEmpty(lv)) {
        next[k] = entry.value;
      }
    }
    return next;
  }

  static Future<int> _importInstructionInjections({
    required Map<String, dynamic> settingsRoot,
    required SharedPreferences prefs,
    required RestoreMode mode,
    required RikkaMergeConflictPolicy mergePolicy,
    required Map<String, String> assistantIdMap,
    required void Function(String) addWarning,
  }) async {
    final incomingRaw = _firstNonNull(<dynamic>[
      settingsRoot['modeInjections'],
      settingsRoot['mode_injections'],
      settingsRoot['instructionInjections'],
      settingsRoot['instruction_injections'],
    ]);
    final incoming = _asMapList(incomingRaw, mapKeyId: 'id');
    final existing = mode == RestoreMode.overwrite
        ? <Map<String, dynamic>>[]
        : _loadJsonList(prefs.getString(_injectionsKey));
    final next = <Map<String, dynamic>>[...existing];
    final usedIds = next
        .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final idMap = <String, String>{};

    var importedCount = 0;
    for (var i = 0; i < incoming.length; i++) {
      final prepared = _prepareInstructionInjection(incoming[i], index: i);
      if (prepared == null) continue;
      final oldId = prepared.sourceId.isNotEmpty
          ? prepared.sourceId
          : '__inj_$i';

      if (mode == RestoreMode.merge &&
          mergePolicy == RikkaMergeConflictPolicy.mergeSameItem) {
        final matchIdx = _findInjectionIndex(next, prepared);
        if (matchIdx != -1) {
          final local = next[matchIdx];
          final merged = _mergeInjectionKeepLocal(local, prepared.data);
          next[matchIdx] = merged;
          final matchId = (_pickString(merged, <String>['id']) ?? '').trim();
          if (matchId.isNotEmpty) idMap[oldId] = matchId;
          importedCount += 1;
          continue;
        }
      }

      var newId = prepared.sourceId.trim();
      if (newId.isEmpty || usedIds.contains(newId)) {
        newId = _newUuid(usedIds);
      }
      usedIds.add(newId);
      final payload = Map<String, dynamic>.from(prepared.data)..['id'] = newId;
      next.add(payload);
      idMap[oldId] = newId;
      importedCount += 1;
    }

    await prefs.setString(_injectionsKey, jsonEncode(next));

    final importedActive = _extractInjectionActiveMap(settingsRoot);
    final remappedActive = _remapActiveMap(
      importedActive,
      assistantIdMap: assistantIdMap,
      itemIdMap: idMap,
      validItemIds: next
          .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toSet(),
    );

    final existingActive = mode == RestoreMode.overwrite
        ? <String, List<String>>{}
        : _loadStringListMap(prefs.getString(_injectionsActiveByAssistantKey));
    final nextActive = _mergeActiveMaps(existingActive, remappedActive);
    await prefs.setString(
      _injectionsActiveByAssistantKey,
      jsonEncode(nextActive),
    );

    final global = nextActive[_defaultAssistantKey] ?? const <String>[];
    if (global.isEmpty) {
      await prefs.remove(_injectionsActiveIdKey);
      await prefs.remove(_injectionsActiveIdsKey);
    } else {
      await prefs.setString(_injectionsActiveIdKey, global.first);
      await prefs.setString(_injectionsActiveIdsKey, jsonEncode(global));
    }

    if (incoming.isEmpty) {
      addWarning('No mode injections found in settings.json.');
    }
    return importedCount;
  }

  static _PreparedInjection? _prepareInstructionInjection(
    Map<String, dynamic> raw, {
    required int index,
  }) {
    final id = (_pickString(raw, <String>['id', 'uuid']) ?? '').trim();
    final title =
        (_pickString(raw, <String>['title', 'name']) ??
                'Mode Injection ${index + 1}')
            .trim();
    final prompt =
        (_pickString(raw, <String>['prompt', 'content', 'text']) ?? '').trim();
    final group = (_pickString(raw, <String>['group']) ?? '').trim();
    if (prompt.isEmpty && title.isEmpty) return null;
    return _PreparedInjection(
      sourceId: id,
      title: title,
      data: <String, dynamic>{
        'id': id.isNotEmpty ? id : const Uuid().v4(),
        'title': title,
        'prompt': prompt,
        'group': group,
      },
    );
  }

  static int _findInjectionIndex(
    List<Map<String, dynamic>> existing,
    _PreparedInjection incoming,
  ) {
    final id = incoming.sourceId.trim();
    if (id.isNotEmpty) {
      final idx = existing.indexWhere(
        (e) => (_pickString(e, <String>['id']) ?? '').trim() == id,
      );
      if (idx != -1) return idx;
    }
    final name = _normalizeName(incoming.title);
    if (name.isNotEmpty) {
      final idx = existing.indexWhere(
        (e) =>
            _normalizeName((_pickString(e, <String>['title']) ?? '')) == name,
      );
      if (idx != -1) return idx;
    }
    final prompt = (_pickString(incoming.data, <String>['prompt']) ?? '')
        .trim();
    if (prompt.isNotEmpty) {
      return existing.indexWhere(
        (e) => (_pickString(e, <String>['prompt']) ?? '').trim() == prompt,
      );
    }
    return -1;
  }

  static Map<String, dynamic> _mergeInjectionKeepLocal(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final next = <String, dynamic>{...local};
    if (_isEmpty(next['title'])) next['title'] = incoming['title'];
    if (_isEmpty(next['prompt'])) next['prompt'] = incoming['prompt'];
    if (_isEmpty(next['group'])) next['group'] = incoming['group'];
    return next;
  }

  static Future<int> _importWorldBooks({
    required Map<String, dynamic> settingsRoot,
    required SharedPreferences prefs,
    required RestoreMode mode,
    required RikkaMergeConflictPolicy mergePolicy,
    required Map<String, String> assistantIdMap,
    required void Function(String) addWarning,
  }) async {
    final incomingRaw = _firstNonNull(<dynamic>[
      settingsRoot['lorebooks'],
      settingsRoot['loreBooks'],
      settingsRoot['worldBooks'],
      settingsRoot['world_books'],
    ]);
    final incoming = _asMapList(incomingRaw, mapKeyId: 'id');

    final existing = mode == RestoreMode.overwrite
        ? <Map<String, dynamic>>[]
        : _loadJsonList(prefs.getString(_worldBooksKey));
    final next = <Map<String, dynamic>>[...existing];
    final usedIds = next
        .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final idMap = <String, String>{};
    var importedCount = 0;

    for (var i = 0; i < incoming.length; i++) {
      final prepared = _prepareWorldBook(incoming[i], index: i);
      if (prepared == null) continue;
      final oldId = prepared.sourceId.isNotEmpty
          ? prepared.sourceId
          : '__book_$i';

      if (mode == RestoreMode.merge &&
          mergePolicy == RikkaMergeConflictPolicy.mergeSameItem) {
        final matchIdx = _findWorldBookIndex(next, prepared);
        if (matchIdx != -1) {
          final local = next[matchIdx];
          final merged = _mergeWorldBookKeepLocal(local, prepared.data);
          next[matchIdx] = merged;
          final matchId = (_pickString(merged, <String>['id']) ?? '').trim();
          if (matchId.isNotEmpty) idMap[oldId] = matchId;
          importedCount += 1;
          continue;
        }
      }

      var newId = prepared.sourceId.trim();
      if (newId.isEmpty || usedIds.contains(newId)) {
        newId = _newUuid(usedIds);
      }
      usedIds.add(newId);
      final payload = Map<String, dynamic>.from(prepared.data)..['id'] = newId;
      next.add(payload);
      idMap[oldId] = newId;
      importedCount += 1;
    }

    await prefs.setString(_worldBooksKey, jsonEncode(next));

    final importedActive = _extractWorldBookActiveMap(settingsRoot);
    final remappedActive = _remapActiveMap(
      importedActive,
      assistantIdMap: assistantIdMap,
      itemIdMap: idMap,
      validItemIds: next
          .map((e) => (_pickString(e, <String>['id']) ?? '').trim())
          .where((e) => e.isNotEmpty)
          .toSet(),
    );
    final existingActive = mode == RestoreMode.overwrite
        ? <String, List<String>>{}
        : _loadStringListMap(prefs.getString(_worldBooksActiveByAssistantKey));
    final nextActive = _mergeActiveMaps(existingActive, remappedActive);
    await prefs.setString(
      _worldBooksActiveByAssistantKey,
      jsonEncode(nextActive),
    );

    if (incoming.isEmpty) {
      addWarning('No lorebooks found in settings.json.');
    }
    return importedCount;
  }

  static _PreparedWorldBook? _prepareWorldBook(
    Map<String, dynamic> raw, {
    required int index,
  }) {
    final id = (_pickString(raw, <String>['id', 'uuid']) ?? '').trim();
    final name =
        (_pickString(raw, <String>['name', 'title']) ?? 'Lorebook ${index + 1}')
            .trim();
    final description =
        (_pickString(raw, <String>['description', 'desc']) ?? '').trim();
    final enabled =
        _asBool(_pickValue(raw, <String>['enabled', 'isEnabled'])) ?? true;

    final entryRaw = _firstNonNull(<dynamic>[raw['entries'], raw['items']]);
    final entries = _asMapList(entryRaw, mapKeyId: 'id')
        .map((e) {
          final entry = _buildWorldBookEntry(e);
          return entry.toJson();
        })
        .toList(growable: false);

    return _PreparedWorldBook(
      sourceId: id,
      name: name,
      data: <String, dynamic>{
        'id': id.isNotEmpty ? id : const Uuid().v4(),
        'name': name,
        'description': description,
        'enabled': enabled,
        'entries': entries,
      },
    );
  }

  static WorldBookEntry _buildWorldBookEntry(Map<String, dynamic> raw) {
    final id = (_pickString(raw, <String>['id', 'uuid']) ?? const Uuid().v4())
        .trim();
    final name = (_pickString(raw, <String>['name', 'title']) ?? '').trim();
    final enabled =
        _asBool(_pickValue(raw, <String>['enabled', 'isEnabled'])) ?? true;
    final priority = _asInt(_pickValue(raw, <String>['priority'])) ?? 0;
    final position = WorldBookInjectionPositionJson.fromJson(
      _pickValue(raw, <String>['position', 'injectPosition']),
    );
    final content =
        (_pickString(raw, <String>['content', 'text', 'prompt']) ?? '').trim();
    final injectDepth =
        _asInt(_pickValue(raw, <String>['injectDepth', 'depth'])) ?? 4;
    final role = WorldBookInjectionRoleJson.fromJson(
      _pickValue(raw, <String>['role']),
    );
    final keywords = _stringList(_pickValue(raw, <String>['keywords', 'keys']));
    final useRegex = _asBool(_pickValue(raw, <String>['useRegex'])) ?? false;
    final caseSensitive =
        _asBool(_pickValue(raw, <String>['caseSensitive'])) ?? false;
    final scanDepth = _asInt(_pickValue(raw, <String>['scanDepth'])) ?? 4;
    final constantActive =
        _asBool(_pickValue(raw, <String>['constantActive'])) ?? false;
    return WorldBookEntry(
      id: id,
      name: name,
      enabled: enabled,
      priority: priority,
      position: position,
      content: content,
      injectDepth: injectDepth,
      role: role,
      keywords: keywords,
      useRegex: useRegex,
      caseSensitive: caseSensitive,
      scanDepth: scanDepth,
      constantActive: constantActive,
    );
  }

  static int _findWorldBookIndex(
    List<Map<String, dynamic>> existing,
    _PreparedWorldBook incoming,
  ) {
    final id = incoming.sourceId.trim();
    if (id.isNotEmpty) {
      final idx = existing.indexWhere(
        (e) => (_pickString(e, <String>['id']) ?? '').trim() == id,
      );
      if (idx != -1) return idx;
    }
    final name = _normalizeName(incoming.name);
    if (name.isEmpty) return -1;
    return existing.indexWhere(
      (e) => _normalizeName((_pickString(e, <String>['name']) ?? '')) == name,
    );
  }

  static Map<String, dynamic> _mergeWorldBookKeepLocal(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final next = <String, dynamic>{...local};
    if (_isEmpty(next['description']))
      next['description'] = incoming['description'];
    if (_isEmpty(next['entries'])) next['entries'] = incoming['entries'];
    final localEnabled = _asBool(next['enabled']) ?? false;
    if (!localEnabled && _asBool(incoming['enabled']) == true) {
      next['enabled'] = true;
    }
    return next;
  }

  static Map<String, List<String>> _mergeActiveMaps(
    Map<String, List<String>> existing,
    Map<String, List<String>> incoming,
  ) {
    if (incoming.isEmpty) return existing;
    final out = <String, List<String>>{
      for (final entry in existing.entries)
        entry.key: entry.value.toSet().toList(growable: false),
    };
    for (final entry in incoming.entries) {
      final set = <String>{
        ...(out[entry.key] ?? const <String>[]),
        ...entry.value,
      };
      out[entry.key] = set.toList(growable: false);
    }
    return out;
  }

  static Map<String, List<String>> _extractInjectionActiveMap(
    Map<String, dynamic> settingsRoot,
  ) {
    final explicit = _parseActiveMap(
      _firstNonNull(<dynamic>[
        settingsRoot['modeInjectionsActiveIdsByAssistant'],
        settingsRoot['mode_injections_active_ids_by_assistant'],
        settingsRoot['instructionInjectionsActiveIdsByAssistant'],
        settingsRoot['instruction_injections_active_ids_by_assistant'],
      ]),
    );
    if (explicit.isNotEmpty) return explicit;
    return _extractAssistantEmbeddedActiveMap(
      settingsRoot,
      candidates: <String>[
        'activeModeInjectionIds',
        'modeInjectionIds',
        'modeInjections',
        'instructionInjectionIds',
        'activeInstructionInjectionIds',
      ],
    );
  }

  static Map<String, List<String>> _extractWorldBookActiveMap(
    Map<String, dynamic> settingsRoot,
  ) {
    final explicit = _parseActiveMap(
      _firstNonNull(<dynamic>[
        settingsRoot['lorebooksActiveIdsByAssistant'],
        settingsRoot['lorebooks_active_ids_by_assistant'],
        settingsRoot['worldBooksActiveIdsByAssistant'],
        settingsRoot['world_books_active_ids_by_assistant'],
      ]),
    );
    if (explicit.isNotEmpty) return explicit;
    return _extractAssistantEmbeddedActiveMap(
      settingsRoot,
      candidates: <String>[
        'activeLorebookIds',
        'lorebookIds',
        'lorebooks',
        'activeWorldBookIds',
        'worldBookIds',
      ],
    );
  }

  static Map<String, List<String>> _extractAssistantEmbeddedActiveMap(
    Map<String, dynamic> settingsRoot, {
    required List<String> candidates,
  }) {
    final out = <String, List<String>>{};
    final assistants = _asMapList(settingsRoot['assistants'], mapKeyId: 'id');
    for (final assistant in assistants) {
      final id =
          (_pickString(assistant, <String>[
                    'id',
                    'uuid',
                    'assistantId',
                    'assistant_id',
                  ]) ??
                  '')
              .trim();
      if (id.isEmpty) continue;
      List<String> active = const <String>[];
      for (final key in candidates) {
        final parsed = _extractIds(_pickValue(assistant, <String>[key]));
        if (parsed.isNotEmpty) {
          active = parsed;
          break;
        }
      }
      if (active.isEmpty) continue;
      out[id] = active;
    }
    return out;
  }

  static Map<String, List<String>> _parseActiveMap(dynamic raw) {
    if (raw == null) return <String, List<String>>{};
    final out = <String, List<String>>{};
    if (raw is Map) {
      final map = _toStringDynamicMap(raw);
      map.forEach((key, value) {
        final ids = _extractIds(value);
        if (ids.isEmpty) return;
        out[key.trim().isEmpty ? _defaultAssistantKey : key.trim()] = ids;
      });
      return out;
    }
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final map = _toStringDynamicMap(item);
        final assistantId =
            (_pickString(map, <String>[
                      'assistantId',
                      'assistant_id',
                      'id',
                      'key',
                    ]) ??
                    '')
                .trim();
        final ids = _extractIds(
          _pickValue(map, <String>['ids', 'activeIds', 'items']),
        );
        if (ids.isEmpty) continue;
        out[assistantId.isEmpty ? _defaultAssistantKey : assistantId] = ids;
      }
    }
    return out;
  }

  static Map<String, List<String>> _remapActiveMap(
    Map<String, List<String>> source, {
    required Map<String, String> assistantIdMap,
    required Map<String, String> itemIdMap,
    required Set<String> validItemIds,
  }) {
    if (source.isEmpty) return <String, List<String>>{};
    final out = <String, List<String>>{};
    source.forEach((assistant, ids) {
      final normalizedAssistant = assistant.trim();
      final mappedAssistant =
          (normalizedAssistant.isEmpty ||
              normalizedAssistant == _defaultAssistantKey)
          ? _defaultAssistantKey
          : (assistantIdMap[normalizedAssistant] ??
                assistantIdMap[normalizedAssistant.toLowerCase()] ??
                normalizedAssistant);
      final mappedIds = <String>{};
      for (final oldId in ids) {
        final clean = oldId.trim();
        if (clean.isEmpty) continue;
        final mapped =
            itemIdMap[clean] ?? itemIdMap[clean.toLowerCase()] ?? clean;
        if (validItemIds.contains(mapped)) mappedIds.add(mapped);
      }
      if (mappedIds.isEmpty) return;
      out[mappedAssistant] = mappedIds.toList(growable: false);
    });
    return out;
  }

  static Future<String?> _extractSqliteDatabase(
    Archive archive,
    Directory tempDir,
  ) async {
    ArchiveFile? dbFile;
    ArchiveFile? walFile;
    ArchiveFile? shmFile;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final base = p.basename(entry.name.replaceAll('\\', '/')).toLowerCase();
      if (base == 'rikka_hub.db' || base == 'rikka_hub') {
        dbFile ??= entry;
      } else if (base == 'rikka_hub.db-wal' || base == 'rikka_hub-wal') {
        walFile ??= entry;
      } else if (base == 'rikka_hub.db-shm' || base == 'rikka_hub-shm') {
        shmFile ??= entry;
      }
    }
    if (dbFile == null) return null;

    final dbPath = p.join(tempDir.path, 'rikka_hub.db');
    await File(dbPath).writeAsBytes(_archiveFileBytes(dbFile), flush: true);
    if (walFile != null) {
      await File(
        '$dbPath-wal',
      ).writeAsBytes(_archiveFileBytes(walFile), flush: true);
    }
    if (shmFile != null) {
      await File(
        '$dbPath-shm',
      ).writeAsBytes(_archiveFileBytes(shmFile), flush: true);
    }
    return dbPath;
  }

  static Future<(int, int)> _importConversationsFromDb({
    required String dbPath,
    required ChatService chatService,
    required RestoreMode mode,
    required RikkaMergeConflictPolicy mergePolicy,
    required Map<String, String> assistantIdMap,
    required Set<String> validAssistantIds,
    required _UploadFileIndex uploadIndex,
    required void Function(String) addWarning,
  }) async {
    Database? db;
    try {
      db = sqlite3.open(dbPath);
    } catch (e) {
      throw RikkaHubImportException('Unable to open rikka_hub.db: $e');
    }

    try {
      final tableRows = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.trim().isNotEmpty)
          .toList(growable: false);
      final convTable = _pickTableName(tableRows, <String>[
        'conversationentity',
        'conversation_entity',
        'conversation',
      ]);
      final nodeTable = _pickTableName(tableRows, <String>[
        'message_node',
        'messagenode',
      ]);
      if (convTable == null) {
        addWarning('ConversationEntity table not found in sqlite database.');
        return (0, 0);
      }
      if (nodeTable == null) {
        addWarning('message_node table not found in sqlite database.');
        return (0, 0);
      }

      final convRows = _resultToMaps(db.select('SELECT * FROM "$convTable"'));
      final nodeRows = _resultToMaps(db.select('SELECT * FROM "$nodeTable"'));

      final nodesByConvId = <String, List<_NodeRecord>>{};
      for (var i = 0; i < nodeRows.length; i++) {
        final row = nodeRows[i];
        final convId =
            (_pickString(row, <String>[
                      'conversationId',
                      'conversation_id',
                      'conversationEntityId',
                      'conversation_entity_id',
                      'chatId',
                    ]) ??
                    '')
                .trim();
        if (convId.isEmpty) continue;
        final nodeId =
            (_pickString(row, <String>['id', 'nodeId', 'uuid']) ??
                    const Uuid().v4())
                .trim();
        final nodeIndex =
            _asInt(
              _pickValue(row, <String>['node_index', 'nodeIndex', 'index']),
            ) ??
            i;
        final selectIndex =
            _asInt(
              _pickValue(row, <String>[
                'select_index',
                'selectIndex',
                'selectedIndex',
              ]),
            ) ??
            0;
        final messages = _decodeListOfMaps(
          _pickValue(row, <String>[
            'messages',
            'messageList',
            'message_list',
            'items',
          ]),
        );
        if (messages.isEmpty) continue;
        (nodesByConvId[convId] ??= <_NodeRecord>[]).add(
          _NodeRecord(
            id: nodeId.isEmpty ? const Uuid().v4() : nodeId,
            index: nodeIndex,
            selectIndex: selectIndex,
            messages: messages,
          ),
        );
      }
      for (final list in nodesByConvId.values) {
        list.sort((a, b) => a.index.compareTo(b.index));
      }

      final existingConversations = chatService.getAllConversations();
      final existingConvIds = existingConversations.map((e) => e.id).toSet();
      final existingTitles = existingConversations
          .map((e) => e.title.trim())
          .toSet();
      final usedConvIds = <String>{...existingConvIds};
      final usedMsgIds = <String>{};
      if (mode == RestoreMode.merge) {
        for (final c in existingConversations) {
          for (final m in chatService.getMessages(c.id)) {
            usedMsgIds.add(m.id);
          }
        }
      }

      var convCount = 0;
      var msgCount = 0;
      for (final convRow in convRows) {
        final oldConvId =
            (_pickString(convRow, <String>['id', 'conversationId']) ?? '')
                .trim();
        if (oldConvId.isEmpty) continue;

        final title =
            (_pickString(convRow, <String>['title', 'name']) ?? 'Imported')
                .trim();
        final createdAt =
            _parseDateTime(
              _pickValue(convRow, <String>[
                'createdAt',
                'createAt',
                'created_at',
              ]),
            ) ??
            DateTime.now();
        final updatedAt =
            _parseDateTime(
              _pickValue(convRow, <String>[
                'updatedAt',
                'updateAt',
                'updated_at',
              ]),
            ) ??
            createdAt;
        final isPinned =
            _asBool(
              _pickValue(convRow, <String>['isPinned', 'is_pinned', 'pinned']),
            ) ??
            false;
        final oldAssistantId =
            (_pickString(convRow, <String>['assistantId', 'assistant_id']) ??
                    '')
                .trim();
        final mappedAssistantId = oldAssistantId.isEmpty
            ? null
            : (assistantIdMap[oldAssistantId] ??
                  assistantIdMap[oldAssistantId.toLowerCase()] ??
                  oldAssistantId);
        final assistantId =
            (mappedAssistantId != null &&
                validAssistantIds.contains(mappedAssistantId))
            ? mappedAssistantId
            : null;
        var truncateIndex =
            _asInt(
              _pickValue(convRow, <String>['truncateIndex', 'truncate_index']),
            ) ??
            -1;

        final nodes = nodesByConvId[oldConvId] ?? const <_NodeRecord>[];
        final built = convertMessageNodesForTest(
          nodeRows: [
            for (final n in nodes)
              <String, dynamic>{
                'id': n.id,
                'node_index': n.index,
                'select_index': n.selectIndex,
                'messages': n.messages,
              },
          ],
          conversationId: oldConvId,
          fallbackTimestamp: updatedAt,
          basenameToPath: uploadIndex.byBasename,
          relativeToPath: uploadIndex.byRelative,
        );

        final messages = <ChatMessage>[];
        final groupVersionCounter = <String, int>{};
        for (final m in built.messages) {
          var msgId = m.id.trim();
          if (msgId.isEmpty) {
            msgId = _newUuid(usedMsgIds);
          }
          if (usedMsgIds.contains(msgId)) {
            if (mode == RestoreMode.merge &&
                mergePolicy == RikkaMergeConflictPolicy.mergeSameItem) {
              addWarning('Skipped duplicated message id "$msgId".');
              continue;
            }
            msgId = _newUuid(usedMsgIds);
          }
          usedMsgIds.add(msgId);
          final gid = (m.groupId ?? m.id).trim().isEmpty
              ? const Uuid().v4()
              : (m.groupId ?? m.id).trim();
          final nextVersion = groupVersionCounter[gid] ?? 0;
          groupVersionCounter[gid] = nextVersion + 1;
          messages.add(
            m.copyWith(
              id: msgId,
              conversationId: oldConvId,
              groupId: gid,
              version: nextVersion,
            ),
          );
        }
        final versionSelections = <String, int>{};
        for (final entry in built.versionSelections.entries) {
          final count = groupVersionCounter[entry.key] ?? 0;
          if (count <= 0) continue;
          var selected = entry.value;
          if (selected < 0) selected = 0;
          if (selected >= count) selected = count - 1;
          versionSelections[entry.key] = selected;
        }

        if (truncateIndex > messages.length) truncateIndex = messages.length;
        if (truncateIndex < -1) truncateIndex = -1;

        var targetConvId = oldConvId;
        var targetTitle = title;
        final collision = usedConvIds.contains(targetConvId);
        if (mode == RestoreMode.merge && collision) {
          if (mergePolicy == RikkaMergeConflictPolicy.duplicateOnConflict) {
            targetConvId = _newUuid(usedConvIds);
            targetTitle = _uniqueDisplayName(
              targetTitle.isEmpty ? 'Imported' : targetTitle,
              existingTitles,
              forceRikkaSuffix: true,
            );
          }
        } else if (mode == RestoreMode.overwrite && collision) {
          targetConvId = _newUuid(usedConvIds);
        }

        if (targetConvId != oldConvId) {
          for (var i = 0; i < messages.length; i++) {
            messages[i] = messages[i].copyWith(conversationId: targetConvId);
          }
        }

        if (mode == RestoreMode.merge &&
            mergePolicy == RikkaMergeConflictPolicy.mergeSameItem &&
            existingConvIds.contains(oldConvId)) {
          final existingMessages = chatService.getMessages(oldConvId);
          final maxVersionByGroup = <String, int>{};
          for (final em in existingMessages) {
            final gid = (em.groupId ?? em.id).trim();
            if (gid.isEmpty) continue;
            final maxV = maxVersionByGroup[gid];
            if (maxV == null || em.version > maxV) {
              maxVersionByGroup[gid] = em.version;
            }
          }
          final offsetByGroup = <String, int>{};
          final adjustedMessages = <ChatMessage>[];
          for (final m in messages) {
            final gid = (m.groupId ?? m.id).trim();
            final baseOffset = offsetByGroup.putIfAbsent(
              gid,
              () => (maxVersionByGroup[gid] ?? -1) + 1,
            );
            final adjustedVersion = baseOffset + m.version;
            final currentMax = maxVersionByGroup[gid];
            if (currentMax == null || adjustedVersion > currentMax) {
              maxVersionByGroup[gid] = adjustedVersion;
            }
            adjustedMessages.add(
              m.copyWith(conversationId: oldConvId, version: adjustedVersion),
            );
          }
          for (final m in adjustedMessages) {
            await chatService.addMessageDirectly(oldConvId, m);
            msgCount += 1;
          }
          final adjustedSelections = <String, int>{};
          for (final entry in versionSelections.entries) {
            final offset = offsetByGroup[entry.key];
            if (offset == null) continue;
            adjustedSelections[entry.key] = offset + entry.value;
          }
          final existing = chatService.getConversation(oldConvId);
          if (existing != null) {
            if (!existing.isPinned && isPinned) existing.isPinned = true;
            if ((existing.assistantId == null ||
                    existing.assistantId!.trim().isEmpty) &&
                assistantId != null) {
              existing.assistantId = assistantId;
            }
            if (existing.title.trim().isEmpty &&
                targetTitle.trim().isNotEmpty) {
              existing.title = targetTitle;
            }
            if (truncateIndex >= 0 && existing.truncateIndex < 0) {
              existing.truncateIndex = truncateIndex;
            }
            if (updatedAt.isAfter(existing.updatedAt)) {
              existing.updatedAt = updatedAt;
            }
            for (final entry in adjustedSelections.entries) {
              existing.versionSelections[entry.key] = entry.value;
            }
            await existing.save();
          }
          if (adjustedMessages.isNotEmpty) convCount += 1;
          continue;
        }

        final conversation = Conversation(
          id: targetConvId,
          title: targetTitle.isEmpty ? 'Imported' : targetTitle,
          createdAt: createdAt,
          updatedAt: updatedAt,
          isPinned: isPinned,
          assistantId: assistantId,
          truncateIndex: truncateIndex,
          versionSelections: Map<String, int>.from(versionSelections),
        );
        await chatService.restoreConversation(conversation, messages);
        convCount += 1;
        msgCount += messages.length;
        usedConvIds.add(targetConvId);
        existingTitles.add(targetTitle);
      }
      return (convCount, msgCount);
    } finally {
      try {
        db.dispose();
      } catch (_) {}
    }
  }

  static ChatMessage? _convertUiMessageToChatMessage({
    required Map<String, dynamic> uiMessage,
    required String conversationId,
    required String groupId,
    required int version,
    required DateTime fallbackTimestamp,
    required _UploadFileIndex uploadIndex,
    required void Function(String) addWarning,
  }) {
    final rawRole =
        (_pickString(uiMessage, <String>['role', 'messageRole', 'type']) ??
                'assistant')
            .trim()
            .toLowerCase();
    String role;
    var systemPrefix = '';
    switch (rawRole) {
      case 'user':
        role = 'user';
        break;
      case 'assistant':
        role = 'assistant';
        break;
      case 'tool':
        role = 'tool';
        break;
      case 'system':
        role = 'assistant';
        systemPrefix = '[System]\n';
        break;
      default:
        role = 'assistant';
    }

    final partObjects = _decodeListOfMaps(
      _pickValue(uiMessage, <String>['parts', 'messageParts', 'contentParts']),
    );
    final convertedParts = <String>[];
    if (partObjects.isNotEmpty) {
      for (final part in partObjects) {
        final converted = _convertMessagePart(
          part,
          role: role,
          uploadIndex: uploadIndex,
          addWarning: addWarning,
        );
        if (converted.trim().isEmpty) continue;
        convertedParts.add(converted.trim());
      }
    }

    if (convertedParts.isEmpty) {
      final fallbackText =
          (_pickString(uiMessage, <String>['content', 'text', 'message']) ?? '')
              .trim();
      if (fallbackText.isNotEmpty) convertedParts.add(fallbackText);
    }

    if (role == 'tool' && convertedParts.isEmpty) {
      final payload = _pickValue(uiMessage, <String>[
        'tool',
        'payload',
        'data',
      ]);
      if (payload != null) {
        try {
          convertedParts.add(jsonEncode(payload));
        } catch (_) {
          convertedParts.add(payload.toString());
        }
      }
    }

    final content = '$systemPrefix${convertedParts.join('\n').trim()}'
        .trimRight();
    final messageId =
        (_pickString(uiMessage, <String>['id', 'messageId', 'uuid']) ??
                const Uuid().v4())
            .trim();
    final timestamp =
        _parseDateTime(
          _pickValue(uiMessage, <String>[
            'timestamp',
            'createdAt',
            'created_at',
            'time',
            'updatedAt',
          ]),
        ) ??
        fallbackTimestamp;
    final modelId =
        (_pickString(uiMessage, <String>['modelId', 'model_id', 'model']) ?? '')
            .trim();
    final providerId =
        (_pickString(uiMessage, <String>[
                  'providerId',
                  'provider_id',
                  'provider',
                ]) ??
                '')
            .trim();
    final totalTokens = _asInt(
      _firstNonNull(<dynamic>[
        _pickValue(uiMessage, <String>['totalTokens', 'total_tokens']),
        _pickNested(uiMessage, <String>['usage', 'totalTokens']),
        _pickNested(uiMessage, <String>['usage', 'total_tokens']),
      ]),
    );

    return ChatMessage(
      id: messageId.isEmpty ? const Uuid().v4() : messageId,
      role: role,
      content: content,
      timestamp: timestamp,
      modelId: modelId.isEmpty ? null : modelId,
      providerId: providerId.isEmpty ? null : providerId,
      totalTokens: totalTokens,
      conversationId: conversationId,
      groupId: groupId,
      version: version,
    );
  }

  static String _convertMessagePart(
    Map<String, dynamic> part, {
    required String role,
    required _UploadFileIndex uploadIndex,
    required void Function(String) addWarning,
  }) {
    final partType = _partTypeName(part);
    final text =
        (_pickString(part, <String>['text', 'content', 'value', 'message']) ??
                '')
            .trim();

    if (partType == 'text' || (partType.isEmpty && text.isNotEmpty)) {
      return text;
    }

    if (partType == 'reasoning' || partType == 'think') {
      if (text.isEmpty) return '';
      return '<think>\n$text\n</think>';
    }

    if (partType == 'tool') {
      final payload = _firstNonNull(<dynamic>[
        _pickValue(part, <String>['payload', 'tool', 'data']),
        part,
      ]);
      try {
        return jsonEncode(payload);
      } catch (_) {
        return payload?.toString() ?? '';
      }
    }

    final isImage = partType.contains('image');
    final isFileLike =
        isImage ||
        partType.contains('document') ||
        partType.contains('video') ||
        partType.contains('audio') ||
        partType.contains('file');
    if (!isFileLike) {
      return text;
    }

    final rawPath =
        (_pickString(part, <String>[
                  'path',
                  'filePath',
                  'file_path',
                  'url',
                  'uri',
                  'src',
                ]) ??
                '')
            .trim();
    if (rawPath.isEmpty) return text;
    final rewritten = _rewriteFileReference(
      rawPath,
      uploadIndex: uploadIndex,
      addWarning: addWarning,
    );
    final fileName =
        (_pickString(part, <String>['name', 'fileName', 'filename']) ?? '')
            .trim();
    final mime = (_pickString(part, <String>['mime', 'mimeType', 'type']) ?? '')
        .trim();
    final safeName = fileName.isEmpty ? p.basename(rewritten) : fileName;
    final safeMime = mime.isEmpty
        ? (isImage ? 'image/png' : 'application/octet-stream')
        : mime;

    if (role == 'assistant') {
      if (isImage) return '![]($rewritten)';
      return '[$safeName]($rewritten)';
    }
    if (isImage) {
      return '[image:$rewritten]';
    }
    return '[file:$rewritten|$safeName|$safeMime]';
  }

  static String _partTypeName(Map<String, dynamic> part) {
    final raw =
        (_pickString(part, <String>['type', 'kind', 'runtimeType']) ?? '')
            .trim()
            .toLowerCase();
    if (raw.contains('text')) return 'text';
    if (raw.contains('reasoning') || raw.contains('think')) return 'reasoning';
    if (raw.contains('image')) return 'image';
    if (raw.contains('document')) return 'document';
    if (raw.contains('video')) return 'video';
    if (raw.contains('audio')) return 'audio';
    if (raw.contains('tool')) return 'tool';
    if (raw.contains('file')) return 'file';
    return raw;
  }

  static String _rewriteFileReference(
    String rawPath, {
    required _UploadFileIndex uploadIndex,
    required void Function(String) addWarning,
  }) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) return rawPath;
    if (uploadIndex.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }

    var normalized = trimmed;
    if (normalized.startsWith('file://')) {
      try {
        final uri = Uri.parse(normalized);
        normalized = uri.toFilePath(windows: Platform.isWindows);
      } catch (_) {
        normalized = normalized.substring('file://'.length);
      }
    }
    normalized = Uri.decodeFull(normalized).replaceAll('\\', '/');

    String? rel;
    final idx = normalized.toLowerCase().lastIndexOf('/upload/');
    if (idx != -1) {
      rel = normalized.substring(idx + '/upload/'.length).toLowerCase();
    } else if (!normalized.startsWith('/')) {
      rel = normalized.toLowerCase();
    }
    if (rel != null && rel.isNotEmpty) {
      final match = uploadIndex.byRelative[rel];
      if (match != null && match.isNotEmpty) return match;
    }

    final base = p.basename(normalized).toLowerCase();
    final byName = uploadIndex.byBasename[base];
    if (byName != null && byName.isNotEmpty) return byName;

    addWarning('Referenced file not found in upload payload: $rawPath');
    return normalized;
  }

  static String? _pickTableName(
    List<String> tableNames,
    List<String> candidates,
  ) {
    final lower = <String, String>{
      for (final name in tableNames) name.toLowerCase(): name,
    };
    for (final c in candidates) {
      final m = lower[c.toLowerCase()];
      if (m != null) return m;
    }
    return null;
  }

  static List<Map<String, dynamic>> _resultToMaps(ResultSet result) {
    final cols = result.columnNames;
    final out = <Map<String, dynamic>>[];
    for (final row in result) {
      final map = <String, dynamic>{};
      for (final c in cols) {
        map[c] = row[c];
      }
      out.add(map);
    }
    return out;
  }

  static List<Map<String, dynamic>> _asMapList(
    dynamic raw, {
    String? mapKeyId,
  }) {
    final out = <Map<String, dynamic>>[];
    if (raw == null) return out;
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) out.add(_toStringDynamicMap(item));
      }
      return out;
    }
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is! Map) return;
        final map = _toStringDynamicMap(value);
        if (mapKeyId != null &&
            (_pickString(map, <String>[mapKeyId]) ?? '').trim().isEmpty) {
          map[mapKeyId] = key.toString();
        }
        out.add(map);
      });
      return out;
    }
    return out;
  }

  static List<Map<String, dynamic>> _decodeListOfMaps(dynamic raw) {
    if (raw == null) return const <Map<String, dynamic>>[];
    dynamic decoded = raw;
    if (raw is Uint8List) {
      decoded = utf8.decode(raw, allowMalformed: true);
    }
    if (decoded is String) {
      final text = decoded.trim();
      if (text.isEmpty) return const <Map<String, dynamic>>[];
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
    if (decoded is List) {
      return [
        for (final item in decoded)
          if (item is Map) _toStringDynamicMap(item),
      ];
    }
    if (decoded is Map) {
      if (decoded['items'] is List) {
        return _decodeListOfMaps(decoded['items']);
      }
      return <Map<String, dynamic>>[_toStringDynamicMap(decoded)];
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _toStringDynamicMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _loadJsonList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final list = jsonDecode(raw);
      if (list is List) {
        return [
          for (final item in list)
            if (item is Map) _toStringDynamicMap(item),
        ];
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _loadJsonMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Map<String, List<String>> _loadStringListMap(String? raw) {
    final out = <String, List<String>>{};
    if (raw == null || raw.trim().isEmpty) return out;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          out[key.toString()] = _extractIds(value);
        });
      }
    } catch (_) {}
    return out;
  }

  static List<String> _extractIds(dynamic raw) {
    if (raw is List) {
      final out = <String>{};
      for (final item in raw) {
        if (item is Map) {
          final map = _toStringDynamicMap(item);
          final id = (_pickString(map, <String>['id', 'uuid', 'value']) ?? '')
              .trim();
          if (id.isNotEmpty) out.add(id);
        } else {
          final id = item.toString().trim();
          if (id.isNotEmpty) out.add(id);
        }
      }
      return out.toList(growable: false);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String>[];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) return _extractIds(decoded);
      } catch (_) {
        return <String>[trimmed];
      }
    }
    if (raw is Map) {
      final map = _toStringDynamicMap(raw);
      final id = (_pickString(map, <String>['id', 'uuid', 'value']) ?? '')
          .trim();
      if (id.isNotEmpty) return <String>[id];
    }
    return const <String>[];
  }

  static dynamic _firstNonNull(List<dynamic> values) {
    for (final v in values) {
      if (v != null) return v;
    }
    return null;
  }

  static dynamic _pickValue(Map<String, dynamic> map, List<String> keys) {
    if (map.isEmpty) return null;
    for (final key in keys) {
      if (map.containsKey(key)) return map[key];
    }
    final lower = <String, dynamic>{
      for (final entry in map.entries) entry.key.toLowerCase(): entry.value,
    };
    for (final key in keys) {
      final value = lower[key.toLowerCase()];
      if (value != null) return value;
    }
    return null;
  }

  static dynamic _pickNested(Map<String, dynamic> map, List<String> path) {
    dynamic cur = map;
    for (final segment in path) {
      if (cur is! Map) return null;
      final cast = _toStringDynamicMap(cur);
      cur = _pickValue(cast, <String>[segment]);
      if (cur == null) return null;
    }
    return cur;
  }

  static String? _pickString(Map<String, dynamic> map, List<String> keys) {
    final value = _pickValue(map, keys);
    if (value == null) return null;
    return value.toString();
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is num) {
      final n = value.toInt();
      if (n <= 0) return null;
      if (n > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(n);
      }
      return DateTime.fromMillisecondsSinceEpoch(n * 1000);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final asInt = int.tryParse(text);
    if (asInt != null) return _parseDateTime(asInt);
    return DateTime.tryParse(text);
  }

  static String _sanitizeKey(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'[\r\n\t]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'RikkaHub' : cleaned;
  }

  static String _normalizeName(String raw) {
    return raw.trim().toLowerCase();
  }

  static String _normalizeBaseUrl(String raw) {
    var s = raw.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s.toLowerCase();
  }

  static bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    if (value is Map) return value.isEmpty;
    return false;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static Iterable<String> _nonEmptyStrings(Iterable<String?> values) sync* {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) yield t;
    }
  }

  static String _uniqueKey(
    String base,
    Set<String> used, {
    bool forceRikkaSuffix = false,
  }) {
    final normalizedBase = _sanitizeKey(base);
    if (!forceRikkaSuffix && !used.contains(normalizedBase))
      return normalizedBase;

    var i = 1;
    while (true) {
      final suffix = i == 1 ? ' (RikkaHub)' : ' (RikkaHub $i)';
      final candidate = '$normalizedBase$suffix';
      if (!used.contains(candidate)) return candidate;
      i += 1;
    }
  }

  static String _uniqueDisplayName(
    String base,
    Set<String> used, {
    bool forceRikkaSuffix = false,
  }) {
    final normalized = base.trim().isEmpty ? 'Imported' : base.trim();
    if (!forceRikkaSuffix && !used.contains(normalized)) return normalized;
    var i = 1;
    while (true) {
      final suffix = i == 1 ? ' (RikkaHub)' : ' (RikkaHub $i)';
      final candidate = '$normalized$suffix';
      if (!used.contains(candidate)) return candidate;
      i += 1;
    }
  }

  static String _newUuid(Set<String> usedIds) {
    while (true) {
      final id = const Uuid().v4();
      if (!usedIds.contains(id)) return id;
    }
  }

  static Map<String, String> _normalizeStringMapKeys(
    Map<String, String> input,
  ) {
    final out = <String, String>{};
    input.forEach((key, value) {
      final k = key.trim().toLowerCase();
      final v = value.trim();
      if (k.isEmpty || v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }
}

class _ProviderImportContext {
  final int importedCount;
  final Map<String, _ResolvedModelRef> modelRefByToken;
  final Map<String, String> providerAliasMap;

  const _ProviderImportContext({
    required this.importedCount,
    required this.modelRefByToken,
    required this.providerAliasMap,
  });
}

class _ResolvedModelRef {
  final String providerKey;
  final String modelId;
  const _ResolvedModelRef({required this.providerKey, required this.modelId});
}

class _ModelToken {
  final String token;
  final String modelId;
  const _ModelToken({required this.token, required this.modelId});
}

class _PreparedProvider {
  final String sourceId;
  final String sourceName;
  final String suggestedKey;
  final Map<String, dynamic> providerData;
  final List<_ModelToken> modelTokens;

  const _PreparedProvider({
    required this.sourceId,
    required this.sourceName,
    required this.suggestedKey,
    required this.providerData,
    required this.modelTokens,
  });
}

class _PreparedAssistant {
  final String sourceId;
  final String sourceName;
  final Map<String, dynamic> assistantData;

  const _PreparedAssistant({
    required this.sourceId,
    required this.sourceName,
    required this.assistantData,
  });
}

class _AssistantImportContext {
  final int importedCount;
  final Map<String, String> oldToNewAssistantId;
  final Set<String> finalAssistantIds;

  const _AssistantImportContext({
    required this.importedCount,
    required this.oldToNewAssistantId,
    required this.finalAssistantIds,
  });
}

class _PreparedInjection {
  final String sourceId;
  final String title;
  final Map<String, dynamic> data;
  const _PreparedInjection({
    required this.sourceId,
    required this.title,
    required this.data,
  });
}

class _PreparedWorldBook {
  final String sourceId;
  final String name;
  final Map<String, dynamic> data;
  const _PreparedWorldBook({
    required this.sourceId,
    required this.name,
    required this.data,
  });
}

class _UploadFileIndex {
  final Map<String, String> byBasename;
  final Map<String, String> byRelative;
  final int copiedFiles;
  bool get isEmpty => byBasename.isEmpty && byRelative.isEmpty;

  const _UploadFileIndex.empty()
    : byBasename = const <String, String>{},
      byRelative = const <String, String>{},
      copiedFiles = 0;

  const _UploadFileIndex({
    required this.byBasename,
    required this.byRelative,
    required this.copiedFiles,
  });
}

class _NodeRecord {
  final String id;
  final int index;
  final int selectIndex;
  final List<Map<String, dynamic>> messages;
  const _NodeRecord({
    required this.id,
    required this.index,
    required this.selectIndex,
    required this.messages,
  });
}

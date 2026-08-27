import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import '../../database/business_repository.dart';
import '../../database/business_settings_router.dart';
import '../../models/api_keys.dart';
import '../../models/backup.dart';
import '../../models/chat_message.dart';
import '../../models/conversation.dart';
import '../../models/message_part.dart';
import '../chat/chat_service.dart';
import '../../../utils/app_directories.dart';
import '../../../utils/sandbox_path_resolver.dart';
import 'backup_cancel_token.dart';
import 'backup_isolate_runner.dart';
import 'backup_task_progress.dart';
import 'cherry_direct_backup_reader.dart';

export 'cherry_direct_backup_reader.dart'
    show CherryUnsupportedBackupVersionException;

class CherryImportResult {
  final int providers;
  final int assistants;
  final int conversations;
  final int messages;
  final int files;
  const CherryImportResult({
    required this.providers,
    required this.assistants,
    required this.conversations,
    required this.messages,
    required this.files,
  });
}

class CherryImporter {
  CherryImporter._();

  // Published backup keys used by the business settings router.
  static const String _providersKey = 'provider_configs_v1';
  static const String _providersOrderKey = 'providers_order_v1';
  static const String _assistantsKey = 'assistants_v1';

  static Future<CherryImportResult> importFromCherryStudio({
    required File file,
    required RestoreMode mode,
    required BusinessRepository businessRepository,
    required ChatService chatService,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    if (!chatService.initialized) {
      await chatService.init();
    }
    final existingConvs = chatService.getAllCompleteConversations();
    final existingConvIds = existingConvs.map((c) => c.id).toList();
    final existingMsgIds = <String>[];
    if (mode == RestoreMode.merge) {
      for (final c in existingConvs) {
        existingMsgIds.addAll(await chatService.getMessageIds(c.id));
      }
    }
    late final _CherryParsedBackup parsed;
    try {
      parsed =
          await runBackupIsolate<_CherryParsedBackup, _CherryParseIsolateArgs>(
            body: _parseCherryBackupInIsolate,
            payload: _CherryParseIsolateArgs(
              path: file.path,
              merge: mode == RestoreMode.merge,
              existingConvIds: existingConvIds,
              existingMsgIds: existingMsgIds,
              debugSpeculativeJsonProbeBytes: debugSpeculativeJsonProbeBytes,
              debugIdentifiedArchiveJsonBytes: debugIdentifiedArchiveJsonBytes,
            ),
            onProgress: onProgress,
            cancelToken: cancelToken,
          );
      debugZipJsonProbeDecodeCount = parsed.debugZipJsonProbeDecodeCount;
    } on CherryUnsupportedBackupVersionException catch (error) {
      debugZipJsonProbeDecodeCount = error.debugZipJsonProbeDecodeCount;
      rethrow;
    }
    final importedProviders = parsed.providers;
    final importedAssistants = parsed.assistants;
    if (cancelToken?.isCancelled == true) {
      throw const BackupCancelledException();
    }
    cancelToken?.setCancellable(false);
    onProgress?.call(
      const BackupProgress(
        phase: BackupPhase.committing,
        processed: 0,
        cancellable: false,
      ),
    );
    await _importBusinessData(
      businessRepository: businessRepository,
      mode: mode,
      providers: importedProviders,
      assistants: importedAssistants,
    );

    // If overwrite, clear chats/files BEFORE writing any uploads to avoid deletion later
    if (mode == RestoreMode.overwrite) {
      await chatService.clearAllData();
    }

    // Materialize stays after the first DB write so overwrite cannot delete
    // the files we just unpacked. Cancel is already disabled at this point.
    final pathsByFileId = await _materializeFiles(
      parsed.filesById,
      parsed.usedFileIds,
      backupArchive: file,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    final convCountAndMsgCount = await _commitTypedCherryTopics(
      topics: parsed.topics,
      filePaths: pathsByFileId,
      chatService: chatService,
    );

    return CherryImportResult(
      providers: importedProviders.length,
      assistants: importedAssistants.length,
      conversations: convCountAndMsgCount.$1,
      messages: convCountAndMsgCount.$2,
      files: pathsByFileId.length + convCountAndMsgCount.$3,
    );
  }

  // ---------- helpers ----------

  /// Cap for *speculative* ZIP-entry probes only (unknown / non-`.json` names).
  static const int defaultSpeculativeJsonProbeBytes = 32 * 1024 * 1024;

  /// Absolute ceiling for in-archive identified `.json` entries only.
  /// Whole-file and gunzipped JSON remain uncapped.
  static const int defaultIdentifiedArchiveJsonBytes = 256 * 1024 * 1024;

  /// Test seam to shrink the speculative probe budget without large fixtures.
  @visibleForTesting
  static int? debugSpeculativeJsonProbeBytes;

  /// Test seam for the in-archive identified `.json` ceiling.
  @visibleForTesting
  static int? debugIdentifiedArchiveJsonBytes;

  @visibleForTesting
  static int get speculativeJsonProbeBytes =>
      debugSpeculativeJsonProbeBytes ?? defaultSpeculativeJsonProbeBytes;

  @visibleForTesting
  static int get identifiedArchiveJsonBytes =>
      debugIdentifiedArchiveJsonBytes ?? defaultIdentifiedArchiveJsonBytes;

  /// Counts ZIP entry content accesses during JSON probe passes (not metadata).
  @visibleForTesting
  static int debugZipJsonProbeDecodeCount = 0;

  @visibleForTesting
  static void debugResetJsonProbeBudgets() {
    debugSpeculativeJsonProbeBytes = null;
    debugIdentifiedArchiveJsonBytes = null;
    debugZipJsonProbeDecodeCount = 0;
    debugPendingWriteAccessCount = 0;
  }

  /// Counts each pending-write access during typed-plan commit.
  @visibleForTesting
  static int debugPendingWriteAccessCount = 0;

  static const Set<String> _blockedSpeculativeProbeExtensions = <String>{
    '.sqlite',
    '.db',
    '.ldb',
    '.log',
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
    '.pdf',
    '.bin',
    '.exe',
    '.dll',
    '.so',
    '.dylib',
    '.wasm',
    '.mp3',
    '.mp4',
    '.wav',
    '.zip',
    '.gz',
  };

  static String _entryBaseName(String name) {
    final normalized = name.replaceAll('\\', '/').toLowerCase();
    return normalized.split('/').last;
  }

  /// Archive entries ending in `.json` are treated as identified JSON targets.
  @visibleForTesting
  static bool isIdentifiedJsonEntryName(String name) {
    return _entryBaseName(name).endsWith('.json');
  }

  /// True when [name] has no directory component (archive-root entry).
  @visibleForTesting
  static bool isArchiveRootEntryName(String name) {
    var normalized = name.replaceAll('\\', '/');
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized.isNotEmpty && !normalized.contains('/');
  }

  /// Whether a non-`.json` ZIP entry may be decompressed as a speculative
  /// JSON probe. Size is checked against [speculativeJsonProbeBytes] before
  /// touching [ArchiveFile.content] (which would decompress and cache).
  @visibleForTesting
  static bool isSpeculativeJsonEntryCandidate(String name, int size) {
    if (size <= 0 || size > speculativeJsonProbeBytes) return false;
    if (isIdentifiedJsonEntryName(name)) return false;
    final base = _entryBaseName(name);
    for (final ext in _blockedSpeculativeProbeExtensions) {
      if (base.endsWith(ext)) return false;
    }
    return true;
  }

  /// Whether an in-archive `.json` entry may be decompressed. Bounded by
  /// [identifiedArchiveJsonBytes] so nested attachment dumps cannot OOM.
  @visibleForTesting
  static bool isIdentifiedArchiveJsonEntryCandidate(String name, int size) {
    if (size <= 0 || size > identifiedArchiveJsonBytes) return false;
    return isIdentifiedJsonEntryName(name);
  }

  static bool _looksLikeZip(List<int> bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        (bytes[2] == 0x03 || bytes[2] == 0x05 || bytes[2] == 0x07) &&
        (bytes[3] == 0x04 || bytes[3] == 0x06 || bytes[3] == 0x08);
  }

  static bool _looksLikeGzip(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  }

  static Map<String, dynamic>? _tryParseBackupJson(String text) {
    try {
      final obj = jsonDecode(text) as Map<String, dynamic>;
      if (obj.containsKey('localStorage') && obj.containsKey('indexedDB')) {
        return obj;
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _tryDecodeBackupJsonBytes(
    List<int> raw, {
    required bool allowMalformed,
  }) {
    try {
      return _tryParseBackupJson(
        utf8.decode(raw, allowMalformed: allowMalformed),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _tryParseZipJsonEntry(
    ArchiveFile entry, {
    required bool identified,
  }) {
    if (!entry.isFile || entry.size <= 0) return null;
    if (identified) {
      if (!isIdentifiedArchiveJsonEntryCandidate(entry.name, entry.size)) {
        return null;
      }
    } else if (!isSpeculativeJsonEntryCandidate(entry.name, entry.size)) {
      return null;
    }
    try {
      debugZipJsonProbeDecodeCount++;
      final raw = entry.content;
      if (identified) {
        if (raw.length > identifiedArchiveJsonBytes) return null;
      } else if (raw.length > speculativeJsonProbeBytes) {
        return null;
      }
      return _tryDecodeBackupJsonBytes(raw, allowMalformed: identified);
    } catch (_) {
      return null;
    }
  }

  static _CherryParsedBackup _parseCherryBackupInIsolate(
    BackupIsolateContext ctx,
    _CherryParseIsolateArgs args,
  ) {
    debugSpeculativeJsonProbeBytes = args.debugSpeculativeJsonProbeBytes;
    debugIdentifiedArchiveJsonBytes = args.debugIdentifiedArchiveJsonBytes;
    debugZipJsonProbeDecodeCount = 0;
    ctx.throwIfCancelled();
    ctx.reportProgress(
      const BackupProgress(
        phase: BackupPhase.preparing,
        processed: 0,
        cancellable: true,
      ),
    );
    late final Map<String, dynamic> root;
    try {
      root = _readCherryBackupFileSync(File(args.path));
    } on CherryUnsupportedBackupVersionException catch (error) {
      throw CherryUnsupportedBackupVersionException(
        error.version,
        debugZipJsonProbeDecodeCount: debugZipJsonProbeDecodeCount,
      );
    }

    final version = (root['version'] as num?)?.toInt() ?? 0;
    if (version < 2) {
      throw Exception('Unsupported Cherry backup version: $version');
    }

    final localStorage =
        (root['localStorage'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        ) ??
        const <String, dynamic>{};
    final persistStr = (localStorage['persist:cherry-studio'] ?? '') as String;
    if (persistStr.isEmpty) {
      throw Exception('Missing localStorage["persist:cherry-studio"]');
    }
    late Map<String, dynamic> persistObj;
    try {
      persistObj = jsonDecode(persistStr) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid persist:cherry-studio JSON');
    }

    Map<String, dynamic> assistantsSlice = const {};
    Map<String, dynamic> llmSlice = const {};
    try {
      final aStr = (persistObj['assistants'] ?? '') as String;
      if (aStr.isNotEmpty) {
        assistantsSlice = jsonDecode(aStr) as Map<String, dynamic>;
      }
    } catch (_) {}
    try {
      final lStr = (persistObj['llm'] ?? '') as String;
      if (lStr.isNotEmpty) {
        llmSlice = jsonDecode(lStr) as Map<String, dynamic>;
      }
    } catch (_) {}

    final List<dynamic> cherryProviders =
        (llmSlice['providers'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryAssistants =
        (assistantsSlice['assistants'] as List?) ?? const <dynamic>[];

    final indexedDB =
        (root['indexedDB'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        const <String, dynamic>{};
    final List<dynamic> cherryFiles =
        (indexedDB['files'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryTopicsWithMessages =
        (indexedDB['topics'] as List?) ?? const <dynamic>[];
    final List<dynamic> cherryMessageBlocks =
        (indexedDB['message_blocks'] as List?) ?? const <dynamic>[];

    final topicMeta = <String, Map<String, dynamic>>{};
    var sessionIndex = 0;
    for (final a in cherryAssistants) {
      ctx.throwIfCancelled();
      sessionIndex++;
      ctx.reportProgress(
        BackupProgress(
          phase: BackupPhase.importingSessions,
          processed: sessionIndex,
          total: cherryAssistants.length,
          unit: BackupProgressUnit.items,
          cancellable: true,
        ),
      );
      if (a is! Map) continue;
      final topics = (a['topics'] as List?) ?? const <dynamic>[];
      for (final t in topics) {
        if (t is Map && t['id'] != null) {
          final id = t['id'].toString();
          topicMeta[id] = t.map((k, v) => MapEntry(k.toString(), v));
          final tm = topicMeta[id]!;
          final parentAssistantId = (a['id'] ?? '').toString();
          final topicAssistantId = (t['assistantId'] ?? '').toString();
          final ownerAssistantId = parentAssistantId.isNotEmpty
              ? parentAssistantId
              : topicAssistantId;
          if (ownerAssistantId.isNotEmpty) {
            tm['assistantId'] = ownerAssistantId;
          }
        }
      }
    }

    final topicMessages = <String, List<Map<String, dynamic>>>{};
    for (final e in cherryTopicsWithMessages) {
      ctx.throwIfCancelled();
      if (e is! Map) continue;
      final id = (e['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final msgs = (e['messages'] as List?) ?? const <dynamic>[];
      topicMessages[id] = [
        for (final m in msgs)
          if (m is Map) m.map((k, v) => MapEntry(k.toString(), v)),
      ];
    }

    final blockTextByMessageId = <String, String>{};
    for (final b in cherryMessageBlocks) {
      ctx.throwIfCancelled();
      if (b is! Map) continue;
      final type = (b['type'] ?? '').toString();
      final messageId = (b['messageId'] ?? '').toString();
      if (messageId.isEmpty) continue;
      if (type == 'main_text') {
        final content = (b['content'] ?? '').toString();
        if (content.isNotEmpty) {
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? content
              : '$prev\n$content';
        }
      } else if (type == 'code') {
        final code = (b['content'] ?? '').toString();
        final lang = (b['language'] ?? '').toString();
        if (code.isNotEmpty) {
          final fenced = '```$lang\n$code\n```';
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? fenced
              : '$prev\n$fenced';
        }
      } else if (type == 'error') {
        final err = (b['content'] ?? '').toString();
        if (err.isNotEmpty) {
          final tagged = '> Error\n> ${err.replaceAll('\n', '\n> ')}';
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? tagged
              : '$prev\n$tagged';
        }
      } else if (type == 'thinking') {
        final think = (b['content'] ?? '').toString();
        if (think.isNotEmpty) {
          final wrapped = '<think>\n$think\n</think>';
          final prev = blockTextByMessageId[messageId];
          blockTextByMessageId[messageId] = prev == null || prev.isEmpty
              ? wrapped
              : '$prev\n$wrapped';
        }
      }
    }

    final filesById = <String, Map<String, dynamic>>{
      for (final f in cherryFiles)
        if (f is Map && f['id'] != null)
          f['id'].toString(): f.map((k, v) => MapEntry(k.toString(), v)),
    };

    final usedFileIds = <String>{};
    for (final entry in topicMessages.entries) {
      ctx.throwIfCancelled();
      for (final m in entry.value) {
        final files = (m['files'] as List?) ?? const <dynamic>[];
        for (final rf in files) {
          if (rf is Map && rf['id'] != null) {
            usedFileIds.add(rf['id'].toString());
          }
        }
      }
    }

    final pendingAttachmentsByMessage = <String, List<_PendingAttachmentRef>>{};
    for (final b in cherryMessageBlocks) {
      ctx.throwIfCancelled();
      if (b is! Map) continue;
      final type = (b['type'] ?? '').toString();
      final messageId = (b['messageId'] ?? '').toString();
      if (messageId.isEmpty) continue;
      final fileObj = (b['file'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final fid = (fileObj?['id'] ?? '').toString();
      if (fid.isNotEmpty) usedFileIds.add(fid);
      final url = (b['url'] ?? '').toString();
      final isImageType =
          type.toLowerCase().contains('image') ||
          (fileObj?['type']?.toString().toLowerCase().startsWith('image') ??
              false);
      if (fileObj != null && fid.isNotEmpty) {
        final originPath = (fileObj['path'] ?? '').toString().trim();
        (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
            .add(
              _PendingAttachmentRef(
                fileId: fid,
                name: (fileObj['origin_name'] ?? fileObj['name'] ?? '')
                    .toString(),
                mime: (fileObj['type'] ?? '').toString(),
                originPath: originPath.isNotEmpty ? originPath : null,
                isImage: isImageType,
              ),
            );
      } else if (url.isNotEmpty) {
        if (url.startsWith('data:image')) {
          (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
              .add(_PendingAttachmentRef(dataUrl: url, isImage: true));
        } else {
          (pendingAttachmentsByMessage[messageId] ??= <_PendingAttachmentRef>[])
              .add(_PendingAttachmentRef(url: url, isImage: isImageType));
        }
      }
    }

    return _CherryParsedBackup(
      providers: _parseProviders(cherryProviders),
      assistants: _parseAssistants(cherryAssistants),
      topics: _buildTypedCherryTopics(
        ctx: ctx,
        topicMeta: topicMeta,
        topicMessages: topicMessages,
        blockTexts: blockTextByMessageId,
        pendingAttachmentsByMessage: pendingAttachmentsByMessage,
        merge: args.merge,
        existingConvIds: args.existingConvIds.toSet(),
        existingMsgIds: args.existingMsgIds.toSet(),
      ),
      filesById: filesById,
      usedFileIds: usedFileIds,
      debugZipJsonProbeDecodeCount: debugZipJsonProbeDecodeCount,
    );
  }

  static Map<String, dynamic> _readCherryBackupFileSync(File file) {
    final bytes = file.readAsBytesSync();

    // Whole-file JSON (not ZIP/GZIP): uncapped, allowMalformed.
    if (!_looksLikeZip(bytes) && !_looksLikeGzip(bytes)) {
      final obj = _tryDecodeBackupJsonBytes(bytes, allowMalformed: true);
      if (obj != null) return obj;
    }

    // ZIP: version-gate from metadata.json before any entry probe.
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      CherryDirectBackupReader.readMetadataOrThrowIfUnsupported(archive);
      for (final entry in archive) {
        if (!isArchiveRootEntryName(entry.name)) continue;
        final obj = _tryParseZipJsonEntry(entry, identified: true);
        if (obj != null) return obj;
      }
      for (final entry in archive) {
        if (isArchiveRootEntryName(entry.name)) continue;
        final obj = _tryParseZipJsonEntry(entry, identified: true);
        if (obj != null) return obj;
      }
      for (final entry in archive) {
        final obj = _tryParseZipJsonEntry(entry, identified: false);
        if (obj != null) return obj;
      }
      final directBackup = CherryDirectBackupReader.readArchive(archive);
      if (directBackup != null) return directBackup;
    } on CherryUnsupportedBackupVersionException {
      rethrow;
    } catch (_) {}

    // GZIP JSON payload: uncapped, allowMalformed.
    if (_looksLikeGzip(bytes)) {
      try {
        final gunzipped = GZipDecoder().decodeBytes(bytes, verify: false);
        final obj = _tryDecodeBackupJsonBytes(gunzipped, allowMalformed: true);
        if (obj != null) return obj;
      } catch (_) {}
    }

    throw Exception('Unable to read Cherry backup file');
  }

  static Map<String, Map<String, dynamic>> _parseProviders(
    List<dynamic> cherryProviders,
  ) {
    // Build imported map id -> ProviderConfig JSON-like
    final imported = <String, Map<String, dynamic>>{};

    for (final p in cherryProviders) {
      if (p is! Map) continue;
      final id = (p['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final type = (p['type'] ?? '').toString().toLowerCase();
      final name = (p['name'] ?? id).toString();
      final apiKeyRaw = (p['apiKey'] ?? '').toString();
      final apiHostRaw = (p['apiHost'] ?? '').toString().trim();

      // Parse comma-separated API keys (Cherry Studio stores multiple keys in one string)
      final apiKeys = _splitApiKeyString(apiKeyRaw);
      final apiKey = apiKeys.isNotEmpty ? apiKeys.first : '';
      final multiKeyEnabled = apiKeys.length > 1;

      // Determine provider kind mapping
      String? kind;
      switch (type) {
        case 'openai':
          kind = 'openai';
          break;
        case 'anthropic':
          kind = 'claude';
          break;
        case 'gemini':
          kind = 'google';
          break;
        default:
          // default to OpenAI-compatible
          kind = 'openai';
      }

      // models list (ids only)
      final models = <String>[];
      final mlist = (p['models'] as List?) ?? const <dynamic>[];
      for (final m in mlist) {
        if (m is Map && m['id'] != null) models.add(m['id'].toString());
      }

      // Normalize baseUrl following Cherry Studio semantics:
      // - In Cherry, for OpenAI/Anthropic providers, if base_url DOES NOT end with '/', they default to appending '/v1'.
      // - Our importer previously kept the base as-is, which could miss '/v1' and break requests.
      // - Here we mirror Cherry's behavior on import for 'openai' and 'claude'.
      String base = apiHostRaw;
      if (base.isNotEmpty) {
        if (base.endsWith('/')) {
          // Trim trailing slash for consistency; user is responsible for including version if needed.
          base = base.substring(0, base.length - 1);
        } else {
          // If it's OpenAI/Claude/Google and no trailing slash, append default version unless a suffix already exists.
          final lower = base.toLowerCase();
          final hasVersionSuffix = RegExp(
            r'/v\d([a-z0-9._-]+)?$',
          ).hasMatch(lower);
          if (!hasVersionSuffix) {
            if (kind == 'google') {
              base = '$base/v1beta';
            } else if (kind == 'openai' || kind == 'claude') {
              base = '$base/v1';
            }
          }
        }
      }

      // Compose ProviderConfig json
      final map = <String, dynamic>{
        'id': id,
        'enabled': (p['enabled'] as bool?) ?? apiKey.isNotEmpty,
        'name': name,
        'apiKey': apiKey,
        'baseUrl': base.isNotEmpty
            ? base
            : (kind == 'google'
                  ? 'https://generativelanguage.googleapis.com/v1beta'
                  : (kind == 'claude'
                        ? 'https://api.anthropic.com/v1'
                        : 'https://api.openai.com/v1')),
        'providerType': kind == 'openai'
            ? 'openai'
            : kind == 'google'
            ? 'google'
            : 'claude',
        'chatPath': kind == 'openai' ? '/chat/completions' : null,
        'useResponseApi': kind == 'openai' ? false : null,
        'vertexAI': kind == 'google' ? false : null,
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
        'multiKeyEnabled': multiKeyEnabled,
        'apiKeys': multiKeyEnabled
            ? apiKeys.map((k) => ApiKeyConfig.create(k).toJson()).toList()
            : const <dynamic>[],
        'keyManagement': const <String, dynamic>{},
      };
      imported[id] = map;
    }

    return imported;
  }

  static List<Map<String, dynamic>> _parseAssistants(
    List<dynamic> cherryAssistants,
  ) {
    // Map to our Assistant JSON list (as stored by Assistant.encodeList)
    final out = <Map<String, dynamic>>[];
    for (final a in cherryAssistants) {
      if (a is! Map) continue;
      final id = (a['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = (a['name'] ?? id).toString();
      final prompt = (a['prompt'] ?? '').toString();
      final settings = (a['settings'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );
      final model = (a['model'] as Map?)?.map(
        (k, v) => MapEntry(k.toString(), v),
      );

      final temperature = (settings?['temperature'] as num?)?.toDouble();
      final topP = (settings?['topP'] as num?)?.toDouble();
      final ctxCount = (settings?['contextCount'] as num?)?.toInt();
      final streamOutput = settings?['streamOutput'] as bool?;
      final enableMaxTokens = settings?['enableMaxTokens'] as bool? ?? false;
      final maxTokens = enableMaxTokens
          ? (settings?['maxTokens'] as num?)?.toInt()
          : null;

      final json = <String, dynamic>{
        'id': id,
        'name': name,
        'avatar': null,
        'useAssistantAvatar': false,
        'useAssistantName': false,
        'chatModelProvider': model?['provider']?.toString(),
        'chatModelId': model?['id']?.toString(),
        'temperature': temperature,
        'topP': topP,
        'contextMessageSize': ctxCount ?? 64,
        'limitContextMessages': true,
        'streamOutput': streamOutput ?? true,
        'thinkingBudget': null,
        'maxTokens': maxTokens,
        'systemPrompt': prompt,
        'messageTemplate': '{{ message }}',
        'mcpServerIds': const <String>[],
        'background': null,
        'customHeaders': const <Map<String, String>>[],
        'customBody': const <Map<String, String>>[],
        'enableMemory': false,
        'allowPastConversationRecall': false,
      };
      out.add(json);
    }

    return out;
  }

  static Future<void> _importBusinessData({
    required BusinessRepository businessRepository,
    required RestoreMode mode,
    required Map<String, Map<String, dynamic>> providers,
    required List<Map<String, dynamic>> assistants,
  }) {
    return businessRepository.transformSnapshot((current) {
      final settings = BusinessSettingsRouter.exportSnapshot(current);
      if (mode == RestoreMode.overwrite) {
        settings[_providersKey] = jsonEncode(providers);
        settings[_providersOrderKey] = providers.keys.toList();
        settings[_assistantsKey] = jsonEncode(assistants);
        return BusinessSettingsRouter.normalizeAndRoute(settings);
      }

      final currentProviders = _jsonObjectMap(
        settings[_providersKey],
        _providersKey,
      );
      for (final entry in providers.entries) {
        final local = currentProviders[entry.key];
        if (local is! Map) {
          currentProviders[entry.key] = entry.value;
          continue;
        }
        final next = local.map((key, value) => MapEntry(key.toString(), value));
        for (final importedField in entry.value.entries) {
          final value = importedField.value;
          if (value == null || (value is String && value.trim().isEmpty)) {
            continue;
          }
          next[importedField.key] = value;
        }
        currentProviders[entry.key] = next;
      }
      settings[_providersKey] = jsonEncode(currentProviders);

      final order = List<String>.from(
        (settings[_providersOrderKey] as List).cast<String>(),
      );
      for (final providerId in providers.keys) {
        if (!order.contains(providerId)) order.add(providerId);
      }
      settings[_providersOrderKey] = order;

      final currentAssistants = _jsonObjectList(
        settings[_assistantsKey],
        _assistantsKey,
      );
      final assistantsById = <String, Map<String, dynamic>>{
        for (final assistant in currentAssistants)
          if (assistant['id'] != null) assistant['id'].toString(): assistant,
      };
      for (final assistant in assistants) {
        final id = assistant['id'] as String;
        final local = assistantsById[id];
        if (local == null) {
          assistantsById[id] = assistant;
          continue;
        }
        final prompt = (assistant['systemPrompt'] as String?)?.trim() ?? '';
        if (prompt.isNotEmpty) local['systemPrompt'] = prompt;
        if (assistant['chatModelProvider'] != null) {
          local['chatModelProvider'] = assistant['chatModelProvider'];
        }
        if (assistant['chatModelId'] != null) {
          local['chatModelId'] = assistant['chatModelId'];
        }
      }
      settings[_assistantsKey] = jsonEncode(assistantsById.values.toList());
      return BusinessSettingsRouter.normalizeAndRoute(settings);
    }, writeReceipt: true);
  }

  static Map<String, dynamic> _jsonObjectMap(Object? raw, String key) {
    if (raw is! String) throw FormatException(key);
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded.values.any((value) => value is! Map)) {
      throw FormatException(key);
    }
    return decoded.map((field, value) => MapEntry(field.toString(), value));
  }

  static List<Map<String, dynamic>> _jsonObjectList(Object? raw, String key) {
    if (raw is! String) throw FormatException(key);
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.any((value) => value is! Map)) {
      throw FormatException(key);
    }
    return decoded
        .cast<Map>()
        .map(
          (value) => value.map(
            (field, fieldValue) => MapEntry(field.toString(), fieldValue),
          ),
        )
        .toList(growable: false);
  }

  static Map<String, String> _materializeFilesInIsolate(
    BackupIsolateContext ctx,
    _CherryMaterializeArgs args,
  ) {
    return _materializeFilesSync(
      backupPath: args.backupPath,
      uploadDirPath: args.uploadDirPath,
      filesById: args.filesById,
      usedIds: args.usedIds,
      ctx: ctx,
    );
  }

  static Future<Map<String, String>> _materializeFiles(
    Map<String, Map<String, dynamic>> filesById,
    Set<String> usedIds, {
    File? backupArchive,
    BackupProgressSink? onProgress,
    BackupCancelToken? cancelToken,
  }) async {
    final uploadDir = await AppDirectories.getUploadDirectory();
    if (!await uploadDir.exists()) await uploadDir.create(recursive: true);

    final filesPayload = <String, Map<String, dynamic>>{
      for (final id in usedIds)
        if (filesById[id] != null)
          id: Map<String, dynamic>.from(filesById[id]!),
    };
    final used = usedIds.toList(growable: false);
    return runBackupIsolate<Map<String, String>, _CherryMaterializeArgs>(
      body: _materializeFilesInIsolate,
      payload: _CherryMaterializeArgs(
        backupPath: backupArchive?.path,
        uploadDirPath: uploadDir.path,
        filesById: filesPayload,
        usedIds: used,
      ),
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
  }

  /// Synchronous attachment materialization — runs inside an isolate.
  static Map<String, String> _materializeFilesSync({
    required String? backupPath,
    required String uploadDirPath,
    required Map<String, Map<String, dynamic>> filesById,
    required List<String> usedIds,
    BackupIsolateContext? ctx,
  }) {
    Map<String, ArchiveFile>? filesIndexByBase;
    Map<String, ArchiveFile>? filesIndexByRel;
    Map<String, ArchiveFile>? filesIndexById;
    Map<String, String>? diskFilesIndexByBase;
    Map<String, String>? diskFilesIndexByRel;
    Map<String, String>? diskFilesIndexById;

    InputFileStream? inputStream;
    Archive? archive;
    if (backupPath != null) {
      try {
        inputStream = InputFileStream(backupPath);
        archive = ZipDecoder().decodeStream(inputStream);
        final byBase = <String, ArchiveFile>{};
        final byRel = <String, ArchiveFile>{};
        final byId = <String, ArchiveFile>{};
        final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
        for (final e in archive) {
          if (!e.isFile) continue;
          final norm = _normalizeZipEntryPath(e.name);
          final base = p.basename(norm);
          byBase[base] = e;
          final l = norm.toLowerCase();
          int idx = l.indexOf('/data/files/');
          if (idx != -1) {
            byRel[l.substring(idx + 1)] = e;
          }
          idx = l.indexOf('/files/');
          if (idx != -1) {
            byRel[l.substring(idx + 1)] = e;
          }
          final noExt = base.contains('.')
              ? base.substring(0, base.lastIndexOf('.'))
              : base;
          if (uuidLike.hasMatch(noExt)) {
            byId[noExt] = e;
          }
        }
        if (byBase.isNotEmpty) filesIndexByBase = byBase;
        if (byRel.isNotEmpty) filesIndexByRel = byRel;
        if (byId.isNotEmpty) filesIndexById = byId;
      } catch (_) {
        // not a zip, ignore
        archive = null;
        try {
          inputStream?.closeSync();
        } catch (_) {}
        inputStream = null;
      }

      try {
        final parent = Directory(p.dirname(backupPath));
        final candidates = <Directory>[
          Directory(p.join(parent.path, 'Data', 'Files')),
          Directory(p.join(parent.path, 'Files')),
          Directory(p.join(parent.path, 'files')),
        ];
        final byBase = <String, String>{};
        final byRel = <String, String>{};
        final byId = <String, String>{};
        final uuidLike = RegExp(r'^[0-9a-fA-F-]{10,}$');
        for (final dir in candidates) {
          if (!dir.existsSync()) continue;
          for (final ent in dir.listSync(recursive: true, followLinks: false)) {
            if (ent is! File) continue;
            final abs = ent.path;
            final base = p.basename(abs);
            byBase[base] = abs;
            final l = _normalizeZipEntryPath(abs).toLowerCase();
            int idx = l.indexOf('/data/files/');
            if (idx != -1) {
              byRel[l.substring(idx + 1)] = abs;
            }
            idx = l.indexOf('/files/');
            if (idx != -1) {
              byRel[l.substring(idx + 1)] = abs;
            }
            final noExt = base.contains('.')
                ? base.substring(0, base.lastIndexOf('.'))
                : base;
            if (uuidLike.hasMatch(noExt)) {
              byId[noExt] = abs;
            }
          }
        }
        if (byBase.isNotEmpty) diskFilesIndexByBase = byBase;
        if (byRel.isNotEmpty) diskFilesIndexByRel = byRel;
        if (byId.isNotEmpty) diskFilesIndexById = byId;
      } catch (_) {}
    }

    try {
      final result = <String, String>{};
      final total = usedIds.length;
      ctx?.reportProgress(
        BackupProgress(
          phase: BackupPhase.materializingFiles,
          processed: 0,
          total: total,
          unit: BackupProgressUnit.items,
          cancellable: false,
        ),
      );
      var processed = 0;
      for (final id in usedIds) {
        ctx?.throwIfCancelled();
        processed++;
        ctx?.reportProgress(
          BackupProgress(
            phase: BackupPhase.materializingFiles,
            processed: processed,
            total: total,
            unit: BackupProgressUnit.items,
            detail: id,
            cancellable: false,
          ),
        );
        final meta = filesById[id];
        if (meta == null) continue;
        final name = (meta['origin_name'] ?? meta['name'] ?? 'file').toString();
        final ext = (meta['ext'] ?? '').toString();
        final safeName = name.replaceAll(RegExp(r'[/\\\0]'), '_');
        final fn = safeName.isNotEmpty
            ? safeName
            : (ext.isNotEmpty ? 'file.$ext' : 'file');
        // `id` comes straight from the imported archive's JSON. Sanitize it
        // like the display name: an id such as `x/../../y` would otherwise
        // escape the upload directory on Windows, whose Win32 path
        // normalization resolves `..` lexically without requiring the
        // intermediate directory to exist.
        final safeId = id.replaceAll(RegExp(r'[/\\\0]'), '_');
        final fileName = 'cherry_${safeId}_$fn';
        final outPath = p.join(uploadDirPath, fileName);
        // Defense in depth: never write outside the upload directory even if
        // a future refactor weakens the sanitization above.
        if (!p.isWithin(p.normalize(uploadDirPath), p.normalize(outPath))) {
          continue;
        }

        if (File(outPath).existsSync()) {
          result[id] = outPath;
          continue;
        }

        final base64Str = (meta['base64'] ?? '') as String;
        final contentStr = (meta['content'] ?? '') as String;
        try {
          if (base64Str.isNotEmpty) {
            String b64 = base64Str;
            final idx = b64.indexOf('base64,');
            if (idx != -1) b64 = b64.substring(idx + 7);
            File(outPath).writeAsBytesSync(base64.decode(b64));
            result[id] = outPath;
            continue;
          }
        } catch (_) {}

        try {
          if (contentStr.isNotEmpty) {
            File(outPath).writeAsStringSync(contentStr);
            result[id] = outPath;
            continue;
          }
        } catch (_) {}

        try {
          final mp = (meta['path'] ?? '').toString();
          if (mp.isNotEmpty) {
            String rel = _normalizeZipEntryPath(mp).trim();
            if (rel.startsWith('file://')) {
              rel = rel.substring('file://'.length);
            }
            if (rel.startsWith('/')) rel = rel.substring(1);
            final lowerRel = rel.toLowerCase();
            final relKeys = <String>{
              lowerRel,
              lowerRel.startsWith('files/') ? lowerRel : 'files/$lowerRel',
              lowerRel.startsWith('data/files/')
                  ? lowerRel
                  : 'data/files/$lowerRel',
            };
            var done = false;
            for (final key in relKeys) {
              if (!done &&
                  filesIndexByRel != null &&
                  filesIndexByRel.containsKey(key)) {
                if (_writeArchiveEntryToFile(filesIndexByRel[key]!, outPath)) {
                  result[id] = outPath;
                  done = true;
                }
              }
              if (!done &&
                  diskFilesIndexByRel != null &&
                  diskFilesIndexByRel.containsKey(key)) {
                if (_copyDiskFileToUpload(diskFilesIndexByRel[key]!, outPath)) {
                  result[id] = outPath;
                  done = true;
                }
              }
              if (done) break;
            }
            if (done) continue;
          }
        } catch (_) {}

        try {
          final candidates = <String>{};
          void add(String? s) {
            if (s != null && s.trim().isNotEmpty) {
              candidates.add(p.basename(s));
            }
          }

          add(meta['name']?.toString());
          add(meta['origin_name']?.toString());
          add(meta['path']?.toString());
          var done = false;
          for (final base in candidates) {
            if (!done &&
                filesIndexByBase != null &&
                filesIndexByBase.containsKey(base)) {
              if (_writeArchiveEntryToFile(filesIndexByBase[base]!, outPath)) {
                result[id] = outPath;
                done = true;
              }
            }
            if (!done &&
                diskFilesIndexByBase != null &&
                diskFilesIndexByBase.containsKey(base)) {
              if (_copyDiskFileToUpload(diskFilesIndexByBase[base]!, outPath)) {
                result[id] = outPath;
                done = true;
              }
            }
            if (done) break;
          }
          if (done) continue;
        } catch (_) {}

        try {
          String fileExt = (meta['ext'] ?? '').toString().trim();
          if (fileExt.isEmpty) {
            final n = (meta['name'] ?? '').toString();
            final b = p.basename(n);
            if (b.contains('.')) fileExt = b.substring(b.lastIndexOf('.') + 1);
          }
          final extNoDot = fileExt.startsWith('.')
              ? fileExt.substring(1)
              : fileExt;
          final idPlus = extNoDot.isNotEmpty ? '$id.$extNoDot' : id;
          if (filesIndexById != null && filesIndexById.containsKey(id)) {
            if (_writeArchiveEntryToFile(filesIndexById[id]!, outPath)) {
              result[id] = outPath;
              continue;
            }
          }
          if (filesIndexByBase != null &&
              filesIndexByBase.containsKey(idPlus)) {
            if (_writeArchiveEntryToFile(filesIndexByBase[idPlus]!, outPath)) {
              result[id] = outPath;
              continue;
            }
          }
          if (diskFilesIndexById != null &&
              diskFilesIndexById.containsKey(id)) {
            if (_copyDiskFileToUpload(diskFilesIndexById[id]!, outPath)) {
              result[id] = outPath;
              continue;
            }
          }
          if (diskFilesIndexByBase != null &&
              diskFilesIndexByBase.containsKey(idPlus)) {
            if (_copyDiskFileToUpload(diskFilesIndexByBase[idPlus]!, outPath)) {
              result[id] = outPath;
              continue;
            }
          }
        } catch (_) {}
      }
      return result;
    } finally {
      try {
        archive?.clearSync();
      } catch (_) {}
      try {
        inputStream?.closeSync();
      } catch (_) {}
    }
  }

  /// ZIP entry names and on-disk paths may use `\` (Windows) or `/`.
  static String _normalizeZipEntryPath(String name) {
    return name.replaceAll('\\', '/');
  }

  static bool _writeArchiveEntryToFile(ArchiveFile entry, String outPath) {
    final output = _ExactSizeOutputFileStream(
      outPath,
      expectedBytes: entry.size,
    );
    var written = false;
    try {
      entry.writeContent(output);
      output.verifyComplete();
      written = true;
    } catch (_) {
      // Partial writes are cleaned up below, once the stream is closed.
    } finally {
      output.closeSync();
    }
    if (!written) {
      try {
        File(outPath).deleteSync();
      } catch (_) {}
      return false;
    }
    // The disk-copy fallback preserves source timestamps; keep both in step.
    final dt = _decodeDosDateTime(entry.lastModTime);
    if (dt != null) {
      try {
        File(outPath).setLastModifiedSync(dt);
      } catch (_) {}
    }
    return true;
  }

  /// Decode a DOS date/time packed value (from a ZIP entry's `lastModTime`)
  /// into a [DateTime]. Returns null when the date portion is zero (unset).
  static DateTime? _decodeDosDateTime(int packed) {
    final dosDate = packed >> 16;
    final dosTime = packed & 0xFFFF;
    if (dosDate == 0) return null;
    final year = ((dosDate >> 9) & 0x7f) + 1980;
    final month = (dosDate >> 5) & 0x0f;
    final day = dosDate & 0x1f;
    final hour = (dosTime >> 11) & 0x1f;
    final minute = (dosTime >> 5) & 0x3f;
    final second = (dosTime & 0x1f) * 2;
    try {
      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  static bool _copyDiskFileToUpload(String srcPath, String outPath) {
    try {
      final src = File(srcPath);
      src.copySync(outPath);
      try {
        File(outPath).setLastModifiedSync(src.lastModifiedSync());
      } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  }

  static String? _cherryModelId(Map<String, dynamic> message) {
    final raw = message['modelId'];
    if (raw != null) {
      if (raw is String) return raw;
      throw const FormatException('cherry_message_model_id');
    }
    final model = message['model'];
    if (model is Map) {
      final id = model['id'];
      if (id == null) return '';
      if (id is String) return id;
      throw const FormatException('cherry_message_model_id');
    }
    return null;
  }

  static List<_CherryTypedTopic> _buildTypedCherryTopics({
    required BackupIsolateContext ctx,
    required Map<String, Map<String, dynamic>> topicMeta,
    required Map<String, List<Map<String, dynamic>>> topicMessages,
    required Map<String, String> blockTexts,
    required Map<String, List<_PendingAttachmentRef>>
    pendingAttachmentsByMessage,
    required bool merge,
    required Set<String> existingConvIds,
    required Set<String> existingMsgIds,
  }) {
    final topicIds = <String>{...topicMeta.keys, ...topicMessages.keys};
    final topicList = topicIds.toList(growable: false);
    final messageTotal = topicMessages.values.fold<int>(
      0,
      (sum, messages) => sum + messages.length,
    );
    var messageProcessed = 0;
    final topics = <_CherryTypedTopic>[];
    for (final topicId in topicList) {
      ctx.throwIfCancelled();
      final msgsRaw = topicMessages[topicId] ?? const <Map<String, dynamic>>[];
      final meta = topicMeta[topicId] ?? const <String, dynamic>{};
      final title = (meta['name'] ?? 'Imported').toString();
      final pinned = meta['pinned'] as bool? ?? false;
      final assistantId = (meta['assistantId'] ?? '').toString().trim().isEmpty
          ? null
          : meta['assistantId'].toString();
      DateTime createdAt;
      DateTime updatedAt;
      try {
        createdAt = DateTime.parse((meta['createdAt'] ?? '').toString());
      } catch (_) {
        createdAt = DateTime.now();
      }
      try {
        updatedAt = DateTime.parse((meta['updatedAt'] ?? '').toString());
      } catch (_) {
        updatedAt = createdAt;
      }

      final messages = <_CherryTypedMessage>[];
      for (final m in msgsRaw) {
        ctx.throwIfCancelled();
        messageProcessed++;
        ctx.reportProgress(
          BackupProgress(
            phase: BackupPhase.importingMessages,
            processed: messageProcessed,
            total: messageTotal,
            unit: BackupProgressUnit.items,
            cancellable: true,
          ),
        );
        final msgId = (m['id'] ?? '').toString();
        if (msgId.isEmpty) continue;
        if (merge && existingMsgIds.contains(msgId)) {
          continue;
        }
        final roleRaw = (m['role'] ?? 'user').toString();
        final role = (roleRaw == 'system') ? 'assistant' : roleRaw;
        String content = '';
        final rawContent = m['content'];
        if (rawContent is String) {
          content = rawContent;
        } else if (rawContent != null) {
          content = rawContent.toString();
        }
        if (content.trim().isEmpty) {
          content = (blockTexts[msgId] ?? '').toString();
        }
        DateTime ts;
        try {
          ts = DateTime.parse((m['createdAt'] ?? '').toString());
        } catch (_) {
          ts = DateTime.now();
        }

        final modelId = _cherryModelId(m);
        final providerId = (m['model'] is Map
            ? (m['model']['provider'] ?? '').toString()
            : null);
        final usage = (m['usage'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        final totalTokens = (usage?['total_tokens'] as num?)?.toInt();

        final files = (m['files'] as List?) ?? const <dynamic>[];
        final pendingWrites = <_PendingAttachmentRef>[];
        for (final f in files) {
          if (f is! Map) continue;
          final fid = (f['id'] ?? '').toString();
          if (fid.isEmpty) continue;
          final name = (f['origin_name'] ?? f['name'] ?? 'file').toString();
          final mime = (f['type'] ?? '').toString();
          final url = (f['url'] ?? '').toString();
          final originPath = (f['path'] ?? '').toString().trim();
          final lowerUrl = url.toLowerCase();
          final isImage =
              mime.toLowerCase().startsWith('image') ||
              (name.toLowerCase().contains('.') &&
                  RegExp(
                    r'\.(png|jpg|jpeg|gif|webp)',
                  ).hasMatch(name.toLowerCase())) ||
              (url.isNotEmpty &&
                  (mime.toLowerCase().startsWith('image/') ||
                      RegExp(
                        r'\.(png|jpg|jpeg|gif|webp)(?:$|[?#])',
                      ).hasMatch(lowerUrl)));
          pendingWrites.add(
            _PendingAttachmentRef(
              fileId: fid,
              url: url.isNotEmpty ? url : null,
              originPath: originPath.isNotEmpty ? originPath : null,
              name: name,
              mime: mime,
              isImage: isImage,
            ),
          );
        }

        final extraAtt =
            pendingAttachmentsByMessage[msgId] ??
            const <_PendingAttachmentRef>[];
        pendingWrites.addAll(extraAtt);

        final metadata = (m['metadata'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        final gen = (metadata?['generateImageResponse'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        if (gen != null) {
          final imgs = (gen['images'] as List?) ?? const <dynamic>[];
          for (final item in imgs) {
            final s = (item ?? '').toString();
            if (s.isEmpty) continue;
            if (s.startsWith('data:image')) {
              pendingWrites.add(
                _PendingAttachmentRef(dataUrl: s, isImage: true),
              );
            } else if (s.startsWith('http://') || s.startsWith('https://')) {
              pendingWrites.add(
                _PendingAttachmentRef(url: s, name: 'image', mime: 'image/png'),
              );
            } else {
              pendingWrites.add(
                _PendingAttachmentRef(
                  dataUrl: 'data:image/png;base64,$s',
                  isImage: true,
                ),
              );
            }
          }
        }

        if (role == 'assistant' && content.contains('data:image')) {
          final dataUrls = _extractDataImageUrls(content);
          if (dataUrls.isNotEmpty) {
            for (final du in dataUrls) {
              pendingWrites.add(
                _PendingAttachmentRef(dataUrl: du, isImage: true),
              );
            }
            content = _stripDataImageUrls(content);
          }
        }

        messages.add(
          _CherryTypedMessage(
            message: ChatMessage(
              id: msgId,
              role: role,
              parts: <MessagePart>[TextPart(content)],
              timestamp: ts,
              modelId: modelId,
              providerId: providerId,
              totalTokens: totalTokens,
              conversationId: topicId,
            ),
            pendingWrites: pendingWrites,
          ),
        );
      }

      if (messages.isNotEmpty) {
        final times = messages.map((m) => m.message.timestamp).toList()..sort();
        createdAt = times.first;
        updatedAt = times.last;
      }

      topics.add(
        _CherryTypedTopic(
          mergeIntoExisting: merge && existingConvIds.contains(topicId),
          conversation: Conversation(
            id: topicId,
            title: title,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPinned: pinned,
            assistantId: assistantId,
          ),
          messages: messages,
        ),
      );
    }
    return topics;
  }

  static Future<(int, int, int)> _commitTypedCherryTopics({
    required List<_CherryTypedTopic> topics,
    required Map<String, String> filePaths,
    required ChatService chatService,
  }) async {
    if (!chatService.initialized) await chatService.init();
    var convCount = 0;
    var msgCount = 0;
    var extraSaved = 0;
    for (final topic in topics) {
      final resolved = <ChatMessage>[];
      for (final typed in topic.messages) {
        final parts = <MessagePart>[...typed.message.parts];
        for (final ref in typed.pendingWrites) {
          debugPendingWriteAccessCount++;
          final part = await _resolveCherryAttachment(ref, filePaths);
          if (ref.dataUrl != null) {
            final unavailable = part is ImagePart
                ? part.unavailable
                : part is FilePart && part.unavailable;
            if (!unavailable) extraSaved += 1;
          }
          parts.add(part);
        }
        resolved.add(typed.message.copyWith(parts: parts));
      }

      if (topic.mergeIntoExisting) {
        for (final message in resolved) {
          await chatService.addMessageDirectly(topic.conversation.id, message);
          msgCount += 1;
        }
      } else {
        await chatService.restoreConversation(topic.conversation, resolved);
        convCount += 1;
        msgCount += resolved.length;
      }
    }
    return (convCount, msgCount, extraSaved);
  }

  static Future<MessagePart> _resolveCherryAttachment(
    _PendingAttachmentRef ref,
    Map<String, String> filePaths,
  ) async {
    final fileName = ref.name ?? (ref.isImage ? 'image' : 'file');
    final fileMime =
        ref.mime ?? (ref.isImage ? 'image/png' : 'application/octet-stream');

    if (ref.dataUrl != null) {
      final savedPath = await _saveDataUrlToUpload(ref.dataUrl!);
      if (savedPath != null) {
        return _attachmentPart(
          isImage: ref.isImage,
          target: savedPath,
          name: fileName,
          mime: fileMime,
        );
      }
      return _attachmentPart(
        isImage: ref.isImage,
        target: 'cherry-missing:data-url',
        name: fileName,
        mime: fileMime,
        unavailable: true,
      );
    }

    if (ref.fileId != null) {
      final savedPath = filePaths[ref.fileId!];
      if (savedPath != null && savedPath.isNotEmpty) {
        return _attachmentPart(
          isImage: ref.isImage,
          target: savedPath,
          name: fileName,
          mime: fileMime,
        );
      }
      if (ref.url != null && ref.url!.isNotEmpty) {
        return _attachmentPart(
          isImage: ref.isImage,
          target: ref.url!,
          name: fileName,
          mime: fileMime,
        );
      }
      if (ref.originPath != null && ref.originPath!.isNotEmpty) {
        return _attachmentPart(
          isImage: ref.isImage,
          target: ref.originPath!,
          name: fileName,
          mime: fileMime,
          unavailable: true,
        );
      }
      return _attachmentPart(
        isImage: ref.isImage,
        target: 'cherry-missing:${ref.fileId}',
        name: fileName,
        mime: fileMime,
        unavailable: true,
      );
    }

    if (ref.url != null && ref.url!.isNotEmpty) {
      return _attachmentPart(
        isImage: ref.isImage,
        target: ref.url!,
        name: fileName,
        mime: fileMime,
      );
    }
    if (ref.originPath != null && ref.originPath!.isNotEmpty) {
      return _attachmentPart(
        isImage: ref.isImage,
        target: ref.originPath!,
        name: fileName,
        mime: fileMime,
        unavailable: true,
      );
    }
    return _attachmentPart(
      isImage: ref.isImage,
      target: 'cherry-missing:unknown',
      name: fileName,
      mime: fileMime,
      unavailable: true,
    );
  }

  static MessagePart _attachmentPart({
    required bool isImage,
    required String target,
    required String name,
    required String mime,
    bool unavailable = false,
  }) {
    final uri = SandboxPathResolver.canonicalize(target);
    if (isImage) {
      return ImagePart(
        uri: uri,
        mime: mime.isNotEmpty ? mime : null,
        unavailable: unavailable,
      );
    }
    return FilePart(
      uri: uri,
      name: name.isNotEmpty ? name : 'file',
      mime: mime.isNotEmpty ? mime : 'application/octet-stream',
      unavailable: unavailable,
    );
  }

  static List<String> _extractDataImageUrls(String text) {
    final re = RegExp(
      r'data:image\/[a-zA-Z0-9.+-]+;base64,[a-zA-Z0-9+\/\=\r\n]+',
    );
    return re.allMatches(text).map((m) => m.group(0)!).toList();
  }

  static String _stripDataImageUrls(String text) {
    final re = RegExp(
      r'data:image\/[a-zA-Z0-9.+-]+;base64,[a-zA-Z0-9+\/\=\r\n]+',
    );
    return text.replaceAll(re, '');
  }

  static Future<String?> _saveDataUrlToUpload(String dataUrl) async {
    try {
      final upload = await AppDirectories.getUploadDirectory();
      if (!await upload.exists()) await upload.create(recursive: true);
      // Extract mime and data
      String mime = 'image/png';
      String payload = dataUrl;
      final colon = dataUrl.indexOf(':');
      final semi = dataUrl.indexOf(';');
      final base = dataUrl.indexOf('base64,');
      if (colon >= 0 && semi > colon) {
        mime = dataUrl.substring(colon + 1, semi);
      }
      if (base >= 0) {
        payload = dataUrl.substring(base + 7);
      }
      final bytes = base64.decode(payload.replaceAll('\n', ''));
      String ext = 'png';
      switch (mime.toLowerCase()) {
        case 'image/jpeg':
        case 'image/jpg':
          ext = 'jpg';
          break;
        case 'image/webp':
          ext = 'webp';
          break;
        case 'image/gif':
          ext = 'gif';
          break;
        default:
          ext = 'png';
      }
      final fname =
          'cherry_img_${DateTime.now().millisecondsSinceEpoch}_${bytes.length}.$ext';
      final out = File(p.join(upload.path, fname));
      await out.writeAsBytes(bytes);
      return out.path;
    } catch (_) {
      return null;
    }
  }
}

/// Verifies an archive entry wrote exactly [expectedBytes].
class _ExactSizeOutputFileStream extends OutputFileStream {
  _ExactSizeOutputFileStream(String path, {required this.expectedBytes})
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int expectedBytes;
  int _writtenBytes = 0;

  void _reserve(int bytes) {
    if (bytes < 0 || _writtenBytes + bytes > expectedBytes) {
      throw const FormatException('zip_entry_size');
    }
    _writtenBytes += bytes;
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final writeLength = length ?? bytes.length;
    if (writeLength < 0 || writeLength > bytes.length) {
      throw RangeError.range(writeLength, 0, bytes.length, 'length');
    }
    _reserve(writeLength);
    super.writeBytes(bytes, length: writeLength);
  }

  @override
  void writeStream(InputStream stream) {
    const chunkSize = 1024 * 1024;
    while (!stream.isEOS) {
      final readSize = stream.length < chunkSize ? stream.length : chunkSize;
      final bytes = stream.readBytes(readSize).toUint8List();
      if (bytes.isEmpty) break;
      writeBytes(bytes);
    }
  }

  void verifyComplete() {
    if (_writtenBytes != expectedBytes) {
      throw const FormatException('zip_entry_size');
    }
  }
}

class _CherryMaterializeArgs {
  const _CherryMaterializeArgs({
    required this.backupPath,
    required this.uploadDirPath,
    required this.filesById,
    required this.usedIds,
  });

  final String? backupPath;
  final String uploadDirPath;
  final Map<String, Map<String, dynamic>> filesById;
  final List<String> usedIds;
}

class _CherryParseIsolateArgs {
  const _CherryParseIsolateArgs({
    required this.path,
    required this.merge,
    required this.existingConvIds,
    required this.existingMsgIds,
    this.debugSpeculativeJsonProbeBytes,
    this.debugIdentifiedArchiveJsonBytes,
  });

  final String path;
  final bool merge;
  final List<String> existingConvIds;
  final List<String> existingMsgIds;
  final int? debugSpeculativeJsonProbeBytes;
  final int? debugIdentifiedArchiveJsonBytes;
}

class _CherryParsedBackup {
  const _CherryParsedBackup({
    required this.providers,
    required this.assistants,
    required this.topics,
    required this.filesById,
    required this.usedFileIds,
    this.debugZipJsonProbeDecodeCount = 0,
  });

  final Map<String, Map<String, dynamic>> providers;
  final List<Map<String, dynamic>> assistants;
  final List<_CherryTypedTopic> topics;
  final Map<String, Map<String, dynamic>> filesById;
  final Set<String> usedFileIds;
  final int debugZipJsonProbeDecodeCount;
}

class _CherryTypedTopic {
  const _CherryTypedTopic({
    required this.mergeIntoExisting,
    required this.conversation,
    required this.messages,
  });

  final bool mergeIntoExisting;
  final Conversation conversation;
  final List<_CherryTypedMessage> messages;
}

class _CherryTypedMessage {
  const _CherryTypedMessage({
    required this.message,
    required this.pendingWrites,
  });

  final ChatMessage message;
  final List<_PendingAttachmentRef> pendingWrites;
}

class _PendingAttachmentRef {
  final String? fileId; // if present, resolve via filePaths
  final String? dataUrl; // if present, save as file
  final String? url; // remote url
  final String? name;
  final String? mime;
  final String? originPath; // archive-relative path when available
  final bool isImage;
  const _PendingAttachmentRef({
    this.fileId,
    this.dataUrl,
    this.url,
    this.name,
    this.mime,
    this.originPath,
    this.isImage = true,
  });
}

/// Splits a comma-separated API key string into a list of keys.
/// Handles escaped commas (\,) and trims whitespace.
/// Mirrors Cherry Studio's splitApiKeyString behavior.
List<String> _splitApiKeyString(String keyStr) {
  if (keyStr.trim().isEmpty) return const <String>[];

  // Use placeholder to handle escaped commas (avoids regex lookbehind for web compatibility)
  const placeholder = '\x00';
  final escaped = keyStr.replaceAll(r'\,', placeholder);
  final parts = escaped.split(',');

  final result = <String>[];
  for (final part in parts) {
    // Restore escaped commas and trim
    final key = part.replaceAll(placeholder, ',').trim();
    if (key.isNotEmpty) {
      result.add(key);
    }
  }

  return result;
}

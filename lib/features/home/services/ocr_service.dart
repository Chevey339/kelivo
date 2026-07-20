import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';

/// OCR 缓存条目
class OcrCacheEntry {
  OcrCacheEntry({required this.text});
  final String text;
}

/// Per-prepare OCR state that is not bounded by the process LRU.
///
/// Each concurrent conversation prepare owns its own session so snapshots cannot
/// overwrite each other.
class OcrPrepareSession {
  final Map<String, String> hashesByPath = <String, String>{};
  final Map<String, String> artifactTextsByHash = <String, String>{};
  final Map<String, Map<String, String>> artifactsByRevision =
      <String, Map<String, String>>{};
  final Set<String> loadedRevisionIds = <String>{};

  int get artifactSize => artifactTextsByHash.length;
}

/// OCR 图片处理服务
///
/// 功能：
/// - 运行 OCR 识别图片内容
/// - 管理 OCR 缓存（内存 LRU → 请求级 artifact 快照 → SQLite → OCR 模型）
/// - 包装 OCR 结果为 XML 格式
class OcrService {
  OcrService({
    this.maxCacheEntries = 48,
    this.resolveContentHashes,
    this.loadArtifacts,
    this.persistArtifact,
    this.ocrExecutor,
  });

  static const String artifactKind = 'image_ocr_v1';
  static const String memoryKeyPrefix = 'image_ocr_v1:';

  /// LRU 缓存最大条目数
  final int maxCacheEntries;

  /// Resolve image path/data-URL → content SHA-256.
  final Future<Map<String, String>> Function(List<String> imagePaths)?
  resolveContentHashes;

  /// Batch-load persisted OCR items by revision ID.
  final Future<Map<String, Map<String, String>>> Function(
    List<String> revisionIds,
  )?
  loadArtifacts;

  /// Persist OCR items for a revision (merged upsert). Failures must not throw
  /// to callers that already have OCR text for the current request.
  final Future<void> Function(String revisionId, Map<String, String> items)?
  persistArtifact;

  /// Optional OCR backend override (tests). When null, uses ChatApiService.
  final Future<String?> Function(List<String> imagePaths)? ocrExecutor;

  /// OCR 缓存 (memoryKey -> cached OCR text)
  final Map<String, OcrCacheEntry> _cache = <String, OcrCacheEntry>{};

  /// LRU 顺序列表 (最旧的在前)
  final List<String> _cacheOrder = <String>[];

  /// 获取缓存条目数量（用于测试/调试）
  int get cacheSize => _cache.length;

  /// 清除缓存
  void clearCache() {
    _cache.clear();
    _cacheOrder.clear();
  }

  static String memoryKeyForContentHash(String contentHash) {
    return '$memoryKeyPrefix$contentHash';
  }

  /// 运行 OCR 识别图片内容
  ///
  /// [imagePaths] 图片路径列表
  /// [context] BuildContext 用于获取 SettingsProvider
  ///
  /// 返回识别的文本内容，失败时返回 null
  Future<String?> runOcrForImages(
    List<String> imagePaths,
    BuildContext context,
  ) async {
    if (imagePaths.isEmpty) return null;
    if (ocrExecutor != null) {
      final out = (await ocrExecutor!(imagePaths))?.trim();
      return (out == null || out.isEmpty) ? null : out;
    }

    final settings = context.read<SettingsProvider>();
    final prov = settings.ocrModelProvider;
    final model = settings.ocrModelId;
    if (prov == null || model == null) return null;

    final cfg = settings.getProviderConfig(prov);

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': settings.ocrPrompt},
      {
        'role': 'user',
        'content':
            'Please perform OCR on the attached image(s) and return only the extracted text and visual descriptions.',
      },
    ];

    final stream = ChatApiService.sendMessageStream(
      config: cfg,
      modelId: model,
      messages: messages,
      userImagePaths: imagePaths,
      thinkingBudget: null,
      temperature: 0.0,
      topP: null,
      maxTokens: null,
      tools: null,
      onToolCall: null,
      extraHeaders: null,
      extraBody: null,
      stream: false,
      ocrActive: true,
    );

    String out = '';
    try {
      await for (final chunk in stream) {
        if (chunk.content.isNotEmpty) {
          out += chunk.content;
        }
      }
    } catch (_) {
      return null;
    }
    out = out.trim();
    return out.isEmpty ? null : out;
  }

  /// 缓存 OCR 文本结果（按内容哈希）
  void cacheOcrText(String contentHash, String text) {
    final hash = contentHash.trim();
    if (hash.isEmpty) return;
    final key = memoryKeyForContentHash(hash);

    _cache[key] = OcrCacheEntry(text: text);
    _cacheOrder.remove(key);
    _cacheOrder.add(key);

    // LRU 淘汰：移除最旧的条目
    while (_cacheOrder.length > maxCacheEntries) {
      final oldest = _cacheOrder.removeAt(0);
      _cache.remove(oldest);
    }
  }

  /// 获取缓存的 OCR 文本
  ///
  /// 返回缓存的文本，不存在时返回 null
  /// 访问时会更新 LRU 顺序
  String? getCachedOcrText(String contentHash) {
    final hash = contentHash.trim();
    if (hash.isEmpty) return null;
    final key = memoryKeyForContentHash(hash);

    final entry = _cache[key];
    if (entry != null) {
      // bump to most-recent
      _cacheOrder.remove(key);
      _cacheOrder.add(key);
      return entry.text;
    }
    return null;
  }

  String? _lookupCachedText(String contentHash, OcrPrepareSession? session) {
    final sessionText = session?.artifactTextsByHash[contentHash]?.trim();
    if (sessionText != null && sessionText.isNotEmpty) return sessionText;
    final memoryText = getCachedOcrText(contentHash)?.trim();
    if (memoryText != null && memoryText.isNotEmpty) return memoryText;
    return null;
  }

  void _rememberRequestText(
    String contentHash,
    String text,
    OcrPrepareSession? session,
  ) {
    final hash = contentHash.trim();
    final trimmed = text.trim();
    if (hash.isEmpty || trimmed.isEmpty) return;
    if (session != null) {
      session.artifactTextsByHash[hash] = trimmed;
    }
    cacheOcrText(hash, trimmed);
  }

  /// Prefetch hashes + SQLite OCR for one prepare/send pass.
  ///
  /// Returns an isolated session owned by the caller. Concurrent prepares must
  /// not share this object.
  Future<OcrPrepareSession> prefetchPersistedOcr({
    required List<String> revisionIds,
    required List<String> imagePaths,
  }) async {
    final session = OcrPrepareSession();

    final paths = <String>[
      ...{
        for (final path in imagePaths)
          if (path.trim().isNotEmpty) path.trim(),
      },
    ];
    if (paths.isNotEmpty && resolveContentHashes != null) {
      try {
        session.hashesByPath.addAll(await resolveContentHashes!(paths));
      } catch (_) {}
    }

    final ids = revisionIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    session.loadedRevisionIds.addAll(ids);

    if (ids.isEmpty || loadArtifacts == null) return session;

    Map<String, Map<String, String>> artifacts;
    try {
      artifacts = await loadArtifacts!(ids);
    } catch (_) {
      return session;
    }

    for (final entry in artifacts.entries) {
      final revisionItems = <String, String>{};
      for (final item in entry.value.entries) {
        final hash = item.key.trim();
        final text = item.value.trim();
        if (hash.isEmpty || text.isEmpty) continue;
        revisionItems[hash] = text;
        session.artifactTextsByHash[hash] = text;
        cacheOcrText(hash, text);
      }
      if (revisionItems.isNotEmpty) {
        session.artifactsByRevision[entry.key] = revisionItems;
      }
    }
    return session;
  }

  /// 获取图片的 OCR 文本（优先使用缓存）
  ///
  /// [imagePaths] 图片路径列表
  /// [context] BuildContext 用于获取 SettingsProvider
  /// [revisionId] 带图 user 消息 revision，用于 SQLite 持久化
  /// [session] optional per-prepare snapshot from [prefetchPersistedOcr]
  ///
  /// 返回合并后的 OCR 文本，失败时返回 null
  Future<String?> getOcrTextForImages(
    List<String> imagePaths,
    BuildContext context, {
    String? revisionId,
    OcrPrepareSession? session,
  }) async {
    if (imagePaths.isEmpty) return null;

    // Test doubles inject ocrExecutor and skip SettingsProvider wiring.
    if (ocrExecutor == null) {
      final settings = context.read<SettingsProvider>();
      if (!(settings.ocrEnabled &&
          settings.ocrModelProvider != null &&
          settings.ocrModelId != null)) {
        return null;
      }
    }

    final paths = imagePaths
        .map((path) => path.trim())
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isEmpty) return null;

    final hashesByPath = <String, String>{};
    final unresolved = <String>[];
    for (final path in paths) {
      final cachedHash = session?.hashesByPath[path]?.trim();
      if (cachedHash != null && cachedHash.isNotEmpty) {
        hashesByPath[path] = cachedHash;
      } else if (!unresolved.contains(path)) {
        unresolved.add(path);
      }
    }
    if (unresolved.isNotEmpty && resolveContentHashes != null) {
      try {
        final resolved = await resolveContentHashes!(unresolved);
        for (final entry in resolved.entries) {
          final hash = entry.value.trim();
          if (hash.isEmpty) continue;
          hashesByPath[entry.key] = hash;
          session?.hashesByPath[entry.key] = hash;
        }
      } catch (_) {}
    }

    final normalizedRevisionId = revisionId?.trim();
    final hasRevision =
        normalizedRevisionId != null && normalizedRevisionId.isNotEmpty;

    // Only hit SQLite here when this revision was not part of the batch prefetch.
    if (hasRevision &&
        loadArtifacts != null &&
        (session == null ||
            !session.loadedRevisionIds.contains(normalizedRevisionId))) {
      try {
        final artifacts = await loadArtifacts!([normalizedRevisionId]);
        final items = artifacts[normalizedRevisionId] ?? const {};
        session?.loadedRevisionIds.add(normalizedRevisionId);
        if (items.isNotEmpty) {
          final revisionItems = <String, String>{
            for (final entry in items.entries)
              if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty)
                entry.key.trim(): entry.value.trim(),
          };
          if (revisionItems.isNotEmpty) {
            session?.artifactsByRevision[normalizedRevisionId] = {
              ...session.artifactsByRevision[normalizedRevisionId] ?? const {},
              ...revisionItems,
            };
            for (final entry in revisionItems.entries) {
              _rememberRequestText(entry.key, entry.value, session);
            }
          }
        }
      } catch (_) {}
    }

    final existingForRevision = hasRevision
        ? <String, String>{
            ...session?.artifactsByRevision[normalizedRevisionId] ?? const {},
          }
        : const <String, String>{};

    final combined = StringBuffer();
    final toPersist = <String, String>{};

    for (final path in paths) {
      final hash = hashesByPath[path]?.trim();
      if (hash != null && hash.isNotEmpty) {
        final cached = _lookupCachedText(hash, session);
        if (cached != null) {
          combined.writeln(cached);
          _rememberRequestText(hash, cached, session);
          if (hasRevision && !existingForRevision.containsKey(hash)) {
            toPersist[hash] = cached;
          }
          continue;
        }
      }

      if (!context.mounted) break;
      final text = await runOcrForImages([path], context);
      if (text != null && text.trim().isNotEmpty) {
        final t = text.trim();
        if (hash != null && hash.isNotEmpty) {
          _rememberRequestText(hash, t, session);
          if (hasRevision) {
            toPersist[hash] = t;
          }
        }
        combined.writeln(t);
      }
    }

    if (toPersist.isNotEmpty && hasRevision && persistArtifact != null) {
      try {
        await persistArtifact!(normalizedRevisionId, toPersist);
        if (session != null) {
          session.artifactsByRevision[normalizedRevisionId] = {
            ...session.artifactsByRevision[normalizedRevisionId] ?? const {},
            ...toPersist,
          };
        }
      } catch (_) {
        // Persistence failure must not block the current chat turn.
      }
    }

    final out = combined.toString().trim();
    return out.isEmpty ? null : out;
  }

  /// 包装 OCR 文本为 XML 格式
  ///
  /// [ocrText] OCR 识别的原始文本
  ///
  /// 返回包装后的 XML 格式文本
  String wrapOcrBlock(String ocrText) {
    final buf = StringBuffer();
    buf.writeln(
      "The image_file_ocr tag contains a description of an image that the user uploaded to you, not the user's prompt.",
    );
    buf.writeln('<image_file_ocr>');
    buf.writeln(ocrText.trim());
    buf.writeln('</image_file_ocr>');
    buf.writeln();
    return buf.toString();
  }
}

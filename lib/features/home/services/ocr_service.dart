import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';

/// OCR 缓存条目
class OcrCacheEntry {
  OcrCacheEntry({required this.text});
  final String text;
}

/// OCR 图片处理服务
///
/// 功能：
/// - 运行 OCR 识别图片内容
/// - 管理 OCR 缓存 (LRU)
/// - 包装 OCR 结果为 XML 格式
class OcrService {
  OcrService({this.maxCacheEntries = 48});

  /// LRU 缓存最大条目数
  final int maxCacheEntries;

  /// OCR 缓存 (path -> cached OCR text)
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

  /// 缓存 OCR 文本结果
  void cacheOcrText(String path, String text) {
    final p = path.trim();
    if (p.isEmpty) return;

    _cache[p] = OcrCacheEntry(text: text);
    _cacheOrder.remove(p);
    _cacheOrder.add(p);

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
  String? getCachedOcrText(String path) {
    final p = path.trim();
    if (p.isEmpty) return null;

    final entry = _cache[p];
    if (entry != null) {
      // bump to most-recent
      _cacheOrder.remove(p);
      _cacheOrder.add(p);
      return entry.text;
    }
    return null;
  }

  /// 获取图片的 OCR 文本（优先使用缓存）
  ///
  /// [imagePaths] 图片路径列表
  /// [context] BuildContext 用于获取 SettingsProvider
  ///
  /// 返回合并后的 OCR 文本，失败时返回 null
  Future<String?> getOcrTextForImages(
    List<String> imagePaths,
    BuildContext context,
  ) async {
    if (imagePaths.isEmpty) return null;

    final settings = context.read<SettingsProvider>();
    if (!(settings.ocrEnabled &&
        settings.ocrModelProvider != null &&
        settings.ocrModelId != null)) {
      return null;
    }

    final combined = StringBuffer();
    final List<String> uncached = <String>[];

    for (final raw in imagePaths) {
      final path = raw.trim();
      if (path.isEmpty) continue;

      final cached = getCachedOcrText(path);
      if (cached != null && cached.trim().isNotEmpty) {
        combined.writeln(cached.trim());
      } else {
        uncached.add(path);
      }
    }

    // Fetch OCR for uncached images one-by-one to populate cache
    // and avoid huge combined prompts.
    for (final path in uncached) {
      final text = await runOcrForImages([path], context);
      if (text != null && text.trim().isNotEmpty) {
        final t = text.trim();
        cacheOcrText(path, t);
        combined.writeln(t);
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

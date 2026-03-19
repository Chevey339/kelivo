import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../settings/widgets/language_select_sheet.dart';

/// 翻译结果类型
enum TranslationResultType {
  /// 翻译成功
  success,

  /// 用户选择清除翻译
  cleared,

  /// 用户取消选择语言
  cancelled,

  /// 未配置翻译模型
  noModelConfigured,

  /// 翻译出错
  error,
}

/// 翻译结果
class TranslationResult {
  TranslationResult({required this.type, this.errorMessage});

  final TranslationResultType type;
  final String? errorMessage;

  bool get isSuccess => type == TranslationResultType.success;
  bool get isCleared => type == TranslationResultType.cleared;
  bool get isCancelled => type == TranslationResultType.cancelled;
}

/// 消息翻译服务
///
/// 功能：
/// - 显示语言选择器
/// - 调用翻译 API
/// - 流式更新翻译结果
/// - 保存翻译到数据库
class TranslationService {
  TranslationService({
    required this.chatService,
    required this.contextProvider,
  });

  final ChatService chatService;
  final BuildContext contextProvider;

  /// 翻译消息
  ///
  /// [message] 要翻译的消息
  /// [onTranslationStarted] 翻译开始回调（用户选择语言后、开始请求前调用）
  /// [onTranslationUpdate] 翻译更新回调（用于实时更新 UI）
  /// [onTranslationCleared] 翻译清除回调
  ///
  /// 返回翻译结果
  Future<TranslationResult> translateMessage({
    required ChatMessage message,
    required void Function() onTranslationStarted,
    required void Function(String translation) onTranslationUpdate,
    required void Function() onTranslationCleared,
  }) async {
    // This service holds a BuildContext; avoid using it across async gaps.
    final settings = contextProvider.read<SettingsProvider>();
    final assistant = contextProvider
        .read<AssistantProvider>()
        .currentAssistant;

    // 显示语言选择器
    final language = await showLanguageSelector(contextProvider);
    if (language == null) {
      return TranslationResult(type: TranslationResultType.cancelled);
    }

    // 检查是否选择清除翻译
    if (language.code == '__clear__') {
      onTranslationCleared();
      await chatService.updateMessage(message.id, translation: '');
      return TranslationResult(type: TranslationResultType.cleared);
    }

    // 获取翻译模型配置，回退顺序：翻译专用 -> 助手模型 -> 全局默认
    final translateProvider =
        settings.translateModelProvider ??
        assistant?.chatModelProvider ??
        settings.currentModelProvider;
    final translateModelId =
        settings.translateModelId ??
        assistant?.chatModelId ??
        settings.currentModelId;

    if (translateProvider == null || translateModelId == null) {
      return TranslationResult(type: TranslationResultType.noModelConfigured);
    }

    // 用户已选择语言且模型配置有效，通知开始翻译
    onTranslationStarted();

    // 提取要翻译的文本内容
    String textToTranslate = message.content;

    try {
      // 构建翻译 prompt
      String prompt = settings.translatePrompt
          .replaceAll('{source_text}', textToTranslate)
          .replaceAll('{target_lang}', language.displayName);

      // 创建翻译请求
      final provider = settings.getProviderConfig(translateProvider);

      final translationStream = ChatApiService.sendMessageStream(
        config: provider,
        modelId: translateModelId,
        messages: [
          {'role': 'user', 'content': prompt},
        ],
      );

      final buffer = StringBuffer();

      await for (final chunk in translationStream) {
        buffer.write(chunk.content);
        // 实时更新翻译
        onTranslationUpdate(buffer.toString());
      }

      // 保存最终翻译结果
      await chatService.updateMessage(
        message.id,
        translation: buffer.toString(),
      );

      return TranslationResult(type: TranslationResultType.success);
    } catch (e) {
      // 出错时清除翻译
      onTranslationCleared();
      await chatService.updateMessage(message.id, translation: '');

      return TranslationResult(
        type: TranslationResultType.error,
        errorMessage: e.toString(),
      );
    }
  }
}

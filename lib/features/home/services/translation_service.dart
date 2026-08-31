import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/api/chat_api_service.dart';
import '../../../core/services/api/retry_policy.dart';
import '../../../core/services/api/stream/stream_chunk.dart';
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

/// True when [runToken] is still the in-flight translation for this message.
@visibleForTesting
bool translationRunIsCurrent(Object runToken, Object? currentToken) =>
    identical(currentToken, runToken);

@visibleForTesting
String translationRequestId(String messageId) => 'translate-msg-$messageId';

/// Replaces any in-flight run so the old token no longer owns UI/DB writes.
@visibleForTesting
Object supersedeTranslationRun(Map<String, Object> runs, String messageId) {
  final token = Object();
  runs[messageId] = token;
  return token;
}

/// True when a failed translation should clear UI/DB and report an error.
@visibleForTesting
bool shouldApplyTranslationFailure({
  required Object runToken,
  required Object? currentToken,
  required Object error,
}) {
  if (!translationRunIsCurrent(runToken, currentToken)) return false;
  return !isUserCancelError(error);
}

/// 消息翻译服务
///
/// 功能：
/// - 显示语言选择器
/// - 调用翻译 API
/// - 流式更新翻译结果
/// - 保存翻译到数据库
class TranslationService {
  TranslationService({required this.chatService, required this._getContext});

  final ChatService chatService;
  final BuildContext Function() _getContext;
  final Map<String, Object> _runs = <String, Object>{};

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
    // Resolve a fresh context per call to avoid holding on to a stale BuildContext.
    final context = _getContext();
    final settings = context.read<SettingsProvider>();
    final assistant = context.read<AssistantProvider>().currentAssistant;

    // 显示语言选择器
    final language = await showLanguageSelector(context);
    if (language == null) {
      return TranslationResult(type: TranslationResultType.cancelled);
    }

    // 检查是否选择清除翻译
    if (language.code == '__clear__') {
      final clearToken = supersedeTranslationRun(_runs, message.id);
      ChatApiService.cancelRequest(translationRequestId(message.id));
      onTranslationCleared();
      await chatService.updateMessage(message.id, translation: '');
      if (identical(_runs[message.id], clearToken)) {
        _runs.remove(message.id);
      }
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
    final runToken = Object();
    _runs[message.id] = runToken;

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
        thinkingBudget: settings.translateGenerationThinkingBudgetFor(
          assistant?.thinkingBudget,
        ),
        requestId: translationRequestId(message.id),
      );

      final buffer = StringBuffer();

      await for (final chunk in translationStream) {
        if (!translationRunIsCurrent(runToken, _runs[message.id])) {
          return TranslationResult(type: TranslationResultType.cancelled);
        }
        if (chunk is! TextDelta || chunk.text.isEmpty) continue;
        buffer.write(chunk.text);
        // 实时更新翻译
        onTranslationUpdate(buffer.toString());
      }

      if (!translationRunIsCurrent(runToken, _runs[message.id])) {
        return TranslationResult(type: TranslationResultType.cancelled);
      }

      // 保存最终翻译结果
      await chatService.updateMessage(
        message.id,
        translation: buffer.toString(),
      );

      return TranslationResult(type: TranslationResultType.success);
    } catch (e) {
      if (!shouldApplyTranslationFailure(
        runToken: runToken,
        currentToken: _runs[message.id],
        error: e,
      )) {
        return TranslationResult(type: TranslationResultType.cancelled);
      }
      // 出错时清除翻译
      onTranslationCleared();
      await chatService.updateMessage(message.id, translation: '');

      return TranslationResult(
        type: TranslationResultType.error,
        errorMessage: e.toString(),
      );
    } finally {
      if (identical(_runs[message.id], runToken)) {
        _runs.remove(message.id);
      }
    }
  }
}

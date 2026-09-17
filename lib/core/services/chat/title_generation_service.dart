import '../../providers/assistant_provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/model_resolution.dart';
import '../api/chat_api_service.dart';
import 'chat_service.dart';

/// Failure raised by [TitleGenerationService] that callers report to the user.
///
/// [toString] returns the bare [reason] so error surfaces keep showing
/// `empty_response` rather than a wrapper class name.
class TitleGenerationException implements Exception {
  const TitleGenerationException(this.reason);

  final String reason;

  @override
  String toString() => reason;
}

/// Owns the conversation-title policy: skip checks, assistant and title-model
/// resolution, prompt assembly, generation and rename.
class TitleGenerationService {
  TitleGenerationService({
    required this._chatService,
    required this._settings,
    required this._assistants,
  });

  final ChatService _chatService;
  final SettingsProvider _settings;
  final AssistantProvider _assistants;

  /// Generates and persists a title for [conversationId].
  ///
  /// Returns the new title, or null when there is nothing to do: generation
  /// disabled, unknown conversation, already titled unless [force], or no
  /// resolvable model. Unchanged default titles ([defaultTitle]) still qualify.
  ///
  /// Throws [TitleGenerationException] when the model returns nothing, and
  /// rethrows API errors.
  Future<String?> generate(
    String conversationId, {
    required String locale,
    String? defaultTitle,
    bool force = false,
  }) async {
    final convo = _chatService.getConversation(conversationId);
    if (convo == null) return null;
    if (!force && convo.title.isNotEmpty && convo.title != defaultTitle) {
      return null;
    }
    if (!_settings.isTitleGenerationEnabled) return null;

    final assistant = convo.assistantId != null
        ? _assistants.getById(convo.assistantId!)
        : _assistants.currentAssistant;
    final chatModel = resolveChatModel(
      _settings,
      conversation: convo,
      assistant: assistant,
    );
    final providerKey = _settings.titleModelProvider ?? chatModel.providerKey;
    final modelId = _settings.titleModelId ?? chatModel.modelId;
    if (providerKey == null || modelId == null) return null;
    final config = _settings.getProviderConfig(providerKey);

    final content = await _chatService.generateTitleSource(convo.id);
    final prompt = _settings.titlePrompt
        .replaceAll('{locale}', locale)
        .replaceAll('{content}', content);

    final title = (await ChatApiService.generateText(
      conversationId: convo.id,
      config: config,
      modelId: modelId,
      prompt: prompt,
      thinkingBudget: _settings.titleGenerationThinkingBudgetFor(
        assistant?.thinkingBudget,
      ),
      skipImageParsing: true,
    )).trim();
    if (title.isEmpty) {
      throw const TitleGenerationException('empty_response');
    }
    await _chatService.renameConversation(convo.id, title);
    return title;
  }
}

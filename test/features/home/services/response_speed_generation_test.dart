import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/response_speed.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart' as sc;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Context extends Fake implements BuildContext {}

class _Builder extends Fake implements MessageBuilderService {}

class _Stream extends Fake implements sc.StreamController {}

class _Generation extends Fake implements GenerationController {
  @override
  Map<String, String>? buildCustomHeaders(Assistant? assistant) => null;
  @override
  Map<String, dynamic>? buildCustomBody(Assistant? assistant) => null;
}

class _Settings extends Fake implements SettingsProvider {
  @override
  bool get ocrActive => false;
  @override
  ProviderConfig getProviderConfig(String key, {String? defaultName}) =>
      ProviderConfig(
        id: key,
        name: key,
        enabled: true,
        apiKey: '',
        baseUrl: 'https://api.openai.com/v1',
        providerType: ProviderKind.openai,
        useResponseApi: true,
      );
}

class _Chat extends ChatService {
  Conversation conversation = Conversation(id: 'one', title: 'one');
  @override
  Conversation? getConversation(String id) =>
      id == conversation.id ? conversation : null;
}

void main() {
  test(
    'generation captures conversation speed once, and the next turn picks up edits',
    () {
      final chat = _Chat();
      addTearDown(chat.dispose);
      void choose(ResponseSpeed speed) {
        chat.conversation = chat.conversation.copyWith(
          extras: ConversationResponseSpeed.updateExtras(
            chat.conversation.extras,
            'openai',
            'gpt-6-astra',
            speed,
          ),
        );
      }

      final service = MessageGenerationService(
        chatService: chat,
        messageBuilderService: _Builder(),
        generationController: _Generation(),
        streamController: _Stream(),
        contextProvider: _Context(),
      );
      sc.GenerationContext build() => service.buildGenerationContext(
        assistantMessage: ChatMessage(
          conversationId: 'one',
          role: 'assistant',
          content: '',
        ),
        prepared: PreparedGeneration(
          apiMessages: const [],
          toolDefs: const [],
          hasBuiltInSearch: false,
          lastUserImagePaths: const [],
        ),
        userImagePaths: const [],
        allowImagesApiRouting: false,
        providerKey: 'openai',
        modelId: 'gpt-6-astra',
        assistant: null,
        settings: _Settings(),
        supportsReasoning: true,
        enableReasoning: true,
        generateTitleOnFinish: false,
      );
      choose(ResponseSpeed.fast);
      final first = build();
      choose(ResponseSpeed.ultrafast);
      expect(first.serviceTier, 'fast');
      expect(build().serviceTier, 'ultrafast');
      choose(ResponseSpeed.standard);
      expect(first.serviceTier, 'fast');
      expect(build().serviceTier, 'default');
    },
  );
}

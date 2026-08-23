import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/generation_controller.dart';
import 'package:Kelivo/features/home/controllers/stream_controller.dart'
    as stream_ctrl;
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';

class _FakeBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeChatService extends ChatService {}

class _StubGenerationController extends Fake implements GenerationController {}

class _StubStreamController extends Fake
    implements stream_ctrl.StreamController {}

void main() {
  test(
    'user regeneration does not claim a reply after the next user group',
    () {
      final chatService = _FakeChatService();
      final context = _FakeBuildContext();
      final service = MessageGenerationService(
        chatService: chatService,
        messageBuilderService: MessageBuilderService(
          chatService: chatService,
          contextProvider: context,
        ),
        generationController: _StubGenerationController(),
        streamController: _StubStreamController(),
        contextProvider: context,
      );
      ChatMessage message(String id, String role) => ChatMessage(
        id: id,
        role: role,
        content: id,
        conversationId: 'conversation',
      );
      final firstUser = message('user-1', 'user');

      final versioning = service.calculateRegenerationVersioning(
        message: firstUser,
        messages: [
          firstUser,
          message('user-2', 'user'),
          message('assistant-2', 'assistant'),
        ],
        assistantAsNewReply: false,
      );

      expect(versioning.targetGroupId, isNull);
      expect(versioning.nextVersion, 0);
      expect(versioning.lastKeep, 0);
    },
  );
}

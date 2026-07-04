import 'package:Cuplivo/core/models/chat_input_data.dart';
import 'package:Cuplivo/features/home/services/message_generation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persisted user message content', () {
    test('keeps text and attachment markers in the same format as send', () {
      final content = MessageGenerationService.buildPersistedUserMessageContent(
        const ChatInputData(
          text: '  edited prompt  ',
          imagePaths: ['C:/tmp/image.png'],
          documents: [
            DocumentAttachment(
              path: 'C:/tmp/spec.pdf',
              fileName: 'spec.pdf',
              mime: 'application/pdf',
            ),
          ],
        ),
        assistant: null,
      );

      expect(
        content,
        'edited prompt\n'
        '[image:C:/tmp/image.png]\n'
        '[file:C:/tmp/spec.pdf|spec.pdf|application/pdf]',
      );
    });

    test('allows attachment-only edits without inventing placeholder text', () {
      final content = MessageGenerationService.buildPersistedUserMessageContent(
        const ChatInputData(text: '', imagePaths: ['C:/tmp/image.png']),
        assistant: null,
      );

      expect(content, '\n[image:C:/tmp/image.png]');
    });
  });
}

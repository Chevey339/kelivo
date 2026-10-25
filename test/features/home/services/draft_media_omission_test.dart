import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/features/home/services/message_builder_service.dart';
import 'package:Kelivo/features/home/services/message_generation_service.dart';

ModelSpec _spec(List<Modality> input) =>
    ModelSpec(id: 'm', displayName: 'm', input: input);

void main() {
  const draft = ChatInputData(
    text: 'describe this',
    imagePaths: ['/tmp/a.png'],
  );

  test(
    'text-only model omits draft images from the request and keeps them persisted',
    () async {
      final parts =
          await MessageGenerationService.buildPersistedUserMessageParts(
            draft,
            assistant: null,
          );
      expect(parts.whereType<ImagePart>().map((part) => part.uri), [
        '/tmp/a.png',
      ]);

      final persisted = ChatMessage(
        id: 'user-1',
        role: 'user',
        conversationId: 'c',
        parts: parts,
      );
      final outbound = <Map<String, dynamic>>[
        {
          'role': 'user',
          'content': persisted.content,
          multimodalInternalMediaPathsKey:
              MessageBuilderService.mediaRefsFromParts(persisted),
        },
      ];

      final spec = _spec(const [Modality.text]);
      final stripped = await ChatApiService.stripUnsupportedMediaFromMessages(
        outbound,
        spec,
      );

      expect(
        stripped.single.containsKey(multimodalInternalMediaPathsKey),
        false,
      );
      expect(stripped.single['content'], 'describe this');
      expect(
        MessageGenerationService.filterMediaPathsForProvider(
          draft.imagePaths,
          spec: spec,
        ),
        isEmpty,
      );
    },
  );

  test(
    'filterMediaPathsForProvider keeps only modalities the spec accepts',
    () {
      const paths = ['/tmp/a.png', '/tmp/voice.wav', '/tmp/clip.mp4'];

      expect(
        MessageGenerationService.filterMediaPathsForProvider(
          paths,
          spec: _spec(const [Modality.text]),
        ),
        isEmpty,
      );
      expect(
        MessageGenerationService.filterMediaPathsForProvider(
          paths,
          spec: _spec(const [Modality.text, Modality.image]),
        ),
        ['/tmp/a.png'],
      );
      expect(
        MessageGenerationService.filterMediaPathsForProvider(
          paths,
          spec: _spec(const [Modality.text, Modality.audio, Modality.video]),
        ),
        ['/tmp/voice.wav', '/tmp/clip.mp4'],
      );
    },
  );
}

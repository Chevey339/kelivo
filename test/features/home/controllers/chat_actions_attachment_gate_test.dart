import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/features/home/controllers/chat_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const imageDraft = ChatInputData(
    text: 'describe this',
    imagePaths: ['/tmp/a.png'],
  );

  test('image draft on a text-only model is rejected before persist', () {
    final spec = ModelSpec(
      id: 'text-only',
      displayName: 'text-only',
      input: const [Modality.text],
    );

    expect(
      ChatActions.draftUnsupportedError(imageDraft, spec),
      'attachment_unsupported:image',
    );
  });

  test('image draft on a text-only model proceeds when OCR is active', () {
    final spec = ModelSpec(
      id: 'text-only',
      displayName: 'text-only',
      input: const [Modality.text],
    );

    expect(
      ChatActions.draftUnsupportedError(imageDraft, spec, ocrActive: true),
      isNull,
    );
  });

  test('image draft on a vision model proceeds', () {
    final spec = ModelSpec(
      id: 'vision',
      displayName: 'vision',
      input: const [Modality.text, Modality.image],
    );

    expect(ChatActions.draftUnsupportedError(imageDraft, spec), isNull);
  });
}

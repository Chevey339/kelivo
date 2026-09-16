import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/features/home/services/attachment_modality_gate.dart';

ModelSpec _spec(List<Modality> input) =>
    ModelSpec(id: 'm', displayName: 'm', input: input);

DocumentAttachment _doc({
  required String path,
  required String mime,
  String? fileName,
}) {
  return DocumentAttachment(
    path: path,
    fileName: fileName ?? path.split('/').last,
    mime: mime,
  );
}

void main() {
  group('unsupportedDraftModalities', () {
    test('imagePaths are image even without a MIME', () {
      expect(
        unsupportedDraftModalities(
          const ChatInputData(text: 'hi', imagePaths: ['/tmp/a.png']),
          _spec(const [Modality.text]),
        ),
        [Modality.image],
      );
      expect(
        unsupportedDraftModalities(
          const ChatInputData(text: 'hi', imagePaths: ['/tmp/a.png']),
          _spec(const [Modality.text, Modality.image]),
        ),
        isEmpty,
      );
    });

    test('documents classify audio and video by MIME; PDF is ignored', () {
      final input = ChatInputData(
        text: 'hi',
        documents: [
          _doc(path: '/tmp/voice.wav', mime: 'audio/wav'),
          _doc(path: '/tmp/clip.mp4', mime: 'video/mp4'),
          _doc(path: '/tmp/notes.pdf', mime: 'application/pdf'),
        ],
      );

      expect(unsupportedDraftModalities(input, _spec(const [Modality.text])), [
        Modality.audio,
        Modality.video,
      ]);
      expect(
        unsupportedDraftModalities(
          input,
          _spec(const [Modality.text, Modality.audio]),
        ),
        [Modality.video],
      );
      expect(
        unsupportedDraftModalities(
          input,
          _spec(const [Modality.text, Modality.audio, Modality.video]),
        ),
        isEmpty,
      );
    });

    test(
      'images are allowed when OCR is active; audio and video stay gated',
      () {
        final input = ChatInputData(
          text: 'hi',
          imagePaths: const ['/tmp/a.png'],
          documents: [
            _doc(path: '/tmp/shot.jpg', mime: 'image/jpeg'),
            _doc(path: '/tmp/voice.wav', mime: 'audio/wav'),
            _doc(path: '/tmp/clip.mp4', mime: 'video/mp4'),
          ],
        );

        expect(
          unsupportedDraftModalities(
            input,
            _spec(const [Modality.text]),
            ocrActive: true,
          ),
          [Modality.audio, Modality.video],
        );
        expect(
          unsupportedDraftModalities(
            input,
            _spec(const [Modality.text]),
            ocrActive: false,
          ),
          [Modality.image, Modality.audio, Modality.video],
        );
      },
    );

    test('error code lists gated modalities in image, audio, video order', () {
      final input = ChatInputData(
        text: '',
        imagePaths: const ['/tmp/a.png'],
        documents: [
          _doc(path: '/tmp/voice.wav', mime: 'audio/wav'),
          _doc(path: '/tmp/clip.mp4', mime: 'video/mp4'),
        ],
      );
      final unsupported = unsupportedDraftModalities(
        input,
        _spec(const [Modality.text]),
      );
      expect(unsupported, [Modality.image, Modality.audio, Modality.video]);
      expect(
        attachmentUnsupportedErrorCode(unsupported),
        'attachment_unsupported:image,audio,video',
      );
    });
  });
}

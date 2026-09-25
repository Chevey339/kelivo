import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

ModelSpec _spec(List<Modality> input) =>
    ModelSpec(id: 'm', displayName: 'm', input: input);

Map<String, dynamic> _userMessage({
  required Object content,
  List<Object>? media,
  List<Object>? documents,
}) {
  return <String, dynamic>{
    'role': 'user',
    'content': content,
    if (media != null) multimodalInternalMediaPathsKey: media,
    if (documents != null) multimodalInternalDocumentPathsKey: documents,
  };
}

void main() {
  group('stripUnsupportedMediaFromMessages', () {
    final mixed = [
      _userMessage(
        content: [
          {'type': 'text', 'text': 'look'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,QUJD'},
          },
        ],
        media: [
          encodeInternalMediaRef(uri: '/tmp/a.png', mime: 'image/png'),
          encodeInternalMediaRef(uri: '/tmp/voice.wav', mime: 'audio/wav'),
          encodeInternalMediaRef(uri: '/tmp/clip.mp4', mime: 'video/mp4'),
        ],
        documents: [
          encodeInternalDocumentRef((
            uri: '/tmp/notes.pdf',
            name: 'notes.pdf',
            mime: 'application/pdf',
          )),
        ],
      ),
    ];

    test('image-only model keeps images and drops audio and video', () async {
      final out = await ChatApiService.stripUnsupportedMediaFromMessages(
        mixed,
        _spec(const [Modality.text, Modality.image]),
      );
      final refs = parseInternalMediaRefs(
        out.single[multimodalInternalMediaPathsKey],
      );
      expect(refs.map((ref) => ref.mime), ['image/png']);
      expect(out.single['content'], isA<List>());
      expect(
        (out.single['content'] as List).any(
          (part) => part is Map && part['type'] == 'image_url',
        ),
        isTrue,
      );
      expect(out.single[multimodalInternalDocumentPathsKey], isNotNull);
    });

    test('audio-only model keeps audio and drops images', () async {
      final out = await ChatApiService.stripUnsupportedMediaFromMessages(
        mixed,
        _spec(const [Modality.text, Modality.audio]),
      );
      final refs = parseInternalMediaRefs(
        out.single[multimodalInternalMediaPathsKey],
      );
      expect(refs.map((ref) => ref.mime), ['audio/wav']);
      expect(out.single['content'], 'look');
      expect(out.single[multimodalInternalDocumentPathsKey], isNotNull);
    });

    test('text-only model drops all media and keeps documents', () async {
      final out = await ChatApiService.stripUnsupportedMediaFromMessages(
        mixed,
        _spec(const [Modality.text]),
      );
      expect(out.single.containsKey(multimodalInternalMediaPathsKey), isFalse);
      expect(out.single['content'], 'look');
      expect(out.single[multimodalInternalDocumentPathsKey], isNotEmpty);
    });

    test('documents are never dropped even when the spec has no pdf', () async {
      final out = await ChatApiService.stripUnsupportedMediaFromMessages(
        mixed,
        _spec(const [Modality.text]),
      );
      final docs = parseInternalDocumentRefs(
        out.single[multimodalInternalDocumentPathsKey],
      );
      expect(docs.single.uri, '/tmp/notes.pdf');
      expect(docs.single.mime, 'application/pdf');
    });

    test(
      'current draft user message drops images for a text-only model',
      () async {
        final draft = [
          _userMessage(
            content: 'describe this',
            media: [
              encodeInternalMediaRef(uri: '/tmp/a.png', mime: 'image/png'),
            ],
          ),
        ];
        final out = await ChatApiService.stripUnsupportedMediaFromMessages(
          draft,
          _spec(const [Modality.text]),
        );
        expect(
          out.single.containsKey(multimodalInternalMediaPathsKey),
          isFalse,
        );
        expect(out.single['content'], 'describe this');
      },
    );
  });
}

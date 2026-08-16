import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/message_part.dart';

void main() {
  group('MessagePart.fromRow / encodePayload roundtrip', () {
    test('TextPart stores raw text payload', () {
      const payload = 'hello\nworld';
      final part = MessagePart.fromRow('text', payload);

      expect(part, isA<TextPart>());
      expect(part.kind, 'text');
      expect((part as TextPart).text, payload);
      expect(part.encodePayload(), payload);
    });

    test('ReasoningPart stores raw text payload', () {
      const payload = 'thinking...';
      final part = MessagePart.fromRow('reasoning', payload);

      expect(part, isA<ReasoningPart>());
      expect(part.kind, 'reasoning');
      expect((part as ReasoningPart).text, payload);
      expect(part.encodePayload(), payload);
    });

    test('ToolCallPart stores JSON payload as-is', () {
      const payload = '{"id":"call_1","name":"search","arguments":"{}"}';
      final part = MessagePart.fromRow('tool_call', payload);

      expect(part, isA<ToolCallPart>());
      expect(part.kind, 'tool_call');
      expect((part as ToolCallPart).payloadJson, payload);
      expect(part.encodePayload(), payload);
    });

    test('ImagePart roundtrips required and optional fields', () {
      final payload = jsonEncode({
        'uri': '/tmp/a.png',
        'mime': 'image/png',
        'assetId': 'asset-1',
        'unavailable': true,
      });
      final part = MessagePart.fromRow('image', payload);

      expect(part, isA<ImagePart>());
      expect(part.kind, 'image');
      final image = part as ImagePart;
      expect(image.uri, '/tmp/a.png');
      expect(image.mime, 'image/png');
      expect(image.assetId, 'asset-1');
      expect(image.unavailable, isTrue);

      final decoded = jsonDecode(part.encodePayload()) as Map<String, dynamic>;
      expect(decoded['uri'], '/tmp/a.png');
      expect(decoded['mime'], 'image/png');
      expect(decoded['assetId'], 'asset-1');
      expect(decoded['unavailable'], isTrue);
    });

    test('FilePart roundtrips required and optional fields', () {
      final payload = jsonEncode({
        'uri': '/tmp/spec.pdf',
        'name': 'spec.pdf',
        'mime': 'application/pdf',
        'assetId': 'asset-2',
        'unavailable': false,
      });
      final part = MessagePart.fromRow('file', payload);

      expect(part, isA<FilePart>());
      expect(part.kind, 'file');
      final file = part as FilePart;
      expect(file.uri, '/tmp/spec.pdf');
      expect(file.name, 'spec.pdf');
      expect(file.mime, 'application/pdf');
      expect(file.assetId, 'asset-2');
      expect(file.unavailable, isFalse);

      final decoded = jsonDecode(part.encodePayload()) as Map<String, dynamic>;
      expect(decoded['uri'], '/tmp/spec.pdf');
      expect(decoded['name'], 'spec.pdf');
      expect(decoded['mime'], 'application/pdf');
      expect(decoded['assetId'], 'asset-2');
    });

    test('optional mime/assetId/unavailable omit preserve semantics', () {
      final imagePayload = jsonEncode({'uri': 'https://example.com/a.png'});
      final image = MessagePart.fromRow('image', imagePayload) as ImagePart;
      expect(image.mime, isNull);
      expect(image.assetId, isNull);
      expect(image.unavailable, isFalse);

      final imageEncoded =
          jsonDecode(image.encodePayload()) as Map<String, dynamic>;
      expect(imageEncoded.containsKey('mime'), isFalse);
      expect(imageEncoded.containsKey('assetId'), isFalse);
      expect(imageEncoded.containsKey('unavailable'), isFalse);
      expect(imageEncoded['uri'], 'https://example.com/a.png');

      final filePayload = jsonEncode({
        'uri': '/tmp/notes.txt',
        'name': 'notes.txt',
      });
      final file = MessagePart.fromRow('file', filePayload) as FilePart;
      expect(file.mime, isNull);
      expect(file.assetId, isNull);
      expect(file.unavailable, isFalse);

      final fileEncoded =
          jsonDecode(file.encodePayload()) as Map<String, dynamic>;
      expect(fileEncoded.containsKey('mime'), isFalse);
      expect(fileEncoded.containsKey('assetId'), isFalse);
      expect(fileEncoded.containsKey('unavailable'), isFalse);
      expect(fileEncoded['uri'], '/tmp/notes.txt');
      expect(fileEncoded['name'], 'notes.txt');
    });

    test('UnknownPart preserves raw kind and payload bytes', () {
      const kind = 'future_kind';
      const payload = '{"x":1,"y":[2,3]}';
      final part = MessagePart.fromRow(kind, payload);

      expect(part, isA<UnknownPart>());
      expect(part.kind, kind);
      final unknown = part as UnknownPart;
      expect(unknown.rawKind, kind);
      expect(unknown.payload, payload);
      expect(part.encodePayload(), same(payload));
      expect(part.encodePayload(), payload);
    });

    test('illegal image JSON payload fails explicitly', () {
      expect(
        () => MessagePart.fromRow('image', 'not-json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MessagePart.fromRow('image', '[]'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MessagePart.fromRow('image', '{}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('illegal file JSON payload fails explicitly', () {
      expect(
        () => MessagePart.fromRow('file', '{'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MessagePart.fromRow('file', '{"uri":"/tmp/a"}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MessagePart.fromRow('file', '{"name":"a.pdf"}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('audio and video stay as file kind via mime', () {
      final audio = MessagePart.fromRow(
        'file',
        jsonEncode({
          'uri': '/tmp/a.mp3',
          'name': 'a.mp3',
          'mime': 'audio/mpeg',
        }),
      );
      final video = MessagePart.fromRow(
        'file',
        jsonEncode({'uri': '/tmp/v.mp4', 'name': 'v.mp4', 'mime': 'video/mp4'}),
      );

      expect(audio, isA<FilePart>());
      expect(audio.kind, 'file');
      expect((audio as FilePart).mime, 'audio/mpeg');
      expect(video, isA<FilePart>());
      expect(video.kind, 'file');
      expect((video as FilePart).mime, 'video/mp4');
    });
  });

  group('renderAssistantFromParts', () {
    test('uses parts when reasoning or tool_call is present', () {
      expect(
        renderAssistantFromParts(
          parts: const [ReasoningPart('plan'), TextPart('hi')],
          hasContentSplits: true,
        ),
        isTrue,
      );
      expect(
        renderAssistantFromParts(
          parts: const [
            ToolCallPart('{"id":"c1","name":"lookup"}'),
            TextPart('done'),
          ],
          hasContentSplits: false,
        ),
        isTrue,
      );
    });

    test('keeps split renderer for historical text plus extracted images', () {
      expect(
        renderAssistantFromParts(
          parts: const [
            TextPart('caption'),
            ImagePart(uri: 'kelivo-file:///images/a.png', mime: 'image/png'),
          ],
          hasContentSplits: true,
        ),
        isFalse,
      );
    });

    test('uses parts for new image-only rows without splits', () {
      expect(
        renderAssistantFromParts(
          parts: const [
            ImagePart(uri: 'https://example.com/a.png', mime: 'image/png'),
            TextPart('Done'),
          ],
          hasContentSplits: false,
        ),
        isTrue,
      );
    });
  });
}

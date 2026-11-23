import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/media/creation_prompt_enhancer.dart';
import 'package:Kelivo/core/services/model_spec/model_spec_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test(
    'diff keeps the rewrite intact and highlights added words and CJK characters',
    () async {
      final spans = await CreationPromptEnhancer.diff(
        '一只猫 sleeps',
        '一只橘猫 sleeps in sunlight',
      );
      expect(spans.map((span) => span.text).join(), '一只橘猫 sleeps in sunlight');
      expect(spans.where((span) => span.added).map((span) => span.text), [
        '橘',
        ' in sunlight',
      ]);
      expect(await CreationPromptEnhancer.diff('A vivid sky', 'A sky'), [
        (text: 'A sky', added: false),
      ]);
    },
  );

  test(
    'the enhancement request sends reference images only to image-input models',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kelivo-enhancement',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/reference.png',
      ).writeAsBytes(image.encodePng(image.Image(width: 4, height: 4)));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = <Map<String, Object?>>[];
      server.listen((request) async {
        received.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': '  Paint a copper sky.  ',
                },
                'finish_reason': 'stop',
              },
            ],
          }),
        );
        await request.response.close();
      });
      final provider = ProviderConfig(
        id: 'enhancement-fixture',
        name: 'Enhancement fixture',
        providerType: ProviderKind.openai,
        enabled: true,
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
        apiKey: 'fixture',
        models: const ['gpt-4o-mini', 'gpt-3.5-turbo'],
      );
      for (final (modelId, vision) in [
        ('gpt-4o-mini', true),
        ('gpt-3.5-turbo', false),
      ]) {
        final model = ModelSpecResolver.instance.spec(provider, modelId);
        expect(model.supportsImageInput, vision);
        final rewrite = await CreationPromptEnhancer.rewrite(
          provider: provider,
          model: model,
          original: 'Clouds at dusk',
          template: 'Rewrite this: {prompt}',
          references: [file.path],
          requestId: 'enhance-$modelId',
          again: !vision,
        );
        expect(rewrite, 'Paint a copper sky.');
        final body = received.last;
        final messages = jsonEncode(body['messages']);
        expect(messages, contains('Rewrite this: Clouds at dusk'));
        expect(messages.contains('data:image/png;base64,'), vision);
        expect(messages.contains('distinct rewrite'), !vision);
        expect(body, isNot(contains('tools')));
      }
      expect(received, hasLength(2));
    },
  );
}

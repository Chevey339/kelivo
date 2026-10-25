import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

import 'support/collect_generation.dart';

enum _Api { chat, responses, claude, vertexClaude, gemini }

String _model(_Api api) => switch (api) {
  _Api.chat || _Api.responses => 'test-model',
  _Api.claude || _Api.vertexClaude => 'claude-sonnet-4-6',
  _Api.gemini => 'gemini-2.5-flash',
};

ProviderConfig _config(_Api api, String baseUrl, List<String> input) =>
    ProviderConfig(
      id: 'native-input-test',
      name: 'Native input test',
      enabled: true,
      apiKey: 'test-key',
      baseUrl: baseUrl,
      providerType: switch (api) {
        _Api.chat || _Api.responses => ProviderKind.openai,
        _Api.claude => ProviderKind.claude,
        _Api.vertexClaude || _Api.gemini => ProviderKind.google,
      },
      useResponseApi: api == _Api.responses,
      vertexAI: api == _Api.vertexClaude,
      modelOverrides: {
        _model(api): {'input': input},
      },
    );

Map<String, dynamic> _response(_Api api, bool tool) => switch (api) {
  _Api.chat => {
    'choices': [
      {
        'message': {
          'role': 'assistant',
          'content': tool ? '' : 'ok',
          if (tool)
            'tool_calls': [
              {
                'id': 'call_1',
                'type': 'function',
                'function': {'name': 'inspect', 'arguments': '{}'},
              },
            ],
        },
        'finish_reason': tool ? 'tool_calls' : 'stop',
      },
    ],
  },
  _Api.responses => {
    'id': 'response_1',
    'status': 'completed',
    'output': [
      if (tool)
        {
          'type': 'function_call',
          'id': 'fc_1',
          'call_id': 'call_1',
          'name': 'inspect',
          'arguments': '{}',
        }
      else
        {
          'type': 'message',
          'role': 'assistant',
          'content': [
            {'type': 'output_text', 'text': 'ok'},
          ],
        },
    ],
  },
  _Api.claude || _Api.vertexClaude => {
    'id': 'msg_1',
    'type': 'message',
    'role': 'assistant',
    'content': [
      if (tool)
        {'type': 'tool_use', 'id': 'call_1', 'name': 'inspect', 'input': {}}
      else
        {'type': 'text', 'text': 'ok'},
    ],
    'stop_reason': tool ? 'tool_use' : 'end_turn',
    'usage': {'input_tokens': 1, 'output_tokens': 1},
  },
  _Api.gemini => {
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            if (tool)
              {
                'functionCall': {'id': 'call_1', 'name': 'inspect', 'args': {}},
              }
            else
              {'text': 'ok'},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  },
};

String _sse(_Api api, bool tool) {
  final response = _response(api, tool);
  final events = switch (api) {
    _Api.chat => [
      {
        'choices': [
          {
            'delta': tool
                ? {
                    'tool_calls': [
                      {
                        ...response['choices'][0]['message']['tool_calls'][0]
                            as Map,
                        'index': 0,
                      },
                    ],
                  }
                : {'content': 'ok'},
            'finish_reason': tool ? 'tool_calls' : 'stop',
          },
        ],
      },
    ],
    _Api.responses => [
      if (tool)
        {
          'type': 'response.output_item.done',
          'output_index': 0,
          'item': response['output'][0],
        },
      if (!tool)
        {
          'type': 'response.output_text.delta',
          'output_index': 0,
          'content_index': 0,
          'item_id': 'msg_1',
          'delta': 'ok',
        },
      {'type': 'response.completed', 'response': response},
    ],
    _Api.claude || _Api.vertexClaude => [
      {
        'type': 'message_start',
        'message': {
          'id': 'msg_1',
          'usage': {'input_tokens': 1, 'output_tokens': 0},
        },
      },
      {
        'type': 'content_block_start',
        'index': 0,
        'content_block': tool
            ? {
                'type': 'tool_use',
                'id': 'call_1',
                'name': 'inspect',
                'input': {},
              }
            : {'type': 'text', 'text': ''},
      },
      {
        'type': 'content_block_delta',
        'index': 0,
        'delta': tool
            ? {'type': 'input_json_delta', 'partial_json': '{}'}
            : {'type': 'text_delta', 'text': 'ok'},
      },
      {'type': 'content_block_stop', 'index': 0},
      {
        'type': 'message_delta',
        'delta': {'stop_reason': tool ? 'tool_use' : 'end_turn'},
        'usage': {'output_tokens': 1},
      },
      {'type': 'message_stop'},
    ],
    _Api.gemini => [response],
  };
  return events
      .map(
        (e) =>
            '${e['type'] == null ? '' : 'event: ${e['type']}\n'}data: ${jsonEncode(e)}\n\n',
      )
      .join();
}

Iterable<Map> _maps(dynamic value) sync* {
  if (value is Map) {
    yield value;
    for (final child in value.values) {
      yield* _maps(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* _maps(child);
    }
  }
}

void main() {
  late Directory dir;
  late File pdf;
  late File audio;
  late File video;
  const bytes = [0, 1, 2, 128, 255];
  final encoded = base64Encode(bytes);
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('native_inputs_');
    pdf = File('${dir.path}/source.pdf')..writeAsBytesSync(bytes);
    audio = File('${dir.path}/voice.m4a')..writeAsBytesSync(bytes);
    video = File('${dir.path}/clip.mp4')..writeAsBytesSync(bytes);
  });
  tearDown(() => dir.delete(recursive: true));

  Map<String, dynamic> message({bool av = false}) => {
    'role': 'user',
    'content': 'describe these',
    multimodalInternalDocumentPathsKey: [
      encodeInternalDocumentRef((
        uri: pdf.path,
        name: 'Original report.pdf',
        mime: 'application/octet-stream',
      )),
    ],
    if (av)
      multimodalInternalMediaPathsKey: [
        encodeInternalMediaRef(uri: audio.path, mime: 'audio/mp4'),
        encodeInternalMediaRef(uri: video.path, mime: 'video/mp4'),
      ],
  };

  for (final api in _Api.values) {
    for (final stream in [false, true]) {
      test(
        '${api.name} stream=$stream sends original PDF without image input through tool continuation',
        () async {
          final requests = <Map<String, dynamic>>[];
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            requests.add(
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>(),
            );
            final tool = requests.length == 1;
            request.response.headers.contentType = stream
                ? ContentType('text', 'event-stream')
                : ContentType.json;
            request.response.write(
              stream ? _sse(api, tool) : jsonEncode(_response(api, tool)),
            );
            await request.response.close();
          });
          final av = api == _Api.gemini || api == _Api.chat;
          var toolCalls = 0;
          final chunks = await ChatApiService.sendMessageStream(
            config: _config(api, 'http://127.0.0.1:${server.port}', [
              'text',
              'pdf',
              if (av) ...['audio', 'video'],
            ]),
            modelId: _model(api),
            stream: stream,
            messages: [message(av: av)],
            // Duplicate latest-user refs must not upload the same attachment twice.
            userImagePaths: av ? [audio.uri.toString(), video.path] : null,
            tools: [
              {
                'type': 'function',
                'function': {
                  'name': 'inspect',
                  'parameters': {'type': 'object', 'properties': {}},
                },
              },
            ],
            onToolCall: (name, args, {toolCallId}) async {
              toolCalls++;
              return 'done';
            },
          ).toList();
          expect(chunks.joinedContent, 'ok');
          expect(toolCalls, 1);
          expect(requests, hasLength(2));
          for (final body in requests) {
            final all = _maps(body).toList();
            switch (api) {
              case _Api.chat:
                final file =
                    all.singleWhere((p) => p['type'] == 'file')['file'] as Map;
                expect(file['filename'], 'Original report.pdf');
                expect(
                  file['file_data'],
                  'data:application/pdf;base64,$encoded',
                );
                expect(
                  all.singleWhere(
                    (p) => p['type'] == 'input_audio',
                  )['input_audio'],
                  {'data': encoded, 'format': 'm4a'},
                );
                expect(
                  all.singleWhere((p) => p['type'] == 'video_url')['video_url'],
                  {'url': 'data:video/mp4;base64,$encoded'},
                );
              case _Api.responses:
                final file = all.singleWhere((p) => p['type'] == 'input_file');
                expect(file['filename'], 'Original report.pdf');
                expect(
                  file['file_data'],
                  'data:application/pdf;base64,$encoded',
                );
              case _Api.claude || _Api.vertexClaude:
                final file = all.singleWhere((p) => p['type'] == 'document');
                expect(file['source'], {
                  'type': 'base64',
                  'media_type': 'application/pdf',
                  'data': encoded,
                });
              case _Api.gemini:
                final files = all
                    .where((p) => p.containsKey('inline_data'))
                    .map((p) => p['inline_data'] as Map)
                    .toList();
                expect(
                  files.map((p) => p['mime_type']),
                  unorderedEquals([
                    'application/pdf',
                    'audio/m4a',
                    'video/mp4',
                  ]),
                );
                expect(files.every((p) => p['data'] == encoded), isTrue);
            }
            expect(jsonEncode(body), isNot(contains('_kelivo_')));
            expect(jsonEncode(body), isNot(contains(dir.path)));
          }
        },
      );
    }
  }

  test(
    'DashScope audio uses a data URL including on international endpoints',
    () async {
      for (final host in [
        'dashscope.aliyuncs.com',
        'dashscope-intl.aliyuncs.com',
        'cn-hongkong.dashscope.aliyuncs.com',
        'workspace.cn-beijing.maas.aliyuncs.com',
      ]) {
        final cfg = _config(_Api.chat, 'https://$host/compatible-mode/v1', [
          'audio',
        ]);
        final parts = await NativeInputAttachments(
          config: cfg,
          spec: ModelSpec(
            id: 'omni',
            displayName: 'omni',
            input: const [Modality.audio],
          ),
          protocol: NativeInputProtocol.chatCompletions,
        ).build(message(av: true));
        expect(parts.single['input_audio'], {
          'data': 'data:audio/mp4;base64,$encoded',
          'format': 'm4a',
        });
      }
    },
  );

  test(
    'OpenAI audio rejects M4A and sends WAV bytes without a data prefix',
    () async {
      final native = NativeInputAttachments(
        config: _config(_Api.chat, 'https://api.openai.com/v1', ['audio']),
        spec: ModelSpec(
          id: 'gpt-audio',
          displayName: 'audio',
          input: const [Modality.audio],
        ),
        protocol: NativeInputProtocol.chatCompletions,
      );
      await expectLater(
        native.build(message(av: true)),
        throwsUnsupportedError,
      );
      final wav = File('${dir.path}/voice.wav')..writeAsBytesSync(bytes);
      final parts = await native.build({
        'role': 'user',
        'content': '',
        multimodalInternalMediaPathsKey: [wav.path],
      });
      expect(parts.single['input_audio'], {'data': encoded, 'format': 'wav'});
    },
  );

  test('disabled modalities do not read files or emit native parts', () async {
    final native = NativeInputAttachments(
      config: _config(_Api.gemini, 'https://example.test', []),
      spec: ModelSpec(id: 'text', displayName: 'text'),
      protocol: NativeInputProtocol.gemini,
    );
    await pdf.delete();
    await audio.delete();
    await video.delete();
    expect(await native.build(message(av: true)), isEmpty);
  });

  test(
    'selected but unreadable PDF fails rather than sending an empty prompt',
    () async {
      final native = NativeInputAttachments(
        config: _config(_Api.responses, 'https://example.test', ['pdf']),
        spec: ModelSpec(
          id: 'pdf',
          displayName: 'pdf',
          input: const [Modality.pdf],
        ),
        protocol: NativeInputProtocol.responses,
      );
      await pdf.delete();
      await expectLater(
        native.build(message()),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}

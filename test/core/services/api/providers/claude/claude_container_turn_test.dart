import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/api/builtin_tools.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_container.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_history.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import '../../../../../support/claude_test_api.dart';
import '../../../../../support/collect_generation.dart';

/// One streamed response whose code run hands back a file, with text on
/// either side of it.
const _fileRunEvents = [
  {
    'type': 'content_block_start',
    'index': 0,
    'content_block': {'type': 'text', 'text': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 0,
    'delta': {'type': 'text_delta', 'text': 'before '},
  },
  {'type': 'content_block_stop', 'index': 0},
  {
    'type': 'content_block_start',
    'index': 1,
    'content_block': {
      'type': 'server_tool_use',
      'id': 'srvtoolu_run',
      'name': 'bash_code_execution',
      'input': {'command': 'python plot.py'},
    },
  },
  {'type': 'content_block_stop', 'index': 1},
  {
    'type': 'content_block_start',
    'index': 2,
    'content_block': {
      'type': 'bash_code_execution_tool_result',
      'tool_use_id': 'srvtoolu_run',
      'content': {
        'type': 'bash_code_execution_result',
        'stdout': '',
        'stderr': '',
        'return_code': 0,
        'content': [
          {'type': 'code_execution_output', 'file_id': 'file_chart'},
        ],
      },
    },
  },
  {'type': 'content_block_stop', 'index': 2},
  {
    'type': 'content_block_start',
    'index': 3,
    'content_block': {'type': 'text', 'text': ''},
  },
  {
    'type': 'content_block_delta',
    'index': 3,
    'delta': {'type': 'text_delta', 'text': 'after'},
  },
  {'type': 'content_block_stop', 'index': 3},
  {
    'type': 'message_delta',
    'delta': {'stop_reason': 'end_turn'},
  },
  {'type': 'message_stop'},
];

void main() {
  group('Claude container turn', () {
    test('a non-streaming hosted tool is persisted as a card', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'id': 'msg_1',
            'stop_reason': 'end_turn',
            'content': const [
              {
                'type': 'server_tool_use',
                'id': 'srvtoolu_fetch',
                'name': 'web_fetch',
                'input': {'url': 'https://example.com'},
              },
              {
                'type': 'web_fetch_tool_result',
                'tool_use_id': 'srvtoolu_fetch',
                'content': {
                  'type': 'web_fetch_result',
                  'url': 'https://example.com',
                },
              },
              {'type': 'text', 'text': 'ok'},
            ],
            'usage': {'input_tokens': 1, 'output_tokens': 1},
          }),
        );
        await request.response.close();
      });

      final result = await HttpOverrides.runZoned(
        () => ChatApiService.generateMessage(
          config: claudeConfig(baseUrl: officialBaseUrl),
          modelId: 'claude-opus-4-7',
          messages: const [
            {'role': 'user', 'content': 'fetch'},
          ],
        ),
        createHttpClient: (context) =>
            ProxyHttpOverrides(server.port).createHttpClient(context),
      );

      expect(result.text, 'ok');
      final tool =
          jsonDecode(result.parts.whereType<ToolCallPart>().single.payloadJson)
              as Map;
      expect(tool['name'], 'web_fetch');
      expect(tool['server'], isTrue);
      expect(tool['arguments'], {'url': 'https://example.com'});
      expect(tool['content'], {
        'type': 'web_fetch_result',
        'url': 'https://example.com',
      });
      // The turn's blocks are stored once, as the message's `claude_turn`
      // artifact; the card carries none of them.
      expect(tool['metadata'], isNull);
    });

    test(
      'a non-streaming container run resumes in the same container and fetches its files',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final paths = <String>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          paths.add(request.uri.path);
          if (request.method == 'GET') {
            // A failed download costs a file, never the turn.
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          bodies.add(
            (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                .cast<String, dynamic>(),
          );
          final paused = bodies.length == 1;
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'msg_${bodies.length}',
              'stop_reason': paused ? 'pause_turn' : 'end_turn',
              'container': {'id': 'container_abc'},
              'content': paused
                  ? const [
                      {
                        'type': 'server_tool_use',
                        'id': 'srvtoolu_run',
                        'name': 'bash_code_execution',
                        'input': {'command': 'python plot.py'},
                      },
                      {
                        'type': 'bash_code_execution_tool_result',
                        'tool_use_id': 'srvtoolu_run',
                        'content': {
                          'type': 'bash_code_execution_result',
                          'stdout': '',
                          'stderr': '',
                          'return_code': 0,
                          'content': [
                            {
                              'type': 'code_execution_output',
                              'file_id': 'file_chart',
                            },
                          ],
                        },
                      },
                    ]
                  : const [
                      {'type': 'text', 'text': 'ok'},
                    ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
          await request.response.close();
        });

        final config = claudeConfig(
          baseUrl: officialBaseUrl,
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.codeExecution],
            },
          },
        );
        await HttpOverrides.runZoned(
          () async {
            // A utility call would leave the container tool out entirely.
            final chunks = await ChatApiService.sendMessageStream(
              config: config,
              modelId: 'claude-opus-4-7',
              messages: const [
                {'role': 'user', 'content': 'hello'},
              ],
              stream: false,
            ).toList();
            expect(chunks.joinedContent, 'ok');
            // The container is stored as soon as a response names it, so a
            // turn stopped before its end still resumes in it next time.
            final containerAt = chunks.indexWhere(
              (chunk) =>
                  chunk is ProviderArtifact &&
                  chunk.kind == claudeContainerArtifactKind,
            );
            expect(containerAt, isNonNegative);
            expect(
              containerAt,
              lessThan(chunks.indexWhere((c) => c is TextDelta)),
            );
          },
          createHttpClient: (context) =>
              ProxyHttpOverrides(server.port).createHttpClient(context),
        );

        expect(bodies, hasLength(2));
        // The first round cannot know a container; every later one must name
        // the same container or the files it wrote are gone.
        expect(bodies[0].containsKey('container'), isFalse);
        expect(bodies[1]['container'], 'container_abc');
        expect(paths.where((path) => path.endsWith('/files/file_chart')), [
          '/files/file_chart',
        ]);
      },
    );

    test('a slow file download does not hold up the text after it', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_claude_dl_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SandboxPathResolver.debugSetDirs(docsDir: tempDir.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPathProvider;
        SandboxPathResolver.debugSetDirs();
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        if (request.method == 'GET') {
          if (request.uri.path.endsWith('/content')) {
            // The file takes longer than the rest of the stream does.
            await Future<void>.delayed(const Duration(milliseconds: 300));
            request.response.statusCode = HttpStatus.ok;
            request.response.add(const <int>[1, 2, 3, 4]);
          } else {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'id': 'file_chart',
                'filename': 'chart.png',
                'mime_type': 'image/png',
                'size_bytes': 4,
                'downloadable': true,
              }),
            );
          }
          await request.response.close();
          return;
        }
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(sseRound('msg_1', _fileRunEvents));
        await request.response.close();
      });

      final config = claudeConfig(
        baseUrl: officialBaseUrl,
        modelOverrides: const <String, dynamic>{
          'claude-opus-4-7': <String, dynamic>{
            'builtInTools': <String>[BuiltInToolNames.codeExecution],
          },
        },
      );
      late List<StreamChunk> chunks;
      await HttpOverrides.runZoned(
        () async {
          chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: 'claude-opus-4-7',
            messages: const [
              {'role': 'user', 'content': 'plot'},
            ],
          ).toList();
        },
        createHttpClient: (context) =>
            ProxyHttpOverrides(server.port).createHttpClient(context),
      );

      expect(chunks.joinedContent, 'before after');
      final lastText = chunks.lastIndexWhere((chunk) => chunk is TextDelta);
      final file = chunks.indexWhere((chunk) => chunk is GeneratedFile);
      expect(file, greaterThan(lastText), reason: 'the text must not wait');
      expect((chunks[file] as GeneratedFile).name, 'chart.png');
    });

    test('a download that breaks off leaves no file behind', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'kelivo_claude_dl_',
      );
      final previousPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      SandboxPathResolver.debugSetDirs(docsDir: tempDir.path);
      addTearDown(() async {
        PathProviderPlatform.instance = previousPathProvider;
        SandboxPathResolver.debugSetDirs();
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });
      server.listen((request) async {
        if (request.method == 'GET') {
          if (request.uri.path.endsWith('/content')) {
            // Half the body, then the connection drops.
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            socket.write('HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\n');
            socket.add(const <int>[1, 2, 3, 4]);
            await socket.flush();
            socket.destroy();
          } else {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'id': 'file_chart',
                'filename': 'chart.png',
                'mime_type': 'image/png',
                'size_bytes': 8,
                'downloadable': true,
              }),
            );
            await request.response.close();
          }
          return;
        }
        await utf8.decoder.bind(request).join();
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(sseRound('msg_1', _fileRunEvents));
        await request.response.close();
      });

      final config = claudeConfig(
        baseUrl: officialBaseUrl,
        modelOverrides: const <String, dynamic>{
          'claude-opus-4-7': <String, dynamic>{
            'builtInTools': <String>[BuiltInToolNames.codeExecution],
          },
        },
      );
      late List<StreamChunk> chunks;
      await HttpOverrides.runZoned(
        () async {
          chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: 'claude-opus-4-7',
            messages: const [
              {'role': 'user', 'content': 'plot'},
            ],
          ).toList();
        },
        createHttpClient: (context) =>
            ProxyHttpOverrides(server.port).createHttpClient(context),
      );

      // The turn survives the lost file; the half of it written is gone.
      expect(chunks.joinedContent, 'before after');
      expect(chunks.whereType<GeneratedFile>(), isEmpty);
      final leftovers = await tempDir
          .list(recursive: true)
          .where((entry) => entry is File)
          .toList();
      expect(leftovers, isEmpty);
    });

    test(
      'a conversation resumes in the container its last turn stored',
      () async {
        final bodies = <Map<String, dynamic>>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });
        server.listen((request) async {
          final body =
              (jsonDecode(await utf8.decoder.bind(request).join()) as Map)
                  .cast<String, dynamic>();
          bodies.add(body);
          // The second turn names a container that has since expired.
          if (bodies.length == 2) {
            request.response.statusCode = HttpStatus.badRequest;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'type': 'error',
                'error': {
                  'type': 'invalid_request_error',
                  'message': 'Container ${body['container']} not found',
                },
              }),
            );
            await request.response.close();
            return;
          }
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(<String, dynamic>{
              'id': 'msg_${bodies.length}',
              'stop_reason': 'end_turn',
              'container': {
                'id': 'container_${bodies.length}',
                'expires_at': '2099-01-01T00:00:00Z',
              },
              'content': const [
                {'type': 'text', 'text': 'ok'},
              ],
              'usage': {'input_tokens': 1, 'output_tokens': 1},
            }),
          );
          await request.response.close();
        });

        final config = claudeConfig(
          baseUrl: officialBaseUrl,
          modelOverrides: const <String, dynamic>{
            'claude-opus-4-7': <String, dynamic>{
              'builtInTools': <String>[BuiltInToolNames.codeExecution],
            },
          },
        );
        Future<String?> turn({String? storedContainer}) async {
          final chunks = await ChatApiService.sendMessageStream(
            config: config,
            modelId: 'claude-opus-4-7',
            messages: [
              {'role': 'user', 'content': 'hello'},
              if (storedContainer != null) ...[
                {
                  'role': 'assistant',
                  'content': 'ran some code',
                  multimodalInternalClaudeContainerKey: storedContainer,
                },
                {'role': 'user', 'content': 'and again'},
              ],
            ],
            stream: false,
          ).toList();
          expect(chunks.joinedContent, 'ok');
          return chunks
              .whereType<ProviderArtifact>()
              .singleWhere((a) => a.kind == claudeContainerArtifactKind)
              .payload;
        }

        await HttpOverrides.runZoned(
          () async {
            // The turn hands its container over; the chat stores it against
            // the assistant message and sends it back with the history.
            final first = await turn();
            expect(ClaudeContainerRef.decode(first)!.id, 'container_1');
            final second = await turn(storedContainer: first);
            expect(ClaudeContainerRef.decode(second)!.id, 'container_3');
            // A container lives 30 days, so a stored one is offered however
            // long ago its turn was; only the API decides it is gone.
            await turn(
              storedContainer: const ClaudeContainerRef(
                id: 'container_old',
              ).encode(),
            );
          },
          createHttpClient: (context) =>
              ProxyHttpOverrides(server.port).createHttpClient(context),
        );

        expect(bodies.map((body) => body['container']).toList(), [
          null, // nothing stored yet
          'container_1', // stored by the first turn, and told it expired
          null, // ...so the round retries fresh
          'container_old', // stored long ago, still offered
        ]);
        // The internal key never reaches the wire.
        expect(jsonEncode(bodies), isNot(contains('_kelivo_')));
      },
    );

    test('a turn is stored against its message once per response', () async {
      // Each response adds itself to the one recording, so the message ends
      // up with the whole turn and a turn cut short with what completed. The
      // cards carry none of it.
      final (bodies: _, :chunks) = await captureClaudeServerToolRounds(
        officialEndpoint: true,
      );

      final turns = chunks
          .whereType<ProviderArtifact>()
          .where((artifact) => artifact.kind == claudeTurnArtifactKind)
          .map((artifact) => decodeClaudeTurn(artifact.payload)!)
          .toList();
      expect(turns.map((turn) => turn.length).toList(), [1, 2]);
      expect(
        turns.last.map((response) => response.map((b) => b['type']).toList()),
        [
          ['server_tool_use', 'web_search_tool_result', 'tool_use'],
          ['text'],
        ],
      );
      expect(turns.last.first, turns.first.single);
      expect(
        chunks.whereType<ToolCallStart>().map((chunk) => chunk.metadata),
        everyElement(isNull),
      );
    });
  });
}

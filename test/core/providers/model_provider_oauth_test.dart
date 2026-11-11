import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/auto_retry_options.dart';
import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_test_harness.dart';

class _LocalHttpOverrides extends HttpOverrides {}

/// Keep the authenticated URL intact until the native transport opens it.
class _LocalHttpClient implements HttpClient {
  _LocalHttpClient(this.inner, this.port);

  final HttpClient inner;
  final int port;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => inner.openUrl(
    method,
    url.replace(scheme: 'http', host: '127.0.0.1', port: port),
  );

  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;

  @override
  set idleTimeout(Duration value) => inner.idleTimeout = value;

  @override
  void close({bool force = false}) => inner.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Codex OAuth', () {
    late SettingsProvider settings;
    late ProviderConfig config;
    setUp(() async {
      final harness = await createBusinessTestHarness();
      settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      final oauth = ProviderOAuthService.instance..bind(settings);
      addTearDown(() {
        oauth.unbind(settings);
        settings.dispose();
      });
      config = ProviderConfig(
        id: 'codex-probe',
        enabled: true,
        name: 'Codex',
        apiKey: '',
        baseUrl: OAuthProvider.chatgpt.baseUrl,
        providerType: ProviderKind.openai,
        oauthProvider: OAuthProvider.chatgpt,
        oauthCredentials: ProviderOAuthCredentials(
          accessToken: 'local-access',
          refreshToken: 'local-refresh',
          accountId: 'workspace',
          sessionId: 'login-session',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      await settings.setProviderConfig(config.id, config);
    });

    final completed = jsonEncode({
      'type': 'response.completed',
      'response': {'id': 'resp', 'status': 'completed', 'output': []},
    });
    for (final (label, contentType, body, error) in <(String, String, String, String?)>[
      (
        'failed',
        'text/event-stream',
        'data: {"type":"response.failed","response":{"status":"failed","error":{"code":"test_failure","message":"mock failure"}}}\n\n',
        'mock failure',
      ),
      (
        'error',
        'text/event-stream',
        'data: {"type":"error","code":"test_failure","message":"mock failure"}\n\n',
        'mock failure',
      ),
      (
        'event-only error type',
        'text/event-stream',
        'event: error\ndata: {"message":"event failure"}\n\n',
        'event failure',
      ),
      (
        'incomplete',
        'text/event-stream',
        'data: {"type":"response.incomplete","response":{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"}}}\n\n',
        'max_output_tokens',
      ),
      ('empty', 'text/event-stream', '', 'without a completed response'),
      (
        'truncated',
        'text/event-stream',
        'data: {"type":"response.created","response":{"id":"resp","status":"in_progress"}}\n\n',
        'without a completed response',
      ),
      (
        'DONE only',
        'text/event-stream',
        'data: [DONE]\n\n',
        'without a completed response',
      ),
      (
        'HTML',
        'text/html',
        '<html>unavailable</html>',
        'without a completed response',
      ),
      (
        'invalid JSON',
        'text/event-stream',
        'data: {broken\n\n',
        'Invalid Responses stream event',
      ),
      (
        'failed completion status',
        'text/event-stream',
        'data: {"type":"response.completed","response":{"status":"failed"}}\n\n',
        'did not complete successfully',
      ),
      (
        'nested completion error',
        'text/event-stream',
        'data: {"type":"response.completed","response":{"status":"completed","error":{"message":"nested failure"}}}\n\n',
        'nested failure',
      ),
      (
        'completed',
        'text/event-stream',
        'data: $completed\n\ndata: [DONE]\n\n',
        null,
      ),
      (
        'CRLF and multiline completion',
        'text/event-stream',
        ': heartbeat\r\n\r\nevent: response.completed\r\ndata: {"response":\r\ndata: {"id":"resp","status":"completed"}}\r\n\r\n',
        null,
      ),
    ]) {
      test('connection probe validates $label', () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final requests = <Map>[];
        server.listen((request) async {
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join()) as Map,
          );
          request.response.headers.contentType = ContentType.parse(contentType);
          request.response.write(body);
          await request.response.close();
        });
        await expectLater(
          HttpOverrides.runZoned(
            () => ProviderManager.testConnection(config, 'gpt-5.4'),
            createHttpClient: (context) => _LocalHttpClient(
              _LocalHttpOverrides().createHttpClient(context),
              server.port,
            ),
          ),
          error == null
              ? completes
              : throwsA(
                  isA<HttpException>().having(
                    (e) => e.message,
                    'message',
                    contains(error),
                  ),
                ),
        );
        expect(requests, hasLength(1));
        expect(requests.single['stream'], true);
      });
    }

    for (final conversationId in ['chat-1', null]) {
      test(
        'turn state survives retries and tools, resets next turn ($conversationId)',
        () async {
          config = config.copyWith(
            customHeaders: [
              {'name': 'X-Codex-Turn-State', 'value': 'stale-custom-state'},
            ],
          );
          await settings.setProviderConfig(config.id, config);
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          final headers = <Map<String, String>>[];
          final bodies = <Map>[];
          var clients = 0;
          var tools = 0;
          server.listen((request) async {
            final currentHeaders = <String, String>{};
            request.headers.forEach(
              (name, values) => currentHeaders[name] = values.join(','),
            );
            headers.add(currentHeaders);
            bodies.add(
              jsonDecode(await utf8.decoder.bind(request).join()) as Map,
            );
            final index = bodies.length - 1;
            request.response.headers
              ..contentType = ContentType('text', 'event-stream')
              ..set(
                'x-codex-turn-state',
                index == 0 ? 'ts-first' : 'ts-$index',
              );
            if (index == 0) {
              // A 200 stream failure exercises the outer retry, which creates a client.
              request.response.write(
                'data: {"type":"error","code":"overloaded","message":"try again"}\n\n',
              );
            } else if (index == 1) {
              request.response.write(
                'data: ${jsonEncode({
                  'type': 'response.output_item.done',
                  'output_index': 0,
                  'item': {'type': 'function_call', 'id': 'fc-1', 'call_id': 'call-1', 'name': 'lookup', 'arguments': '{}'},
                })}\n\n',
              );
              request.response.write(
                'data: ${jsonEncode({
                  'type': 'response.completed',
                  'response': {
                    'id': 'tool-response',
                    'status': 'completed',
                    'output': [
                      {'type': 'function_call', 'id': 'fc-1', 'call_id': 'call-1', 'name': 'lookup', 'arguments': '{}'},
                    ],
                  },
                })}\n\n',
              );
            } else if (index == 2) {
              request.response.statusCode = HttpStatus.serviceUnavailable;
              request.response.write('unavailable');
            } else {
              request.response.write(
                'data: {"type":"response.output_text.delta","delta":"OK"}\n\ndata: $completed\n\n',
              );
            }
            await request.response.close();
          });
          await HttpOverrides.runZoned(
            () async {
              Future<List<StreamChunk>> send() =>
                  ChatApiService.sendMessageStream(
                    config: config,
                    modelId: 'gpt-5.4',
                    conversationId: conversationId,
                    messages: const [
                      {'role': 'user', 'content': 'look up'},
                    ],
                    tools: const [
                      {
                        'type': 'function',
                        'function': {
                          'name': 'lookup',
                          'parameters': {'type': 'object', 'properties': {}},
                        },
                      },
                    ],
                    onToolCall: (name, arguments, {toolCallId}) async {
                      tools++;
                      return 'found it';
                    },
                    retryOverride: AutoRetryOptions(
                      enabled: true,
                      maxRetries: 1,
                      initialDelayMs: 0,
                      multiplier: 1,
                      maxDelayMs: 0,
                      jitter: false,
                      retryOnNetworkError: true,
                      retryStatusCodes:
                          AutoRetryOptions.defaultRetryStatusCodes,
                      retryKeywords: AutoRetryOptions.defaultRetryKeywords,
                      stopKeywords: AutoRetryOptions.defaultStopKeywords,
                    ),
                  ).toList();
              expect(
                (await send()).whereType<TextDelta>().map((e) => e.text).join(),
                'OK',
              );
              expect(clients, 2);
              expect(
                (await send()).whereType<TextDelta>().map((e) => e.text).join(),
                'OK',
              );
            },
            createHttpClient: (context) {
              clients++;
              return _LocalHttpClient(
                _LocalHttpOverrides().createHttpClient(context),
                server.port,
              );
            },
          );
          expect(tools, 1);
          expect(headers.map((h) => h['x-codex-turn-state']), [
            null,
            'ts-first',
            'ts-first',
            'ts-first',
            null,
          ]);
          final session = headers.first['session-id'];
          expect(session, isNotEmpty);
          for (var i = 0; i < headers.length; i++) {
            expect(headers[i]['thread-id'], headers[i]['session-id']);
            expect(bodies[i]['prompt_cache_key'], headers[i]['session-id']);
            expect(headers[i], isNot(contains('session_id')));
            expect(headers[i], isNot(contains('conversation_id')));
            if (i < 4 || conversationId != null) {
              expect(headers[i]['session-id'], session);
            } else {
              expect(headers[i]['session-id'], isNot(session));
            }
          }
          expect(
            (bodies[2]['input'] as List)
                .where((i) => i['type'] == 'function_call_output')
                .single['output'],
            'found it',
          );
          expect(bodies[3], bodies[2]);
        },
      );
    }
  });

  test(
    'Claude OAuth connection tests apply model ceilings and thinking budgets',
    () async {
      final harness = await createBusinessTestHarness();
      final settings = SettingsProvider(harness.preferences);
      await settings.loaded;
      final oauth = ProviderOAuthService.instance..bind(settings);
      addTearDown(() {
        oauth.unbind(settings);
        settings.dispose();
      });
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bodies = <Map>[];
      server.listen((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        bodies.add(body);
        final thinking = body['thinking'];
        if (thinking is Map && thinking['type'] == 'enabled') {
          final budget = thinking['budget_tokens'] as int;
          if (budget < 1024 || budget >= (body['max_tokens'] as int)) {
            request.response.statusCode = HttpStatus.badRequest;
          }
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        await request.response.close();
      });

      for (final (ceiling, budget, maximum, expectedMax, expectedBudget) in [
        (128000, null, null, 8, null),
        (128000, 4096, null, 8096, 4096),
        (4096, 4096, null, 4096, 1024),
        (128000, null, 999999, 128000, null),
      ]) {
        final config = ProviderConfig(
          id: 'claude-oauth-probe',
          enabled: true,
          name: 'Claude',
          apiKey: '',
          baseUrl: OAuthProvider.claude.baseUrl,
          providerType: ProviderKind.claude,
          oauthProvider: OAuthProvider.claude,
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'sk-ant-oat-test',
            refreshToken: 'test-refresh',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            sessionId: 'session',
          ),
          modelOverrides: {
            'local-alias': {
              'apiModelId': 'claude-sonnet-4-5',
              'maxOutput': ceiling,
              'body': [
                if (budget != null)
                  {
                    'key': 'thinking',
                    'value': jsonEncode({
                      'type': 'enabled',
                      'budget_tokens': budget,
                    }),
                  },
                if (maximum != null) {'key': 'max_tokens', 'value': '$maximum'},
              ],
            },
          },
        );
        await settings.setProviderConfig(config.id, config);
        await HttpOverrides.runZoned(
          () => ProviderManager.testConnection(config, 'local-alias'),
          createHttpClient: (context) => _LocalHttpClient(
            _LocalHttpOverrides().createHttpClient(context),
            server.port,
          ),
        );
        final body = bodies.last;
        expect(body['model'], 'claude-sonnet-4-5');
        expect(body['max_tokens'], expectedMax);
        expect((body['thinking'] as Map?)?['budget_tokens'], expectedBudget);
      }
      expect(bodies, hasLength(4));
    },
  );
}

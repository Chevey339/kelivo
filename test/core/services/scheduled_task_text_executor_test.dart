import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/auth/provider_oauth_service.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/scheduled_task.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/scheduled_task_text_executor.dart';
import 'package:Kelivo/core/services/scheduled_tasks_service.dart';
import '../../support/business_test_harness.dart';

// Route the real OAuth/API transport to a local server without changing the
// provider identity, URL validation, credential resolution or request builders.
class _LocalOAuthOverrides extends HttpOverrides {
  _LocalOAuthOverrides(this.port);
  final int port;
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _LocalOAuthClient(super.createHttpClient(context), port);
}

class _LocalOAuthClient implements HttpClient {
  _LocalOAuthClient(this.inner, this.port);
  final HttpClient inner;
  final int port;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => inner.openUrl(
    method,
    Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: url.path,
      query: url.query,
    ),
  );
  @override
  Duration? get connectionTimeout => inner.connectionTimeout;
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
  for (final template in <String?>[
    null,
    '只说正文。时间 {{scheduled_time}}，时差 {{utc_offset}}。Use tools.',
    '',
  ]) {
    test(
      'preparation separates task instructions and restricts tools (template: $template)',
      () async {
        const assistant = Assistant(
          id: 'a',
          name: 'Assistant',
          mcpServerIds: ['server'],
          localToolIds: ['run_shortcut'],
          customHeaders: [
            {'name': 'X-Assistant', 'value': 'assistant'},
            {'name': 'X-Route', 'value': 'assistant'},
          ],
          customBody: [
            {'key': 'tools', 'value': '[{"type":"shell"}]'},
          ],
        );
        final storage = await createBusinessTestHarness(
          initial: {
            'assistants_v1': jsonEncode([assistant.toJson()]),
          },
        );
        final assistants = AssistantProvider(preferences: storage.preferences);
        final settings = SettingsProvider(storage.preferences);
        final chat = ChatService();
        addTearDown(assistants.dispose);
        addTearDown(settings.dispose);
        addTearDown(chat.dispose);
        await Future.wait([assistants.loaded, settings.loaded]);
        final requests = <Map<String, dynamic>>[];
        final headers = <HttpHeaders>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          headers.add(request.headers);
          requests.add(
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>,
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'choices': [
                {
                  'message': {'role': 'assistant', 'content': 'Prepared hello'},
                  'finish_reason': 'stop',
                },
              ],
              'usage': {
                'prompt_tokens': 10,
                'completion_tokens': 5,
                'total_tokens': 15,
              },
            }),
          );
          await request.response.close();
        });
        await settings.setProviderConfig(
          'p',
          ProviderConfig(
            id: 'p',
            enabled: true,
            name: 'Provider',
            apiKey: 'test',
            baseUrl: 'http://${server.address.address}:${server.port}/v1',
            providerType: ProviderKind.openai,
            models: ['logical'],
            customHeaders: const [
              {'name': 'X-Provider', 'value': 'provider'},
              {'name': 'X-Route', 'value': 'provider'},
            ],
            customBody: const [
              {'key': 'tools', 'value': '[{"type":"web_search_preview"}]'},
            ],
            modelOverrides: const {
              'logical': {
                'apiModelId': 'vendor-model',
                'headers': [
                  {'name': 'X-Model-Key', 'value': 'model-key'},
                  {'key': 'x-route', 'value': 'model'},
                ],
                'builtInTools': ['search', 'shell'],
                'body': [
                  {'key': 'tools', 'value': '[{"type":"code_interpreter"}]'},
                ],
              },
            },
          ),
        );
        final executor = ScheduledTaskTextExecutor(
          chat: chat,
          assistants: assistants,
          settings: settings,
          busy: (_) => false,
          promptConfiguration: (_) => null,
          buildContext: (_, _, _, _) async => [
            {'role': 'system', 'content': 'Be concise.'},
          ],
        );
        final task = ScheduledTask(
          id: 'task',
          name: 'Task',
          prompt: 'Hello',
          assistantId: 'a',
          hour: 21,
          minute: 0,
          allowPreparation: true,
          preparationPrompt: template ?? ScheduledTask.defaultPreparationPrompt,
          modelProvider: 'p',
          modelId: 'logical',
        );
        final payload = await executor.prepare(
          task,
          ScheduledTaskRun(
            id: 'run',
            status: 'preparing',
            scheduledFor: DateTime(2026, 9, 19, 21),
            prepareAttempts: 1,
          ),
          ScheduledRunCancellation(),
        );
        expect(payload.text, 'Prepared hello');
        expect(payload.totalTokens, 15);
        expect(requests, hasLength(1));
        expect(requests.single['model'], 'vendor-model');
        expect(requests.single['tools'], isNull);
        expect(requests.single['tool_choice'], isNull);
        final messages = requests.single['messages'] as List;
        expect(messages.last, {'role': 'user', 'content': 'Hello'});
        expect(messages.first, {'role': 'system', 'content': 'Be concise.'});
        if (template == '') {
          expect(messages, hasLength(2));
        } else {
          final planned = DateTime(2026, 9, 19, 21);
          expect(messages, hasLength(3));
          expect(messages[1]['role'], 'system');
          final instructions = messages[1]['content'] as String;
          expect(instructions, contains(planned.toIso8601String()));
          expect(instructions, contains(planned.timeZoneOffset.toString()));
          expect(instructions, isNot(contains('{{')));
          if (template == null) {
            expect(instructions, contains('Output only the message itself'));
          } else {
            expect(
              instructions,
              template
                  .replaceAll('{{scheduled_time}}', planned.toIso8601String())
                  .replaceAll(
                    '{{utc_offset}}',
                    planned.timeZoneOffset.toString(),
                  ),
            );
          }
        }
        expect(headers.single.value('x-assistant'), 'assistant');
        expect(headers.single.value('x-provider'), 'provider');
        expect(headers.single.value('x-model-key'), 'model-key');
        expect(headers.single.value('x-route'), 'model');
        expect(chat.getAllConversations(), isEmpty);
      },
    );
  }

  for (final scenario in [
    (
      provider: OAuthProvider.chatgpt,
      custom: false,
      expired: false,
      unauthorized: false,
      protocol: 'openai',
    ),
    (
      provider: OAuthProvider.chatgpt,
      custom: true,
      expired: true,
      unauthorized: false,
      protocol: 'openai',
    ),
    (
      provider: OAuthProvider.chatgpt,
      custom: true,
      expired: false,
      unauthorized: true,
      protocol: 'openai',
    ),
    (
      provider: OAuthProvider.claude,
      custom: true,
      expired: false,
      unauthorized: false,
      protocol: 'anthropic',
    ),
    (
      provider: OAuthProvider.kimi,
      custom: true,
      expired: false,
      unauthorized: false,
      protocol: 'anthropic',
    ),
    (
      provider: OAuthProvider.kimi,
      custom: false,
      expired: false,
      unauthorized: false,
      protocol: 'openai',
    ),
    (
      provider: OAuthProvider.grok,
      custom: true,
      expired: false,
      unauthorized: false,
      protocol: 'openai',
    ),
  ]) {
    test(
      'preparation stays text-only after OAuth resolution and refresh: $scenario',
      () async {
        const assistant = Assistant(id: 'a', name: 'Assistant');
        final storage = await createBusinessTestHarness(
          initial: {
            'assistants_v1': jsonEncode([assistant.toJson()]),
          },
        );
        final assistants = AssistantProvider(preferences: storage.preferences);
        final settings = SettingsProvider(storage.preferences);
        final chat = ChatService();
        final oauth = ProviderOAuthService.instance;
        addTearDown(() {
          oauth.unbind(settings);
          assistants.dispose();
          settings.dispose();
          chat.dispose();
        });
        await Future.wait([assistants.loaded, settings.loaded]);
        final original = ProviderConfig(
          id: 'oauth-test',
          enabled: true,
          name: 'OAuth',
          apiKey: '',
          baseUrl: scenario.provider.baseUrl,
          providerType: ProviderKind.openai,
          oauthProvider: scenario.provider,
          oauthCredentials: ProviderOAuthCredentials(
            accessToken: 'old-test-token',
            refreshToken: 'test-refresh',
            sessionId: 'test-session',
            accountId: 'test-account',
            expiresAt: DateTime.now().add(
              scenario.expired
                  ? const Duration(hours: -1)
                  : const Duration(hours: 2),
            ),
          ),
          models: ['logical'],
          customBody: scenario.custom
              ? const [
                  {
                    'key': 'tools',
                    'value':
                        '[{"type":"code_interpreter","container":{"type":"auto"}}]',
                  },
                  {'key': 'tool_choice', 'value': 'required'},
                ]
              : const [],
          modelOverrides: {
            'logical': {
              'apiModelId': 'vendor-model',
              'headers': [
                {'name': 'X-Model-Key', 'value': 'oauth-model-key'},
              ],
              'builtInTools': ['search', 'code_interpreter'],
              'oauthProtocol': scenario.protocol,
              if (scenario.provider == OAuthProvider.kimi &&
                  scenario.protocol == 'openai') ...{
                'abilities': ['reasoning'],
                'oauthThinkingRequired': true,
                'oauthThinkingEfforts': ['high'],
                'oauthThinkingDefaultEffort': 'high',
              },
              if (scenario.custom)
                'body': [
                  {'key': 'tools', 'value': '[{"type":"web_search"}]'},
                  {'key': 'tool_choice', 'value': 'required'},
                ],
            },
          },
        );
        await settings.setProviderConfig(original.id, original);
        oauth.bind(settings);
        final bodies = <Map<String, dynamic>>[];
        final auth = <String?>[];
        final modelKeys = <String?>[];
        var refreshes = 0;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          final raw = await utf8.decoder.bind(request).join();
          request.response.headers.contentType = ContentType.json;
          if (request.uri.path.endsWith('/token')) {
            refreshes++;
            request.response.write(
              jsonEncode({
                'access_token': 'fresh-test-token',
                'refresh_token': 'test-refresh',
                'expires_in': 7200,
              }),
            );
          } else {
            final body = jsonDecode(raw) as Map<String, dynamic>;
            bodies.add(body);
            auth.add(request.headers.value('authorization'));
            modelKeys.add(request.headers.value('x-model-key'));
            if (scenario.unauthorized && bodies.length == 1) {
              request.response.statusCode = 401;
              request.response.write('{"error":"expired"}');
            } else if (body['stream'] == true) {
              request.response.headers.contentType = ContentType(
                'text',
                'event-stream',
              );
              request.response.write(
                'data: {"type":"response.output_text.delta","delta":"Prepared hello"}\n\ndata: {"type":"response.completed","response":{"id":"response","output":[]}}\n\n',
              );
            } else if (request.uri.path.endsWith('/messages')) {
              request.response.write(
                jsonEncode({
                  'id': 'response',
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {'type': 'text', 'text': 'Prepared hello'},
                  ],
                  'stop_reason': 'end_turn',
                  'usage': {'input_tokens': 10, 'output_tokens': 5},
                }),
              );
            } else if (request.uri.path.endsWith('/responses')) {
              request.response.write(
                jsonEncode({
                  'id': 'response',
                  'status': 'completed',
                  'output': [
                    {
                      'type': 'message',
                      'role': 'assistant',
                      'content': [
                        {'type': 'output_text', 'text': 'Prepared hello'},
                      ],
                    },
                  ],
                }),
              );
            } else {
              request.response.write(
                jsonEncode({
                  'choices': [
                    {
                      'message': {
                        'role': 'assistant',
                        'content': 'Prepared hello',
                      },
                      'finish_reason': 'stop',
                    },
                  ],
                }),
              );
            }
          }
          await request.response.close();
        });
        final executor = ScheduledTaskTextExecutor(
          chat: chat,
          assistants: assistants,
          settings: settings,
          busy: (_) => false,
          promptConfiguration: (_) => null,
          buildContext: (_, _, _, _) async => [
            {'role': 'system', 'content': 'Text only.'},
          ],
        );
        final payload = await HttpOverrides.runWithHttpOverrides(
          () => executor.prepare(
            const ScheduledTask(
              id: 'task',
              name: 'Task',
              prompt: 'Hello',
              assistantId: 'a',
              hour: 21,
              minute: 0,
              allowPreparation: true,
              modelProvider: 'oauth-test',
              modelId: 'logical',
            ),
            ScheduledTaskRun(
              id: 'run',
              status: 'preparing',
              scheduledFor: DateTime(2026, 9, 19, 21),
              prepareAttempts: 1,
            ),
            ScheduledRunCancellation(),
          ),
          _LocalOAuthOverrides(server.port),
        );
        expect(payload.text, 'Prepared hello');
        expect(bodies, hasLength(scenario.unauthorized ? 2 : 1));
        expect(refreshes, scenario.expired || scenario.unauthorized ? 1 : 0);
        expect(modelKeys, everyElement('oauth-model-key'));
        for (final body in bodies) {
          expect(body['model'], 'vendor-model');
          expect(body['tools'] ?? [], isEmpty);
          expect(body['tool_choice'], isNull);
        }
        if (refreshes > 0) expect(auth.last, 'Bearer fresh-test-token');
        if (scenario.provider == OAuthProvider.kimi &&
            scenario.protocol == 'openai') {
          expect(bodies.single['thinking'], {
            'type': 'enabled',
            'effort': 'high',
          });
        }
        // Request restrictions must not erase the user's stored provider options.
        expect(
          settings.getProviderConfig(original.id).customBody,
          original.customBody,
        );
        expect(
          settings.getProviderConfig(original.id).modelOverrides,
          original.modelOverrides,
        );
        expect(chat.getAllConversations(), isEmpty);
      },
    );
  }
}

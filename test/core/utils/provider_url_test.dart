import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/model_provider.dart';
import 'package:Kelivo/core/utils/provider_url.dart';

ProviderConfig config(
  String base, {
  ProviderKind kind = ProviderKind.openai,
  bool responses = false,
  String? path,
}) => ProviderConfig(
  id: 'Test',
  enabled: true,
  name: 'Test',
  apiKey: '',
  baseUrl: base,
  providerType: kind,
  useResponseApi: responses,
  chatPath: path,
);

void main() {
  group('normalizeBaseUrl', () {
    for (final kind in ProviderKind.values) {
      test('${kind.name} trims, adds scheme and only versions bare hosts', () {
        final result = normalizeBaseUrl('  api.example.com  ', kind);
        expect(
          result.value,
          'https://api.example.com${providerUrlVersion(kind)}',
        );
        expect(
          result.notes,
          containsAll([
            NormalizeNote.trimmedWhitespace,
            NormalizeNote.addedScheme,
            NormalizeNote.addedVersion,
          ]),
        );
        expect(result.error, isNull);
      });
      test('${kind.name} honors opt-out', () {
        final result = normalizeBaseUrl(
          ' https://api.example.com/ ',
          kind,
          allowAutoVersion: false,
        );
        expect(result.value, 'https://api.example.com');
        expect(result.notes, isNot(contains(NormalizeNote.addedVersion)));
      });
    }
    for (final raw in ['', '  ', '\n\t']) {
      test(
        'empty ${raw.codeUnits}',
        () => expect(
          normalizeBaseUrl(raw, ProviderKind.openai).error,
          UrlError.empty,
        ),
      );
    }
    for (final raw in [
      'htps://example.com',
      'ftp://example.com',
      'file:///tmp/file',
      'https://',
      'https:///v1',
      'https://a b.com',
      'https://example.com:abc',
      'https://[oops',
      'mailto:me@example.com',
      'https://host\\path',
    ]) {
      test(
        'rejects $raw',
        () => expect(
          normalizeBaseUrl(raw, ProviderKind.openai).error,
          UrlError.invalid,
        ),
      );
    }
    for (final raw in [
      'http://localhost:8080',
      'localhost:8080',
      '127.0.0.1:8000',
      'http://[::1]:8080',
    ]) {
      test(
        'accepts local endpoint $raw',
        () => expect(normalizeBaseUrl(raw, ProviderKind.openai).error, isNull),
      );
    }
    for (final path in ['/chat/completions', '/responses', '/messages']) {
      test('moves $path', () {
        final result = normalizeBaseUrl(
          'https://x.com/v1$path',
          ProviderKind.openai,
        );
        expect(result.value, 'https://x.com/v1');
        expect(result.movedPath, path);
        expect(result.notes, [NormalizeNote.movedPath]);
      });
    }
    test('trailing slash is removed before deciding on a version', () {
      final result = normalizeBaseUrl(
        'https://example.com///',
        ProviderKind.openai,
      );
      expect(result.value, 'https://example.com/v1');
      expect(result.notes, [
        NormalizeNote.trimmedSlash,
        NormalizeNote.addedVersion,
      ]);
      expect(
        normalizeBaseUrl(
          'https://example.com/v2///',
          ProviderKind.openai,
        ).value,
        'https://example.com/v2',
      );
    });
    for (final base in [
      'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'https://open.bigmodel.cn/api/paas/v4',
      'https://ark.cn-beijing.volces.com/api/v3',
      'https://relay.foo.cn/v2',
      'https://relay.foo.cn/v3',
      'https://relay.foo.cn/openai',
    ]) {
      test('preserves $base', () {
        final result = normalizeBaseUrl(base, ProviderKind.openai);
        expect(result.value, base);
        expect(result.notes, isEmpty);
      });
    }
    test('keeps query and fragment while splitting an endpoint', () {
      final result = normalizeBaseUrl(
        'https://x.com/v1/messages?route=1#ref',
        ProviderKind.claude,
      );
      expect(result.value, 'https://x.com/v1?route=1#ref');
      expect(result.movedPath, '/messages');
    });
  });

  group('resolveRequestUrl', () {
    test('OpenAI default, custom, empty paths and one trailing slash', () {
      expect(
        resolveRequestUrl(config('https://x.com/v1/')),
        'https://x.com/v1/chat/completions',
      );
      expect(
        resolveRequestUrl(config('https://x.com/v3', path: '/custom')),
        'https://x.com/v3/custom',
      );
      expect(
        resolveRequestUrl(config('https://x.com', path: '')),
        'https://x.com',
      );
      expect(
        resolveRequestUrl(
          config('https://x.com/v1', responses: true, path: '/custom'),
        ),
        'https://x.com/v1/responses',
      );
    });
    for (final host in ['dashscope.aliyuncs.com']) {
      test('DashScope Responses special case $host', () {
        expect(
          resolveRequestUrl(
            config('https://$host/compatible-mode/v1', responses: true),
          ),
          'https://$host/api/v2/apps/protocols/compatible-mode/v1/responses',
        );
        expect(
          resolveRequestUrl(
            config(
              'https://$host/api/v2/apps/protocols/compatible-mode/v1/',
              responses: true,
            ),
          ),
          'https://$host/api/v2/apps/protocols/compatible-mode/v1/responses',
        );
        expect(
          resolveRequestUrl(config('https://$host/compatible-mode/v1')),
          'https://$host/compatible-mode/v1/chat/completions',
        );
      });
    }
    test(
      'other DashScope hosts retain the existing standard Responses path',
      () => expect(
        resolveRequestUrl(
          config(
            'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
            responses: true,
          ),
        ),
        'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/responses',
      ),
    );
    test(
      'Claude ignores chat path',
      () => expect(
        resolveRequestUrl(
          config(
            'https://x.com/v1/',
            kind: ProviderKind.claude,
            path: '/custom',
          ),
        ),
        'https://x.com/v1/messages',
      ),
    );
    test('Gemini default placeholder and stream choice', () {
      final c = config('https://x.com/v1beta/', kind: ProviderKind.google);
      expect(
        resolveRequestUrl(c),
        'https://x.com/v1beta/models/{模型}:streamGenerateContent',
      );
      expect(
        resolveRequestUrl(c, modelId: 'gemini-test'),
        'https://x.com/v1beta/models/gemini-test:streamGenerateContent',
      );
      expect(
        resolveRequestUrl(c, modelId: 'gemini-test', stream: false),
        'https://x.com/v1beta/models/gemini-test:generateContent',
      );
    });
    test('Vertex uses project and location, incomplete config keeps base URL', () {
      final c = config(
        'https://aiplatform.googleapis.com',
        kind: ProviderKind.google,
      ).copyWith(vertexAI: true, location: 'us-central1', projectId: 'demo');
      expect(
        resolveRequestUrl(c, modelId: 'gemini-test'),
        'https://aiplatform.googleapis.com/v1/projects/demo/locations/us-central1/publishers/google/models/gemini-test:streamGenerateContent',
      );
      expect(
        resolveRequestUrl(c.copyWith(projectId: ''), modelId: 'gemini-test'),
        'https://aiplatform.googleapis.com/models/gemini-test:streamGenerateContent',
      );
      expect(
        resolveRequestUrl(c, modelId: 'claude-test'),
        'https://us-central1-aiplatform.googleapis.com/v1/projects/demo/locations/us-central1/publishers/anthropic/models/claude-test:streamRawPredict',
      );
    });
    test('opt-out survives serialization and unrelated copies', () {
      final old = config('https://example.com');
      expect(
        ProviderConfig.fromJson(
          old.toJson()..remove('autoVersionDisabled'),
        ).autoVersionDisabled,
        isFalse,
      );
      final edited = old
          .copyWith(autoVersionDisabled: true)
          .copyWith(name: 'Renamed');
      expect(
        ProviderConfig.fromJson(edited.toJson()).autoVersionDisabled,
        isTrue,
      );
      expect(edited.baseUrl, old.baseUrl);
    });
  });

  for (final kind in ProviderKind.values) {
    for (final stream in [false, true]) {
      test(
        'actual ${kind.name} connection request equals resolved URL, stream=$stream',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          late Uri received;
          server.listen((request) async {
            received = request.requestedUri;
            await request.drain<void>();
            request.response.write('{}');
            await request.response.close();
          });
          final c = config('http://127.0.0.1:${server.port}/v1/', kind: kind)
              .copyWith(
                modelOverrides: {
                  'logical': {'apiModelId': 'upstream'},
                },
              );
          String? displayed;
          await ProviderManager.testConnection(
            c,
            'logical',
            useStream: stream,
            onRequestUrl: (url) => displayed = url,
          );
          expect(
            received.toString(),
            resolveRequestUrl(c, modelId: 'upstream', stream: stream),
          );
          expect(displayed, received.toString());
        },
      );
    }
    test('${kind.name} model list strips trailing slash', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      late Uri received;
      server.listen((request) async {
        received = request.uri;
        request.response.write('{"data":[],"models":[]}');
        await request.response.close();
      });
      await ProviderManager.listModels(
        config('http://127.0.0.1:${server.port}/v1/', kind: kind),
      );
      expect(received.path, '/v1/models');
    });
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_container.dart';
import 'package:Kelivo/core/services/api/providers/claude/claude_files.dart';
import 'package:Kelivo/core/services/api/providers/claude_official.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';

const _model = 'claude-sonnet-4-5-20250929';

ProviderConfig _officialClaude({
  List<String> builtInTools = const ['code_execution'],
}) {
  return ProviderConfig(
    id: 'Claude',
    enabled: true,
    name: 'Claude',
    apiKey: 'sk-test',
    baseUrl: 'https://api.anthropic.com/v1',
    providerType: ProviderKind.claude,
    modelOverrides: {
      _model: {'builtInTools': builtInTools},
    },
  );
}

String _messagesResponse() => jsonEncode({
  'id': 'msg_1',
  'type': 'message',
  'role': 'assistant',
  'content': [
    {'type': 'text', 'text': 'ok'},
  ],
  'stop_reason': 'end_turn',
  'usage': {'input_tokens': 1, 'output_tokens': 1},
});

String _staleContainerResponse(String id) => jsonEncode({
  'type': 'error',
  'error': {
    'type': 'invalid_request_error',
    'message': 'Container $id not found',
  },
});

Map<String, dynamic> _doc(File file, String name, String mime) => {
  'uri': file.path,
  'name': name,
  'mime': mime,
};

List<Map> _blocks(Map<String, dynamic> body) =>
    ((body['messages'] as List).last['content'] as List).cast<Map>();

void main() {
  late Directory tempDir;
  late File sales;
  late File stock;
  late File chart;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_container_upload');
    sales = File('${tempDir.path}/sales.csv')..writeAsStringSync('a,b\n1,2\n');
    stock = File('${tempDir.path}/stock.xlsx')..writeAsBytesSync([1, 2, 3]);
    chart = File('${tempDir.path}/chart.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        ),
      );
  });

  tearDown(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Two turns: the first attached a spreadsheet and ran code in
  /// `container_1`; this one attaches a CSV and a text note.
  List<Map<String, dynamic>> conversation({String? storedContainer}) => [
    {
      'role': 'user',
      'content': 'earlier question',
      multimodalInternalDocumentPathsKey: [
        _doc(stock, 'stock.xlsx', 'application/vnd.ms-excel'),
      ],
    },
    {
      'role': 'assistant',
      'content': 'earlier answer',
      if (storedContainer != null)
        multimodalInternalClaudeContainerKey: '{"id":"$storedContainer"}',
    },
    {
      'role': 'user',
      'content': 'analyse this',
      multimodalInternalDocumentPathsKey: [
        _doc(sales, 'sales.csv', 'text/csv'),
        _doc(sales, 'notes.txt', 'text/plain'),
      ],
    },
  ];

  /// Answers uploads with ids taken from the file name and messages with a
  /// text reply, refusing the given container once as expired.
  ({List<http.Request> requests, http.Client client}) fakeApi({
    String? staleContainer,
    String? refusedUpload,
  }) {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/v1/files') {
        final name = RegExp(
          r'filename="([^"]+)"',
        ).firstMatch(request.body)!.group(1)!;
        if (name == refusedUpload) {
          return http.Response(
            '{"type":"error","error":{"type":"rate_limit_error",'
            '"message":"Too many requests"}}',
            429,
          );
        }
        return http.Response('{"id":"file_$name"}', 200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (staleContainer != null && body['container'] == staleContainer) {
        return http.Response(_staleContainerResponse(staleContainer), 400);
      }
      return http.Response(_messagesResponse(), 200);
    });
    return (requests: requests, client: client);
  }

  test('a fresh container gets every data file the user attached', () async {
    final api = fakeApi();

    await sendClaudeStream(
      api.client,
      _officialClaude(),
      _model,
      conversation(),
      stream: false,
    ).toList();

    expect(api.requests.map((r) => r.url.path), [
      '/v1/files',
      '/v1/files',
      '/v1/messages',
    ]);
    final upload = api.requests.first;
    expect(upload.headers['content-type'], startsWith('multipart/form-data'));
    expect(upload.headers['x-api-key'], 'sk-test');
    expect(upload.headers['accept'], isNull);

    final body = jsonDecode(api.requests.last.body) as Map<String, dynamic>;
    expect(body.containsKey('container'), isFalse);
    expect((body['messages'] as List).first['content'], 'earlier question');
    final last = _blocks(body);
    expect(last.map((b) => b['type']), [
      'text',
      'container_upload',
      'container_upload',
    ]);
    // Conversation order; the note is prose and stays in the prompt.
    expect(last.skip(1).map((b) => b['file_id']), [
      'file_stock.xlsx',
      'file_sales.csv',
    ]);
  });

  test('a container still in use gets only this turn\'s files', () async {
    final api = fakeApi();

    await sendClaudeStream(
      api.client,
      _officialClaude(),
      _model,
      conversation(storedContainer: 'container_1'),
      stream: false,
    ).toList();

    expect(api.requests.map((r) => r.url.path), ['/v1/files', '/v1/messages']);
    final body = jsonDecode(api.requests.last.body) as Map<String, dynamic>;
    expect(body['container'], 'container_1');
    expect(_blocks(body).map((b) => b['file_id']), [null, 'file_sales.csv']);
  });

  test('a container found expired gets the earlier files too', () async {
    final api = fakeApi(staleContainer: 'container_1');

    await sendClaudeStream(
      api.client,
      _officialClaude(),
      _model,
      conversation(storedContainer: 'container_1'),
      stream: false,
    ).toList();

    expect(api.requests.map((r) => r.url.path), [
      '/v1/files',
      '/v1/messages',
      '/v1/files',
      '/v1/messages',
    ]);
    final retry = jsonDecode(api.requests.last.body) as Map<String, dynamic>;
    expect(retry.containsKey('container'), isFalse);
    // This turn's file went up before the first attempt; only the earlier
    // one is added, and it is not uploaded twice.
    expect(_blocks(retry).map((b) => b['file_id']), [
      null,
      'file_sales.csv',
      'file_stock.xlsx',
    ]);
  });

  test('an image the model drew last turn is not uploaded', () async {
    final api = fakeApi();

    await sendClaudeStream(api.client, _officialClaude(), _model, [
      {'role': 'user', 'content': 'draw a chart'},
      {
        'role': 'assistant',
        'content': 'done',
        multimodalInternalMediaPathsKey: [chart.path],
        multimodalInternalClaudeContainerKey: '{"id":"container_1"}',
      },
      {'role': 'user', 'content': 'which bar is tallest'},
    ], stream: false).toList();

    expect(api.requests.map((r) => r.url.path), ['/v1/messages']);
    final body = jsonDecode(api.requests.single.body) as Map<String, dynamic>;
    // The chart reaches the model as an image block, not a container file.
    expect(_blocks(body).map((b) => b['type']), ['text', 'image', 'text']);
  });

  test('without the tool nothing is uploaded', () async {
    final api = fakeApi();

    await sendClaudeStream(
      api.client,
      _officialClaude(builtInTools: const ['web_fetch']),
      _model,
      conversation(),
      stream: false,
    ).toList();

    expect(api.requests.map((r) => r.url.path), ['/v1/messages']);
    final body = jsonDecode(api.requests.single.body) as Map<String, dynamic>;
    expect((body['messages'] as List).last['content'], 'analyse this');
  });

  test(
    'files attached after the stored container go up with this turn\'s',
    () async {
      // The reply to the second question was deleted (or its send failed
      // before a request), so the stored container is the first reply's and
      // has never seen q2.csv.
      final q2 = File('${tempDir.path}/q2.csv')..writeAsStringSync('q\n2\n');
      final api = fakeApi();

      await sendClaudeStream(api.client, _officialClaude(), _model, [
        {
          'role': 'user',
          'content': 'first question',
          multimodalInternalDocumentPathsKey: [
            _doc(stock, 'stock.xlsx', 'application/vnd.ms-excel'),
          ],
        },
        {
          'role': 'assistant',
          'content': 'first answer',
          multimodalInternalClaudeContainerKey: '{"id":"container_1"}',
        },
        {
          'role': 'user',
          'content': 'second question',
          multimodalInternalDocumentPathsKey: [_doc(q2, 'q2.csv', 'text/csv')],
        },
        {
          'role': 'user',
          'content': 'third question',
          multimodalInternalDocumentPathsKey: [
            _doc(sales, 'sales.csv', 'text/csv'),
          ],
        },
      ], stream: false).toList();

      final body = jsonDecode(api.requests.last.body) as Map<String, dynamic>;
      expect(body['container'], 'container_1');
      expect(_blocks(body).map((b) => b['file_id']), [
        null,
        'file_q2.csv',
        'file_sales.csv',
      ]);
    },
  );

  test('a refused upload of this turn\'s file fails the turn first', () async {
    final api = fakeApi(refusedUpload: 'sales.csv');

    await expectLater(
      sendClaudeStream(
        api.client,
        _officialClaude(),
        _model,
        conversation(),
        stream: false,
      ).toList(),
      throwsA(
        isA<ClaudeFileUploadException>().having(
          (e) => e.toString(),
          'message',
          'Attachment "sales.csv" could not be uploaded: '
              'HTTP 429: Too many requests',
        ),
      ),
    );
    expect(api.requests.map((r) => r.url.path), ['/v1/files', '/v1/files']);
  });

  test('an earlier turn\'s lost file is reported, not fatal', () async {
    // The spreadsheet from the first turn was cleared from the device; a
    // fresh container wants it, but this turn is about the CSV.
    stock.deleteSync();
    final api = fakeApi();

    await sendClaudeStream(
      api.client,
      _officialClaude(),
      _model,
      conversation(),
      stream: false,
    ).toList();

    expect(api.requests.map((r) => r.url.path), ['/v1/files', '/v1/messages']);
    final body = jsonDecode(api.requests.last.body) as Map<String, dynamic>;
    expect(_blocks(body).map((b) => b['type']), [
      'text',
      'text',
      'container_upload',
    ]);
    expect(
      _blocks(body)[1]['text'],
      'Attachment "stock.xlsx" could not be uploaded: the file cannot be read',
    );
  });

  test('an error about a container_upload block is not a stale container', () {
    expect(
      isClaudeStaleContainerError(
        400,
        '{"error":{"message":"messages.2.content.1.container_upload.file_id: '
        'file not found"}}',
      ),
      isFalse,
    );
    expect(
      isClaudeStaleContainerError(
        400,
        '{"error":{"message":"container container_01 not found"}}',
      ),
      isTrue,
    );
    expect(isClaudeStaleContainerError(500, 'container'), isFalse);
  });
}

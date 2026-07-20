import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/core/services/api/chat_api_service.dart';

ProviderConfig _openAiConfig(String baseUrl) {
  return ProviderConfig(
    id: 'OpenAITest',
    enabled: true,
    name: 'OpenAITest',
    apiKey: 'test-key',
    baseUrl: baseUrl,
    providerType: ProviderKind.openai,
    useResponseApi: false,
  );
}

ProviderConfig _openAiResponsesConfig(String baseUrl) {
  return _openAiConfig(baseUrl).copyWith(useResponseApi: true);
}

/// Build a minimal valid DOCX (ZIP containing word/document.xml).
Uint8List _buildMinimalDocx(String text) {
  final archive = Archive();
  final documentXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:body><w:p><w:r><w:t>$text</w:t></w:r></w:p></w:body>'
      '</w:document>';
  archive.addFile(
    ArchiveFile(
      'word/document.xml',
      documentXml.length,
      utf8.encode(documentXml),
    ),
  );
  final encoded = ZipEncoder().encode(archive);
  return Uint8List.fromList(encoded);
}

void main() {
  late Directory tempDir;
  late String docxPath;
  late String pngPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kelivo_office_doc_');
    docxPath = '${tempDir.path}/test.docx';
    await File(docxPath).writeAsBytes(_buildMinimalDocx('Hello World'));
    pngPath = '${tempDir.path}/img.png';
    await File(
      pngPath,
    ).writeAsBytes(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Chat completions path', () {
    test('routes DOCX via userMediaPaths as file type', () async {
      final body = await _sendAndCaptureChatBody((baseUrl) {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {'role': 'user', 'content': 'summarize this'},
          ],
          userMediaPaths: [docxPath],
          stream: false,
        ).toList();
      });

      final parts = _extractChatMessageParts(body);
      expect(parts, hasLength(2));
      expect(parts[0]['type'], 'text');
      expect(parts[0]['text'], 'summarize this');
      expect(parts[1]['type'], 'file');
      expect(parts[1]['file']['filename'], 'test.docx');
      final fileData = parts[1]['file']['file_data'] as String;
      expect(
        fileData.startsWith(
          'data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,',
        ),
        isTrue,
      );
    });

    test('does not send image_url for DOCX', () async {
      final body = await _sendAndCaptureChatBody((baseUrl) {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {'role': 'user', 'content': 'summarize this'},
          ],
          userMediaPaths: [docxPath],
          stream: false,
        ).toList();
      });

      expect(jsonEncode(body), isNot(contains('image_url')));
    });

    test('still routes images as image_url alongside DOCX file', () async {
      final body = await _sendAndCaptureChatBody((baseUrl) {
        return ChatApiService.sendMessageStream(
          config: _openAiConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {'role': 'user', 'content': 'describe this'},
          ],
          userMediaPaths: [pngPath, docxPath],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(body);
      expect(encoded, contains('image_url'));
      expect(encoded, contains('file'));
      final parts = _extractChatMessageParts(body);
      final imageParts = parts.where((p) => p['type'] == 'image_url').toList();
      final fileParts = parts.where((p) => p['type'] == 'file').toList();
      expect(imageParts, hasLength(1));
      expect(fileParts, hasLength(1));
      expect(fileParts[0]['file']['filename'], 'test.docx');
    });
  });

  group('Responses API path', () {
    test('routes DOCX via userMediaPaths as input_file type', () async {
      final requestBodies = await _sendAndCaptureResponsesBodies((baseUrl) {
        return ChatApiService.sendMessageStream(
          config: _openAiResponsesConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {'role': 'user', 'content': 'summarize this'},
          ],
          userMediaPaths: [docxPath],
          stream: false,
        ).toList();
      });

      expect(requestBodies, hasLength(1));
      final input = (requestBodies[0]['input'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);
      final userMsg = input.firstWhere((item) => item['role'] == 'user');
      final content = (userMsg['content'] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false);

      expect(content, hasLength(2));
      expect(content[0]['type'], 'input_text');
      expect(content[0]['text'], 'summarize this');
      expect(content[1]['type'], 'input_file');
      expect(content[1]['filename'], 'test.docx');
      final fileData = content[1]['file_data'] as String;
      expect(
        fileData.startsWith(
          'data:application/vnd.openxmlformats-officedocument.wordprocessingml.document;base64,',
        ),
        isTrue,
      );
    });

    test('does not send input_image for DOCX in Responses API', () async {
      final requestBodies = await _sendAndCaptureResponsesBodies((baseUrl) {
        return ChatApiService.sendMessageStream(
          config: _openAiResponsesConfig(baseUrl),
          modelId: 'gpt-4.1',
          messages: const [
            {'role': 'user', 'content': 'summarize this'},
          ],
          userMediaPaths: [docxPath],
          stream: false,
        ).toList();
      });

      final encoded = jsonEncode(requestBodies[0]);
      expect(encoded, isNot(contains('input_image')));
    });

    test(
      'still routes images as input_image alongside DOCX input_file',
      () async {
        final requestBodies = await _sendAndCaptureResponsesBodies((baseUrl) {
          return ChatApiService.sendMessageStream(
            config: _openAiResponsesConfig(baseUrl),
            modelId: 'gpt-4.1',
            messages: const [
              {'role': 'user', 'content': 'describe this'},
            ],
            userMediaPaths: [pngPath, docxPath],
            stream: false,
          ).toList();
        });

        expect(requestBodies, hasLength(1));
        final encoded = jsonEncode(requestBodies[0]);
        expect(encoded, contains('input_image'));
        expect(encoded, contains('input_file'));
      },
    );
  });
}

/// Send a request through the Chat Completions (JSON) path and capture the body.
Future<Map<String, dynamic>> _sendAndCaptureChatBody(
  Future<List<dynamic>> Function(String baseUrl) sendRequest,
) async {
  Map<String, dynamic>? requestBody;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.address}:${server.port}/v1';

  try {
    server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      requestBody = (jsonDecode(rawBody) as Map).cast<String, dynamic>();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'id': 'chatcmpl-1',
          'object': 'chat.completion',
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': 'ok'},
              'finish_reason': 'stop',
            },
          ],
          'usage': {
            'prompt_tokens': 1,
            'completion_tokens': 1,
            'total_tokens': 2,
          },
        }),
      );
      await request.response.close();
    });

    final chunks = await sendRequest(baseUrl);
    expect(chunks, isNotEmpty);
    expect(requestBody, isNotNull);
    return requestBody!;
  } finally {
    await server.close(force: true);
  }
}

/// Extract structured content parts from a Chat Completions message body.
List<Map<String, dynamic>> _extractChatMessageParts(Map<String, dynamic> body) {
  final messages = (body['messages'] as List).cast<dynamic>();
  expect(messages, hasLength(1));
  final content =
      (messages.single as Map<String, dynamic>)['content'] as List<dynamic>;
  return content
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList(growable: false);
}

/// Send a request through the Responses API (non-streaming) path and capture all request bodies.
Future<List<Map<String, dynamic>>> _sendAndCaptureResponsesBodies(
  Future<List<dynamic>> Function(String baseUrl) sendRequest,
) async {
  final requestBodies = <Map<String, dynamic>>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final baseUrl = 'http://${server.address.address}:${server.port}/v1';

  try {
    server.listen((request) async {
      final rawBody = await utf8.decoder.bind(request).join();
      requestBodies.add((jsonDecode(rawBody) as Map).cast<String, dynamic>());
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'output_text': 'done',
          'usage': {'input_tokens': 1, 'output_tokens': 1},
        }),
      );
      await request.response.close();
    });

    final chunks = await sendRequest(baseUrl);
    expect(chunks, isNotEmpty);
    expect(requestBodies, isNotEmpty);
    return requestBodies;
  } finally {
    await server.close(force: true);
  }
}

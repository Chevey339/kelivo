import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/tool_call_cancellation.dart';
import 'package:Kelivo/core/services/api/chat_api_service.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/mcp/mcp_image_snapshot.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  test(
    'stopping generation aborts the historical image download before sending',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final connected = Completer<void>();
      final disconnected = Completer<void>();
      var providerRequests = 0;
      server.listen((request) async {
        if (request.uri.path != '/drawing.png') {
          providerRequests++;
          request.response.statusCode = 500;
          await request.response.close();
          return;
        }
        final socket = await request.response.detachSocket(writeHeaders: false);
        addTearDown(socket.destroy);
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 1000\r\n\r\na',
        );
        await socket.flush();
        void disconnectedFromPeer() {
          if (!disconnected.isCompleted) disconnected.complete();
        }

        socket.listen(
          (_) {},
          onDone: disconnectedFromPeer,
          onError: (Object _) => disconnectedFromPeer(),
        );
        connected.complete();
      });
      const requestId = 'mcp-history-cancellation';
      final url = 'http://127.0.0.1:${server.port}/drawing.png';
      final generation = ChatApiService.sendMessageStream(
        config: ProviderConfig(
          id: 'mcp-images',
          name: 'mcp-images',
          enabled: true,
          apiKey: 'test',
          baseUrl: 'http://127.0.0.1:${server.port}',
          providerType: ProviderKind.openai,
          modelOverrides: {
            'gpt-4.1': {
              'input': ['text', 'image'],
              'abilities': ['tool'],
            },
          },
        ),
        modelId: 'gpt-4.1',
        requestId: requestId,
        stream: false,
        messages: [
          {'role': 'user', 'content': 'inspect'},
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call_image',
                'type': 'function',
                'function': {'name': 'view_drawing', 'arguments': '{}'},
              },
            ],
          },
          {
            'role': 'tool',
            'name': 'view_drawing',
            'tool_call_id': 'call_image',
            'content': '![]($url)',
            'metadata': {
              kMcpResultMetadataKey: mcpResultMetadata([url]),
            },
          },
          {'role': 'user', 'content': 'describe again'},
        ],
      ).toList();
      final stopped = generation.then<void>((_) {}, onError: (Object _) {});
      await connected.future.timeout(const Duration(seconds: 3));
      ChatApiService.cancelRequest(requestId);
      await disconnected.future.timeout(const Duration(seconds: 3));
      await stopped.timeout(const Duration(seconds: 3));
      expect(providerRequests, 0);
    },
  );

  for (final cancel in [false, true]) {
    test(
      '${cancel ? 'cancellation' : 'timeout'} closes a stalled image connection',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final connected = Completer<void>();
        final disconnected = Completer<void>();
        server.listen((request) async {
          final socket = await request.response.detachSocket(
            writeHeaders: false,
          );
          addTearDown(socket.destroy);
          socket.write(
            'HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: 1000\r\n\r\na',
          );
          await socket.flush();
          socket.listen(
            (_) {},
            onDone: () {
              if (!disconnected.isCompleted) disconnected.complete();
            },
            onError: (Object _) {
              if (!disconnected.isCompleted) disconnected.complete();
            },
          );
          connected.complete();
        });
        final cancellation = Completer<void>();
        final context = ToolCallCancellation(
          isCancelled: () => cancellation.isCompleted,
          cancelled: cancellation.future,
        );
        final download = context.run(
          () => McpImageSnapshot.download(
            'http://127.0.0.1:${server.port}/image.png',
            timeout: cancel
                ? const Duration(seconds: 10)
                : const Duration(milliseconds: 300),
          ),
        );
        final result = cancel
            ? expectLater(download, throwsStateError)
            : expectLater(download, completion(isNull));
        await connected.future.timeout(const Duration(seconds: 3));
        if (cancel) cancellation.complete();
        await result;
        await disconnected.future.timeout(const Duration(seconds: 3));
      },
    );
  }
}

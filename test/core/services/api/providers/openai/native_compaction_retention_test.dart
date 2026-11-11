import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/models/provider_oauth.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/native_compaction_context.dart';
import 'package:Kelivo/core/services/api/providers/openai/native_compaction.dart';
import 'package:Kelivo/core/services/api/providers/openai/responses_request.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/request_token_estimate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

int _tokens(Map item) => estimateRequestInput({
  'input': [item],
}, ProviderKind.openai);

Map<String, dynamic> _userWithTokens(int tokens) {
  final item = <String, dynamic>{
    'role': 'user',
    'content': 'start end',
    historySourceKey: 'user',
  };
  final words = tokens - _tokens(item);
  item['content'] = 'start ${'word ' * words}end';
  expect(_tokens(item), tokens);
  return item;
}

void main() {
  final config = nativeResponsesConfig(
    ProviderConfig(
      id: 'subscription',
      name: 'Subscription',
      enabled: true,
      oauthProvider: OAuthProvider.chatgpt,
      baseUrl: OAuthProvider.chatgpt.baseUrl,
      apiKey: 'test',
    ),
  );
  const model = 'custom-codex-model';
  const compaction = {
    'type': 'compaction',
    'id': 'signed',
    'encrypted_content': 'do-not-change',
  };

  Future<NativeCompactionPayload> compact(
    Map<String, dynamic> body, {
    void Function()? onResponse,
  }) async {
    String event(Map<String, dynamic> value) =>
        'data: ${jsonEncode(value)}\n\n';
    final original = jsonEncode(body);
    final client = MockClient((request) async {
      expect(request.body, isNot(contains(nativeCompactionWireKey)));
      expect(request.body, isNot(contains(historySourceKey)));
      onResponse?.call();
      return http.Response(
        event({
              'type': 'response.output_item.done',
              'output_index': 0,
              'item': compaction,
            }) +
            event({
              'type': 'response.completed',
              'response': {'status': 'completed'},
            }),
        200,
      );
    });
    addTearDown(client.close);
    final result = await requestNativeCompaction(client, config, model, body);
    expect(jsonEncode(body), original);
    expect(result.output.last, compaction);
    expect(
      result.output
          .where((item) => item['role'] == 'user')
          .fold<int>(0, (sum, item) => sum + _tokens(item)),
      lessThanOrEqualTo(64000),
    );
    return result;
  }

  Future<Map<String, dynamic>> prepare(
    List<Map<String, dynamic>> messages,
  ) async {
    final body = await buildOpenAIResponsesBody(
      config,
      model,
      RequestHistoryContext.identify(messages),
    );
    return RequestImageContext(
      settings: const ImageContextSettings(),
      images: [],
    ).project(body, preserveSources: true);
  }

  test('near-64k user retention is unchanged across native replays', () async {
    final original = await prepare([
      {..._userWithTokens(31999), imageContextOwnerKey: 'old'},
      {..._userWithTokens(31999), imageContextOwnerKey: 'new'},
    ]);
    final first = await compact(original);
    expect(first.output, hasLength(3));
    var previous = first;
    for (var pass = 0; pass < 2; pass++) {
      final replay = await prepare([
        {
          'role': 'user',
          'content': '',
          imageContextOwnerKey: 'native-window',
          nativeCompactionMessageKey: previous.toJson(),
        },
      ]);
      final input = (replay['input'] as List).cast<Map>();
      expect(
        input.every((item) => item[nativeCompactionWireKey] == true),
        isTrue,
      );
      expect(input.where((item) => item['role'] == 'user').map(_tokens), [
        31999,
        31999,
      ]);
      previous = await compact(replay);
      expect(previous.output, first.output);
    }
  });

  test('50k newest user leaves 14k for part of the older 20k user', () async {
    final old = _userWithTokens(20000);
    final newest = _userWithTokens(50000);
    final result = await compact({
      'model': model,
      'input': [old, newest],
    });
    expect(result.output, hasLength(3));
    final boundary = result.output.first;
    final text = boundary['content'] as String;
    expect(text, startsWith('start '));
    expect(text, endsWith('end'));
    expect(text, contains('[…truncated…]'));
    expect(text.length, lessThan((old['content'] as String).length));
    expect(_tokens(boundary), inInclusiveRange(13990, 14000));
    expect(result.output[1]['content'], newest['content']);

    final replay = await prepare([
      {
        'role': 'user',
        'content': '',
        imageContextOwnerKey: 'native-window',
        nativeCompactionMessageKey: result.toJson(),
      },
    ]);
    expect((await compact(replay)).output, result.output);
  });

  test(
    'an oversized newest text user is retained within the full budget',
    () async {
      var eventLoopAdvanced = false;
      final result = await compact({
        'model': model,
        'input': [_userWithTokens(100000)],
      }, onResponse: () => Timer.run(() => eventLoopAdvanced = true));
      expect(eventLoopAdvanced, isTrue);
      expect(result.output, hasLength(2));
      expect(_tokens(result.output.first), inInclusiveRange(63990, 64000));
    },
  );

  test(
    'multipart boundary preserves text fields and Unicode within budget',
    () async {
      const firstPart = {'type': 'input_text', 'text': 'introduction'};
      final result = await compact({
        'model': model,
        'input': [
          {
            'type': 'message',
            'role': 'user',
            'id': 'boundary',
            'content': [
              firstPart,
              {
                'type': 'input_text',
                'text': '😀中文\\"\n' * 3000,
                'vendor_field': 'preserve',
              },
              {'type': 'input_text', 'text': 'after the exhausted text budget'},
            ],
          },
          _userWithTokens(63000),
        ],
      });
      expect(result.output, hasLength(3));
      final boundary = result.output.first;
      expect(boundary['id'], 'boundary');
      expect(_tokens(boundary), inInclusiveRange(970, 1000));
      final parts = boundary['content'] as List;
      expect(parts, hasLength(2));
      expect(parts.first, firstPart);
      expect(parts.last['vendor_field'], 'preserve');
      final text = parts.last['text'] as String;
      expect(text, contains('[…truncated…]'));
      expect(utf8.decode(utf8.encode(text)), text);
      expect(
        text.runes.any((rune) => rune >= 0xD800 && rune <= 0xDFFF),
        isFalse,
      );
    },
  );

  for (final newestTokens in [63999, 64000]) {
    test(
      'no placeholder is kept when only ${64000 - newestTokens} tokens remain',
      () async {
        final newest = _userWithTokens(newestTokens);
        final result = await compact({
          'model': model,
          'input': [_userWithTokens(20000), newest],
        });
        expect(result.output, hasLength(2));
        expect(result.output.first['content'], newest['content']);
      },
    );
  }

  for (final part in [
    {'type': 'input_image', 'image_url': 'data:image/png;base64,YWJj'},
    {'type': 'input_file', 'file_id': 'file-123'},
    {'type': 'future_content', 'data': 'opaque'},
  ]) {
    test(
      'an oversized ${part['type']} boundary is neither rewritten nor backfilled',
      () async {
        final newest = _userWithTokens(63000);
        final mixed = {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'word ' * 2000},
            part,
          ],
        };
        final result = await compact({
          'model': model,
          'input': [_userWithTokens(100), mixed, newest],
        });
        expect(result.output, hasLength(2));
        expect(result.output.first['content'], newest['content']);

        final fits = await compact({
          'model': model,
          'input': [mixed, _userWithTokens(50000)],
        });
        expect(fits.output, hasLength(3));
        expect(fits.output.first, mixed);
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

const _recall = {
  'type': 'function',
  'function': {
    'name': 'read_chat_image',
    'parameters': {'type': 'object'},
  },
};
const _other = {
  'type': 'function',
  'function': {'name': 'other'},
};
final _image = ChatContextImage(
  identity: const ContextImageIdentity('user', 'part:0'),
  uri: 'data:image/png;base64,YWJj',
  source: ContextImageSource.user,
  label: 'attachment',
);

void main() {
  for (final (label, body) in <(String, Map<String, dynamic>)>[
    (
      'chat',
      {
        'tools': [_recall],
        'tool_choice': 'auto',
      },
    ),
    (
      'responses',
      {
        'tools': [
          {'type': 'function', 'name': 'read_chat_image'},
        ],
        'tool_choice': 'auto',
      },
    ),
    (
      'claude',
      {
        'tools': [
          {'name': 'read_chat_image', 'input_schema': <String, dynamic>{}},
        ],
        'tool_choice': {'type': 'auto'},
      },
    ),
    for (final key in ['function_declarations', 'functionDeclarations'])
      (
        'gemini $key',
        {
          'tools': [
            {
              key: [
                {'name': 'read_chat_image'},
              ],
            },
          ],
          'toolConfig': {
            'function_calling_config': {'mode': 'AUTO'},
          },
        },
      ),
  ]) {
    test(
      '$label removes unused tools and restores them after a new image',
      () async {
        final original = jsonEncode(body);
        final context = RequestImageContext(
          settings: const ImageContextSettings(),
          images: [],
        );
        expect(await context.project(body), isEmpty);
        context.toolReferences(
          'drawing',
          [_image.uri],
          {
            kMcpResultMetadataKey: mcpResultMetadata([_image.uri]),
          },
          'draw',
        );
        expect(await context.project(body), body);
        expect(jsonEncode(body), original);

        final disabled = RequestImageContext(
          settings: const ImageContextSettings(allowRecall: false),
          images: [_image],
        );
        expect(await disabled.project(body), isEmpty);
        expect(jsonDecode(await RequestImageContext.encodeBody(body)), isEmpty);
      },
    );
  }

  test(
    'keeps unrelated and hosted tools without empty Gemini calling config',
    () async {
      final context = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: false),
        images: [_image],
      );
      const search = {'google_search': <String, dynamic>{}};
      final body = {
        'tools': [
          {
            'function_declarations': [
              {'name': 'read_chat_image'},
            ],
          },
          search,
        ],
        'toolConfig': {
          'function_calling_config': {'mode': 'VALIDATED'},
          'includeServerSideToolInvocations': true,
          'retrieval_config': {'lat_lng': <String, dynamic>{}},
        },
      };
      expect(await context.project(body), {
        'tools': [search],
        'toolConfig': {
          'retrieval_config': {'lat_lng': <String, dynamic>{}},
        },
      });
      final otherDeclaration = {'name': 'other'};
      final mixed = {
        'tools': [
          {
            'functionDeclarations': [
              {'name': 'read_chat_image'},
              otherDeclaration,
            ],
          },
          search,
        ],
        'toolConfig': {
          'function_calling_config': {'mode': 'VALIDATED'},
          'includeServerSideToolInvocations': true,
        },
      };
      final projected = await context.project(mixed);
      expect(projected['tools'], [
        {
          'functionDeclarations': [otherDeclaration],
        },
        search,
      ]);
      expect(projected['toolConfig'], mixed['toolConfig']);

      for (final choice in [
        'auto',
        _recall,
        {'type': 'tool', 'name': 'read_chat_image'},
      ]) {
        final result = await context.project({
          'tools': [
            _recall,
            _other,
            {'type': 'web_search'},
          ],
          'tool_choice': choice,
        });
        expect(result['tools'], [
          _other,
          {'type': 'web_search'},
        ]);
        expect(result['tool_choice'], choice == 'auto' ? 'auto' : isNull);
      }
    },
  );

  test(
    'recall permission is independent of pruning and enforced during reads',
    () {
      for (final automatic in [true, false]) {
        for (final allowRecall in [true, false]) {
          final context = RequestImageContext(
            settings: ImageContextSettings(
              automatic: automatic,
              allowRecall: allowRecall,
            ),
            images: [_image],
          );
          expect(context.hasRecallableImages, allowRecall);
          expect(
            context.readImage(_image.handle).metadata != null,
            allowRecall,
          );
          expect(
            context.readImage('').content.contains('image_id'),
            allowRecall,
          );
          expect(
            context.omittedText(_image.handle).contains('read_chat_image'),
            allowRecall,
          );
          if (!allowRecall) {
            expect(
              context.readImage('unknown').content,
              isNot(contains('read_chat_image')),
            );
          }
        }
      }
      for (final context in [
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [_image],
          canRecall: false,
        ),
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [_image],
          canImageInput: false,
        ),
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [
            ChatContextImage(
              identity: _image.identity,
              uri: _image.uri,
              source: _image.source,
              label: _image.label,
              unavailable: true,
            ),
          ],
        ),
      ]) {
        expect(context.hasRecallableImages, isFalse);
        expect(context.readImage(_image.handle).metadata, isNull);
        expect(
          context.omittedText(_image.handle),
          isNot(contains('read_chat_image')),
        );
      }
    },
  );

  test(
    'preview uses the same tool selection without consuming candidates',
    () async {
      final candidates = [_recall, _other];
      for (final context in <RequestImageContext?>[
        null,
        RequestImageContext(settings: const ImageContextSettings(), images: []),
        RequestImageContext(
          settings: const ImageContextSettings(),
          images: [_image],
        ),
        RequestImageContext(
          settings: const ImageContextSettings(allowRecall: false),
          images: [_image],
        ),
      ]) {
        final preview = ContextAssemblyPreview.fromApiMessages(
          apiMessages: const [],
          tools: candidates,
          mcpToolNames: const {},
          images: const [],
          imageContext: context,
        );
        final body = {'tools': candidates};
        final wire = context == null
            ? jsonDecode(await RequestImageContext.encodeBody(body)) as Map
            : await context.project(body);
        expect(preview.tools, wire['tools']);
        expect(candidates, [_recall, _other]);
      }
    },
  );
}

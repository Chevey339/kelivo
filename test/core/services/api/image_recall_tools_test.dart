import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/tools/view_image_tool.dart';
import 'package:Kelivo/core/services/tools/tool_schema_overrides.dart';
import 'package:Kelivo/core/services/workspace/workspace_tools_service.dart';
import 'package:Kelivo/core/models/tool_schema_override.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

const _recall = {
  'type': 'function',
  'function': {
    'name': 'view_image',
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
  test(
    'current images need no recall tool; missing history can still be read',
    () async {
      final viewer = ViewImageTool.withHistory();
      final context = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [_image],
        latestUserId: _image.identity.messageId,
      );
      Map<String, dynamic> body(String url) => {
        'tools': [viewer],
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': url},
              },
            ],
          },
        ],
      };
      for (final url in [_image.reference, _image.uri]) {
        final request = await context.project(body(url));
        expect(request, isNot(contains('tools')));
        expect(
          request['messages'][0]['content'][0]['image_url']['url'],
          _image.uri,
        );
      }
      // A message window or compression can omit a still-readable old image.
      final missing = await context.project({
        'tools': [viewer],
        'messages': [
          {'role': 'user', 'content': 'What was in that image?'},
        ],
      });
      expect(missing['tools'], [viewer]);
      context.compressedOwners.add(_image.identity.messageId);
      final compressed = await context.project(body(_image.reference));
      expect(compressed['tools'], [viewer]);
      expect(
        compressed['messages'][0]['content'][0]['text'],
        contains(_image.handle),
      );
      final listed = jsonDecode(context.readImage('').content) as Map;
      expect(listed['images'][0]['image_id'], _image.handle);
      expect(context.readImage('img_1').metadata, isNull);
      final read = context.readImage(_image.handle);
      final references = context.toolReferences(
        'view_image',
        [_image.uri],
        read.metadata,
        'read',
      );
      final restored = await context.project(body(references.single));
      expect(
        restored,
        isNot(contains('tools')),
        reason: 'a restored observation also supplies the original image',
      );
      expect(
        restored['messages'][0]['content'][0]['image_url']['url'],
        _image.uri,
      );
    },
  );

  test(
    'disabling recall keeps the file viewer and its edited descriptions',
    () async {
      final fileViewer = WorkspaceToolsService.definitions().singleWhere(
        (tool) => tool['function']['name'] == 'view_image',
      );
      final combined = ViewImageTool.withHistory(fileViewer);
      final candidates = ToolSchemaOverrides.apply(
        [combined],
        {
          'view_image': const ToolSchemaOverride(
            description: 'Custom image viewer',
          ),
        },
      );
      final original = jsonEncode(candidates);
      final context = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: false),
        images: [_image],
      );
      final projected = await context.project({
        'tools': candidates,
        'tool_choice': {
          'type': 'function',
          'function': {'name': 'view_image'},
        },
      });
      final viewer = (projected['tools'] as List).single as Map;
      expect(ViewImageTool.supportsFiles(viewer), isTrue);
      expect(ViewImageTool.supportsHistory(viewer), isFalse);
      expect(viewer['function']['parameters']['required'], ['path']);
      expect(viewer['function']['description'], 'Custom image viewer');
      expect(projected, contains('tool_choice'));
      expect(jsonEncode(candidates), original);
      final ordinary = await context.project({
        'tools': [combined],
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': _image.uri},
              },
            ],
          },
        ],
      });
      expect(jsonEncode(ordinary['tools']), isNot(contains('image_id')));
      expect(
        ordinary['messages'][0]['content'][0]['image_url']['url'],
        _image.uri,
      );
    },
  );

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
          {'type': 'function', 'name': 'view_image'},
        ],
        'tool_choice': 'auto',
      },
    ),
    (
      'claude',
      {
        'tools': [
          {'name': 'view_image', 'input_schema': <String, dynamic>{}},
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
                {'name': 'view_image'},
              ],
            },
          ],
          'toolConfig': {
            if (key == 'functionDeclarations')
              'functionCallingConfig': {'mode': 'AUTO'}
            else
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
      const search = {'googleSearch': <String, dynamic>{}};
      final body = {
        'tools': [
          {
            'functionDeclarations': [
              {'name': 'view_image'},
            ],
          },
          search,
        ],
        'toolConfig': {
          'functionCallingConfig': {'mode': 'VALIDATED'},
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
              {'name': 'view_image'},
              otherDeclaration,
            ],
          },
          search,
        ],
        'toolConfig': {
          'functionCallingConfig': {'mode': 'VALIDATED'},
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
        {'type': 'tool', 'name': 'view_image'},
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
            context.omittedText(_image.handle).contains('view_image'),
            allowRecall,
          );
          if (!allowRecall) {
            expect(
              context.readImage('unknown').content,
              isNot(contains('view_image')),
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
          isNot(contains('view_image')),
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

import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/models/request_budget.dart';
import 'package:Kelivo/core/models/carried_original.dart';
import 'package:Kelivo/core/utils/multimodal_input_utils.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/models/image_context.dart';
import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/services/api/request_image_context.dart';
import 'package:Kelivo/core/services/api/chat_api_helpers.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/tool_result_content.dart';
import 'package:Kelivo/core/services/tools/view_image_tool.dart';
import 'package:Kelivo/core/services/api/providers/openai/chat_completions_api.dart';
import 'package:Kelivo/core/services/api/native_input_attachments.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/models/model_spec.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';
import 'package:Kelivo/utils/sandbox_path_resolver.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';

const pixels = 'data:image/png;base64,YWJj';
ChatContextImage image(
  int i, {
  ContextImageSource source = ContextImageSource.tool,
}) => ChatContextImage(
  identity: ContextImageIdentity('m$i', 'tool:call$i'),
  uri: pixels,
  source: source,
  label: 'image $i',
  toolCallId: source == ContextImageSource.tool ? 'call$i' : null,
);

void main() {
  Map<String, dynamic> bodyFor(List<String> urls) => {
    'input': [
      {
        'role': 'user',
        'content': [
          for (final url in urls) {'type': 'input_image', 'image_url': url},
        ],
      },
    ],
  };

  test('manual exclusion overrides pins, replay and history recall', () async {
    final a = image(0, source: ContextImageSource.user);
    final b = image(1, source: ContextImageSource.user);
    final recalled = ChatContextImage(
      identity: const ContextImageIdentity('assistant', 'tool:read'),
      uri: a.uri,
      source: ContextImageSource.tool,
      label: 'Recalled copy',
      materializationKey: a.key,
    );
    final settings = ImageContextSettings(
      automatic: false,
      allowRecall: true,
      pinned: {a.key},
    );
    final hidden = settings.exclude({a.key}, true);
    final context = RequestImageContext(
      settings: hidden,
      images: [a, b, recalled],
      latestUserId: a.identity.messageId,
      loader: (image) async {
        expect(image, same(b));
        return pixels;
      },
    );
    context.activeHandles.addAll([a.handle, b.handle, recalled.handle]);
    final body = bodyFor([a.reference, b.reference, recalled.reference]);
    final projected = await context.project(body);
    expect(context.lastRequestImageCount, 1);
    expect(projected['input'][0]['content'].map((part) => part['type']), [
      'input_text',
      'input_image',
      'input_text',
    ]);
    expect(jsonEncode(projected), isNot(contains(a.handle)));
    expect((await context.preview()).map((item) => item.excluded), [
      true,
      false,
      true,
    ]);
    expect(context.readImage(a.handle).metadata, isNull);
    expect(context.readImage(recalled.handle).metadata, isNull);
    expect(context.readImage(b.handle).metadata, isNotNull);
    expect(context.readImage('').content, isNot(contains(a.handle)));
    expect(context.readImage('').content, isNot(contains(recalled.handle)));
    expect(context.readImage('').content, contains(b.handle));

    final restored = RequestImageContext(
      settings: hidden.exclude({a.key}, false),
      images: [a, b, recalled],
      loader: (_) async => pixels,
    );
    await restored.project(body);
    expect(restored.lastRequestImageCount, 3);
    expect(restored.settings.pinned, {a.key});
    expect(restored.readImage(a.handle).metadata, isNotNull);
    expect(restored.readImage(a.handle, excluded: {a.key}).metadata, isNull);
  });

  test(
    'exclusion masks only the selected attachment and its Markdown link',
    () async {
      const selected = 'https://example.test/first.png';
      const other = 'https://example.test/second.png';
      const text =
          'Keep this `![code]($selected)`.\n![first]($selected)\n![second]($other)';
      final message = ChatMessage(
        id: 'user',
        role: 'user',
        conversationId: 'chat',
        parts: const [
          TextPart(text),
          ImagePart(uri: selected),
          ImagePart(uri: other),
        ],
      );
      final key = const ContextImageIdentity('user', 'part:1').key;
      final requestMessages = RequestImageContext.withoutExcludedAttachments(
        [message],
        {key},
      );
      expect(requestMessages.affectedRevisions, {message.id});
      expect(requestMessages.messages.single.parts, const [
        TextPart(text),
        TextPart(''),
        ImagePart(uri: other),
      ]);
      expect(message.parts[1], const ImagePart(uri: selected));
      final request = [
        {imageContextOwnerKey: message.id, 'role': 'user', 'content': text},
        {imageContextOwnerKey: 'other-owner', 'role': 'user', 'content': text},
      ];
      await RequestImageContext.omitExcludedMarkdownImages(
        request,
        [message],
        {key},
      );
      expect(
        request.first['content'],
        'Keep this `![code]($selected)`.\n[Image excluded from context by the user.]\n![second]($other)',
      );
      expect(request.last['content'], text);
    },
  );

  test('Markdown exclusion follows the providers’ image scanner', () async {
    final message = ChatMessage(
      id: 'markdown',
      role: 'user',
      conversationId: 'chat',
      content: 'Prefix \\![alt]($pixels) keep `![example]($pixels)`',
    );
    final images = await RequestImageContext.collectHistory(
      [message],
      parseMarkdownImages: true,
      allowRemoteImages: true,
    );
    final request = [
      {imageContextOwnerKey: message.id, 'content': message.content},
    ];
    await RequestImageContext.omitExcludedMarkdownImages(
      request,
      [message],
      {images.single.key},
    );
    expect(
      request.single['content'],
      'Prefix \\[Image excluded from context by the user.] keep `![example]($pixels)`',
    );
    final outgoing = await parseTextAndImages(
      request.single['content']!,
      allowRemoteImages: true,
      allowLocalImages: true,
    );
    expect(outgoing.images, isEmpty);
    final replayCatalog = await RequestImageContext.collectHistory(
      [message],
      parseMarkdownImages: false,
      allowRemoteImages: false,
      excluded: {images.single.key},
    );
    expect(replayCatalog.single.key, images.single.key);
  });

  test('Markdown exclusion is portable while old handles still work', () async {
    final directory = await Directory.systemTemp.createTemp('markdown_image_');
    addTearDown(() async {
      SandboxPathResolver.debugSetDirs();
      await directory.delete(recursive: true);
    });
    Future<File> imageIn(String container) async {
      final file = File('${directory.path}/$container/images/photo.png');
      await file.parent.create(recursive: true);
      return file.writeAsString('photo');
    }

    Future<ChatContextImage> observe(String uri) async =>
        (await RequestImageContext.collectHistory(
          [
            ChatMessage(
              id: 'user',
              conversationId: 'chat',
              role: 'user',
              content: '![]($uri)',
            ),
          ],
          parseMarkdownImages: true,
          allowRemoteImages: false,
        )).single;

    final file = await imageIn('original');
    SandboxPathResolver.debugSetDirs(docsDir: '${directory.path}/original');
    final original = await observe(file.path);
    final oldIdentity = ContextImageIdentity.markdown(
      'user',
      SandboxPathResolver.dedupeKey(file.path),
    );
    expect(original.handle, oldIdentity.handle);
    expect(original.exclusionKey, isNot(oldIdentity.key));
    final portable = SandboxPathResolver.canonicalize(file.path);
    expect(
      (await RequestImageContext(
        settings: ImageContextSettings(pinned: {oldIdentity.key}),
        images: [original],
      ).preview()).single.pinned,
      isTrue,
    );

    await imageIn('restored');
    SandboxPathResolver.debugSetDirs(docsDir: '${directory.path}/restored');
    final restored = await observe(portable);
    final recalled = ChatContextImage(
      identity: const ContextImageIdentity('assistant', 'tool:view'),
      uri: portable,
      source: ContextImageSource.tool,
      label: 'Old recall result',
      materializationKey: oldIdentity.key,
      workspaceSnapshot: true,
    );
    final context = RequestImageContext(
      settings: ImageContextSettings(
        excluded: {original.exclusionKey},
        allowRecall: true,
      ),
      images: [restored, recalled],
    );
    expect(restored.exclusionKey, original.exclusionKey);
    expect((await context.preview()).last.inheritedExclusion, isTrue);
    expect(context.readImage(restored.handle).metadata, isNull);
    expect(context.readImage(recalled.handle).metadata, isNull);
  });

  test(
    'a subsequent carry uses the original handle after editing Markdown',
    () async {
      final original = ChatContextImage(
        identity: const ContextImageIdentity('old', 'part:1'),
        uri: pixels,
        source: ContextImageSource.user,
        label: 'original',
      );
      final markdown = ChatContextImage(
        identity: const ContextImageIdentity('old', 'markdown:original'),
        uri: 'https://example.test/original.png',
        source: ContextImageSource.user,
        label: 'markdown',
      );
      final images = RequestImageContext(
        settings: const ImageContextSettings(automatic: false),
        images: [original, markdown],
        latestUserId: 'current',
      );
      final frozen = <String, dynamic>{
        'role': 'user',
        'content': 'edited ![new](https://example.test/new.png)',
        imageContextOwnerKey: '${carriedPrefix}first:old',
        carriedTextOnlyKey: true,
        carriedImageHandlesKey: [original.handle, markdown.handle],
      };
      await images.prepareMessages(
        [frozen],
        [],
        parseMarkdownImages: true,
        allowRemoteImages: true,
      );
      expect(
        parseInternalMediaRefs(
          frozen[multimodalInternalMediaPathsKey],
        ).map((r) => r.uri),
        [original.reference, markdown.reference],
      );
      final history = RequestHistoryContext(
        currentUserId: 'current',
        targetMessageId: 'answer',
        isCancelled: () => false,
        beforeRequest: (_, _, _) async => null,
      )..format = HistoryWireFormat.responses;
      final projected = history.projectCandidate(
        {
          'input': [
            {
              ...(bodyFor([original.reference, markdown.reference])['input']
                          as List)
                      .single
                  as Map,
              historySourceKey: '${carriedPrefix}first:old',
            },
            {'role': 'user', 'content': 'current', historySourceKey: 'current'},
          ],
        },
        [
          {...frozen, imageContextOwnerKey: '${carriedPrefix}second:old'},
        ],
      );
      images.compressedOwners.add('old');
      final next = await images.project(projected);
      final parts = (next['input'] as List).first['content'] as List;
      expect(
        parts
            .where((p) => p['type'] == 'input_image')
            .map((p) => p['image_url']),
        [pixels, markdown.uri],
      );
      expect(parts.first['text'], frozen['content']);
    },
  );
  test(
    'automatic carry retains the chosen user image through both projections',
    () async {
      final original = image(1, source: ContextImageSource.user);
      final omitted = image(2, source: ContextImageSource.user);
      final images = RequestImageContext(
        settings: const ImageContextSettings(automatic: false),
        images: [original, omitted],
      );
      final history = RequestHistoryContext(
        currentUserId: 'current',
        targetMessageId: 'answer',
        isCancelled: () => false,
        beforeRequest: (_, _, _) async => null,
      )..format = HistoryWireFormat.google;
      final replacement = [
        <String, dynamic>{
          'role': 'user',
          'content': 'edited',
          imageContextOwnerKey: '${carriedPrefix}op:m1',
          carriedImageHandlesKey: [original.handle],
        },
        <String, dynamic>{
          'role': 'user',
          'content': 'summary',
          imageContextOwnerKey: 'context-summary:op',
        },
      ];
      final body = history.projectCandidate({
        'contents': [
          {
            'role': 'user',
            historySourceKey: 'm1',
            'parts': [
              {'text': 'old'},
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': 'kelivo-image-ref:${original.handle}',
                },
              },
              {
                'inlineData': {
                  'mimeType': 'application/pdf',
                  'data': 'document bytes',
                },
              },
              {
                'fileData': {
                  'mimeType': 'audio/mpeg',
                  'fileUri': 'https://example.test/audio',
                },
              },
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': 'kelivo-image-ref:${omitted.handle}',
                },
              },
            ],
          },
          {
            'role': 'user',
            historySourceKey: 'current',
            'parts': [
              {'text': 'next'},
            ],
          },
        ],
      }, replacement);
      final preview = await images.project(body, excludedOwners: {'m1', 'm2'});
      images.compressedOwners.addAll(['m1', 'm2']);
      final sent = await images.project(body);
      expect(sent, preview);
      final parts = (sent['contents'] as List).first['parts'];
      expect(parts, [
        {'text': 'edited'},
        {
          'inlineData': {'mimeType': 'image/png', 'data': 'YWJj'},
        },
      ]);
      expect(jsonEncode(sent), isNot(contains('_kelivo_')));
    },
  );
  test(
    'native retained pixels suppress only the matching local image lookup',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'native_inline_image_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final file = File('${directory.path}/image.png');
      await file.writeAsBytes(bytes);
      final local = ChatContextImage(
        identity: const ContextImageIdentity('user', 'part:0'),
        uri: file.path,
        source: ContextImageSource.user,
        label: 'image',
      );
      final tools = [ViewImageTool.withHistory()];
      RequestImageContext context(List<ChatContextImage> images) =>
          RequestImageContext(
            settings: const ImageContextSettings(allowRecall: true),
            images: images,
            latestUserId: 'user',
          );
      final first = await context([local]).project({
        ...bodyFor([local.reference]),
        'tools': tools,
      });
      expect(first, isNot(contains('tools')));
      final retained = <String, dynamic>{
        ...first,
        'tools': tools,
        'input': [
          {...first['input'][0] as Map, nativeCompactionWireKey: true},
        ],
      };
      final original = jsonEncode(retained);
      final replayContext = context([local]);
      final replay = await replayContext.project(retained);
      expect(replay, isNot(contains('tools')));
      expect(replayContext.lastRequestImageCount, 1);
      expect(replay['input'], first['input']);
      expect(jsonEncode(retained), original);

      // Equal file sizes do not prove that another historical image is visible.
      final otherFile = File('${directory.path}/other.png');
      await otherFile.writeAsBytes([
        ...bytes.take(bytes.length - 1),
        bytes.last ^ 1,
      ]);
      final other = ChatContextImage(
        identity: const ContextImageIdentity('older-user', 'part:0'),
        uri: otherFile.path,
        source: ContextImageSource.user,
        label: 'different content',
      );
      final missingHistory = await context([other, local]).project(retained);
      expect(missingHistory['tools'], tools);
      expect(missingHistory['input'], first['input']);

      final samePixels = ChatContextImage(
        identity: const ContextImageIdentity('another-user', 'part:0'),
        uri: local.uri,
        source: ContextImageSource.user,
        label: 'independent attachment',
      );
      final opaque = {'type': 'compaction', 'encrypted_content': 'opaque'};
      final retainedUser = first['input'][0] as Map;
      final exclusion = RequestImageContext(
        settings: ImageContextSettings(excluded: {local.key}),
        images: [local, samePixels, other],
      );
      final projected = await exclusion.project({
        'input': [
          {
            ...retainedUser,
            carriedWireKey: true,
            historySourceKey: '${carriedPrefix}op:user',
          },
          {
            ...retainedUser,
            nativeCompactionWireKey: true,
            historySourceKey: 'user',
          },
          {
            ...retainedUser,
            nativeCompactionWireKey: true,
            historySourceKey: 'another-user',
          },
          {...opaque, nativeCompactionWireKey: true},
        ],
      });
      final input = projected['input'] as List;
      expect(input[0]['content'][0]['type'], 'input_text');
      expect(input[1]['content'][0]['type'], 'input_text');
      expect(input[2], retainedUser);
      expect(input[3], opaque);
      expect(exclusion.lastRequestImageCount, 1);
      final unknownOwner = await RequestImageContext(
        settings: ImageContextSettings(excluded: {local.key}),
        images: [local, other],
      ).project(retained);
      expect(unknownOwner['input'][0]['content'][0]['type'], 'input_text');

      final copy = await file.copy('${directory.path}/copy.png');
      final duplicate = ChatContextImage(
        identity: const ContextImageIdentity('user', 'part:1'),
        uri: copy.path,
        source: ContextImageSource.user,
        label: 'same pixels from another attachment',
      );
      final part = (retainedUser['content'] as List).single;
      final duplicateContext = RequestImageContext(
        settings: ImageContextSettings(excluded: {local.key}),
        images: [local, duplicate],
      );
      await duplicateContext.project({
        'input': [
          {
            ...retainedUser,
            nativeCompactionWireKey: true,
            historySourceKey: 'user',
            'content': [part, part],
          },
        ],
      });
      expect(duplicateContext.lastRequestImageCount, 1);

      final assistant = ChatContextImage(
        identity: const ContextImageIdentity('assistant', 'part:0'),
        uri: file.path,
        source: ContextImageSource.assistant,
        label: 'assistant image appended to user turn',
      );
      final mixedContext = RequestImageContext(
        settings: ImageContextSettings(excluded: {assistant.key}),
        images: [other, assistant],
      );
      final userPixels =
          'data:image/png;base64,${base64Encode(await otherFile.readAsBytes())}';
      final mixed = await mixedContext.project({
        'input': [
          {
            ...retainedUser,
            nativeCompactionWireKey: true,
            historySourceKey: other.identity.messageId,
            'content': [
              {'type': 'input_image', 'image_url': userPixels},
              part,
            ],
          },
        ],
      });
      expect(mixed['input'][0]['content'].map((part) => part['type']), [
        'input_image',
        'input_text',
      ]);
      expect(mixedContext.lastRequestImageCount, 1);
    },
  );

  test(
    'image-free retry omits pinned, native and tool images without loading pixels',
    () async {
      final originalImage = image(0, source: ContextImageSource.user);
      final context = RequestImageContext(
        settings: ImageContextSettings(
          automatic: false,
          allowRecall: true,
          pinned: {originalImage.key},
        ),
        images: [originalImage],
        latestUserId: originalImage.identity.messageId,
        omitImages: true,
        loader: (_) async => fail('An image-free retry must not load pixels'),
      );
      final body = bodyFor([
        originalImage.reference,
        pixels,
        'https://example.com/image.png',
      ]);
      body['input'] = <Map<String, dynamic>>[
        ...(body['input'] as List).cast<Map<String, dynamic>>(),
        {
          nativeCompactionWireKey: true,
          'role': 'user',
          'content': [
            {'type': 'input_image', 'file_id': 'file-1'},
          ],
        },
        {
          'type': 'function_call_output',
          'call_id': 'tool-1',
          'output': [
            {'type': 'input_image', 'image_url': originalImage.reference},
          ],
        },
      ];
      body['tools'] = [
        {'type': 'function', 'name': 'view_image'},
      ];
      final original = jsonEncode(body);
      final projected = await context.project(body);
      expect(jsonEncode(projected), isNot(contains('input_image')));
      expect(jsonEncode(projected), isNot(contains('base64')));
      expect(projected.containsKey('tools'), false);
      expect(context.hasRecallableImages, false);
      expect(context.lastRequestImageCount, 0);
      expect(jsonEncode(body), original);
      // A fresh image introduced by a subsequent tool is also omitted.
      final followUp = await context.project(bodyFor([pixels]));
      expect(jsonEncode(followUp), isNot(contains('input_image')));
      // Ordinary retries retain the image; the option never changes saved data.
      final normal = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
      );
      expect(await normal.project(bodyFor([pixels])), bodyFor([pixels]));
      expect(normal.lastRequestImageCount, 1);
    },
  );

  test(
    'all image limits report measured values and allow the exact boundary',
    () async {
      for (final (budget, urls, kind, actual, limit) in [
        (
          const RequestBudget(singleImageBytes: 3),
          [pixels],
          ImageContextBudgetKind.singleImage,
          4,
          3,
        ),
        (
          const RequestBudget(totalImageBytes: 7),
          [pixels, pixels],
          ImageContextBudgetKind.totalImages,
          8,
          7,
        ),
        (
          const RequestBudget(imageCount: 1),
          [pixels, pixels],
          ImageContextBudgetKind.imageCount,
          2,
          1,
        ),
      ]) {
        final request = RequestImageContext(
          settings: const ImageContextSettings(automatic: false),
          images: [],
          budget: budget,
        );
        await expectLater(
          request.project(bodyFor(urls)),
          throwsA(
            isA<ImageContextBudgetException>()
                .having((e) => e.kind, 'kind', kind)
                .having((e) => e.actual, 'actual', actual)
                .having((e) => e.limit, 'limit', limit),
          ),
        );
      }
      final exact = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: const RequestBudget(
          singleImageBytes: 4,
          totalImageBytes: 8,
          imageCount: 2,
        ),
      );
      expect(
        await exact.project(bodyFor([pixels, pixels])),
        bodyFor([pixels, pixels]),
      );
    },
  );

  test(
    'body diagnostics count final UTF-8 JSON including text and tools, without local metadata',
    () async {
      final body = <String, dynamic>{
        'input': [
          {
            'role': 'user',
            historySourceKey: 'local-source',
            'content': [
              {'type': 'input_text', 'text': '中文🙂\\\n' * 5000},
            ],
          },
        ],
        'tools': [
          {'type': 'function', 'name': 'test', 'description': '字' * 100},
        ],
      };
      final expectedBytes = utf8
          .encode(jsonEncode(RequestHistoryContext.stripSources(body)))
          .length;
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: RequestBudget(bodyBytes: expectedBytes - 1),
      );
      await expectLater(
        request.project(body),
        throwsA(
          isA<ImageContextBudgetException>()
              .having((e) => e.kind, 'kind', ImageContextBudgetKind.requestBody)
              .having((e) => e.actual, 'actual', expectedBytes)
              .having((e) => e.limit, 'limit', expectedBytes - 1),
        ),
      );
      final exact = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        budget: RequestBudget(bodyBytes: expectedBytes),
      );
      expect(
        utf8.encode(jsonEncode(await exact.project(body))).length,
        expectedBytes,
      );
    },
  );

  test(
    'larger sending limits permit pins without expanding automatic retention',
    () async {
      final images = [
        for (var i = 0; i < 4; i++) image(i, source: ContextImageSource.user),
      ];
      const history = RequestBudget(totalImageBytes: 8);
      const sending = RequestBudget(totalImageBytes: 16);
      RequestImageContext request(ImageContextSettings settings) =>
          RequestImageContext(
            settings: settings,
            images: images,
            latestUserId: 'new-text',
            historyBudget: history,
            budget: sending,
          );
      final automatic = request(const ImageContextSettings());
      expect(await automatic.historyOmissions(), {
        'm0|tool:call0|0',
        'm1|tool:call1|0',
      });
      final pinned = request(
        ImageContextSettings(pinned: images.map((im) => im.key).toSet()),
      );
      expect(await pinned.historyOmissions(), isEmpty);
      final output = await pinned.project(
        bodyFor(images.map((im) => im.reference).toList()),
      );
      expect(jsonEncode(output), isNot(contains('omitted')));
      expect('YWJj'.allMatches(jsonEncode(output)).length, 4);
    },
  );

  test(
    'single-image errors identify the transmitted image and pin before reading',
    () async {
      final old = image(0);
      final large = image(1);
      var loads = 0;
      final request = RequestImageContext(
        settings: ImageContextSettings(pinned: {large.key}),
        images: [old, large],
        budget: const RequestBudget(singleImageBytes: 3),
        loader: (_) async {
          loads++;
          return pixels;
        },
      );
      request.compressedOwners.add(old.identity.messageId);
      await expectLater(
        request.project(bodyFor([old.reference, large.reference])),
        throwsA(
          isA<ImageContextBudgetException>()
              .having((e) => e.imageIndex, 'request image position', 1)
              .having((e) => e.imageKey, 'image identity', large.key)
              .having((e) => e.pinned, 'pinned', isTrue)
              .having((e) => e.actual, 'encoded size', 4),
        ),
      );
      expect(loads, 0);
    },
  );

  test(
    'old oversized user images retire after their turn unless pinned',
    () async {
      final old = image(0, source: ContextImageSource.user);
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [old],
        latestUserId: 'new-text',
        budget: const RequestBudget(singleImageBytes: 3),
      );
      expect(await request.historyOmissions(), {old.key});
      expect(
        jsonEncode(await request.project(bodyFor([old.reference]))),
        contains('omitted'),
      );
    },
  );

  test('remote preview size is a reservation and never loads pixels', () async {
    var loads = 0;
    final remote = ChatContextImage(
      identity: const ContextImageIdentity('m', 'tool:c'),
      uri: 'https://example.test/image',
      source: ContextImageSource.tool,
      label: 'remote',
    );
    final request = RequestImageContext(
      settings: const ImageContextSettings(),
      images: [remote],
      loader: (_) async {
        loads++;
        return pixels;
      },
    );
    final preview = await request.preview();
    expect(preview.single.sizeIsEstimate, isTrue);
    expect(loads, 0);
  });

  test(
    'missing pixels do not consume image count, and loading stops at the limit',
    () async {
      final images = [for (var i = 0; i < 5; i++) image(i)];
      var loads = 0;
      final request = RequestImageContext(
        settings: const ImageContextSettings(automatic: false),
        images: images,
        budget: const RequestBudget(imageCount: 1),
        loader: (image) async {
          loads++;
          return image == images.first ? null : pixels;
        },
      );
      await expectLater(
        request.project(bodyFor(images.map((im) => im.reference).toList())),
        throwsA(
          isA<ImageContextBudgetException>()
              .having((e) => e.kind, 'kind', ImageContextBudgetKind.imageCount)
              .having((e) => e.actual, 'resolved image count', 2)
              .having(
                (e) => e.minimum,
                'stopped before remaining images',
                isTrue,
              ),
        ),
      );
      expect(loads, 3);
      final allowed = RequestImageContext(
        settings: const ImageContextSettings(automatic: false),
        images: images.take(2).toList(),
        budget: const RequestBudget(imageCount: 1),
        loader: (image) async => image == images.first ? null : pixels,
      );
      final projected = await allowed.project(
        bodyFor(images.take(2).map((im) => im.reference).toList()),
      );
      expect('YWJj'.allMatches(jsonEncode(projected)).length, 1);
    },
  );

  test('a text-only append cannot restore a byte-evicted tool image', () async {
    const large = 'data:image/png;base64,AAAAAAAA';
    const small = 'data:image/png;base64,AAAA';
    final messages = [
      ChatMessage(
        id: 'Q',
        role: 'user',
        conversationId: 'c',
        parts: [for (var i = 0; i < 3; i++) ImagePart(uri: large)],
      ),
      ChatMessage(
        id: 'P',
        role: 'user',
        conversationId: 'c',
        parts: [for (var i = 0; i < 4; i++) ImagePart(uri: large)],
      ),
      ChatMessage(
        id: 'A',
        role: 'assistant',
        conversationId: 'c',
        parts: [
          for (var i = 0; i < 2; i++)
            ToolCallPart(
              jsonEncode({
                'id': 'T$i',
                'name': 'drawing',
                'metadata': {
                  kMcpResultMetadataKey: mcpResultMetadata([small]),
                },
              }),
            ),
        ],
      ),
    ];
    final catalog = RequestImageContext.collect(messages);
    final settings = ImageContextSettings(
      pinned: catalog.take(3).map((im) => im.key).toSet(),
    );
    Future<Map<String, dynamic>> project(String user) =>
        RequestImageContext(
          settings: settings,
          images: catalog,
          latestUserId: user,
          budget: const RequestBudget(
            totalImageBytes: 40,
            singleImageBytes: 10,
          ),
          loader: (im) async => im.uri,
        ).project({
          'input': [
            {
              'role': 'user',
              'content': [
                for (final image in catalog.skip(3))
                  {'type': 'input_image', 'image_url': image.reference},
              ],
            },
          ],
        });
    final before = await project('P');
    final after = await project('Z');
    expect(before['input'][0]['content'][4]['type'], 'input_text');
    expect(after['input'][0]['content'][4]['type'], 'input_text');
  });

  test('a saved read result can replay without its original message', () async {
    final original = ChatMessage(
      id: 'upload',
      role: 'user',
      conversationId: 'source',
      parts: [ImagePart(uri: pixels, mime: 'image/png')],
    );
    final request = RequestImageContext(
      settings: const ImageContextSettings(allowRecall: true),
      images: RequestImageContext.collect([original]),
    );
    final result = request.readImage(request.images.single.handle);
    final retained = ChatMessage(
      id: 'retained',
      role: 'assistant',
      conversationId: 'fork',
      parts: [
        ToolCallPart(
          jsonEncode({
            'id': 'read',
            'name': 'view_image',
            'content': result.content,
            'metadata': result.metadata,
          }),
        ),
      ],
    );
    final catalog = RequestImageContext.collect([retained]);
    expect(catalog, hasLength(1));
    final replay = RequestImageContext(
      settings: const ImageContextSettings(allowRecall: true),
      images: catalog,
    );
    final body = await replay.project({
      'input': [
        {
          'type': 'function_call_output',
          'call_id': 'read',
          'output': [
            {'type': 'input_image', 'image_url': catalog.single.reference},
          ],
        },
      ],
    });
    expect(body['input'][0]['output'][0]['image_url'], pixels);
    expect(
      replay.readImage(catalog.single.handle, allowedMessages: {}).metadata,
      isNull,
    );
  });

  test(
    'mixed Markdown retains remote text and preparation performs no HEAD',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previous);
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var heads = 0;
      server.listen((request) async {
        heads++;
        request.response.statusCode = 200;
        await request.response.close();
      });
      final url = 'http://127.0.0.1:${server.port}/diagram.png';
      final raw = 'before ![remote diagram]($url) ![]($pixels) after';
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [],
        latestUserId: 'user',
      );
      final messages = <Map<String, dynamic>>[
        {'role': 'user', 'content': raw, imageContextOwnerKey: 'user'},
      ];
      await request.prepareMessages(
        messages,
        [],
        parseMarkdownImages: true,
        allowRemoteImages: true,
      );
      expect(heads, 0);
      expect(messages.single['content'], raw);
      final preview = ContextAssemblyPreview.fromApiMessages(
        apiMessages: messages,
        tools: [],
        mcpToolNames: {},
        images: [],
        imageContext: request,
      );
      expect(preview.historyText, contains('![remote diagram]($url)'));
      expect(preview.historyText, isNot(contains(pixels)));
      final textOnly = request.withoutImageInput(messages).single['content'];
      expect(textOnly, contains('![remote diagram]($url)'));
      expect(textOnly, isNot(contains(pixels)));
      await request.run(() async* {
        final built = await buildOpenAIChatCompletionMessages(
          messages,
          nativeInputs: NativeInputAttachments(
            config: ProviderConfig(
              id: 'test',
              enabled: true,
              name: 'test',
              apiKey: '',
              baseUrl: 'http://test',
            ),
            spec: ModelSpec(id: 'test', displayName: 'test'),
            protocol: NativeInputProtocol.chatCompletions,
          ),
          canImageInput: true,
          allowRemoteImages: true,
          reasoningReplay: ReasoningReplayPolicy.all,
        );
        final projected = await request.project({'messages': built});
        final parts = projected['messages'][0]['content'] as List;
        expect(parts.first['text'], contains('![remote diagram]($url)'));
        expect(parts.where((p) => p['type'] == 'image_url').length, 2);
        expect(
          parts
              .where(
                (p) => p['type'] == 'image_url' && p['image_url']['url'] == url,
              )
              .length,
          1,
        );
        yield 0;
      }).drain<void>();
      expect(heads, 1);
    },
  );

  test(
    'oversized current images and pinned selections fail before loading pixels',
    () async {
      var loads = 0;
      final current = image(0, source: ContextImageSource.user);
      final one = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [current],
        latestUserId: 'm0',
        budget: RequestBudget(singleImageBytes: 2),
        loader: (_) async {
          loads++;
          return pixels;
        },
      );
      Map<String, dynamic> body(List<ChatContextImage> images) => {
        'input': [
          {
            'role': 'user',
            'content': [
              for (final image in images)
                {'type': 'input_image', 'image_url': image.reference},
            ],
          },
        ],
      };
      await expectLater(
        one.project(body([current])),
        throwsA(isA<ImageContextBudgetException>()),
      );
      final pinned = [for (var i = 0; i < 6; i++) image(i)];
      final many = RequestImageContext(
        settings: ImageContextSettings(
          pinned: pinned.map((im) => im.key).toSet(),
        ),
        images: pinned,
        budget: RequestBudget(totalImageBytes: 16),
        loader: (_) async {
          loads++;
          return pixels;
        },
      );
      await expectLater(
        many.project(body(pinned)),
        throwsA(isA<ImageContextBudgetException>()),
      );
      expect(loads, 0);
    },
  );

  test(
    'generated assistant images restore through their owned attachment',
    () async {
      final owner = ChatMessage(
        id: 'answer',
        role: 'assistant',
        conversationId: 'chat',
        parts: [ImagePart(uri: pixels)],
      );
      final request = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: RequestImageContext.collect([owner]),
        targetMessageId: 'next',
      );
      final restored = request.readImage(request.images.single.handle);
      await request.run(() async* {
        final result = await ToolResultContent.read(
          'view_image',
          restored.content,
          metadata: restored.metadata,
          toolCallId: 'read',
        );
        final body = await request.project({
          'input': [
            {
              'type': 'function_call_output',
              'call_id': 'read',
              'output': result.responsesOutput,
            },
          ],
        });
        expect(jsonEncode(body), contains('YWJj'));
        yield 0;
      }).drain<void>();
    },
  );

  test(
    'composer paths reuse image references and leave other media untouched',
    () {
      final user = ChatMessage(
        id: 'user',
        role: 'user',
        conversationId: 'chat',
        parts: [ImagePart(uri: '/tmp/photo')],
      );
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: RequestImageContext.collect([user]),
        latestUserId: user.id,
      );
      final paths = request.preparePaths([
        '/tmp/photo',
        '/tmp/recording',
        '/tmp/movie.mp4',
      ]);
      expect(paths.first, request.images.single.reference);
      expect(paths.skip(1), ['/tmp/recording', '/tmp/movie.mp4']);
      expect(request.preparePaths(paths), paths);
      expect(request.images.length, 1);
    },
  );

  test(
    'discovery is scoped and paginated; a text-only preview includes no image payloads',
    () async {
      final items = [for (var i = 0; i < 35; i++) image(i)];
      final request = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: items,
      );
      request.activeHandles.addAll(items.map((im) => im.handle));
      expect(
        (jsonDecode(request.readImage('').content)['images'] as List).length,
        30,
      );
      expect(jsonDecode(request.readImage('').content)['next_offset'], 30);
      expect(
        (jsonDecode(request.readImage('', offset: 30).content)['images']
                as List)
            .length,
        5,
      );
      expect(
        (jsonDecode(
                  request.readImage('', allowedMessages: {'m1'}).content,
                )['images']
                as List)
            .single['image_id'],
        items[1].handle,
      );
      expect(
        request.readImage(items[0].handle, allowedMessages: {}).metadata,
        isNull,
      );
      final textOnly = RequestImageContext(
        settings: const ImageContextSettings(),
        images: items,
        canImageInput: false,
      )..activeHandles.addAll(items.map((im) => im.handle));
      expect(
        (await textOnly.preview()).any((image) => image.included),
        isFalse,
      );
    },
  );

  test(
    'every native protocol projects the same plan without mutating source, text or signatures',
    () async {
      for (final protocol in ['chat', 'responses', 'claude', 'gemini']) {
        var loads = 0;
        final images = [for (var i = 0; i < 13; i++) image(i)];
        final request = RequestImageContext(
          settings: const ImageContextSettings(),
          images: images,
          loader: (_) async {
            loads++;
            return pixels;
          },
        );
        Map<String, dynamic> pixel(ChatContextImage im) => switch (protocol) {
          'chat' => {
            'type': 'image_url',
            'image_url': {'url': im.reference},
          },
          'responses' => {'type': 'input_image', 'image_url': im.reference},
          'claude' => {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': 'image/png',
              'data': im.reference.split(',').last,
            },
          },
          _ => {
            'inlineData': {
              'mimeType': 'image/png',
              'data': im.reference.split(',').last,
            },
          },
        };
        final body = <String, dynamic>{
          if (protocol == 'responses')
            'input': [
              for (final im in images)
                {
                  'type': 'function_call_output',
                  'call_id': im.toolCallId,
                  'output': [
                    {'type': 'input_text', 'text': 'original'},
                    pixel(im),
                  ],
                },
            ],
          if (protocol == 'gemini')
            'contents': [
              for (final im in images)
                {
                  'role': 'user',
                  'parts': [
                    {
                      'functionResponse': {
                        'name': 'screenshot',
                        'id': im.toolCallId,
                        'response': {'text': 'original'},
                      },
                    },
                    pixel(im),
                  ],
                },
            ],
          if (protocol == 'claude')
            'messages': [
              {
                'role': 'assistant',
                'content': [
                  {
                    'type': 'thinking',
                    'thinking': 'thought',
                    'signature': 'signed',
                  },
                ],
              },
              {
                'role': 'user',
                'content': [
                  for (final im in images)
                    {
                      'type': 'tool_result',
                      'tool_use_id': im.toolCallId,
                      'content': [
                        {'type': 'text', 'text': 'original'},
                        pixel(im),
                      ],
                    },
                ],
              },
            ],
          if (protocol == 'chat')
            'messages': [
              for (final im in images) ...[
                {
                  'role': 'tool',
                  'tool_call_id': im.toolCallId,
                  'content': 'original',
                },
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'text',
                      'text':
                          'Image returned by screenshot (${im.toolCallId}):',
                    },
                    pixel(im),
                  ],
                },
              ],
            ],
        };
        final original = jsonEncode(body);
        final result = await request.project(body);
        expect(loads, 4, reason: protocol);
        expect(jsonEncode(body), original);
        final encoded = jsonEncode(result);
        expect('YWJj'.allMatches(encoded).length, 4, reason: protocol);
        expect(encoded, isNot(contains('kelivo-image-ref:')));
        expect('omitted'.allMatches(encoded).length, 9, reason: protocol);
        expect('original'.allMatches(encoded).length, 13, reason: protocol);
        if (protocol == 'chat') {
          final messages = result['messages'] as List;
          expect(messages.where((m) => m['role'] == 'tool').length, 13);
          expect(messages.where((m) => m['role'] == 'user').length, 4);
          expect(messages.first['content'], contains('omitted'));
        }
        if (protocol == 'claude') expect(encoded, contains('signed'));
        expect(
          jsonEncode(await request.project(body)),
          encoded,
          reason: 'retry is deterministic',
        );
        expect(loads, 4, reason: 'no repeated reads');
      }
    },
  );

  test(
    'a protocol continuation evicts accumulated references when the 13th screenshot arrives',
    () async {
      final originals = [for (var i = 0; i < 12; i++) image(i)];
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: originals,
        loader: (_) async => pixels,
        targetMessageId: 'm12',
      );
      final input = [
        for (final im in originals)
          {
            'type': 'function_call_output',
            'call_id': im.toolCallId,
            'output': [
              {'type': 'input_image', 'image_url': im.reference},
            ],
          },
      ];
      final before = await request.project({'input': input});
      expect('YWJj'.allMatches(jsonEncode(before)).length, 12);
      await request.run(() async* {
        final content = await ToolResultContent.read(
          'screenshot',
          'new text',
          toolCallId: 'call12',
          metadata: {
            kMcpResultMetadataKey: mcpResultMetadata([pixels]),
          },
        );
        input.add({
          'type': 'function_call_output',
          'call_id': 'call12',
          'output': content.responsesOutput,
        });
        yield 0;
      }).drain<void>();
      final after = await request.project({'input': input});
      expect('YWJj'.allMatches(jsonEncode(after)).length, 4);
      expect((after['input'] as List).length, 13);
    },
  );

  test(
    'old user attachment recall is scoped and becomes a new tool occurrence',
    () async {
      final owner = ChatMessage(
        id: 'user',
        conversationId: 'chat',
        role: 'user',
        parts: [ImagePart(uri: pixels)],
      );
      final request = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: RequestImageContext.collect([owner]),
        targetMessageId: 'assistant',
        loader: (_) async => pixels,
      );
      final original = request.images.single;
      expect(request.readImage('/etc/private.png').metadata, isNull);
      expect(request.readImage('img_foreign').metadata, isNull);
      final restored = request.readImage(original.handle);
      await request.run(() async* {
        final result = await ToolResultContent.read(
          'view_image',
          restored.content,
          metadata: restored.metadata,
          toolCallId: 'read-1',
        );
        final body = await request.project({
          'input': [
            {
              'type': 'function_call_output',
              'call_id': 'read-1',
              'output': result.responsesOutput,
            },
          ],
        });
        expect(jsonEncode(body), contains('YWJj'));
        expect(request.images.last.handle, isNot(original.handle));
        yield 0;
      }).drain<void>();
      final cleared = RequestImageContext(
        settings: const ImageContextSettings(allowRecall: true),
        images: [],
      );
      expect(cleared.readImage(original.handle).metadata, isNull);
    },
  );

  test(
    'Chat Completions builder preserves call pairing and moves omissions to tool text',
    () async {
      final images = [for (var i = 0; i < 13; i++) image(i)];
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: images,
        loader: (_) async => pixels,
      );
      final source = <Map<String, dynamic>>[
        {'role': 'user', 'content': 'draw'},
        for (var i = 0; i < 13; i++) ...[
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call$i',
                'type': 'function',
                'function': {'name': 'drawing', 'arguments': '{}'},
              },
            ],
          },
          {
            'role': 'tool',
            'name': 'drawing',
            'tool_call_id': 'call$i',
            'content': 'text$i',
            'metadata': {
              imageContextOwnerKey: 'm$i',
              kMcpResultMetadataKey: mcpResultMetadata([pixels]),
            },
          },
        ],
      ];
      await request.run(() async* {
        final messages = await buildOpenAIChatCompletionMessages(
          source,
          nativeInputs: NativeInputAttachments(
            config: ProviderConfig(
              id: 'test',
              enabled: true,
              name: 'test',
              apiKey: '',
              baseUrl: 'http://test',
            ),
            spec: ModelSpec(id: 'test', displayName: 'test'),
            protocol: NativeInputProtocol.chatCompletions,
          ),
          canImageInput: true,
          allowRemoteImages: true,
          reasoningReplay: ReasoningReplayPolicy.all,
        );
        final body = await request.project({'messages': messages});
        final sent = body['messages'] as List;
        expect(sent.where((m) => m['role'] == 'tool').length, 13);
        expect(sent.where((m) => m['tool_calls'] != null).length, 13);
        expect(sent.where((m) => m['role'] == 'user').length, 5);
        expect(jsonEncode(body), isNot(contains('kelivo-image-ref:')));
        yield 0;
      }).drain<void>();
    },
  );

  test(
    'no images removed before the threshold; arbitrary JSON is not inspected',
    () async {
      final im = image(0);
      final request = RequestImageContext(
        settings: const ImageContextSettings(),
        images: [im],
        loader: (_) async => pixels,
      );
      final body = {
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': 'Attached file / Path: unchanged'},
              {
                'type': 'image_url',
                'image_url': {'url': im.reference},
              },
            ],
          },
        ],
        'tools': [
          {
            'arguments': {
              'image_url': {'url': im.reference},
            },
          },
        ],
      };
      final projected = await request.project(body);
      expect(projected['tools'], body['tools']);
      expect(((projected['messages'] as List).first['content'] as List).first, {
        'type': 'text',
        'text': 'Attached file / Path: unchanged',
      });
    },
  );
}

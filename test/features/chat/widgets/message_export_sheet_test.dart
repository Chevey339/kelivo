import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/features/chat/widgets/message_export_sheet.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

Uint8List _solidPng({
  required int width,
  required int height,
  required image_lib.Color color,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(color);
  return image_lib.encodePng(image);
}

Uint8List _rowIndexPng({required int width, required int height}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      image.setPixelRgba(x, y, 0, y, 0, 255);
    }
  }
  return image_lib.encodePng(image);
}

Uint8List _blankPaddedPng({
  required int width,
  required int height,
  required image_lib.Color background,
  required image_lib.Color content,
  required int contentLeft,
  required int contentTop,
  required int contentWidth,
  required int contentHeight,
}) {
  final image = image_lib.Image(width: width, height: height, numChannels: 4)
    ..clear(background);
  for (var y = contentTop; y < contentTop + contentHeight; y += 1) {
    for (var x = contentLeft; x < contentLeft + contentWidth; x += 1) {
      image.setPixel(x, y, content);
    }
  }
  return image_lib.encodePng(image);
}

void main() {
  testWidgets('export capture root keeps the captured theme', (tester) async {
    final exportTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );
    Color? capturedSurface;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: buildExportCaptureRootForTesting(
          theme: exportTheme,
          child: Builder(
            builder: (context) {
              capturedSurface = Theme.of(context).colorScheme.surface;
              return const SizedBox(width: 80, height: 40);
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(capturedSurface, exportTheme.colorScheme.surface);
  });

  testWidgets('export viewport root captures a shifted slice', (tester) async {
    final exportTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: buildExportCaptureViewportRootForTesting(
          theme: exportTheme,
          width: 80,
          viewportHeight: 40,
          contentHeight: 120,
          offsetY: 40,
          child: Column(
            children: const [
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.red),
              ),
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.green),
              ),
              SizedBox(
                width: 80,
                height: 40,
                child: ColoredBox(color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final overflowBox = tester.widget<OverflowBox>(find.byType(OverflowBox));
    final transform = tester.widget<Transform>(find.byType(Transform));

    expect(overflowBox.minHeight, 120);
    expect(overflowBox.maxHeight, 120);
    expect(transform.transform.getTranslation().y, -40);
  });

  test('desktop export image config keeps enough source pixels for text', () {
    final config = exportImageRenderConfigForTesting(isDesktop: true);

    expect(config.width * config.pixelRatio, greaterThanOrEqualTo(2160));
    expect(config.pixelRatio, greaterThanOrEqualTo(3.0));
  });

  test('export capture keeps medium-long images on the whole-capture path', () {
    expect(
      shouldUseFullExportCaptureForTesting(
        logicalSize: const Size(480, 2665),
        pixelRatio: 3,
      ),
      isTrue,
    );
    expect(
      exportFullCapturePixelRatioForTesting(
        logicalSize: const Size(480, 2665),
        requestedPixelRatio: 3,
      ),
      3,
    );
  });

  test('export capture downscales very long whole captures before slicing', () {
    final pixelRatio = exportFullCapturePixelRatioForTesting(
      logicalSize: const Size(480, 7537),
      requestedPixelRatio: 3,
    );

    expect(pixelRatio, isNotNull);
    expect(pixelRatio!, closeTo(15360 / 7537, 0.0001));
    expect(
      shouldUseFullExportCaptureForTesting(
        logicalSize: const Size(480, 8000),
        pixelRatio: 3,
      ),
      isFalse,
    );
  });

  test('export capture slice height stays on logical pixel boundaries', () {
    final logicalHeight = exportCaptureSliceLogicalHeightForTesting(
      pixelRatio: 3,
    );

    expect(logicalHeight, 1365);
    expect(logicalHeight * 3, lessThanOrEqualTo(4096));
  });

  test('export image stitching keeps bottom slice content', () {
    final pngBytes = stitchExportPngSlicesForTesting(
      outputWidth: 20,
      outputHeight: 4136,
      slices: [
        (
          bytes: _solidPng(
            width: 20,
            height: 4096,
            color: image_lib.ColorRgba8(255, 0, 0, 255),
          ),
          y: 0,
        ),
        (
          bytes: _solidPng(
            width: 20,
            height: 40,
            color: image_lib.ColorRgba8(0, 255, 0, 255),
          ),
          y: 4096,
        ),
      ],
    );

    final image = image_lib.decodePng(pngBytes);
    expect(image, isNotNull);
    expect(image!.width, 20);
    expect(image.height, 4136);

    final topPixel = image.getPixel(10, 20);
    expect(topPixel.r, greaterThan(topPixel.g));

    final bottomPixel = image.getPixel(10, 4116);
    expect(bottomPixel.g, greaterThan(bottomPixel.r));
  });

  test(
    'export image stitching crops slices that extend past output height',
    () {
      final pngBytes = stitchExportPngSlicesForTesting(
        outputWidth: 20,
        outputHeight: 100,
        slices: [
          (
            bytes: _solidPng(
              width: 20,
              height: 80,
              color: image_lib.ColorRgba8(255, 0, 0, 255),
            ),
            y: 0,
          ),
          (
            bytes: _solidPng(
              width: 20,
              height: 21,
              color: image_lib.ColorRgba8(0, 255, 0, 255),
            ),
            y: 80,
          ),
        ],
      );

      final image = image_lib.decodePng(pngBytes);
      expect(image, isNotNull);
      expect(image!.width, 20);
      expect(image.height, 100);

      final lastPixel = image.getPixel(10, 99);
      expect(lastPixel.g, greaterThan(lastPixel.r));
    },
  );

  test('export image stitching crops without vertical resampling', () {
    final pngBytes = stitchExportPngSlicesForTesting(
      outputWidth: 2,
      outputHeight: 20,
      slices: [(bytes: _rowIndexPng(width: 2, height: 21), y: 0)],
    );

    final image = image_lib.decodePng(pngBytes);
    expect(image, isNotNull);
    expect(image!.height, 20);
    for (var y = 0; y < 20; y += 1) {
      expect(image.getPixel(1, y).g, y);
    }
  });

  test('export image blank trim removes opaque outer padding', () {
    final pngBytes = _blankPaddedPng(
      width: 12,
      height: 24,
      background: image_lib.ColorRgba8(255, 255, 255, 255),
      content: image_lib.ColorRgba8(255, 0, 0, 255),
      contentLeft: 4,
      contentTop: 9,
      contentWidth: 3,
      contentHeight: 4,
    );

    final trimmed = trimExportPngBlankPaddingForTesting(
      pngBytes,
      preservePadding: 2,
    );

    final image = image_lib.decodePng(trimmed);
    expect(image, isNotNull);
    expect(image!.width, 7);
    expect(image.height, 8);
    final contentPixel = image.getPixel(3, 3);
    expect(contentPixel.r, greaterThan(contentPixel.g));
  });

  test('export image blank trim removes transparent outer padding', () {
    final pngBytes = _blankPaddedPng(
      width: 10,
      height: 18,
      background: image_lib.ColorRgba8(0, 0, 0, 0),
      content: image_lib.ColorRgba8(0, 255, 0, 255),
      contentLeft: 2,
      contentTop: 7,
      contentWidth: 5,
      contentHeight: 3,
    );

    final trimmed = trimExportPngBlankPaddingForTesting(
      pngBytes,
      preservePadding: 1,
    );

    final image = image_lib.decodePng(trimmed);
    expect(image, isNotNull);
    expect(image!.width, 7);
    expect(image.height, 5);
    final contentPixel = image.getPixel(2, 2);
    expect(contentPixel.g, greaterThan(contentPixel.r));
  });

  test(
    'captured export png processing trims a single capture asynchronously',
    () async {
      final pngBytes = _blankPaddedPng(
        width: 12,
        height: 24,
        background: image_lib.ColorRgba8(255, 255, 255, 255),
        content: image_lib.ColorRgba8(0, 0, 255, 255),
        contentLeft: 4,
        contentTop: 9,
        contentWidth: 3,
        contentHeight: 4,
      );

      final trimmed = await processCapturedExportPngForTesting(
        singlePngBytes: pngBytes,
        preservePadding: 2,
      );

      final image = image_lib.decodePng(trimmed);
      expect(image, isNotNull);
      expect(image!.width, 7);
      expect(image.height, 8);
      final contentPixel = image.getPixel(3, 3);
      expect(contentPixel.b, greaterThan(contentPixel.r));
    },
  );

  test(
    'captured export png processing stitches slices asynchronously',
    () async {
      final pngBytes = await processCapturedExportPngForTesting(
        outputWidth: 8,
        outputHeight: 14,
        slices: [
          (
            bytes: _blankPaddedPng(
              width: 8,
              height: 8,
              background: image_lib.ColorRgba8(0, 0, 0, 0),
              content: image_lib.ColorRgba8(255, 0, 0, 255),
              contentLeft: 2,
              contentTop: 2,
              contentWidth: 4,
              contentHeight: 4,
            ),
            y: 0,
          ),
          (
            bytes: _blankPaddedPng(
              width: 8,
              height: 6,
              background: image_lib.ColorRgba8(0, 0, 0, 0),
              content: image_lib.ColorRgba8(0, 255, 0, 255),
              contentLeft: 2,
              contentTop: 0,
              contentWidth: 4,
              contentHeight: 4,
            ),
            y: 8,
          ),
        ],
        preservePadding: 0,
      );

      final image = image_lib.decodePng(pngBytes);
      expect(image, isNotNull);
      expect(image!.width, 4);
      expect(image.height, 10);
      expect(image.getPixel(2, 0).r, greaterThan(image.getPixel(2, 0).g));
      expect(image.getPixel(2, 9).g, greaterThan(image.getPixel(2, 9).r));
    },
  );

  test(
    'hiding thinking drops reasoning and tool parts from export message',
    () {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          ReasoningPart('plan'),
          ToolCallPart('{"id":"call_1","name":"lookup"}'),
          TextPart('answer'),
          ImagePart(uri: 'https://example.com/a.png'),
        ],
      );

      final hidden = messageForThinkingExport(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden.parts.whereType<ReasoningPart>(), isEmpty);
      expect(hidden.parts.whereType<ToolCallPart>(), isEmpty);
      expect(hidden.content, 'answer');
      expect(
        hidden.parts.whereType<ImagePart>().single.uri,
        'https://example.com/a.png',
      );

      final shown = messageForThinkingExport(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown.parts.whereType<ReasoningPart>(), isNotEmpty);
      expect(shown.parts.whereType<ToolCallPart>(), isNotEmpty);
    },
  );

  test('image export with cards on strips unclosed think from the body', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('visible <think>partial'),
        ToolCallPart('{"id":"lookup","name":"lookup"}'),
      ],
    );

    final shown = messageForThinkingExport(
      message,
      showThinkingAndToolCards: true,
    );
    expect(shown.parts.whereType<ToolCallPart>(), isNotEmpty);
    expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
      'partial',
    ]);
    expect(shown.content, 'visible ');
    expect(shown.content, isNot(contains('partial')));
    expect(shown.content, isNot(contains('<think>')));
    expect(shown.parts.map((part) => part.kind), [
      'text',
      'reasoning',
      'tool_call',
    ]);

    final hidden = messageForThinkingExport(
      message,
      showThinkingAndToolCards: false,
    );
    expect(hidden.parts.whereType<ToolCallPart>(), isEmpty);
    expect(hidden.parts.whereType<ReasoningPart>(), isEmpty);
    expect(hidden.content, 'visible ');
  });

  test('image export with cards on inserts ReasoningPart before ImagePart', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('before <think>secret</think>'),
        ImagePart(uri: 'https://example.com/a.png'),
        TextPart(' after'),
      ],
    );

    final shown = messageForThinkingExport(
      message,
      showThinkingAndToolCards: true,
    );
    expect(shown.parts.whereType<ImagePart>(), isNotEmpty);
    expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
      'secret',
    ]);
    expect(shown.content, 'before  after');
    expect(shown.parts.map((part) => part.kind), [
      'text',
      'reasoning',
      'image',
      'text',
    ]);

    final hidden = messageForThinkingExport(
      message,
      showThinkingAndToolCards: false,
    );
    expect(hidden.parts.whereType<ReasoningPart>(), isEmpty);
    expect(hidden.parts.whereType<ImagePart>(), isNotEmpty);
    expect(hidden.content, 'before  after');
  });

  test('image export splits a think range that spans a ToolCallPart', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('<think>A'),
        ToolCallPart('{"id":"lookup","name":"lookup"}'),
        TextPart('B</think>answer'),
      ],
    );

    final shown = messageForThinkingExport(
      message,
      showThinkingAndToolCards: true,
    );
    expect(shown.parts.map((part) => part.kind), [
      'reasoning',
      'tool_call',
      'reasoning',
      'text',
    ]);
    expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
      'A',
      'B',
    ]);
    expect(shown.content, 'answer');

    final hidden = messageForThinkingExport(
      message,
      showThinkingAndToolCards: false,
    );
    expect(hidden.parts.whereType<ReasoningPart>(), isEmpty);
    expect(hidden.parts.whereType<ToolCallPart>(), isEmpty);
    expect(hidden.content, 'answer');
  });

  test(
    'image export keeps split think fragments collapsed when expand is off',
    () {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('<think>A'),
          ToolCallPart('{"id":"lookup","name":"lookup"}'),
          TextPart('B</think>answer'),
        ],
      );

      expect(
        exportReasoningExpandedFlagsForTesting(
          message,
          expandThinkingContent: false,
        ),
        [false, false],
      );
      expect(
        exportReasoningExpandedFlagsForTesting(
          message,
          expandThinkingContent: true,
        ),
        [true, true],
      );
    },
  );

  test(
    'image export inherits collapse onto padded fragments when segments json has one block',
    () {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('<think>A'),
          ImagePart(uri: 'https://example.com/a.png'),
          TextPart('B</think>answer'),
        ],
        reasoningSegmentsJson: '{"segments":[{"text":"AB"}]}',
      );

      expect(
        exportReasoningExpandedFlagsForTesting(
          message,
          expandThinkingContent: false,
        ),
        [false, false],
      );
    },
  );

  test(
    'image export copies think timing onto split fragments of the same block',
    () {
      final firstStart = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final firstEnd = DateTime.utc(2026, 1, 1, 0, 0, 10);
      final secondStart = DateTime.utc(2026, 1, 1, 0, 0, 20);
      final secondEnd = DateTime.utc(2026, 1, 1, 0, 0, 30);
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('<think>A'),
          ToolCallPart('{"id":"lookup","name":"lookup"}'),
          TextPart('B</think>mid<think>C</think>answer'),
        ],
        reasoningSegmentsJson:
            '{"segments":['
            '{"text":"AB","startAt":"${firstStart.toIso8601String()}","finishedAt":"${firstEnd.toIso8601String()}"},'
            '{"text":"C","startAt":"${secondStart.toIso8601String()}","finishedAt":"${secondEnd.toIso8601String()}"}'
            ']}',
      );

      final metadata = exportReasoningMetadataForTesting(
        message,
        expandThinkingContent: false,
      );
      expect(metadata, hasLength(3));
      expect(metadata.map((item) => item.expanded), [false, false, false]);
      expect(metadata[0].startAt, firstStart);
      expect(metadata[0].finishedAt, firstEnd);
      expect(metadata[1].startAt, firstStart);
      expect(metadata[1].finishedAt, firstEnd);
      expect(metadata[2].startAt, secondStart);
      expect(metadata[2].finishedAt, secondEnd);
    },
  );

  test(
    'image export aligns extra structured ReasoningParts to the expand toggle',
    () {
      final startAt = DateTime.utc(2026, 1, 1, 0, 0, 0);
      final finishedAt = DateTime.utc(2026, 1, 1, 0, 0, 8);
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          ReasoningPart('first thought'),
          ReasoningPart('second thought'),
          TextPart('answer'),
        ],
        reasoningSegmentsJson:
            '{"segments":[{"text":"first thought","startAt":"${startAt.toIso8601String()}","finishedAt":"${finishedAt.toIso8601String()}"}]}',
      );

      final collapsed = exportReasoningMetadataForTesting(
        message,
        expandThinkingContent: false,
      );
      expect(collapsed.map((item) => item.expanded), [false, false]);
      expect(collapsed[0].startAt, startAt);
      expect(collapsed[0].finishedAt, finishedAt);
      expect(collapsed[1].startAt, isNull);
      expect(collapsed[1].finishedAt, isNull);

      final expanded = exportReasoningMetadataForTesting(
        message,
        expandThinkingContent: true,
      );
      expect(expanded.map((item) => item.expanded), [true, true]);

      final noJson = exportReasoningExpandedFlagsForTesting(
        ChatMessage(
          role: 'assistant',
          conversationId: 'c1',
          parts: const [
            ReasoningPart('first thought'),
            ReasoningPart('second thought'),
          ],
        ),
        expandThinkingContent: false,
      );
      expect(noJson, [false, false]);
    },
  );

  test('image export drops malformed contentSplits instead of truncating', () {
    final mismatched = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      content: 'hello',
      reasoningSegmentsJson:
          '{"v":2,"segments":[{"text":"plan"}],"contentSplits":{"offsets":[0,6],"reasoningCounts":[1],"toolCounts":[0,1]}}',
    );
    final empty = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      content: 'hello',
      reasoningSegmentsJson:
          '{"v":2,"segments":[{"text":"plan"}],"contentSplits":{"offsets":[],"reasoningCounts":[],"toolCounts":[]}}',
    );

    for (final message in [mismatched, empty]) {
      final splits = exportContentSplitsForTesting(message);
      expect(splits.offsets, isNull);
      expect(splits.reasoningCounts, isNull);
      expect(splits.toolCounts, isNull);
    }
  });

  test('image export keeps structurally valid historical contentSplits', () {
    final splits = exportContentSplitsForTesting(
      ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        content: 'hello',
        reasoningSegmentsJson:
            '{"v":2,"segments":[{"text":"plan"}],"contentSplits":{"offsets":[0],"reasoningCounts":[1],"toolCounts":[0]}}',
      ),
    );
    expect(splits.offsets, [0]);
    expect(splits.reasoningCounts, [1]);
    expect(splits.toolCounts, [0]);
  });

  test('image export splits a think range that spans an ImagePart', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('<think>A'),
        ImagePart(uri: 'https://example.com/a.png'),
        TextPart('B</think>answer'),
      ],
    );

    final shown = messageForThinkingExport(
      message,
      showThinkingAndToolCards: true,
    );
    expect(shown.parts.map((part) => part.kind), [
      'reasoning',
      'image',
      'reasoning',
      'text',
    ]);
    expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
      'A',
      'B',
    ]);
    expect(shown.content, 'answer');
  });

  test(
    'image export keeps adjacent TextParts of one think as one ReasoningPart',
    () {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [TextPart('<think>A'), TextPart('B</think>answer')],
      );

      final shown = messageForThinkingExport(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown.parts.map((part) => part.kind), ['reasoning', 'text']);
      expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
        'AB',
      ]);
      expect(shown.content, 'answer');
    },
  );

  test(
    'image export does not attach later think text to an empty think block',
    () {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('before<think></think>middle<think>secret</think>after'),
        ],
      );

      final shown = messageForThinkingExport(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown.parts.whereType<ReasoningPart>().map((part) => part.text), [
        'secret',
      ]);
      expect(shown.content, 'beforemiddleafter');
      expect(shown.parts.map((part) => part.kind), [
        'text',
        'text',
        'reasoning',
        'text',
      ]);
      expect((shown.parts[0] as TextPart).text, 'before');
      expect((shown.parts[1] as TextPart).text, 'middle');
      expect((shown.parts[3] as TextPart).text, 'after');
    },
  );

  test('image export keeps TextParts on both sides of an ImagePart', () {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('before'),
        ImagePart(uri: 'https://example.com/a.png'),
        TextPart('after'),
      ],
    );

    final hidden = messageForThinkingExport(
      message,
      showThinkingAndToolCards: false,
    );
    expect(hidden.parts.map((part) => part.kind), ['text', 'image', 'text']);
    expect((hidden.parts[0] as TextPart).text, 'before');
    expect((hidden.parts[1] as ImagePart).uri, 'https://example.com/a.png');
    expect((hidden.parts[2] as TextPart).text, 'after');

    final shown = messageForThinkingExport(
      message,
      showThinkingAndToolCards: true,
    );
    expect(shown.parts.map((part) => part.kind), ['text', 'image', 'text']);
    expect((shown.parts[0] as TextPart).text, 'before');
    expect((shown.parts[2] as TextPart).text, 'after');
  });

  test(
    'legacy <think> assistant text is stripped and not duplicated',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [TextPart('<think>secret plan</think>\nvisible answer')],
      );

      final hidden = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden, contains('visible answer'));
      expect(hidden, isNot(contains('secret plan')));
      expect(hidden, isNot(contains('<think>')));

      final shown = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown, contains('visible answer'));
      expect(shown, contains('[Thinking]'));
      expect(shown, contains('secret plan'));
      expect(shown, isNot(contains('<think>')));
      expect('secret plan'.allMatches(shown).length, 1);
    },
  );

  test(
    'think tags split across TextParts stay hidden and keep tool order',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('<t'),
          ToolCallPart('{"id":"lookup","name":"lookup","content":"hits"}'),
          TextPart('hink>secret</think>answer'),
        ],
      );

      final hidden = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden, isNot(contains('secret')));
      expect(hidden, isNot(contains('<think>')));
      expect(hidden, contains('answer'));

      final shown = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown.split('[Thinking]').first, isNot(contains('secret')));
      expect(shown.indexOf('[lookup]'), lessThan(shown.indexOf('answer')));
    },
  );

  test(
    'think tags that span TextParts stay hidden and keep tool order',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('<think>secret'),
          ToolCallPart('{"id":"lookup","name":"lookup","content":"hits"}'),
          TextPart(' continued</think>answer'),
        ],
      );

      final hidden = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden, isNot(contains('secret')));
      expect(hidden, isNot(contains('<think>')));
      expect(hidden, isNot(contains('</think>')));
      expect(hidden, contains('answer'));

      final shown = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown, isNot(contains('<think>')));
      expect(shown, isNot(contains('</think>')));
      expect(shown.split('[Thinking]').first, isNot(contains('secret')));
      expect(shown.indexOf('[lookup]'), lessThan(shown.indexOf('answer')));
    },
  );

  test(
    'unclosed trailing think is hidden or shown from the whole-string parse',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [TextPart('visible <think>partial')],
      );

      final hidden = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden, contains('visible'));
      expect(hidden, isNot(contains('partial')));
      expect(hidden, isNot(contains('<think>')));

      final shown = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown, contains('[Thinking]'));
      expect(shown, contains('partial'));
      expect(shown.split('[Thinking]').first, isNot(contains('partial')));
    },
  );

  test(
    'multi TextPart export without think keeps indent and trailing spaces',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('    indented\nline  '),
          ToolCallPart('{"id":"lookup","name":"lookup","content":"hits"}'),
          TextPart('after  '),
        ],
      );

      final exported = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(exported, contains('    indented\nline  \n'));
      expect(exported, contains('after  \n'));
      expect(
        exported.indexOf('    indented'),
        lessThan(exported.indexOf('[lookup]')),
      );
      expect(
        exported.indexOf('[lookup]'),
        lessThan(exported.indexOf('after  ')),
      );
    },
  );

  test(
    'interleaved Text/Tool/Text with one <think> part keeps order and hides think',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('before <think>secret plan</think>'),
          ToolCallPart('{"id":"lookup","name":"lookup","content":"hits"}'),
          TextPart('after'),
        ],
      );

      final hidden = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: false,
      );
      expect(hidden, contains('before \n\nafter\n'));
      expect(hidden.indexOf('before'), lessThan(hidden.indexOf('after')));
      expect(hidden, isNot(contains('[lookup]')));
      expect(hidden, isNot(contains('secret plan')));
      expect(hidden, isNot(contains('<think>')));

      final shown = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(shown, contains('before \n\n[lookup]\nhits\n\nafter\n'));
      expect(shown.indexOf('before'), lessThan(shown.indexOf('[lookup]')));
      expect(shown.indexOf('[lookup]'), lessThan(shown.indexOf('after')));
      expect(shown, isNot(contains('<think>')));
      expect('secret plan'.allMatches(shown).length, 1);
      expect(shown.indexOf('after'), lessThan(shown.indexOf('secret plan')));
    },
  );

  test(
    'non-reasoning interleaved Text/Tool/Text export keeps part order',
    () async {
      final message = ChatMessage(
        role: 'assistant',
        conversationId: 'c1',
        parts: const [
          TextPart('before'),
          ToolCallPart('{"id":"lookup","name":"lookup","content":"hits"}'),
          TextPart('after'),
        ],
      );

      final exported = await exportMessageBlocksForTesting(
        message,
        showThinkingAndToolCards: true,
      );
      expect(exported, contains('before\n\n[lookup]\nhits\n\nafter\n'));
      expect(
        exported.indexOf('before'),
        lessThan(exported.indexOf('[lookup]')),
      );
      expect(exported.indexOf('[lookup]'), lessThan(exported.indexOf('after')));
    },
  );

  test('md/txt export walks parts in screen order including tools', () async {
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: const [
        TextPart('我查一下'),
        ToolCallPart('{"id":"search","name":"search","content":"hits"}'),
        TextPart('结果是 X'),
        ReasoningPart('plan'),
      ],
    );

    final exported = await exportMessageBlocksForTesting(
      message,
      showThinkingAndToolCards: true,
    );
    expect(
      exported,
      contains('我查一下\n\n[search]\nhits\n\n结果是 X\n\n\n[Thinking]\n\nplan\n\n'),
    );
  });

  test('tool export uses Markdown, never the JSON envelope', () async {
    final envelope = encodeLegacyMcpToolResultEnvelope(
      text: 'caption',
      imageUris: ['/tmp/shot.png'],
    );
    final message = ChatMessage(
      role: 'assistant',
      conversationId: 'c1',
      parts: [
        ToolCallPart(
          jsonEncode({
            'id': 'shot',
            'name': 'shot',
            'content': envelope,
          }),
        ),
      ],
    );

    final exported = await exportMessageBlocksForTesting(
      message,
      showThinkingAndToolCards: true,
    );
    expect(exported, isNot(contains('"kelivo"')));
    expect(exported, contains('[shot]'));
    expect(exported, contains('caption'));
    expect(exported, contains('![]('));
  });
}

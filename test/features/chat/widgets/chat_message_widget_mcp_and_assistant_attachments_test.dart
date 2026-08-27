import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tinyPngDataUri =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

SafeResizeImage? _resizeOf(Image image) {
  final provider = image.image;
  return provider is SafeResizeImage ? provider : null;
}

T? _innerProvider<T extends ImageProvider>(Image image) {
  final resized = _resizeOf(image);
  final inner = resized?.imageProvider ?? image.image;
  return inner is T ? inner : null;
}

void _setToolImageView(WidgetTester tester, {double dpr = 3}) {
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _harness(Widget child, {SettingsProvider? settings}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) =>
            settings ?? SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            TtsProvider(preferences: createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider(create: (_) => ToolApprovalService()),
      ChangeNotifierProvider(create: (_) => AskUserInteractionService()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('parseMcpImagePathsForTesting', () {
    test('extracts markdown images and cleans text', () {
      const content = '''
result ok
![](/tmp/mcp_img_1.png)
more text
![shot](https://example.com/a.png)
''';
      final (clean, images) = parseMcpImagePathsForTesting(content);
      expect(images, ['/tmp/mcp_img_1.png', 'https://example.com/a.png']);
      expect(clean.contains('!['), isFalse);
      expect(clean.contains('result ok'), isTrue);
      expect(clean.contains('more text'), isTrue);
    });

    test('does not parse custom [image:] markers', () {
      const content = 'plain [image:/tmp/legacy.png] stays';
      final (clean, images) = parseMcpImagePathsForTesting(content);
      expect(images, isEmpty);
      expect(clean, 'plain [image:/tmp/legacy.png] stays');
    });

    test('ignores empty and generated placeholders', () {
      const content = '![]()\n![x](generated)\n![ok](/tmp/real.png)';
      final (clean, images) = parseMcpImagePathsForTesting(content);
      expect(images, ['/tmp/real.png']);
      expect(clean.contains('/tmp/real.png'), isFalse);
    });

    test('extracts destinations containing parentheses', () {
      const content = 'shot\n![](/tmp/run (1)/image.png)\ndone';
      final (clean, images) = parseMcpImagePathsForTesting(content);
      expect(images, ['/tmp/run (1)/image.png']);
      expect(clean.contains('/tmp/run'), isFalse);
      expect(clean.contains('shot'), isTrue);
      expect(clean.contains('done'), isTrue);
    });
  });

  testWidgets('MCP markdown images populate tool thumbnail list', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: 'assistant-mcp-thumbs',
            role: 'assistant',
            content: 'tool ran',
            conversationId: 'conversation-mcp-thumbs',
          ),
          toolParts: const [
            ToolUIPart(
              id: 'tool-1',
              toolName: 'screenshot',
              arguments: {'target': 'desk'},
              content:
                  'captured\n![](https://example.com/mcp.png)\n![local](/tmp/mcp_local.png)',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final thumbs = find.byKey(const ValueKey('tool-image-thumbnails:tool-1'));
    expect(thumbs, findsOneWidget);

    expect(
      find.descendant(of: thumbs, matching: find.byType(GestureDetector)),
      findsNWidgets(2),
    );

    final images = tester
        .widgetList<Image>(
          find.descendant(of: thumbs, matching: find.byType(Image)),
        )
        .toList();
    expect(
      images.any(
        (image) =>
            _innerProvider<NetworkImage>(image)?.url ==
            'https://example.com/mcp.png',
      ),
      isTrue,
    );
    expect(images.every((image) => _resizeOf(image) != null), isTrue);
  });

  testWidgets('hideToolResultImages suppresses MCP thumbnails under the card', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setHideToolResultImages(true);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: 'assistant-mcp-thumbs-hidden',
            role: 'assistant',
            content: 'tool ran',
            conversationId: 'conversation-mcp-thumbs-hidden',
          ),
          toolParts: const [
            ToolUIPart(
              id: 'tool-hidden',
              toolName: 'screenshot',
              arguments: {'target': 'desk'},
              content:
                  'captured\n![](https://example.com/mcp.png)\n![local](/tmp/mcp_local.png)',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('tool-image-thumbnails:tool-hidden')),
      findsNothing,
    );
    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (image) =>
                image.image is NetworkImage &&
                (image.image as NetworkImage).url ==
                    'https://example.com/mcp.png',
          ),
      isFalse,
    );
  });

  testWidgets('MCP markdown images appear in tool detail sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: 'assistant-mcp-detail',
            role: 'assistant',
            content: 'tool ran',
            conversationId: 'conversation-mcp-detail',
          ),
          toolParts: const [
            ToolUIPart(
              id: 'tool-detail-1',
              toolName: 'screenshot',
              arguments: {'target': 'desk'},
              content: 'captured\n![](https://example.com/detail.png)',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    // Open the tool detail sheet from the timeline step.
    await tester.tap(find.byIcon(Lucide.ChevronRight).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('https://example.com/detail.png'), findsNothing);
    final sheetImages = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(
      sheetImages.any(
        (image) =>
            _innerProvider<NetworkImage>(image)?.url ==
            'https://example.com/detail.png',
      ),
      isTrue,
    );
  });

  testWidgets('hideToolResultImages also hides tool-role card thumbnails', (
    tester,
  ) async {
    final settings = SettingsProvider(createBusinessTestPreferences());
    await settings.loaded;
    await settings.setHideToolResultImages(true);

    await tester.pumpWidget(
      _harness(
        settings: settings,
        ChatMessageWidget(
          message: ChatMessage(
            id: 'tool-role-mcp-hidden',
            role: 'tool',
            conversationId: 'conversation-tool-role-mcp-hidden',
            content:
                '{"tool":"screenshot","arguments":{},"result":"ok\\n![](https://example.com/tool-role.png)"}',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester
          .widgetList<Image>(find.byType(Image))
          .any(
            (image) =>
                _innerProvider<NetworkImage>(image)?.url ==
                'https://example.com/tool-role.png',
          ),
      isFalse,
    );
  });

  testWidgets(
    'hideToolResultImages=false still renders the tool-role thumbnail',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setHideToolResultImages(false);

      await tester.pumpWidget(
        _harness(
          settings: settings,
          ChatMessageWidget(
            message: ChatMessage(
              id: 'tool-role-mcp-shown',
              role: 'tool',
              conversationId: 'conversation-tool-role-mcp-shown',
              content:
                  '{"tool":"screenshot","arguments":{},"result":"ok\\n![](https://example.com/tool-role.png)"}',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any(
              (image) =>
                  _innerProvider<NetworkImage>(image)?.url ==
                  'https://example.com/tool-role.png',
            ),
        isTrue,
      );
    },
  );

  testWidgets('tool-role card also shows MCP markdown thumbnails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          message: ChatMessage(
            id: 'tool-role-mcp',
            role: 'tool',
            conversationId: 'conversation-tool-role-mcp',
            content:
                '{"tool":"screenshot","arguments":{},"result":"ok\\n![](https://example.com/tool-role.png)"}',
          ),
        ),
      ),
    );
    await tester.pump();

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(
      images.any(
        (image) =>
            _innerProvider<NetworkImage>(image)?.url ==
            'https://example.com/tool-role.png',
      ),
      isTrue,
    );
  });

  testWidgets(
    'assistant FilePart stays in the strip; ImagePart renders in the timeline',
    (tester) async {
      const messageId = 'assistant-with-attachments';

      await tester.pumpWidget(
        _harness(
          ChatMessageWidget(
            showModelIcon: false,
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: 'conversation-assistant-attachments',
              parts: const [
                TextPart('这是助手附图'),
                FilePart(
                  uri: '/tmp/report.pdf',
                  name: 'report.pdf',
                  mime: 'application/pdf',
                ),
                ImagePart(uri: 'https://example.com/assistant.png'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final attachmentsFinder = find.byKey(
        const ValueKey('assistant-message-attachments:$messageId'),
      );
      expect(attachmentsFinder, findsOneWidget);
      expect(
        find.descendant(
          of: attachmentsFinder,
          matching: find.text('report.pdf'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assistant-message-attachment:$messageId:0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('assistant-message-attachment:$messageId:1')),
        findsNothing,
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(
        images.any((image) {
          final provider = image.image;
          final network = provider is NetworkImage
              ? provider
              : provider is SafeResizeImage &&
                    provider.imageProvider is NetworkImage
              ? provider.imageProvider as NetworkImage
              : provider is ResizeImage &&
                    provider.imageProvider is NetworkImage
              ? provider.imageProvider as NetworkImage
              : null;
          return network?.url == 'https://example.com/assistant.png';
        }),
        isTrue,
      );

      final align = tester.widget<Align>(attachmentsFinder);
      expect(align.alignment, Alignment.centerLeft);
    },
  );

  testWidgets('assistant data URI ImagePart uses MemoryImage', (tester) async {
    const messageId = 'assistant-data-image';
    const dataUri =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: messageId,
            role: 'assistant',
            conversationId: 'conversation-assistant-data-image',
            parts: const [
              TextPart('data image'),
              ImagePart(uri: dataUri),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('assistant-message-attachments:$messageId')),
      findsNothing,
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    final memory = provider is MemoryImage
        ? provider
        : provider is SafeResizeImage && provider.imageProvider is MemoryImage
        ? provider.imageProvider as MemoryImage
        : provider is ResizeImage && provider.imageProvider is MemoryImage
        ? provider.imageProvider as MemoryImage
        : null;
    expect(memory, isA<MemoryImage>());
  });

  List<Image> imagesWithUrl(WidgetTester tester, String url) {
    return tester.widgetList<Image>(find.byType(Image)).where((image) {
      final provider = image.image;
      final network = provider is NetworkImage
          ? provider
          : provider is SafeResizeImage &&
                provider.imageProvider is NetworkImage
          ? provider.imageProvider as NetworkImage
          : provider is ResizeImage && provider.imageProvider is NetworkImage
          ? provider.imageProvider as NetworkImage
          : null;
      return network?.url == url;
    }).toList();
  }

  testWidgets(
    'semantic split fallback inlines ImagePart once and keeps FilePart in the strip',
    (tester) async {
      const messageId = 'assistant-semantic-image';
      const imageUrl = 'https://example.com/semantic.png';

      await tester.pumpWidget(
        _harness(
          ChatMessageWidget(
            showModelIcon: false,
            message: ChatMessage(
              id: messageId,
              role: 'assistant',
              conversationId: 'conversation-semantic-image',
              parts: const [
                ReasoningPart('THINK_PLAN'),
                TextPart('BODY_HELLO'),
                FilePart(
                  uri: '/tmp/report.pdf',
                  name: 'report.pdf',
                  mime: 'application/pdf',
                ),
                ImagePart(uri: imageUrl),
              ],
            ),
            reasoningSegments: const [
              ReasoningSegment(
                text: 'THINK_PLAN',
                expanded: true,
                loading: false,
              ),
            ],
            toolParts: const [
              ToolUIPart(
                id: 't1',
                toolName: 'alpha_search',
                arguments: {},
                content: 'ok',
              ),
              ToolUIPart(
                id: 't2',
                toolName: 'beta_search',
                arguments: {},
                content: 'ok',
              ),
              ToolUIPart(
                id: 't3',
                toolName: 'omega_search',
                arguments: {},
                content: 'ok',
              ),
            ],
            contentSplitOffsets: const [0],
            reasoningCountAtSplit: const [1],
            toolCountAtSplit: const [1],
          ),
        ),
      );
      await tester.pump();

      final attachmentsFinder = find.byKey(
        const ValueKey('assistant-message-attachments:$messageId'),
      );
      expect(attachmentsFinder, findsOneWidget);
      expect(
        find.descendant(
          of: attachmentsFinder,
          matching: find.text('report.pdf'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
        findsNothing,
      );
      expect(imagesWithUrl(tester, imageUrl), hasLength(1));
    },
  );

  testWidgets('complete historical splits keep ImagePart in the strip only', (
    tester,
  ) async {
    const messageId = 'assistant-complete-split-image';
    const imageUrl = 'https://example.com/historical.png';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: messageId,
            role: 'assistant',
            content: 'hello',
            conversationId: 'conversation-complete-split-image',
            parts: const [
              TextPart('hello'),
              ImagePart(uri: imageUrl),
            ],
          ),
          reasoningSegments: const [
            ReasoningSegment(text: 'plan', expanded: true, loading: false),
          ],
          contentSplitOffsets: const [0],
          reasoningCountAtSplit: const [1],
          toolCountAtSplit: const [0],
        ),
      ),
    );
    await tester.pump();

    final attachmentsFinder = find.byKey(
      const ValueKey('assistant-message-attachments:$messageId'),
    );
    expect(attachmentsFinder, findsOneWidget);
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(imagesWithUrl(tester, imageUrl), hasLength(1));
  });

  testWidgets(
    'tool thumbnails wrap network, local, and data URI with SafeResizeImage',
    (tester) async {
      _setToolImageView(tester);
      const localPath = '/tmp/tool_resize_local.png';

      await tester.pumpWidget(
        _harness(
          ChatMessageWidget(
            showModelIcon: false,
            message: ChatMessage(
              id: 'assistant-tool-resize',
              role: 'assistant',
              content: 'tool ran',
              conversationId: 'conversation-tool-resize',
            ),
            toolParts: const [
              ToolUIPart(
                id: 'tool-resize',
                toolName: 'screenshot',
                arguments: {},
                content:
                    'ok\n'
                    '![](https://example.com/net.png)\n'
                    '![]($localPath)\n'
                    '![]($_tinyPngDataUri)',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      final thumbs = find.byKey(
        const ValueKey('tool-image-thumbnails:tool-resize'),
      );
      final images = tester
          .widgetList<Image>(
            find.descendant(of: thumbs, matching: find.byType(Image)),
          )
          .toList();
      expect(images, hasLength(3));
      expect(images.every((image) => _resizeOf(image) != null), isTrue);
      expect(
        images.any(
          (image) =>
              _innerProvider<NetworkImage>(image)?.url ==
              'https://example.com/net.png',
        ),
        isTrue,
      );
      expect(
        images.any((image) => _innerProvider<FileImage>(image) != null),
        isTrue,
      );
      expect(
        images.any((image) => _innerProvider<MemoryImage>(image) != null),
        isTrue,
      );

      const dpr = 3.0;
      final expected = toolImageDecodePixels(
        logicalWidth: kToolImageTimelineMaxWidth,
        logicalHeight: kToolImageTimelineHeight,
        devicePixelRatio: dpr,
      );
      for (final image in images) {
        final resized = _resizeOf(image)!;
        expect(resized.width, expected.width);
        expect(resized.height, expected.height);
        expect(resized.width * resized.height * 4, lessThan(8 << 20));
      }
    },
  );

  testWidgets('standalone tool card decode stays within card bounds', (
    tester,
  ) async {
    _setToolImageView(tester);
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          message: ChatMessage(
            id: 'tool-role-resize',
            role: 'tool',
            conversationId: 'conversation-tool-role-resize',
            content:
                '{"tool":"screenshot","arguments":{},"result":"ok\\n![](https://example.com/card.png)"}',
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final resized = _resizeOf(image);
    expect(resized, isNotNull);
    final expected = toolImageDecodePixels(
      logicalWidth: kToolImageCardMaxWidth,
      logicalHeight: kToolImageCardHeight,
      devicePixelRatio: 3,
    );
    expect(resized!.width, expected.width);
    expect(resized.height, expected.height);
    expect(resized.width * resized.height * 4, lessThan(8 << 20));
  });

  testWidgets('tool detail decode stays within detail bounds', (tester) async {
    _setToolImageView(tester);
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showModelIcon: false,
          message: ChatMessage(
            id: 'assistant-detail-resize',
            role: 'assistant',
            content: 'tool ran',
            conversationId: 'conversation-detail-resize',
          ),
          toolParts: const [
            ToolUIPart(
              id: 'tool-detail-resize',
              toolName: 'screenshot',
              arguments: {'target': 'desk'},
              content: 'captured\n![](https://example.com/detail-bound.png)',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Lucide.ChevronRight).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final expected = toolImageDecodePixels(
      logicalWidth: kToolImageDetailMaxWidth,
      logicalHeight: kToolImageDetailHeight,
      devicePixelRatio: 3,
    );
    final detailImages = tester.widgetList<Image>(find.byType(Image)).where((
      image,
    ) {
      if (_innerProvider<NetworkImage>(image)?.url !=
          'https://example.com/detail-bound.png') {
        return false;
      }
      final resized = _resizeOf(image);
      return resized?.width == expected.width &&
          resized?.height == expected.height;
    }).toList();
    expect(detailImages, isNotEmpty);
    for (final image in detailImages) {
      final resized = _resizeOf(image)!;
      expect(resized.width * resized.height * 4, lessThan(8 << 20));
    }
  });

  testWidgets(
    'hideToolResultImages hides card images but detail still shows them',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      await settings.loaded;
      await settings.setHideToolResultImages(true);

      await tester.pumpWidget(
        _harness(
          settings: settings,
          ChatMessageWidget(
            showModelIcon: false,
            message: ChatMessage(
              id: 'assistant-hide-detail',
              role: 'assistant',
              content: 'tool ran',
              conversationId: 'conversation-hide-detail',
            ),
            toolParts: const [
              ToolUIPart(
                id: 'tool-hide-detail',
                toolName: 'screenshot',
                arguments: {'target': 'desk'},
                content: 'captured\n![](https://example.com/hidden-card.png)',
              ),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('tool-image-thumbnails:tool-hide-detail')),
        findsNothing,
      );
      expect(
        tester
            .widgetList<Image>(find.byType(Image))
            .any(
              (image) =>
                  _innerProvider<NetworkImage>(image)?.url ==
                  'https://example.com/hidden-card.png',
            ),
        isFalse,
      );

      await tester.tap(find.byIcon(Lucide.ChevronRight).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final detailImages = tester
          .widgetList<Image>(find.byType(Image))
          .toList();
      expect(
        detailImages.any(
          (image) =>
              _innerProvider<NetworkImage>(image)?.url ==
              'https://example.com/hidden-card.png',
        ),
        isTrue,
      );
      expect(detailImages.any((image) => _resizeOf(image) != null), isTrue);
    },
  );

  test('17k tool thumbnail would decode under 8 MiB', () {
    const originalWidth = 17277;
    const originalHeight = 11457;
    expect(originalWidth * originalHeight * 4, greaterThan(700 << 20));

    final decode = toolImageDecodePixels(
      logicalWidth: kToolImageTimelineMaxWidth,
      logicalHeight: kToolImageTimelineHeight,
      devicePixelRatio: 3,
    );
    expect(decode.width, lessThan(originalWidth));
    expect(decode.height, lessThan(originalHeight));
    expect(decode.width * decode.height * 4, lessThan(8 << 20));
  });

  test('toolImageDecodePixels caps DPR 1/3/5/8 and both orientations', () {
    const sizes = <({double w, double h})>[
      (w: kToolImageDetailMaxWidth, h: kToolImageDetailHeight),
      (w: kToolImageDetailHeight, h: kToolImageDetailMaxWidth),
    ];
    for (final dpr in <double>[1, 3, 5, 8]) {
      for (final size in sizes) {
        final decode = toolImageDecodePixels(
          logicalWidth: size.w,
          logicalHeight: size.h,
          devicePixelRatio: dpr,
        );
        expect(decode.width, greaterThanOrEqualTo(1));
        expect(decode.height, greaterThanOrEqualTo(1));
        expect(decode.width, lessThanOrEqualTo(kToolImageMaxDecodeEdge));
        expect(decode.height, lessThanOrEqualTo(kToolImageMaxDecodeEdge));
        expect(
          decode.width * decode.height,
          lessThanOrEqualTo(kToolImageMaxDecodePixels),
        );
        expect(decode.width * decode.height * 4, lessThanOrEqualTo(8 << 20));
      }
    }
  });
}

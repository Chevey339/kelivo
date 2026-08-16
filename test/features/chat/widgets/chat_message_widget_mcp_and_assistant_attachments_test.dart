import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/tts_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/features/home/services/ask_user_interaction_service.dart';
import 'package:Kelivo/features/home/services/tool_approval_service.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
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
            image.image is NetworkImage &&
            (image.image as NetworkImage).url == 'https://example.com/mcp.png',
      ),
      isTrue,
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
            image.image is NetworkImage &&
            (image.image as NetworkImage).url ==
                'https://example.com/detail.png',
      ),
      isTrue,
    );
  });

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
            image.image is NetworkImage &&
            (image.image as NetworkImage).url ==
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
        : provider is ResizeImage && provider.imageProvider is MemoryImage
        ? provider.imageProvider as MemoryImage
        : null;
    expect(memory, isA<MemoryImage>());
  });
}

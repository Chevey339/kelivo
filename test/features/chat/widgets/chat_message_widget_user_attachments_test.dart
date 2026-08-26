import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/providers/user_provider.dart';
import 'package:Kelivo/features/chat/widgets/chat_message_widget.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppSnackBarOverlay(child: child!),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSnackBarManager().dismissAll();
  });

  tearDown(() {
    AppSnackBarManager().dismissAll();
  });

  testWidgets('用户消息附件显示在文本气泡上方且不在气泡内部', (tester) async {
    const messageId = 'user-with-attachments';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-user-attachments',
            parts: const [
              TextPart('请看这个'),
              ImagePart(uri: 'missing-user-image.png'),
              FilePart(
                uri: '/tmp/spec.pdf',
                name: 'spec.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ),
      ),
    );

    final bubbleFinder = find.byKey(
      const ValueKey('user-message-text-bubble:$messageId'),
    );
    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );

    expect(bubbleFinder, findsOneWidget);
    expect(attachmentsFinder, findsOneWidget);
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('请看这个')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.text('spec.pdf')),
      findsNothing,
    );
    expect(
      find.descendant(of: bubbleFinder, matching: find.byType(Image)),
      findsNothing,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.text('spec.pdf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(InkWell)),
      findsNothing,
    );

    final attachmentsRect = tester.getRect(attachmentsFinder);
    final bubbleRect = tester.getRect(bubbleFinder);
    expect(attachmentsRect.bottom, lessThanOrEqualTo(bubbleRect.top));
  });

  testWidgets('TextPart 中的字面量附件标记按纯文本显示且不生成附件', (tester) async {
    const messageId = 'user-literal-markers';
    const literal =
        '请看这个\n[image:missing-user-image.png]\n[file:/tmp/spec.pdf|spec.pdf|application/pdf]';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-literal-markers',
            parts: const [TextPart(literal)],
          ),
        ),
      ),
    );

    expect(
      find.byKey(ValueKey('user-message-attachments:$messageId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('user-message-text-bubble:$messageId')),
      findsOneWidget,
    );
    expect(
      find.textContaining('[image:missing-user-image.png]'),
      findsOneWidget,
    );
    expect(
      find.textContaining('[file:/tmp/spec.pdf|spec.pdf|application/pdf]'),
      findsOneWidget,
    );
  });

  testWidgets('unavailable ImagePart 显示占位而不是可查看图片', (tester) async {
    const messageId = 'user-unavailable-image';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-unavailable-image',
            parts: const [
              TextPart('图挂了'),
              ImagePart(uri: '/tmp/gone.png', unavailable: true),
            ],
          ),
        ),
      ),
    );

    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );
    expect(attachmentsFinder, findsOneWidget);
    expect(
      find.descendant(of: attachmentsFinder, matching: find.byType(Image)),
      findsNothing,
    );
  });

  testWidgets('MalformedPart 显示附件不可用占位', (tester) async {
    const messageId = 'user-malformed-attachments';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-malformed-attachments',
            parts: const [
              TextPart('附件损坏'),
              MalformedPart(
                rawKind: 'image',
                rawPayload: '{',
                parseError: 'invalid image payload JSON',
              ),
              MalformedPart(
                rawKind: 'file',
                rawPayload: '{}',
                parseError: 'file payload requires non-empty uri',
              ),
            ],
          ),
        ),
      ),
    );

    final attachmentsFinder = find.byKey(
      const ValueKey('user-message-attachments:$messageId'),
    );
    expect(attachmentsFinder, findsOneWidget);
    expect(
      find.descendant(
        of: attachmentsFinder,
        matching: find.text('Attachment unavailable'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-message-attachment:$messageId:1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('user-message-attachment:$messageId:2')),
      findsOneWidget,
    );
  });

  testWidgets('FilePart 在 ImagePart 之前时保持 parts 序号顺序', (tester) async {
    const messageId = 'user-file-before-image';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-file-before-image',
            parts: const [
              TextPart('顺序'),
              FilePart(
                uri: '/tmp/first.pdf',
                name: 'first.pdf',
                mime: 'application/pdf',
              ),
              ImagePart(uri: 'https://example.com/second.png'),
            ],
          ),
        ),
      ),
    );

    final fileFinder = find.byKey(
      const ValueKey('user-message-attachment:$messageId:1'),
    );
    final imageFinder = find.byKey(
      const ValueKey('user-message-attachment:$messageId:2'),
    );
    expect(fileFinder, findsOneWidget);
    expect(imageFinder, findsOneWidget);
    expect(
      tester.getRect(fileFinder).left,
      lessThan(tester.getRect(imageFinder).left),
    );
    expect(
      find.descendant(of: fileFinder, matching: find.text('first.pdf')),
      findsOneWidget,
    );

    final image = tester.widget<Image>(
      find.descendant(of: imageFinder, matching: find.byType(Image)),
    );
    final provider = image.image;
    final network = provider is NetworkImage
        ? provider
        : provider is SafeResizeImage && provider.imageProvider is NetworkImage
        ? provider.imageProvider as NetworkImage
        : null;
    expect(network, isA<NetworkImage>());
    expect(network!.url, 'https://example.com/second.png');
  });

  testWidgets('http ImagePart 使用 Image.network 而不是 Image.file', (tester) async {
    const messageId = 'user-http-image';

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-http-image',
            parts: const [
              TextPart('远程图'),
              ImagePart(uri: 'https://cdn.example.com/a.png'),
            ],
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    final inner = provider is SafeResizeImage ? provider.imageProvider : provider;
    expect(inner, isA<NetworkImage>());
    expect(inner, isNot(isA<FileImage>()));
  });

  testWidgets('tapping https FilePart launches external URL', (tester) async {
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(launcherChannel, (call) async {
          if (call.method == 'launch') {
            launchedUrl = (call.arguments as Map)['url'] as String?;
            return true;
          }
          return false;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(launcherChannel, null);
    });

    const messageId = 'user-https-file';
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-https-file',
            parts: const [
              TextPart('远程文件'),
              FilePart(
                uri: 'https://example.com/doc.pdf',
                name: 'doc.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('user-message-attachment:$messageId:1')),
    );
    await tester.pumpAndSettle();

    expect(launchedUrl, 'https://example.com/doc.pdf');
    expect(find.textContaining('File not found'), findsNothing);
    expect(find.textContaining('文件不存在'), findsNothing);
  });

  testWidgets('tapping data: FilePart shows unsupported snackbar', (
    tester,
  ) async {
    const messageId = 'user-data-file';
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: messageId,
            role: 'user',
            conversationId: 'conversation-data-file',
            parts: const [
              TextPart('data文件'),
              FilePart(
                uri: 'data:application/pdf;base64,AAAA',
                name: 'inline.pdf',
                mime: 'application/pdf',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('user-message-attachment:$messageId:1')),
    );
    await tester.pump(); // show snackbar without waiting for auto-dismiss timer

    expect(
      find.textContaining('Cannot open file: unsupported data URI'),
      findsOneWidget,
    );
    expect(find.textContaining('File not found'), findsNothing);
    expect(find.textContaining('文件不存在'), findsNothing);

    // Drain snackbar auto-dismiss timer so the test binding stays clean.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('user attachment thumbs decode with cover and no upscaling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: 'user-cover-thumb',
            role: 'user',
            conversationId: 'conversation-cover-thumb',
            parts: const [
              TextPart('图'),
              ImagePart(uri: 'https://example.com/wide.png'),
            ],
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(image.image, isA<SafeResizeImage>());
    final resized = image.image as SafeResizeImage;
    expect(resized.fit, SafeResizeFit.cover);
    expect(resized.allowUpscaling, isFalse);
    expect(resized.width, 336);
    expect(resized.height, 336);
    expect(
      resized.width * resized.height,
      lessThanOrEqualTo(kToolImageMaxDecodePixels),
    );
  });
}

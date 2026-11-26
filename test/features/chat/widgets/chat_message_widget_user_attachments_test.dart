import 'dart:convert';

import "../../../support/business_test_harness.dart";
import 'package:Kelivo/features/chat/pages/image_viewer_page.dart';
import 'package:Kelivo/core/models/chat_message.dart';
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
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
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/fake_audioplayers_platform.dart';
import '../../../support/markdown_render_helpers.dart';

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

  testWidgets(
    'a landscape attachment lands at its final bounds on the first viewer frame',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bytes = img.encodeJpg(img.Image(width: 200, height: 100));
      final source = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await tester.pumpWidget(
        _harness(
          ChatMessageWidget(
            showUserAvatar: false,
            message: ChatMessage(
              id: 'flight',
              role: 'user',
              conversationId: 'c',
              parts: [
                ImagePart(uri: source),
                ImagePart(uri: source),
              ],
            ),
          ),
        ),
      );
      final tile = find.byKey(
        const ValueKey('user-message-attachment:flight:1'),
      );
      final pixels = find.descendant(of: tile, matching: find.byType(RawImage));
      for (
        var i = 0;
        i < 50 && tester.widget<RawImage>(pixels).image == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(tester.widget<RawImage>(pixels).image, isNotNull);
      final start = tester.getRect(tile);
      await tester.tap(tile);
      await tester.pump();
      final destination = find.descendant(
        of: find.byType(ImageViewerPage, skipOffstage: false),
        matching: find.byType(Hero, skipOffstage: false),
        skipOffstage: false,
      );
      const expanded = Rect.fromLTWH(0, 324.5, 390, 195);
      expect(
        tester
            .widget<ImageViewerPage>(
              find.byType(ImageViewerPage, skipOffstage: false),
            )
            .initialIndex,
        1,
      );
      expect(tester.getRect(destination), expanded);
      // Sample the overlay that is actually painted during the flight.
      final flightPixels = find.byWidgetPredicate(
        (widget) => widget is RawImage && widget.fit == BoxFit.cover,
      );
      var previous = start;
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        final shuttle = find
            .ancestor(of: flightPixels, matching: find.byType(ClipRRect))
            .evaluate()
            .where(
              (element) =>
                  element.findAncestorWidgetOfExactType<ChatMessageWidget>() ==
                      null &&
                  element.findAncestorWidgetOfExactType<ImageViewerPage>() ==
                      null,
            )
            .single;
        final box = shuttle.findRenderObject()! as RenderBox;
        final rect = box.localToGlobal(Offset.zero) & box.size;
        expect(
          rect.width,
          inInclusiveRange(previous.width - .01, expanded.width + .01),
        );
        expect(
          rect.center.dy,
          inInclusiveRange(previous.center.dy - .01, expanded.center.dy + .01),
        );
        previous = rect;
      }
      await tester.pumpAndSettle();
      expect(tester.getRect(destination), expanded);
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();
      expect(tester.getRect(tile), start);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local audio attachments render as playable clips', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        ChatMessageWidget(
          showUserAvatar: false,
          message: ChatMessage(
            id: 'user-with-audio',
            role: 'user',
            conversationId: 'conversation-user-audio',
            parts: const [
              FilePart(
                uri: '/tmp/voice_20260929_120000.wav',
                name: 'voice_20260929_120000.wav',
                mime: 'audio/wav',
              ),
              FilePart(
                uri: 'https://example.com/remote.mp3',
                name: 'remote.mp3',
                mime: 'audio/mpeg',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byTooltip('Play audio'), findsOneWidget);
    expect(find.text('voice_20260929_120000.wav'), findsOneWidget);
    expect(find.text('remote.mp3'), findsOneWidget);
  });

  testWidgets('a playing audio clip fits a narrow message column', (
    tester,
  ) async {
    final previous = AudioplayersPlatformInterface.instance;
    final previousGlobal = GlobalAudioplayersPlatformInterface.instance;
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
    addTearDown(() {
      AudioplayersPlatformInterface.instance = previous;
      GlobalAudioplayersPlatformInterface.instance = previousGlobal;
    });
    const name = 'voice_20260929_120000_with_a_rather_long_name.wav';

    await tester.pumpWidget(
      _harness(
        Center(
          child: SizedBox(
            width: 320,
            child: ChatMessageWidget(
              showUserAvatar: false,
              message: ChatMessage(
                id: 'user-with-long-audio',
                role: 'user',
                conversationId: 'conversation-user-audio',
                parts: const [
                  FilePart(uri: '/tmp/$name', name: name, mime: 'audio/wav'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Play audio'));
    final time = find.text('0:00 / 0:12');
    // The fake player resolves over several microtask hops.
    for (var i = 0; i < 50 && time.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(time, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
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
      renderParagraphs(
        bubbleFinder,
      ).map((paragraph) => paragraph.text.toPlainText()),
      contains('请看这个'),
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
      markdownParagraph(
        tester,
        '[image:missing-user-image.png]',
      ).text.toPlainText(),
      literal,
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
    final inner = provider is SafeResizeImage
        ? provider.imageProvider
        : provider;
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

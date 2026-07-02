import 'package:Cuplivo/core/models/chat_input_data.dart';
import 'package:Cuplivo/core/providers/assistant_provider.dart';
import 'package:Cuplivo/core/providers/settings_provider.dart';
import 'package:Cuplivo/features/home/widgets/chat_input_bar.dart';
import 'package:Cuplivo/icons/lucide_adapter.dart';
import 'package:Cuplivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness({
    required TextEditingController controller,
    required FocusNode focusNode,
    required Future<ChatInputSubmissionResult> Function(ChatInputData input)
    onSend,
    SettingsProvider? settingsProvider,
    AssistantProvider? assistantProvider,
    ChatInputBarController? mediaController,
    bool loading = false,
    bool hasQueuedInput = false,
    String? queuedPreviewText,
    VoidCallback? onCancelQueuedInput,
    String? conversationId,
    String? sendButtonTooltip,
    ThemeData? theme,
    bool backgroundImageActive = false,
    double inputBackgroundOpacityLight = 0.8236,
    double inputBackgroundOpacityDark = 0.7396,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: settingsProvider ?? SettingsProvider(),
        ),
        ChangeNotifierProvider.value(
          value: assistantProvider ?? AssistantProvider(),
        ),
      ],
      child: MaterialApp(
        theme: theme,
        darkTheme: theme,
        themeMode: theme?.brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            mediaController: mediaController,
            onSend: onSend,
            loading: loading,
            hasQueuedInput: hasQueuedInput,
            queuedPreviewText: queuedPreviewText,
            onCancelQueuedInput: onCancelQueuedInput,
            conversationId: conversationId,
            sendButtonTooltip: sendButtonTooltip,
            backgroundImageActive: backgroundImageActive,
            inputBackgroundOpacityLight: inputBackgroundOpacityLight,
            inputBackgroundOpacityDark: inputBackgroundOpacityDark,
          ),
        ),
      ),
    );
  }

  testWidgets('提交结果 queued 时会清空输入', (tester) async {
    final controller = TextEditingController(text: 'queued message');
    final focusNode = FocusNode();
    ChatInputData? submitted;

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        onSend: (input) async {
          submitted = input;
          return ChatInputSubmissionResult.queued;
        },
      ),
    );

    await tapSendButton(tester);

    expect(submitted?.text, 'queued message');
    expect(controller.text, isEmpty);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('提交结果 rejected 时保留输入内容', (tester) async {
    final controller = TextEditingController(text: 'keep me');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    await tapSendButton(tester);

    expect(controller.text, 'keep me');

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('发送按钮可显示编辑态保存并发送提示', (tester) async {
    final controller = TextEditingController(text: 'edited message');
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        sendButtonTooltip: 'Save & Send',
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    expect(find.byTooltip('Save & Send'), findsOneWidget);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('有排队项时显示状态并允许取消', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    var cancelled = false;
    const preview = '第一行\n第二行\n第三行\n第四行';

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        hasQueuedInput: true,
        queuedPreviewText: preview,
        onCancelQueuedInput: () {
          cancelled = true;
        },
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.readOnly, isTrue);
    expect(find.text('Queued to send'), findsOneWidget);
    expect(find.text('Cancel Queue'), findsOneWidget);
    expect(find.text(preview), findsOneWidget);

    final previewText = tester.widget<Text>(find.text(preview));
    expect(previewText.maxLines, 3);
    expect(previewText.overflow, TextOverflow.ellipsis);

    await tester.tap(find.text('Cancel Queue'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('绘图模式胶囊可关闭并传递聊天接口路由', (tester) async {
    final controller = TextEditingController(text: 'draw a cat');
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();
    final settings = SettingsProvider();
    await settings.setProviderConfig(
      'OpenAITest',
      ProviderConfig(
        id: 'OpenAITest',
        enabled: true,
        name: 'OpenAITest',
        apiKey: 'test-key',
        baseUrl: 'https://example.com/v1',
        providerType: ProviderKind.openai,
      ),
    );
    await settings.setCurrentModel('OpenAITest', 'gpt-image-2');
    ChatInputData? submitted;

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        settingsProvider: settings,
        onSend: (input) async {
          submitted = input;
          return ChatInputSubmissionResult.rejected;
        },
      ),
    );

    expect(find.text('Image mode'), findsOneWidget);

    await tester.tap(find.byIcon(Lucide.X));
    await tester.pumpAndSettle();

    expect(find.text('Image mode'), findsNothing);
    expect(mediaController.allowImagesApiRouting, isFalse);

    await tapSendButton(tester);

    expect(submitted?.text, 'draw a cat');
    expect(submitted?.allowImagesApiRouting, isFalse);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('绘图模式关闭后切换对话会重新显示', (tester) async {
    final controller = TextEditingController(text: 'draw a cat');
    final focusNode = FocusNode();
    final settings = SettingsProvider();
    await settings.setProviderConfig(
      'OpenAITest',
      ProviderConfig(
        id: 'OpenAITest',
        enabled: true,
        name: 'OpenAITest',
        apiKey: 'test-key',
        baseUrl: 'https://example.com/v1',
        providerType: ProviderKind.openai,
      ),
    );
    await settings.setCurrentModel('OpenAITest', 'gpt-image-2');

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        settingsProvider: settings,
        conversationId: 'conversation-a',
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    expect(find.text('Image mode'), findsOneWidget);

    await tester.tap(find.byIcon(Lucide.X));
    await tester.pumpAndSettle();

    expect(find.text('Image mode'), findsNothing);

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        settingsProvider: settings,
        conversationId: 'conversation-b',
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Image mode'), findsOneWidget);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('非绘图模型保持默认路由许可', (tester) async {
    final controller = TextEditingController(text: 'hello');
    final focusNode = FocusNode();
    ChatInputData? submitted;

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        onSend: (input) async {
          submitted = input;
          return ChatInputSubmissionResult.rejected;
        },
      ),
    );

    expect(find.text('Image mode'), findsNothing);

    await tapSendButton(tester);

    expect(submitted?.allowImagesApiRouting, isTrue);

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入框在亮色主题下有稳定底色', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        theme: ThemeData.light(),
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final decoration = _mainInputDecoration(tester);
    expect(decoration.color?.a, greaterThanOrEqualTo(0.70));

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入框在暗色主题下不是纯透明毛玻璃', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        theme: ThemeData.dark(),
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final decoration = _mainInputDecoration(tester);
    expect(decoration.color?.a, greaterThanOrEqualTo(0.60));

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入框在背景图模式下降低纯色覆盖', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        theme: ThemeData.light(),
        backgroundImageActive: true,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final decoration = _mainInputDecoration(tester);
    expect(decoration.color?.a, inExclusiveRange(0.35, 0.70));

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入框背景透明度按当前主题选择实际 alpha', (tester) async {
    final lightController = TextEditingController();
    final lightFocusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: lightController,
        focusNode: lightFocusNode,
        theme: ThemeData.light(),
        inputBackgroundOpacityLight: 0.35,
        inputBackgroundOpacityDark: 0.75,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final light = _mainInputDecoration(tester).color;
    expect(light?.a, closeTo(0.35, 0.0001));

    await tester.pumpWidget(const SizedBox.shrink());

    lightController.dispose();
    lightFocusNode.dispose();

    final darkController = TextEditingController();
    final darkFocusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: darkController,
        focusNode: darkFocusNode,
        theme: ThemeData.dark(),
        inputBackgroundOpacityLight: 0.35,
        inputBackgroundOpacityDark: 0.75,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final dark = _mainInputDecoration(tester).color;
    expect(dark?.a, closeTo(0.75, 0.0001));

    darkController.dispose();
    darkFocusNode.dispose();
  });

  testWidgets('背景图模式同样遵循输入框背景透明度设置', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        theme: ThemeData.dark(),
        backgroundImageActive: true,
        inputBackgroundOpacityDark: 0.7396,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    final decoration = _mainInputDecoration(tester);
    expect(decoration.color?.a, closeTo(0.545, 0.0001));

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('图片和文件预览显示在主输入框内部顶部', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final mediaController = ChatInputBarController();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        mediaController: mediaController,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    mediaController
      ..addFiles(const [
        DocumentAttachment(
          path: '/tmp/draft.pdf',
          fileName: 'draft.pdf',
          mime: 'application/pdf',
        ),
      ])
      ..addImages(['missing-draft-image.png']);
    await tester.pump();

    final surfaceFinder = _mainInputSurfaceFinder();
    expect(surfaceFinder, findsOneWidget);
    expect(
      find.descendant(of: surfaceFinder, matching: find.text('draft.pdf')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: surfaceFinder, matching: find.byType(Image)),
      findsOneWidget,
    );
    final imagePreviewsFinder = find.byKey(
      const ValueKey('chat-input-image-previews'),
    );
    final documentPreviewsFinder = find.byKey(
      const ValueKey('chat-input-document-previews'),
    );
    expect(imagePreviewsFinder, findsOneWidget);
    expect(documentPreviewsFinder, findsOneWidget);

    final imagePreviewsRect = tester.getRect(imagePreviewsFinder);
    final documentPreviewsRect = tester.getRect(documentPreviewsFinder);
    expect(
      imagePreviewsRect.bottom,
      lessThanOrEqualTo(documentPreviewsRect.top),
    );

    final imageRect = tester.getRect(find.byType(Image));
    final removeButtonRect = tester.getRect(
      find.byKey(const ValueKey('chat-input-image-remove:0')),
    );
    expect(imageRect.contains(removeButtonRect.topLeft), isTrue);
    expect(imageRect.contains(removeButtonRect.bottomRight), isTrue);
    expect(removeButtonRect.width, lessThan(22));
    expect(removeButtonRect.height, lessThan(22));
    expect(
      find.descendant(of: imagePreviewsFinder, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: documentPreviewsFinder,
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    controller.dispose();
    focusNode.dispose();
  });

  testWidgets('输入框外层底部留白只下移一点', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      buildHarness(
        controller: controller,
        focusNode: focusNode,
        onSend: (_) async => ChatInputSubmissionResult.rejected,
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Padding &&
            widget.padding == const EdgeInsets.fromLTRB(12, 4, 12, 8),
      ),
      findsOneWidget,
    );

    controller.dispose();
    focusNode.dispose();
  });
}

Future<void> tapSendButton(WidgetTester tester) async {
  await tester.tap(find.byIcon(Lucide.ArrowUp));
  await tester.pumpAndSettle();
}

Finder _mainInputSurfaceFinder() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).borderRadius ==
            BorderRadius.circular(20),
  );
}

BoxDecoration _mainInputDecoration(WidgetTester tester) {
  final candidates = tester
      .widgetList<Container>(_mainInputSurfaceFinder())
      .map((widget) => widget.decoration)
      .whereType<BoxDecoration>()
      .toList();

  expect(candidates, hasLength(1));
  return candidates.single;
}

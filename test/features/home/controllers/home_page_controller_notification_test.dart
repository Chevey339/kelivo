import '../../../support/business_test_harness.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/core/services/notification_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'dispatches a completion notification from the success callback',
    (tester) async {
      final settings = SettingsProvider(createBusinessTestPreferences());
      final notifications = <Map<String, String?>>[];
      HomePageController? controller;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider(create: (_) => ChatService()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _ControllerHarness(
              onCreated: (value) => controller = value,
              notificationSender:
                  ({required conversationId, title, body}) async {
                    notifications.add({
                      'conversationId': conversationId,
                      'title': title,
                      'body': body,
                    });
                  },
            ),
          ),
        ),
      );

      controller!.onAppLifecycleStateChanged(AppLifecycleState.paused);
      controller!.debugHandleAssistantMessageFinished(
        ChatMessage(
          role: 'assistant',
          content: 'done',
          conversationId: 'conversation-1',
        ),
      );
      await tester.pump();
      expect(notifications, isEmpty);

      await settings.setAndroidBackgroundChatMode(
        AndroidBackgroundChatMode.onNotify,
      );
      controller!.debugHandleAssistantMessageFinished(
        ChatMessage(
          role: 'user',
          content: 'not a completion',
          conversationId: 'conversation-1',
        ),
      );
      controller!.debugHandleAssistantMessageFinished(
        ChatMessage(
          role: 'assistant',
          content: 'done',
          conversationId: 'conversation-1',
        ),
      );
      await tester.pump();

      expect(notifications, [
        {
          'conversationId': 'conversation-1',
          'title': 'Generation complete',
          'body': 'Assistant reply has been generated',
        },
      ]);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({
    required this.onCreated,
    required this.notificationSender,
  });

  final ValueChanged<HomePageController> onCreated;
  final ChatCompletionNotificationSender notificationSender;

  @override
  State<_ControllerHarness> createState() => _ControllerHarnessState();
}

class _ControllerHarnessState extends State<_ControllerHarness>
    with TickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _inputBarKey = GlobalKey();
  final _inputFocus = FocusNode();
  final _inputController = TextEditingController();
  final _mediaController = ChatInputBarController();
  final _scrollController = ChatAutoFollowScrollController();
  late final HomePageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomePageController(
      context: context,
      vsync: this,
      scaffoldKey: _scaffoldKey,
      inputBarKey: _inputBarKey,
      inputFocus: _inputFocus,
      inputController: _inputController,
      mediaController: _mediaController,
      scrollController: _scrollController,
      isAndroidOverride: true,
      chatCompletionNotificationSender: widget.notificationSender,
    );
    widget.onCreated(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(key: _scaffoldKey);
}

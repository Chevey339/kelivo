import "../../../support/business_test_harness.dart";
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/controllers/scroll_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _RecordingChatService extends ChatService {
  final List<String> timelineCalls = <String>[];
  void Function()? onFirstTimelineCall;

  @override
  Future<LoadedTimelinePage?> loadTimelinePage(
    String conversationId, {
    String? beforeRevisionId,
    String? afterRevisionId,
    String? aroundRevisionId,
    bool fromStart = false,
    int limit = 40,
  }) async {
    timelineCalls.add(conversationId);
    final hook = onFirstTimelineCall;
    if (hook != null) {
      onFirstTimelineCall = null;
      hook();
    }
    return null;
  }
}

void main() {
  testWidgets('startup warm-up loads each queued conversation serially', (
    tester,
  ) async {
    final service = _RecordingChatService();
    HomePageController? controller;
    await tester.pumpWidget(_buildHarness(service, (c) => controller = c));

    await controller!.warmUpRecentConversations(const [
      'a',
      'b',
      'c',
    ], controller!.debugWarmupSerial);

    expect(service.timelineCalls, orderedEquals(['a', 'b', 'c']));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('startup warm-up abandons the queue after a user operation', (
    tester,
  ) async {
    final service = _RecordingChatService();
    HomePageController? controller;
    await tester.pumpWidget(_buildHarness(service, (c) => controller = c));

    service.onFirstTimelineCall = () => controller!.debugAbandonStartupWarmup();
    await controller!.warmUpRecentConversations(const [
      'a',
      'b',
      'c',
    ], controller!.debugWarmupSerial);

    expect(service.timelineCalls, orderedEquals(['a']));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('user operations bump the warm-up serial', (tester) async {
    final service = _RecordingChatService();
    HomePageController? controller;
    await tester.pumpWidget(_buildHarness(service, (c) => controller = c));

    final initial = controller!.debugWarmupSerial;
    // Pagination is a user operation competing for the single connection.
    await controller!.loadMoreBefore();
    await controller!.loadMoreAfter();

    expect(controller!.debugWarmupSerial, greaterThan(initial + 1));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _buildHarness(
  ChatService chatService,
  ValueChanged<HomePageController> onCreated,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => SettingsProvider(createBusinessTestPreferences()),
      ),
      ChangeNotifierProvider<ChatService>.value(value: chatService),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _ControllerHarness(onCreated: onCreated),
    ),
  );
}

class _ControllerHarness extends StatefulWidget {
  const _ControllerHarness({required this.onCreated});

  final ValueChanged<HomePageController> onCreated;

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

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

void main() {
  testWidgets('inserts a selected message quote into the current draft', (
    tester,
  ) async {
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => ChatService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );

    controller!.inputController.value = const TextEditingValue(
      text: 'Follow up',
      selection: TextSelection.collapsed(offset: 9),
    );
    controller!.insertQuotedSelection('first line\nsecond line');

    expect(
      controller!.inputController.text,
      'Follow up\n\n> first line\n> second line\n\n',
    );
    expect(
      controller!.inputController.selection.baseOffset,
      controller!.inputController.text.length,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('initializes chat controller before timeline scroll callbacks', (
    tester,
  ) async {
    HomePageController? controller;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SettingsProvider(createBusinessTestPreferences()),
          ),
          ChangeNotifierProvider(create: (_) => ChatService()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _ControllerHarness(onCreated: (value) => controller = value),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(controller, isNotNull);
    expect(
      controller!.scrollCtrl.scrollController,
      same(controller!.scrollController),
    );

    final replacement = ChatAutoFollowScrollController();
    controller!.replaceScrollController(replacement);
    expect(controller!.scrollController, same(replacement));
    expect(controller!.scrollCtrl.scrollController, same(replacement));

    controller!.scrollCtrl.handleUserScrollIntent();
    expect(controller!.scrollCtrl.isUserScrolling, isTrue);
    await controller!.forceScrollToBottom(animate: false);
    expect(controller!.scrollCtrl.isUserScrolling, isFalse);
    expect(controller!.scrollCtrl.autoStickToBottom, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    replacement.dispose();
  });
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

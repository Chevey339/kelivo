import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/home_page_controller.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('滚动 UI 状态变化不触发 HomePage 页面级通知', (tester) async {
    SharedPreferences.setMockInitialValues({});

    late HomePageController controller;
    final scaffoldKey = GlobalKey<ScaffoldState>();
    final inputBarKey = GlobalKey();
    final inputFocus = FocusNode();
    final inputController = TextEditingController();
    final mediaController = ChatInputBarController();
    var pageNotifyCount = 0;
    var scrollUiNotifyCount = 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => ChatService()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              controller = HomePageController(
                context: context,
                vsync: tester,
                scaffoldKey: scaffoldKey,
                inputBarKey: inputBarKey,
                inputFocus: inputFocus,
                inputController: inputController,
                mediaController: mediaController,
              );
              controller.addListener(() {
                pageNotifyCount++;
              });
              controller.scrollUiState.addListener(() {
                scrollUiNotifyCount++;
              });
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      ),
    );
    addTearDown(() {
      controller.dispose();
      inputFocus.dispose();
      inputController.dispose();
    });

    controller.scrollCtrl.revealNavButtons();

    expect(scrollUiNotifyCount, 1);
    expect(pageNotifyCount, 0);

    controller.scrollCtrl.hideNavButtons();

    expect(scrollUiNotifyCount, 2);
    expect(pageNotifyCount, 0);

    controller.notifyListeners();

    expect(pageNotifyCount, 1);
  });
}

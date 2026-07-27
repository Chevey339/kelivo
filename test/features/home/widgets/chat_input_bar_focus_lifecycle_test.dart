import 'package:Kelivo/core/models/chat_input_data.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/widgets/chat_input_bar.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/business_test_harness.dart';

void _pauseApp(TestWidgetsFlutterBinding binding) {
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void _beginResumeApp(TestWidgetsFlutterBinding binding) {
  binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
}

void _finishResumeApp(TestWidgetsFlutterBinding binding) {
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void _restoreResumedApp(TestWidgetsFlutterBinding binding) {
  switch (binding.lifecycleState) {
    case AppLifecycleState.resumed:
      return;
    case AppLifecycleState.paused:
      _beginResumeApp(binding);
      _finishResumeApp(binding);
      return;
    case AppLifecycleState.hidden:
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      _finishResumeApp(binding);
      return;
    case AppLifecycleState.inactive:
    case AppLifecycleState.detached:
    case null:
      _finishResumeApp(binding);
      return;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildHarness({
    required TextEditingController controller,
    required FocusNode focusNode,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(createBusinessTestPreferences()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              AssistantProvider(preferences: createBusinessTestPreferences()),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInputBar(
            controller: controller,
            focusNode: focusNode,
            onSend: (_) async => ChatInputSubmissionResult.rejected,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'resume must preserve focus acquired during lifecycle transition',
    (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(() {
        _restoreResumedApp(tester.binding);
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        buildHarness(controller: controller, focusNode: focusNode),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      tester.testTextInput.closeConnection();
      await tester.pump();

      _pauseApp(tester.binding);
      _beginResumeApp(tester.binding);
      await tester.pump();

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);

      _finishResumeApp(tester.binding);
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.hasAnyClients, isTrue);
    },
  );

  testWidgets(
    'a stale resume timer must not re-enable menus after pausing again',
    (tester) async {
      final controller = TextEditingController(text: 'draft');
      final focusNode = FocusNode();
      addTearDown(() {
        _restoreResumedApp(tester.binding);
        controller.dispose();
        focusNode.dispose();
      });

      await tester.pumpWidget(
        buildHarness(
          controller: controller,
          focusNode: focusNode,
          platform: TargetPlatform.iOS,
        ),
      );

      var contextMenuRemoved = false;
      final contextMenuController = ContextMenuController(
        onRemove: () => contextMenuRemoved = true,
      );
      contextMenuController.show(
        context: tester.element(find.byType(ChatInputBar)),
        contextMenuBuilder: (_) => const SizedBox(width: 1, height: 1),
      );
      await tester.pump();
      expect(contextMenuController.isShown, isTrue);

      _pauseApp(tester.binding);
      await tester.pump();
      expect(contextMenuController.isShown, isFalse);
      expect(contextMenuRemoved, isTrue);

      _beginResumeApp(tester.binding);
      _finishResumeApp(tester.binding);
      _pauseApp(tester.binding);
      await tester.pump(const Duration(milliseconds: 301));

      final textField = tester.widget<TextField>(find.byType(TextField));
      final editableState = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final contextMenu = textField.contextMenuBuilder!(
        editableState.context,
        editableState,
      );

      expect(contextMenu, isA<SizedBox>());
    },
  );
}

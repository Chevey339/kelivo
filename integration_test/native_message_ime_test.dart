import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/features/chat/pages/message_edit_page.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/text_input/message_editing_controller.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run with tool/run_native_ime_integration.py on the isolated Android AVD.
// The separate driver APK touches real Gboard; no text-input mock or production
// probe channel is installed. Clipboard contents are this synthetic fixture.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('production Android document and Gboard integration', (
    tester,
  ) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toString();
    final driver = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => driver.close(force: true));
    final completedActions = <String, Completer<void>>{};
    driver.listen((request) async {
      final path = request.uri.pathSegments;
      final completed =
          request.method == 'POST' && path.length == 2 && path.first == runId
          ? completedActions.remove(path.last)
          : null;
      request.response.statusCode = completed == null ? 404 : 204;
      await request.response.close();
      completed?.complete();
    });
    final results = <Map<String, Object?>>[];
    final source = ('${'中文 mixed text 0123456789 ' * 9}\n' * 100).substring(
      0,
      10000,
    );

    Widget nativeTestSurface(BuildContext context, Widget? child) => MediaQuery(
      // UiAutomation enables Android accessibility while locating Gboard keys.
      // Pin only this fixture's renderer so the test cannot silently validate
      // the stock TextField fallback instead of the native document bridge.
      data: MediaQuery.of(context).copyWith(accessibleNavigation: false),
      child: child!,
    );

    Future<void> ready(String name, String actions, {int delay = 150}) async {
      final completed = Completer<void>();
      completedActions[name] = completed;
      // ignore: avoid_print
      print(
        'NATIVE_IME_READY ${jsonEncode({'runId': runId, 'case': name, 'actions': actions, 'delay': delay, 'port': driver.port})}',
      );
      // The expected final text can also occur midway through typing/deleting.
      // Do not retire this document until every requested UI action has ended.
      await completed.future.timeout(const Duration(seconds: 60));
    }

    Future<void> until(bool Function() condition, String label) async {
      final limit = DateTime.now().add(const Duration(seconds: 45));
      while (!condition() && DateTime.now().isBefore(limit)) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(condition(), isTrue, reason: label);
    }

    Future<void> mount(
      MessageEditingController document,
      FocusNode focus,
    ) async {
      document.value = TextEditingValue(
        text: source,
        selection: const TextSelection.collapsed(offset: 100),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: nativeTestSurface,
          home: Scaffold(
            body: LongMessageEditor(
              key: ValueKey(document),
              controller: document,
              focusNode: focus,
              autofocus: true,
              decoration: const InputDecoration(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester
            .state<LongMessageEditorState>(find.byType(LongMessageEditor))
            .usesLineEditor,
        isTrue,
      );
      expect(document.hasNativeInput, isTrue);
    }

    void expectNative(MessageEditingController document) {
      expect(
        tester
            .state<LongMessageEditorState>(find.byType(LongMessageEditor))
            .usesLineEditor,
        isTrue,
      );
      expect(document.hasNativeInput, isTrue);
    }

    // Kelivo starts its cached engine before attaching the Android Activity.
    // Wait for that Activity's real constraints before mounting the test UI.
    await until(
      () => !tester.view.physicalSize.isEmpty,
      'Android Activity has not supplied its viewport',
    );

    const cases = <String, String>{
      'select_all': '@editing|全选',
      'select_all_delete': '@editing|全选|删除',
      'immediate_cut': '@editing|全选|剪切',
      'cut_then_type': '@editing|全选|剪切|@keyboard|n|i|你',
      'partial_delete': '@editing|打开选择模式|右移光标|右移光标|右移光标|删除',
      'cursor_roundtrip': '@editing|将光标向下移|上移光标',
      'cursor_then_type': '@editing|将光标向下移|@keyboard|n|i|你',
      'composing_all': '@keyboard|n|i|@ctrlA',
      'composing_all_cut': '@keyboard|n|i|@ctrlA|@ctrlX',
      'composing_all_delete_then_type': '@keyboard|n|i|@ctrlA|删除|n|i|你',
      'cross_paragraph': '@keyboard|n|i|你|Enter 键|n|i|你|Enter 键|n|i|你|删除|删除',
      'cross_paragraph_fast':
          '@keyboard|n|i|你|Enter 键|n|i|你|Enter 键|n|i|你|删除|删除',
    };
    for (final entry in cases.entries) {
      final document = MessageEditingController();
      final focus = FocusNode();
      await mount(document, focus);
      var composed = false;
      int? moved;
      void observe() {
        if (document.value.composing.isValid &&
            !document.value.composing.isCollapsed) {
          composed = true;
        }
        if (document.text == source &&
            document.selection.isCollapsed &&
            document.selection.extentOffset > 100) {
          moved ??= document.selection.extentOffset;
        }
      }

      document.addListener(observe);
      final name = entry.key;
      final withCandidate = source.replaceRange(100, 100, 'ni');
      String expected() => switch (name) {
        'immediate_cut' || 'composing_all_cut' || 'select_all_delete' => '',
        'cut_then_type' || 'composing_all_delete_then_type' => '你',
        'partial_delete' => source.replaceRange(100, 103, ''),
        'cursor_then_type' =>
          moved == null ? source : source.replaceRange(moved!, moved!, '你'),
        'composing_all' => withCandidate,
        'cross_paragraph' ||
        'cross_paragraph_fast' => source.replaceRange(100, 100, '你\n你\n'),
        _ => source,
      };
      bool complete() {
        if (document.text != expected()) return false;
        return switch (name) {
          'select_all' || 'composing_all' =>
            document.selection.start == 0 &&
                document.selection.end == document.text.length,
          'cursor_roundtrip' =>
            moved != null && document.selection.extentOffset == 100,
          'cursor_then_type' =>
            moved != null && document.selection.extentOffset == moved! + 1,
          _ => !name.startsWith('composing') || composed,
        };
      }

      await ready(
        name,
        entry.value,
        delay: name == 'immediate_cut' || name.endsWith('_fast') ? 0 : 150,
      );
      await until(complete, '$name did not reach its expected text/selection');
      await document.flushInput();
      expect(complete(), isTrue);
      expectNative(document);
      if (name.startsWith('composing')) expect(composed, isTrue);
      if (name.contains('cut')) {
        expect(
          (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
              (name.startsWith('composing') ? withCandidate : source),
          isTrue,
          reason: '$name clipboard complete',
        );
      }
      results.add({
        'case': name,
        'pass': true,
        'characters': document.text.length,
        'sawComposing': composed,
      });
      document.removeListener(observe);
      await document.retireInput();
      await tester.pumpWidget(const SizedBox());
      document.dispose();
      focus.dispose();
    }

    for (final restore in [false, true]) {
      final name = restore ? 'composing_app_restore' : 'composing_app_paste';
      final document = MessageEditingController();
      final focus = FocusNode();
      await mount(document, focus);
      final original = document.value;
      await ready('${name}_prefix', '@keyboard|n|i');
      await until(
        () =>
            document.value.composing.isValid &&
            document.value.composing.end - document.value.composing.start == 2,
        '$name requires an uncommitted candidate',
      );
      if (restore) {
        document.value = original;
      } else {
        await Clipboard.setData(const ClipboardData(text: 'APP'));
        await document.performCommand('paste');
      }
      await document.flushInput();
      await ready('${name}_suffix', '@keyboard|n|i|你');
      final expected = source.replaceRange(100, 100, restore ? '你' : 'niAPP你');
      await until(
        () => document.text == expected,
        '$name candidate remained stale',
      );
      expectNative(document);
      results.add({'case': name, 'pass': true});
      await document.retireInput();
      await tester.pumpWidget(const SizedBox());
      document.dispose();
      focus.dispose();
    }

    final document = MessageEditingController();
    final focus = FocusNode();
    final began = Completer<void>();
    final clipboard = Completer<String>();
    document.configureOwner(
      onCommand: (command, _) async {
        if (command != 'paste') return;
        began.complete();
        final text = await clipboard.future;
        document.value = document.value.replaced(document.selection, text);
      },
    );
    await mount(document, focus);
    await ready('paste_during_close', '@keyboard|@ctrlV');
    await until(
      () => began.isCompleted,
      'native owner paste was not delivered',
    );
    var closed = false;
    final closing = document.retireInput().then((_) => closed = true);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    expect(closed, isFalse);
    clipboard.complete('APP');
    await closing;
    expect(document.text == source.replaceRange(100, 100, 'APP'), isTrue);
    results.add({'case': 'paste_during_close', 'pass': true});
    document.dispose();
    focus.dispose();

    final historyDocument = MessageEditingController();
    final historyFocus = FocusNode();
    await mount(historyDocument, historyFocus);
    await tester.pump(const Duration(milliseconds: 600));
    historyDocument.value = historyDocument.value.replaced(
      historyDocument.selection,
      'FIRST',
    );
    await historyDocument.flushInput();
    await tester.pump(const Duration(milliseconds: 600));
    await ready('hardware_undo', '@keyboard|@ctrlZ');
    await until(() => historyDocument.text == source, 'hardware undo');
    await ready('hardware_redo', '@keyboard|@ctrlShiftZ');
    await until(
      () => historyDocument.text == source.replaceRange(100, 100, 'FIRST'),
      'hardware redo',
    );
    expectNative(historyDocument);
    results.add({'case': 'hardware_history', 'pass': true});
    await historyDocument.retireInput();
    await tester.pumpWidget(const SizedBox());
    historyDocument.dispose();
    historyFocus.dispose();

    final fallbackDocument = MessageEditingController();
    final fallbackFocus = FocusNode();
    await mount(fallbackDocument, fallbackFocus);
    fallbackDocument.value = fallbackDocument.value.replaced(
      fallbackDocument.selection,
      '\r\n',
    );
    await until(
      () =>
          !fallbackDocument.isInputPaused &&
          find.byType(TextField).evaluate().isNotEmpty,
      'CRLF document must hand off to TextField',
    );
    await ready('fallback_typing', '@keyboard|n|i|你');
    await until(
      () => fallbackDocument.text == source.replaceRange(100, 100, '\r\n你'),
      'Gboard input after renderer handoff',
    );
    results.add({'case': 'fallback_typing', 'pass': true});
    await fallbackDocument.retireInput();
    await tester.pumpWidget(const SizedBox());
    fallbackDocument.dispose();
    fallbackFocus.dispose();

    final navigation = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        builder: nativeTestSurface,
        navigatorKey: navigation,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    );
    final saved = navigation.currentState!.push<String>(
      MaterialPageRoute(
        builder: (_) => MessageEditPage(
          message: ChatMessage(
            id: 'native-edit',
            role: 'user',
            conversationId: 'native-edit',
            content: source,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    final pageDocument =
        tester
                .widget<LongMessageEditor>(find.byType(LongMessageEditor))
                .controller
            as MessageEditingController;
    expectNative(pageDocument);
    pageDocument.selection = const TextSelection.collapsed(offset: 100);
    await pageDocument.flushInput();
    await Clipboard.setData(const ClipboardData(text: 'APP'));
    final pagePaste = pageDocument.performCommand('paste');
    await tester.tap(find.text('Save'));
    await pagePaste;
    expect(await saved, source.replaceRange(100, 100, 'APP').trim());
    results.add({'case': 'edit_page_save_during_paste', 'pass': true});
    await tester.pump(const Duration(seconds: 1));
    binding.reportData = {'runId': runId, 'cases': results};
    for (final result in results) {
      // Each record stays below Android's log-line limit.
      // ignore: avoid_print
      print('NATIVE_IME_CASE ${jsonEncode({'runId': runId, ...result})}');
    }
    // ignore: avoid_print
    print(
      'NATIVE_IME_RESULT ${jsonEncode({'runId': runId, 'cases': results.length})}',
    );
  }, timeout: const Timeout(Duration(minutes: 12)));
}

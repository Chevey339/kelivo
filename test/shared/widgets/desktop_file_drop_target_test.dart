import 'package:Kelivo/shared/widgets/desktop_file_drop_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a native file drop reaches only the exposed desktop draft', (
    tester,
  ) async {
    const codec = StandardMethodCodec();
    final chat = <String>[], references = <String>[];
    final active = ValueNotifier(1);
    final menu = ValueNotifier(false);
    final navigator = GlobalKey<NavigatorState>();
    Future<void> native(String method, Object data) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'desktop_drop',
        codec.encodeMethodCall(MethodCall(method, data)),
        (_) {},
      );
    }

    Future<void> enter() => native('entered', [100.0, 100.0]);
    Future<void> drop() => native('performOperation_macos', [
      {'path': '/tmp/reference.png'},
    ]);

    Widget draft(int tab, int index, List<String> paths) => TickerMode(
      enabled: index == tab,
      child: DesktopFileDropTarget(
        onFiles: (files) => paths.addAll(files.map((f) => f.path)),
        overlay: Text('Hover $tab'),
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ValueListenableBuilder(
          valueListenable: active,
          builder: (context, index, _) => Stack(
            children: [
              IndexedStack(
                index: index,
                children: [draft(0, index, chat), draft(1, index, references)],
              ),
              ValueListenableBuilder(
                valueListenable: menu,
                builder: (_, open, _) => open
                    ? const Positioned.fill(child: ModalBarrier())
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );

    await enter();
    await tester.pump();
    expect(find.text('Hover 1'), findsOneWidget);
    await drop();
    expect(references, ['/tmp/reference.png']);
    expect(chat, isEmpty);

    menu.value = true;
    await tester.pump();
    await enter();
    await drop();
    menu.value = false;
    await tester.pump();

    await enter();
    active.value = 0;
    await tester.pump();
    await native('updated', [100.0, 100.0]);
    await drop();
    expect(chat, ['/tmp/reference.png']);

    navigator.currentState!.push(
      DialogRoute<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Cover')),
      ),
    );
    await tester.pumpAndSettle();
    await enter();
    await drop();
    expect(chat, hasLength(1));
    expect(references, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    active.dispose();
    menu.dispose();
  });
}

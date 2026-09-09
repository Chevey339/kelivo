import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:terminal_view/terminal_view.dart';

import '../_fixture/_fixture.dart';

@GenerateNiceMocks([MockSpec<TerminalInputHandler>()])
import 'terminal_view_test.mocks.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'htop golden test',
    (tester) async {
      final terminal = Terminal();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal),
        ),
      ));

      terminal.write(TestFixtures.htop_80x25_3s());
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/htop_80x25_3s.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  testWidgets(
    'color golden test',
    (tester) async {
      final terminal = Terminal();

      // terminal.lineFeedMode = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(
            terminal,
            textStyle: TerminalStyle(fontSize: 8),
          ),
        ),
      ));

      terminal.write(TestFixtures.colors().replaceAll('\n', '\r\n'));
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/colors.png'),
      );
    },
    skip: !Platform.isMacOS,
  );

  group('TerminalView.readOnly', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: true, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), isEmpty);
    });

    testWidgets('does not block input when false', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, readOnly: false, autofocus: true),
        ),
      ));

      // https://github.com/flutter/flutter/issues/11181#issuecomment-314936646
      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('ls -al');
      await binding.idle();

      expect(terminalOutput.join(), 'ls -al');
    });
  });

  group('TerminalView.focusNode', () {
    testWidgets('is not listened when terminal is disposed', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isTrue);

      isActive.value = false;
      await tester.pumpAndSettle();

      // ignore: invalid_use_of_protected_member
      expect(focusNode.hasListeners, isFalse);
    });

    testWidgets('does not dispose external focus node', (tester) async {
      final terminal = Terminal();

      final focusNode = FocusNode();

      final isActive = ValueNotifier(true);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: isActive,
            builder: (context, isActive, child) {
              if (!isActive) {
                return Container();
              }
              return TerminalView(
                terminal,
                focusNode: focusNode,
                autofocus: true,
              );
            },
          ),
        ),
      ));

      isActive.value = false;
      await tester.pumpAndSettle();

      expect(() => focusNode.addListener(() {}), returnsNormally);
    });
  });

  group('TerminalController.pointerInputs', () {
    testWidgets('works', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.all(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isNotEmpty);
    });

    testWidgets('does not respond when disabled', (tester) async {
      final output = <String>[];

      final terminal = Terminal(onOutput: output.add);

      // enable mouse reporting
      terminal.write('\x1b[?1000h');

      final terminalView = TerminalController(
        pointerInputs: PointerInputs.none(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              controller: terminalView,
            ),
          ),
        ),
      );

      final pointer = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(pointer.down(Offset(1, 1)));

      await tester.pumpAndSettle();

      expect(output, isEmpty);
    });
  });

  group('TerminalView.autofocus', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('works in hardwareKeyboardOnly mode', (tester) async {
      final terminal = Terminal();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              focusNode: focusNode,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      expect(focusNode.hasFocus, isTrue);
    });
  });

  group('TerminalView.hardwareKeyboardOnly', () {
    testWidgets('works', (tester) async {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TerminalView(
              terminal,
              autofocus: true,
              hardwareKeyboardOnly: true,
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);

      expect(output.join(), 'abc');
    });
  });

  group('TerminalView.textScaler', () {
    testWidgets('works', (tester) async {
      final terminal = Terminal();

      final textScaler = ValueNotifier(TextScaler.linear(1.0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<TextScaler>(
              valueListenable: textScaler,
              builder: (context, textScaler, child) {
                return TerminalView(
                  terminal,
                  textScaler: textScaler,
                );
              },
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@1x.png'),
      );

      textScaler.value = TextScaler.linear(2.0);
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });

    testWidgets('can obtain textScaler from parent', (tester) async {
      final terminal = Terminal();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: TerminalView(
                terminal,
              ),
            ),
          ),
        ),
      );

      terminal.write('Hello World');
      await tester.pump();

      await expectLater(
        find.byType(TerminalView),
        matchesGoldenFile('_goldens/text_scale_factor@2x.png'),
      );
    });
  });

  group('TerminalView.inputHandler', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      await tester.pumpAndSettle();

      expect(terminalOutput.join(), '\x04');
    });

    testWidgets('can convert text input to key events', (tester) async {
      final inputHandler = MockTerminalInputHandler();
      when(inputHandler.call(any)).thenAnswer((invocation) => 'AAA');

      final terminalOutput = <String>[];
      final terminal = Terminal(
        inputHandler: inputHandler,
        onOutput: terminalOutput.add,
      );

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true),
      ));

      await tester.tap(find.byType(TerminalView));
      await tester.pump(Duration(seconds: 1));

      binding.testTextInput.enterText('c');
      await binding.idle();

      await tester.pumpAndSettle();

      verify(inputHandler.call(any));
      expect(terminalOutput.join(), 'AAA');
    });
  });

  group('TerminalView.simulateScroll', () {
    testWidgets('works', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: true),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), contains('\x1B[B'));
    });

    testWidgets('does nothing when disabled', (tester) async {
      final terminalOutput = <String>[];
      final terminal = Terminal(onOutput: terminalOutput.add);
      terminal.useAltBuffer();

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(terminal, autofocus: true, simulateScroll: false),
      ));

      await tester.drag(find.byType(TerminalView), const Offset(0, -100));

      expect(terminalOutput.join(), isEmpty);
    });
  });

  group('TerminalView.onTapUp', () {
    testWidgets('reports the tapped cell', (tester) async {
      final terminal = Terminal();
      CellOffset? tapped;

      await tester.pumpWidget(MaterialApp(
        home: TerminalView(
          terminal,
          onTapUp: (_, offset) => tapped = offset,
        ),
      ));

      await tester.tapAt(
          tester.getTopLeft(find.byType(TerminalView)) + const Offset(1, 1));
      await tester.pump(kDoubleTapTimeout);

      expect(tapped, isNotNull);
      expect(tapped!.x, 0);
      expect(tapped!.y, 0);
    });
  });
}

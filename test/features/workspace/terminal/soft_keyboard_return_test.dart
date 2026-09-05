import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

/// The terminal page runs [TerminalView] with a soft keyboard, where the return
/// key can be reported twice: iOS writes a newline into the editing value and
/// reports a newline input action on top of it, Android only reports the
/// action. Either way the shell must see exactly one submitted line.
void main() {
  late Terminal terminal;
  late List<String> output;

  Future<void> pumpTerminal(WidgetTester tester) async {
    terminal = Terminal();
    output = <String>[];
    terminal.onOutput = output.add;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TerminalView(terminal, autofocus: true, deleteDetection: true),
        ),
      ),
    );
    await tester.pump();
    expect(tester.testTextInput.hasAnyClients, isTrue);
  }

  /// What a soft keyboard leaves in the editing value after one return, on top
  /// of the two spaces the view seeds for delete detection.
  void insertReturn(WidgetTester tester) {
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '  \n',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
  }

  void insertText(WidgetTester tester, String text) {
    tester.testTextInput.updateEditingValue(
      TextEditingValue(
        text: '  $text',
        selection: TextSelection.collapsed(offset: 2 + text.length),
      ),
    );
  }

  testWidgets('a return reported both ways submits one line', (tester) async {
    await pumpTerminal(tester);

    insertReturn(tester);
    await tester.testTextInput.receiveAction(TextInputAction.newline);

    expect(output, <String>['\r']);
  });

  testWidgets('two returns reported both ways submit two lines', (
    tester,
  ) async {
    await pumpTerminal(tester);

    insertReturn(tester);
    await tester.testTextInput.receiveAction(TextInputAction.newline);
    insertReturn(tester);
    await tester.testTextInput.receiveAction(TextInputAction.newline);

    expect(output, <String>['\r', '\r']);
  });

  testWidgets('a keyboard that only reports the action still submits', (
    tester,
  ) async {
    await pumpTerminal(tester);

    await tester.testTextInput.receiveAction(TextInputAction.newline);
    await tester.testTextInput.receiveAction(TextInputAction.newline);

    expect(output, <String>['\r', '\r']);
  });

  testWidgets('a keyboard that only inserts a newline still submits', (
    tester,
  ) async {
    await pumpTerminal(tester);

    insertReturn(tester);
    insertReturn(tester);

    expect(output, <String>['\r', '\r']);
  });

  testWidgets('typing between the halves keeps both returns', (tester) async {
    await pumpTerminal(tester);

    insertReturn(tester);
    insertText(tester, 'a');
    await tester.testTextInput.receiveAction(TextInputAction.newline);

    expect(output, <String>['\r', 'a', '\r']);
  });
}

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:mockito/annotations.dart';
// import 'package:mockito/mockito.dart';
// import 'package:terminal_view/terminal_view.dart';

// @GenerateMocks([
//   TerminalUiInteraction,
// ])
void main() {
//   group('InputBehaviorDesktop', () {
//     test('can handle fast typing', () {
//       final mockTerminal = MockTerminalUiInteraction();
//       final inputBehavior = InputBehaviorDesktop();

//       inputBehavior.onTextEdit(composing('l', -1, -1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('l'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(composing('ls', -1, -1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('s'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       verifyNever(mockTerminal.raiseOnInput(any));
//       verifyNever(mockTerminal.updateComposingString(any));
//     });

//     test('can handle English', () {
//       final mockTerminal = MockTerminalUiInteraction();
//       final inputBehavior = InputBehaviorDesktop();

//       // typing 'hello'

//       inputBehavior.onTextEdit(composing('h', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('h'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       inputBehavior.onTextEdit(composing('e', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('e'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       inputBehavior.onTextEdit(composing('l', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('l'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       inputBehavior.onTextEdit(composing('l', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('l'));
//       verifyNever(mockTerminal.updateComposingString(any));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       inputBehavior.onTextEdit(composing('o', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('o'));
//       verifyNever(mockTerminal.updateComposingString(any));
//     });

//     test('can handle Chinese', () {
//       final mockTerminal = MockTerminalUiInteraction();
//       final inputBehavior = InputBehaviorDesktop();

//       // typing '你好'

//       inputBehavior.onTextEdit(composing('n', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('ni', 0, 2), mockTerminal);
//       inputBehavior.onTextEdit(composing('ni h', 0, 4), mockTerminal);
//       inputBehavior.onTextEdit(composing('ni ha', 0, 5), mockTerminal);
//       inputBehavior.onTextEdit(composing('ni hao', 0, 6), mockTerminal);
//       inputBehavior.onTextEdit(composing('你好', 0, 2), mockTerminal);
//       verify(mockTerminal.updateComposingString(any)).called(6);
//       verifyNever(mockTerminal.raiseOnInput(any));

//       inputBehavior.onTextEdit(composing('你好', -1, -1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('你好'));
//       verify(mockTerminal.updateComposingString(''));
//     });

//     test('can handle Japanese', () {
//       final mockTerminal = MockTerminalUiInteraction();
//       final inputBehavior = InputBehaviorDesktop();

//       // typing 'どうも'

//       inputBehavior.onTextEdit(composing('d', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('ど', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('どう', 0, 2), mockTerminal);
//       inputBehavior.onTextEdit(composing('どうm', 0, 3), mockTerminal);
//       inputBehavior.onTextEdit(composing('どうも', 0, 3), mockTerminal);
//       verify(mockTerminal.updateComposingString(any)).called(5);
//       verifyNever(mockTerminal.raiseOnInput(any));

//       inputBehavior.onTextEdit(composing('どうも', -1, -1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('どうも'));
//       verify(mockTerminal.updateComposingString(''));
//     });

//     test('can handle Korean', () {
//       final mockTerminal = MockTerminalUiInteraction();
//       final inputBehavior = InputBehaviorDesktop();

//       // typing '안녕'

//       inputBehavior.onTextEdit(composing('ㅇ', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('아', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('안', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('안', 0, 1), mockTerminal);
//       verify(mockTerminal.updateComposingString(any)).called(4);
//       verifyNever(mockTerminal.raiseOnInput(any));

//       inputBehavior.onTextEdit(composing('안', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('안'));
//       verify(mockTerminal.updateComposingString(''));

//       inputBehavior.onTextEdit(TextEditingValue.empty, mockTerminal);
//       inputBehavior.onTextEdit(composing('ㄴ', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('녀', 0, 1), mockTerminal);
//       inputBehavior.onTextEdit(composing('녕', 0, 1), mockTerminal);
//       verify(mockTerminal.updateComposingString(any)).called(3);
//       verifyNever(mockTerminal.raiseOnInput(any));

//       inputBehavior.onTextEdit(composing('녕', 1, 1), mockTerminal);
//       verify(mockTerminal.raiseOnInput('녕'));
//       verify(mockTerminal.updateComposingString(''));
//     });
//   });
// }

// TextEditingValue composing(String text, int start, int end) {
//   return TextEditingValue(
//     text: text,
//     selection: TextSelection.collapsed(offset: text.length),
//     composing: TextRange(start: start, end: end),
//   );
}

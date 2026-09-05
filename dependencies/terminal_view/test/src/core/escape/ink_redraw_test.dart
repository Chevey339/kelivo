import 'package:test/test.dart';
import 'package:terminal_view/core.dart';

/// The redraw React Ink performs: walk the cursor back up over the frame it
/// last drew, erase from there down, and write the new one. Anything that
/// leaves the cursor a row or a column off shows up as one frame printed over
/// another rather than in place of it.
List<String> _screen(Terminal terminal) {
  final buffer = terminal.buffer;
  return [
    for (var y = 0; y < terminal.viewHeight; y++)
      buffer.lines[buffer.scrollBack + y].getText().trimRight(),
  ];
}

void main() {
  group('Ink style redraw', () {
    test('a frame redrawn in place replaces the one before it', () {
      final terminal = Terminal()..resize(40, 10);

      terminal.write('─' * 40);
      terminal.write('\r\n');
      terminal.write('first frame');

      terminal.write('\x1b[1A\r\x1b[J');
      terminal.write('second\r\n');
      terminal.write('frame');

      expect(_screen(terminal).take(3), ['second', 'frame', '']);
    });

    test('erase to end of line clears cells a later cursor move skips', () {
      final terminal = Terminal()..resize(40, 10);

      terminal.write('─' * 40);
      terminal.write('\r\x1b[K');
      terminal.write('a\x1b[3Cb');

      expect(_screen(terminal).first, 'a   b');
    });

    test('a cursor move alone does not clear what it passes over', () {
      final terminal = Terminal()..resize(40, 10);

      terminal.write('─' * 40);
      terminal.write('\r');
      terminal.write('a\x1b[3Cb');

      expect(
        _screen(terminal).first,
        'a───b${'─' * 35}',
      );
    });

    test('CSI K with no parameter erases to the end of the line', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('abcdefghij');
      terminal.write('\r\x1b[3C\x1b[K');

      expect(_screen(terminal).first, 'abc');
    });

    test('CSI J with no parameter erases to the end of the screen', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('aaa\r\nbbb\r\nccc');
      terminal.write('\x1b[2;1H\x1b[J');

      expect(_screen(terminal).take(3), ['aaa', '', '']);
    });

    test('cursor up walks back exactly the rows a wrapped write took', () {
      final terminal = Terminal()..resize(10, 6);

      terminal.write('\x1b[H');
      terminal.write('0123456789abcde');
      expect(terminal.buffer.cursorY, 1);

      terminal.write('\x1b[1A\r');
      expect(terminal.buffer.cursorY, 0);
      expect(terminal.buffer.cursorX, 0);
    });

    test('a write ending exactly on the margin does not consume a row', () {
      final terminal = Terminal()..resize(10, 6);

      terminal.write('\x1b[H');
      terminal.write('0123456789');

      expect(terminal.buffer.cursorY, 0);

      terminal.write('\r\n');
      expect(terminal.buffer.cursorY, 1);
    });

    test('scrolling at the bottom keeps cursor up relative to the viewport',
        () {
      final terminal = Terminal()..resize(10, 3);

      terminal.write('\x1b[H');
      terminal.write('one\r\ntwo\r\nthree\r\nfour');

      expect(_screen(terminal), ['two', 'three', 'four']);
      expect(terminal.buffer.cursorY, 2);

      terminal.write('\x1b[2A\r\x1b[J');
      terminal.write('TWO');

      expect(_screen(terminal), ['TWO', '', '']);
    });

    test('erasing a line clears the whole width, not the trimmed length', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('─' * 20);
      terminal.write('\x1b[1;1H\x1b[2K');
      terminal.write('x');

      expect(_screen(terminal).first, 'x');
    });
  });
}

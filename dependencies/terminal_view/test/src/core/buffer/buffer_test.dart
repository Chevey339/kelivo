import 'package:test/test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  group('Buffer.getText()', () {
    test('should return the text', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.getText(), startsWith('Hello World'));
    });

    test('can handle line wrap', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      final line1 = 'This is a long line that should wrap';
      final line2 = 'This is a short line';
      final line3 = 'This is a long long long long line that should wrap';
      final line4 = 'Short';

      terminal.write('$line1\r\n');
      terminal.write('$line2\r\n');
      terminal.write('$line3\r\n');
      terminal.write('$line4\r\n');

      final lines = terminal.buffer.getText().split('\n');
      expect(lines[0], line1);
      expect(lines[1], line2);
      expect(lines[2], line3);
      expect(lines[3], line4);
    });

    test('can handle negative start', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(-100, -100), CellOffset(100, 100)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle invalid end', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(0, 0), CellOffset(100, 100)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle reversed range', () {
      final terminal = Terminal();

      terminal.write('Hello World');

      expect(
        terminal.buffer.getText(
          BufferRangeLine(CellOffset(5, 5), CellOffset(0, 0)),
        ),
        startsWith('Hello World'),
      );
    });

    test('can handle block range', () {
      final terminal = Terminal();

      terminal.write('Hello World\r\n');
      terminal.write('Nice to meet you\r\n');

      expect(
        terminal.buffer.getText(
          BufferRangeBlock(CellOffset(2, 0), CellOffset(5, 1)),
        ),
        startsWith('llo\nce '),
      );
    });
  });

  group('Buffer.resize()', () {
    test('should resize the buffer', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      expect(terminal.viewWidth, 10);
      expect(terminal.viewHeight, 10);

      for (var i = 0; i < terminal.lines.length; i++) {
        final line = terminal.lines[i];
        expect(line.length, 10);
      }

      terminal.resize(20, 20);

      expect(terminal.viewWidth, 20);
      expect(terminal.viewHeight, 20);

      for (var i = 0; i < terminal.lines.length; i++) {
        final line = terminal.lines[i];
        expect(line.length, 20);
      }
    });
  });

  group('Buffer.deleteLines()', () {
    test('works', () {
      final terminal = Terminal();
      terminal.resize(10, 10);

      for (var i = 1; i <= 10; i++) {
        terminal.write('line$i');

        if (i < 10) {
          terminal.write('\r\n');
        }
      }

      terminal.setMargins(3, 7);
      terminal.setCursor(0, 5);

      terminal.buffer.deleteLines(1);

      expect(terminal.buffer.lines[2].toString(), 'line3');
      expect(terminal.buffer.lines[3].toString(), 'line4');
      expect(terminal.buffer.lines[4].toString(), 'line5');
      expect(terminal.buffer.lines[5].toString(), 'line7');
      expect(terminal.buffer.lines[6].toString(), 'line8');
      expect(terminal.buffer.lines[7].toString(), '');
      expect(terminal.buffer.lines[8].toString(), 'line9');
      expect(terminal.buffer.lines[9].toString(), 'line10');
    });
  });

  group('Buffer.insertLines()', () {
    test('works', () {
      final terminal = Terminal();

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      print(terminal.buffer);

      terminal.setMargins(2, 6);
      terminal.setCursor(0, 4);

      print(terminal.buffer.absoluteCursorY);

      terminal.buffer.insertLines(1);

      print(terminal.buffer);

      expect(terminal.buffer.lines[3].toString(), 'line3');
      expect(terminal.buffer.lines[4].toString(), ''); // inserted
      expect(terminal.buffer.lines[5].toString(), 'line4'); // moved
      expect(terminal.buffer.lines[6].toString(), 'line5'); // moved
      expect(terminal.buffer.lines[7].toString(), 'line7');
    });

    test('has no effect if cursor is out of scroll region', () {
      final terminal = Terminal();

      for (var i = 0; i < 10; i++) {
        terminal.write('line$i\r\n');
      }

      terminal.setMargins(2, 6);
      terminal.setCursor(0, 1);

      terminal.buffer.insertLines(1);

      expect(terminal.buffer.lines[2].toString(), 'line2');
      expect(terminal.buffer.lines[3].toString(), 'line3');
      expect(terminal.buffer.lines[4].toString(), 'line4');
      expect(terminal.buffer.lines[5].toString(), 'line5');
      expect(terminal.buffer.lines[6].toString(), 'line6');
      expect(terminal.buffer.lines[7].toString(), 'line7');
    });
  });

  group('Buffer.getWordBoundary supports custom word separators', () {
    test('can set word separators', () {
      final terminal = Terminal(wordSeparators: {'o'.codeUnitAt(0)});

      terminal.write('Hello World');

      expect(
        terminal.mainBuffer.getWordBoundary(CellOffset(0, 0)),
        BufferRangeLine(CellOffset(0, 0), CellOffset(4, 0)),
      );

      expect(
        terminal.mainBuffer.getWordBoundary(CellOffset(5, 0)),
        BufferRangeLine(CellOffset(5, 0), CellOffset(7, 0)),
      );
    });
  });

  test('does not delete lines beyond the scroll region', () {
    final terminal = Terminal();
    terminal.resize(10, 10);

    for (var i = 1; i <= 10; i++) {
      terminal.write('line$i');

      if (i < 10) {
        terminal.write('\r\n');
      }
    }

    terminal.setMargins(3, 7);
    terminal.setCursor(0, 5);

    terminal.buffer.deleteLines(20);

    expect(terminal.buffer.lines[2].toString(), 'line3');
    expect(terminal.buffer.lines[3].toString(), 'line4');
    expect(terminal.buffer.lines[4].toString(), 'line5');
    expect(terminal.buffer.lines[5].toString(), '');
    expect(terminal.buffer.lines[6].toString(), '');
    expect(terminal.buffer.lines[7].toString(), '');
    expect(terminal.buffer.lines[8].toString(), 'line9');
    expect(terminal.buffer.lines[9].toString(), 'line10');
  });

  group('Buffer.eraseDisplayFromCursor()', () {
    test('works', () {
      final terminal = Terminal();
      terminal.resize(3, 3);
      terminal.write('123\r\n456\r\n789');

      terminal.setCursor(1, 1);
      terminal.buffer.eraseDisplayFromCursor();

      expect(terminal.buffer.lines[0].toString(), '123');
      expect(terminal.buffer.lines[1].toString(), '4');
      expect(terminal.buffer.lines[2].toString(), '');
    });
  });

  group('Buffer.writeChar()', () {
    test('tracks line feeds and scrollback eviction', () {
      final terminal = Terminal(maxLines: 24);
      terminal.resize(16, 2);

      for (var i = 0; i <= 24; i++) {
        if (i > 0) terminal.write('\r\n');
        terminal.write('line$i');
      }

      expect(terminal.buffer.lines.length, 24);
      expect(terminal.buffer.lines[0].toString(), 'line1');
      expect(terminal.buffer.currentLine.toString(), 'line24');

      terminal.write('!');

      expect(terminal.buffer.lines[23].toString(), 'line24!');
    });

    test('zero-width characters do not consume a column', () {
      final terminal = Terminal();
      terminal.resize(10, 3);
      terminal.write('A\u0301B');

      final line = terminal.buffer.lines[0];
      expect(line.getCodePoint(0), 'A'.codeUnitAt(0));
      expect(line.getCodePoint(1), 'B'.codeUnitAt(0));
      expect(line.getWidth(0), 1);
      expect(line.getWidth(1), 1);
      expect(terminal.buffer.cursorX, 2);
    });

    test('combining marks are kept, attached to the base character', () {
      final terminal = Terminal();
      terminal.resize(10, 3);
      terminal.write('A\u0301B');

      final line = terminal.buffer.lines[0];
      expect(line.getCombined(0), '\u0301');
      expect(line.toString(), 'A\u0301B');
    });

    test('a zero width joiner sequence is kept on the base character', () {
      final terminal = Terminal();
      terminal.resize(10, 3);
      terminal.write(
        '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}x',
      );

      final line = terminal.buffer.lines[0];
      expect(
        line.getCombined(0),
        '\u200D\u{1F469}\u200D\u{1F467}',
      );
      expect(line.getCodePoint(2), 'x'.codeUnitAt(0));
      expect(terminal.buffer.cursorX, 3);
    });

    test('leading zero-width characters are ignored', () {
      final terminal = Terminal();
      terminal.resize(10, 3);
      terminal.write('\u0301A');

      final line = terminal.buffer.lines[0];
      expect(line.getCodePoint(0), 'A'.codeUnitAt(0));
      expect(line.getWidth(0), 1);
      expect(terminal.buffer.cursorX, 1);
    });

    test('ignores C1 control characters for column width', () {
      final terminal = Terminal();
      terminal.resize(10, 3);
      terminal.write('A${String.fromCharCode(0x7F)}B');

      final line = terminal.buffer.lines[0];
      expect(line.getCodePoint(0), 'A'.codeUnitAt(0));
      expect(line.getCodePoint(1), 'B'.codeUnitAt(0));
      expect(terminal.buffer.cursorX, 2);
    });
  });

  group('Buffer.getText() over a selection', () {
    test('keeps a tab-aligned table aligned', () {
      // What `ls -l`, `git log --graph` or any TUI writes: columns placed with
      // tabs and cursor moves, not with spaces.
      final terminal = Terminal(maxLines: 100);
      terminal.write('name\tsize\r\n');
      terminal.write('a.txt\t12\r\n');
      final text = terminal.buffer.getText(
        BufferRangeLine(const CellOffset(0, 0), const CellOffset(20, 0)),
      );
      expect(text, 'name    size');
    });

    test('keeps the gaps on every line of a multi-line selection', () {
      final terminal = Terminal(maxLines: 100);
      terminal.write('one\ttwo\r\n');
      terminal.write('three\tfour\r\n');
      final text = terminal.buffer.getText(
        BufferRangeLine(const CellOffset(0, 0), const CellOffset(20, 1)),
      );
      expect(text, 'one     two\nthree   four');
    });
  });
}

import 'package:test/test.dart';
import 'package:terminal_view/terminal_view.dart';

void main() {
  group('BufferLine.getText()', () {
    test('should return the text', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(), 'Hello World');
    });

    test('getText() should support wide characters', () {
      final text = '😀😁😂🤣😃';
      final terminal = Terminal();
      terminal.write(text);
      expect(terminal.buffer.lines[0].getText(), equals(text));
    });

    test('can specify a range', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 5), 'Hello');
    });

    test('can handle invalid ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(0, 100), 'Hello World');
    });

    test('can handle negative ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(-100, 100), 'Hello World');
    });

    test('keeps the gap a tab jumped over', () {
      // Nothing is written into the cells a tab skips, but they are blanks on
      // screen and have to be blanks in the clipboard too.
      final terminal = Terminal();
      terminal.write('a\tb');
      expect(terminal.buffer.lines[0].getText(), 'a       b');
    });

    test('keeps the gap a cursor move skipped over', () {
      final terminal = Terminal();
      terminal.write('a\x1b[4Cb');
      expect(terminal.buffer.lines[0].getText(), 'a    b');

      final addressed = Terminal();
      addressed.write('a\x1b[10Gb');
      expect(addressed.buffer.lines[0].getText(), 'a        b');
    });

    test('keeps an erased gap between two words', () {
      final terminal = Terminal();
      terminal.write('one two');
      // Erase "two" in place, then write past it.
      terminal.write('\r\x1b[4C\x1b[K\x1b[6Cend');
      expect(terminal.buffer.lines[0].getText(), 'one       end');
    });

    test('does not pad past the end of the text', () {
      final terminal = Terminal();
      terminal.write('hi');
      expect(terminal.buffer.lines[0].getText(), 'hi');
      expect(terminal.buffer.lines[0].getText(0, 40), 'hi');
    });

    test('does not slip a space into a double-width glyph', () {
      final terminal = Terminal();
      terminal.write('日本語');
      expect(terminal.buffer.lines[0].getText(), '日本語');

      final mixed = Terminal();
      mixed.write('日本\tx');
      expect(mixed.buffer.lines[0].getText(), '日本    x');
    });

    test('can specify a range across a gap', () {
      final terminal = Terminal();
      terminal.write('a\tb');
      // Blanks between two glyphs are kept; blanks the range ends on are not,
      // the same way a terminal trims the tail of a copied line.
      expect(terminal.buffer.lines[0].getText(0, 4), 'a');
      expect(terminal.buffer.lines[0].getText(2, 9), '      b');
    });

    test('can handle reversed ranges', () {
      final terminal = Terminal();
      terminal.write('Hello World');
      expect(terminal.buffer.lines[0].getText(5, 0), '');
    });
  });

  group('BufferLine.getTrimmedLength()', () {
    test('can get trimmed length', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(), equals(text.length));
    });

    test('can get trimmed length with wide characters', () {
      final terminal = Terminal();
      final text = '😀😁😂🤣😃';

      terminal.write(text);

      expect(terminal.buffer.lines[0].getTrimmedLength(), equals(text.length));
    });

    test('can handle length larger than the line', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(1000), equals(text.length));
    });

    test('can handle negative start', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      expect(line.getTrimmedLength(-1000), equals(0));
    });
  });

  group('BufferLine.resize', () {
    test('can resize', () {
      final line = BufferLine(10);

      final text = 'ABCDEF';

      for (var i = 0; i < text.length; i++) {
        line.setCodePoint(i, text.codeUnitAt(i));
      }

      line.resize(20);

      expect(line.length, equals(20));
    });
  });

  group('Buffer.createAnchor', () {
    test('works', () {
      final terminal = Terminal();
      final line = terminal.buffer.lines[3];
      final anchor = line.createAnchor(5);

      terminal.insertLines(5);
      expect(anchor.x, 5);
      expect(anchor.y, 8);

      terminal.buffer.clear();
      expect(line.attached, false);
      expect(anchor.attached, false);
    });
  });
}

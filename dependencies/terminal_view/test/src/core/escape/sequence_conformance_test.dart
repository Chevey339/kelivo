import 'package:test/test.dart';
import 'package:terminal_view/core.dart';

String _lineText(Terminal terminal, int y) {
  return terminal.buffer.lines[terminal.buffer.scrollBack + y].getText();
}

void main() {
  group('prefixed CSI sequences', () {
    test('CSI ? u does not restore the cursor', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('\x1b[3;5H');
      terminal.write('\x1b[s');
      terminal.write('\x1b[1;1H');
      terminal.write('\x1b[?u');

      expect(terminal.buffer.cursorX, 0);
      expect(terminal.buffer.cursorY, 0);
    });

    test('kitty keyboard push and pop do not restore the cursor', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('\x1b[3;5H\x1b[s\x1b[1;1H');

      terminal.write('\x1b[>1u');
      expect(terminal.buffer.cursorY, 0);

      terminal.write('\x1b[<u');
      expect(terminal.buffer.cursorY, 0);
    });

    test('CSI ? Pm s does not save the cursor', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('\x1b[2;3H\x1b[s');
      terminal.write('\x1b[5;9H\x1b[?1049s');
      terminal.write('\x1b[u');

      expect(terminal.buffer.cursorX, 2);
      expect(terminal.buffer.cursorY, 1);
    });

    test('CSI ? Pm r does not set the scroll margins', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[?1049r');

      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, 9);
    });
  });

  group('string sequences', () {
    test('a DCS body is not written to the screen', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('a\x1bP1;2|payload\x1b\\b');

      expect(_lineText(terminal, 0), 'ab');
    });

    test('an APC body is not written to the screen', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('a\x1b_Gf=100,a=T;junk\x1b\\b');

      expect(_lineText(terminal, 0), 'ab');
    });

    test('a DCS split across writes is not written to the screen', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('a\x1bP1;2|pay');
      terminal.write('load\x1b\\b');

      expect(_lineText(terminal, 0), 'ab');
    });

    test('an OSC aborted by an escape reparses the escape', () {
      final terminal = Terminal()..resize(20, 5);

      terminal.write('\x1b]0;title\x1b[3;1Hx');

      expect(terminal.buffer.cursorY, 2);
      expect(_lineText(terminal, 2), 'x');
    });
  });

  group('autowrap', () {
    test('DECAWM off overwrites the last column instead of wrapping', () {
      final terminal = Terminal()..resize(5, 5);

      terminal.write('\x1b[?7l');
      terminal.write('abcdefg');

      expect(_lineText(terminal, 0), 'abcdg');
      expect(_lineText(terminal, 1), '');
      expect(terminal.buffer.cursorY, 0);
    });

    test('DECAWM on still wraps', () {
      final terminal = Terminal()..resize(5, 5);

      terminal.write('abcdefg');

      expect(_lineText(terminal, 0), 'abcde');
      expect(_lineText(terminal, 1), 'fg');
    });
  });

  group('character width', () {
    test('a wide glyph that does not fit moves whole to the next line', () {
      final terminal = Terminal()..resize(5, 5);

      terminal.write('abcd你');

      expect(_lineText(terminal, 0), 'abcd');
      expect(_lineText(terminal, 1), '你');
      expect(terminal.buffer.cursorX, 2);
    });

    test('an emoji presentation selector widens the character before it', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('✔️x');

      expect(terminal.buffer.lines[0].getWidth(0), 2);
      expect(terminal.buffer.lines[0].getCodePoint(1), 0);
      expect(terminal.buffer.lines[0].getCodePoint(2), 'x'.codeUnitAt(0));
    });

    test('a zero width joiner sequence costs two columns', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('\u{1F468}‍\u{1F469}‍\u{1F467}x');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.lines[0].getCodePoint(2), 'x'.codeUnitAt(0));
    });

    test('a skin tone modifier costs no column of its own', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('\u{1F44D}\u{1F3FD}x');

      expect(terminal.buffer.cursorX, 3);
      expect(terminal.buffer.lines[0].getCodePoint(2), 'x'.codeUnitAt(0));
    });

    test('a combining mark is not given a column', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('éx');

      expect(terminal.buffer.cursorX, 2);
    });
  });

  group('insert mode', () {
    test('IRM shifts the cells to the right of the cursor', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('abcdef');
      terminal.write('\x1b[1;1H');
      terminal.write('\x1b[4h');
      terminal.write('XY');

      expect(_lineText(terminal, 0), 'XYabcdef');
    });

    test('IRM off overwrites', () {
      final terminal = Terminal()..resize(10, 5);

      terminal.write('abcdef');
      terminal.write('\x1b[1;1H');
      terminal.write('XY');

      expect(_lineText(terminal, 0), 'XYcdef');
    });
  });

  group('tab stops', () {
    test('HTS sets a tab stop the next tab lands on', () {
      final terminal = Terminal()..resize(40, 5);

      terminal.write('\x1b[1;4H\x1bH');
      terminal.write('\x1b[1;1H\t');

      expect(terminal.buffer.cursorX, 3);
    });

    test('CBT walks back over tab stops', () {
      final terminal = Terminal()..resize(40, 5);

      terminal.write('\x1b[1;20H');
      terminal.write('\x1b[2Z');

      expect(terminal.buffer.cursorX, 8);
    });

    test('CHT walks forward over tab stops', () {
      final terminal = Terminal()..resize(40, 5);

      terminal.write('\x1b[1;1H');
      terminal.write('\x1b[3I');

      expect(terminal.buffer.cursorX, 24);
    });
  });

  group('cursor movement', () {
    test('HPR and VPR move the cursor relative to where it is', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[1;1H');
      terminal.write('\x1b[4a');
      terminal.write('\x1b[2e');

      expect(terminal.buffer.cursorX, 4);
      expect(terminal.buffer.cursorY, 2);
    });

    test('HPA sets the column', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[7`');

      expect(terminal.buffer.cursorX, 6);
    });

    test('CUD stops at the bottom margin', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[3;6r');
      terminal.write('\x1b[4;1H');
      terminal.write('\x1b[20B');

      expect(terminal.buffer.cursorY, 5);
    });

    test('CUU stops at the top margin', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[3;6r');
      terminal.write('\x1b[5;1H');
      terminal.write('\x1b[20A');

      expect(terminal.buffer.cursorY, 2);
    });
  });

  group('reports', () {
    test('DSR reports a one based cursor position', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(20, 10);

      terminal.write('\x1b[1;1H');
      terminal.write('\x1b[6n');

      expect(output, ['\x1b[1;1R']);
    });

    test('DECRQM reports a set DEC private mode', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(20, 10);

      terminal.write('\x1b[?2004h');
      terminal.write('\x1b[?2004\$p');

      expect(output, ['\x1b[?2004;1\$y']);
    });

    test('DECRQM reports a reset DEC private mode', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(20, 10);

      terminal.write('\x1b[?2004l');
      terminal.write('\x1b[?2004\$p');

      expect(output, ['\x1b[?2004;2\$y']);
    });

    test('DECRQM reports an unknown mode as not recognized', () {
      final output = <String>[];
      final terminal = Terminal(onOutput: output.add)..resize(20, 10);

      terminal.write('\x1b[?9999\$p');

      expect(output, ['\x1b[?9999;0\$y']);
    });
  });

  group('resets', () {
    test('DECSTR restores the modes it owns', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[?7l\x1b[?6h\x1b[4h\x1b[3;6r\x1b[?25l');
      terminal.write('\x1b[!p');

      expect(terminal.autoWrapMode, isTrue);
      expect(terminal.originMode, isFalse);
      expect(terminal.insertMode, isFalse);
      expect(terminal.cursorVisibleMode, isTrue);
      expect(terminal.buffer.marginTop, 0);
      expect(terminal.buffer.marginBottom, 9);
    });

    test('RIS clears the screen and the modes', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('hello\x1b[?7l\x1b[?1049h');
      terminal.write('\x1bc');

      expect(terminal.autoWrapMode, isTrue);
      expect(terminal.isUsingAltBuffer, isFalse);
      expect(_lineText(terminal, 0), '');
    });
  });

  group('synchronized output', () {
    test('holds notifications until the mode is reset', () {
      final terminal = Terminal()..resize(20, 10);

      var notifications = 0;
      terminal.addListener(() => notifications++);

      terminal.write('\x1b[?2026h');
      terminal.write('frame');
      expect(notifications, 0);

      terminal.write('\x1b[?2026l');
      expect(notifications, 1);
    });
  });

  group('DECSCUSR', () {
    test('sets the shape the program asked for', () {
      final terminal = Terminal()..resize(20, 10);

      terminal.write('\x1b[5 q');
      expect(terminal.cursorShape, TerminalCursorType.verticalBar);
      expect(terminal.cursorBlinkMode, isTrue);

      terminal.write('\x1b[4 q');
      expect(terminal.cursorShape, TerminalCursorType.underline);
      expect(terminal.cursorBlinkMode, isFalse);
    });
  });
}

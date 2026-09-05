// Regression tests for the bugs documented in ../../CURSOR_AND_BUFFER_BUGS.md.
// Each test encodes the xterm.js behavior the fix restored.
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/src/terminal.dart';

void main() {
  group('EL/ED erase inclusively (A.1)', () {
    test('EL1 (ESC[1K) erases through the cursor cell', () {
      final t = Terminal();
      t.write('ABCDE');
      t.write('\x1b[3G'); // cursor to col 3 (0-based 2), on 'C'
      t.write('\x1b[1K');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), '   DE');
    });

    test('ED1 (ESC[1J) erases through the cursor cell', () {
      final t = Terminal();
      t.write('ABCDE');
      t.write('\x1b[3G');
      t.write('\x1b[1J');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), '   DE');
    });
  });

  group('pending-wrap sentinel collapses before cell operations (A.2)', () {
    test('EL0 (ESC[K) erases the last column', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH'); // fills row; cursor pending at last col
      t.write('\x1b[K');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ABCDEFG');
    });

    test('ECH (ESC[X) erases the last column', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x1b[1X');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ABCDEFG');
    });

    test('DCH (ESC[P) deletes at the cursor without asserting', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x1b[1P');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ABCDEFG');
    });

    test('ICH (ESC[@) inserts at the cursor without asserting', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x1b[2@');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ABCDEFG');
    });

    test('ED0 (ESC[J) erases the last column of the cursor row', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x1b[J');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ABCDEFG');
    });

    test('CR after pending wrap clears the pending state', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\r');
      t.write('Z');
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'ZBCDEFGH');
      expect(t.buffer.cursorX, 1);
    });
  });

  group('relative moves resolve from the displayed cursor (B.1)', () {
    test('CUB (ESC[D) from pending-wrap gives width-2 (xterm _moveCursor)', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x1b[1D');
      expect(t.buffer.cursorX, 6);
    });

    test('BS from pending-wrap gives width-2 (xterm backspace)', () {
      final t = Terminal()..resize(8, 4);
      t.write('ABCDEFGH');
      t.write('\x08');
      expect(t.buffer.cursorX, 6);
    });

    test('BS at column 0 stays put (no reverse wraparound)', () {
      final t = Terminal()..resize(8, 4);
      t.write('AB\r');
      t.write('\x08');
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0);
    });
  });

  group('DECSTBM (A.4, A.5)', () {
    test('homes the cursor', () {
      final t = Terminal();
      t.write('XY');
      t.write('\x1b[2;10r');
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0);
      expect(t.buffer.marginTop, 1);
      expect(t.buffer.marginBottom, 9);
    });

    test('CSI 1;0r sets full-screen margins (0 = default bottom)', () {
      final t = Terminal();
      t.write('\x1b[1;0r');
      expect(t.buffer.marginTop, 0);
      expect(t.buffer.marginBottom, 23);
    });

    test('CSI r alone resets margins to full screen and homes', () {
      final t = Terminal();
      t.write('\x1b[2;10r');
      t.write('\x1b[5;5H');
      t.write('\x1b[r');
      expect(t.buffer.marginTop, 0);
      expect(t.buffer.marginBottom, 23);
      expect(t.buffer.cursorX, 0);
      expect(t.buffer.cursorY, 0);
    });

    test('a region smaller than two lines is not applied', () {
      final t = Terminal();
      t.write('\x1b[5;5r');
      expect(t.buffer.marginTop, 0);
      expect(t.buffer.marginBottom, 23);
      expect(t.buffer.cursorY, 0);
    });
  });

  group('DECSC/DECRC (A.3, B.5)', () {
    test('restoreCursor clamps to the screen after a shrink', () {
      final t = Terminal()..resize(80, 24);
      t.write('\x1b[1;80H'); // row 1, col 80
      t.write('\x1b7'); // save at x=79
      t.resize(40, 24);
      t.write('\x1b8'); // restore -> should clamp to x=39
      expect(t.buffer.cursorX, 39);
      t.write('Z');
      // Z must land at col 39 of the cursor row, not wrap to the next line.
      expect(
        t.buffer.lines[t.buffer.scrollBack].toString().endsWith('Z'),
        isTrue,
      );
    });

    test('saves and restores origin and autowrap modes', () {
      final t = Terminal();
      t.write('\x1b7'); // save with defaults
      t.write('\x1b[?6h\x1b[?7l'); // origin on, autowrap off
      t.write('\x1b8');
      expect(t.originMode, isFalse);
      expect(t.autoWrapMode, isTrue);
    });

    test('1049 round-trip restores the cursor across a resize', () {
      final t = Terminal()..resize(80, 24);
      t.write('\x1b[10;10H');
      t.write('\x1b[?1049h'); // enter alt buffer (saves cursor 9,9)
      t.resize(20, 10);
      t.write('\x1b[?1049l'); // leave alt buffer (restores, clamped to 20x10)
      t.write('Z');
      expect(t.buffer.cursorX, 10);
      expect(
        t.buffer.lines[t.buffer.scrollBack + 9].toString().endsWith('Z'),
        isTrue,
      );
    });
  });

  group('parser robustness (B.2, B.3)', () {
    test('a DCS aborted by ESC + non-ST reparses the escape', () {
      final t = Terminal();
      // DCS body, then ESC G (a charset designation) that must run.
      t.write('\x1bP1;2|ignored\x1b(G');
      // ESC ( G designates G0 = G0-disp... the key effect: nothing from the
      // body leaks onto the screen and the ESC was consumed as a sequence.
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), '');
    });

    test('C0 controls inside an unfinished CSI stay ignored (parser design)', () {
      // xterm executes C0 in place; terminal_view rolls back incomplete
      // sequences, so executing them would replay the control on every
      // subsequent write. Asserting the current contract: no corruption.
      final t = Terminal();
      t.write('AB');
      t.write('\x1b[');
      t.write('\nC');
      // The LF is swallowed and 'C' completes the sequence as CUF 1.
      expect(t.buffer.lines[t.buffer.scrollBack].toString(), 'AB');
      expect(t.buffer.cursorX, 3);
    });
  });
}

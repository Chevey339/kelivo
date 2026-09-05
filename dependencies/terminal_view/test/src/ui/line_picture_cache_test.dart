import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_view/terminal_view.dart';

/// The painter records a line into a [ui.Picture] once it has stayed unchanged
/// across two frames, and replays that recording instead of walking the cells
/// again. These tests cover what that trades away: a recording that outlives
/// the content it was made from would leave stale text on screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final boundaryKey = GlobalKey();

  /// Renders whatever [TerminalView] is currently on screen to raw pixels.
  Future<Uint8List> snapshot(WidgetTester tester) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;

    final image = await tester.runAsync(() => boundary.toImage());
    final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );

    image!.dispose();
    return data!.buffer.asUint8List();
  }

  Future<void> pumpTerminal(WidgetTester tester, Terminal terminal) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RepaintBoundary(
            key: boundaryKey,
            child: TerminalView(terminal),
          ),
        ),
      ),
    );
  }

  testWidgets('a line renders the same once it is served from the cache',
      (tester) async {
    final terminal = Terminal();
    await pumpTerminal(tester, terminal);

    terminal.write('the quick brown fox\r\njumps over the lazy dog\r\n');
    await tester.pump();

    // First repaint after the write paints the cells directly and only notes
    // the line's version.
    final direct = await snapshot(tester);

    // By now the lines have held still long enough to be recorded, so this
    // frame is drawn from pictures instead.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    final cached = await snapshot(tester);

    expect(cached, equals(direct));
  });

  testWidgets('writing to a cached line shows the new text', (tester) async {
    final terminal = Terminal();
    await pumpTerminal(tester, terminal);

    terminal.write('aaaa');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));

    final beforeEdit = await snapshot(tester);

    // Overwrite the same line the painter just recorded. The change has to be
    // a color rather than different letters: the font the test environment
    // substitutes draws every glyph as the same box, so swapping characters
    // would come out pixel for pixel identical whether the cache updated or
    // not, and the test would pass on a stale recording.
    terminal.write('\r\x1b[31maaaa');
    await tester.pump();

    final afterEdit = await snapshot(tester);
    expect(afterEdit, isNot(equals(beforeEdit)));

    // And the replacement has to survive being recorded in its turn.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(await snapshot(tester), equals(afterEdit));
  });

  testWidgets('BufferLine.version tracks every kind of cell change',
      (tester) async {
    final terminal = Terminal();
    await pumpTerminal(tester, terminal);

    final line = terminal.buffer.lines[0];

    void expectBumped(String description, void Function() change) {
      final before = line.version;
      change();
      expect(
        line.version,
        greaterThan(before),
        reason: '$description should invalidate a recorded line',
      );
    }

    expectBumped('setContent', () => line.setContent(0, 0x41));
    expectBumped('setForeground', () => line.setForeground(0, 1));
    expectBumped('setBackground', () => line.setBackground(0, 1));
    expectBumped('setAttributes', () => line.setAttributes(0, 1));
    expectBumped('setCodePoint', () => line.setCodePoint(1, 0x42));
    expectBumped(
      'setCell',
      () => line.setCell(2, 0x43, 1, CursorStyle.empty),
    );
    expectBumped('eraseCell', () => line.eraseCell(2, CursorStyle.empty));
    expectBumped('resetCell', () => line.resetCell(2));
    expectBumped(
      'eraseRange',
      () => line.eraseRange(0, 3, CursorStyle.empty),
    );
    expectBumped('insertCells', () => line.insertCells(0, 2));
    expectBumped('removeCells', () => line.removeCells(0, 2));
    expectBumped('resize', () => line.resize(line.length + 1));
  });
}

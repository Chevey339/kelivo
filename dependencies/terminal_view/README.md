# terminal_view

A terminal emulator widget for Flutter. Give it bytes from a shell, an SSH
channel or a PTY, and it draws a real terminal: VT100/xterm escape sequences,
scrollback, selection, mouse reporting and IME input.

Built for phones first. The renderer is tuned to keep a busy `tail -f` at
60fps on mid-range Android hardware.

## Install

```yaml
dependencies:
  terminal_view: ^0.1.0
```

## Use

Create a terminal, hand it to the widget, and write to it:

```dart
import 'package:flutter/material.dart';
import 'package:terminal_view/terminal_view.dart';

final terminal = Terminal();

// Everything the user types arrives here. Send it to your shell or SSH channel.
terminal.onOutput = (data) => channel.write(data);

// Everything the far end sends goes back in.
terminal.write('Hello, world!\r\n');

// ...
Widget build(BuildContext context) => TerminalView(terminal);
```

`Terminal` is the emulator and holds no Flutter dependency, so it can run in an
isolate or be tested on its own. `TerminalView` is the widget that paints it.

### Selection and the clipboard

Selection is driven by a `TerminalController`:

```dart
final controller = TerminalController();

TerminalView(terminal, controller: controller);

// Later:
final range = controller.selection;
final text = range == null ? null : terminal.buffer.getText(range);
controller.clearSelection();
```

A long press starts a word selection, and a drag extends it. Blank cells and
empty lines can be selected too, so a selection can start anywhere on screen
and be adjusted from there.

### Theming

```dart
TerminalView(
  terminal,
  theme: TerminalThemes.defaultTheme,
  textStyle: const TerminalStyle(fontSize: 14, fontFamily: 'JetBrainsMono'),
  cursorType: TerminalCursorType.block,
  blinkInterval: const Duration(milliseconds: 600),
)
```

`TerminalTheme` and `TerminalStyle` compare by value, so rebuilding one inline
on every frame does not throw away the glyph cache.

## Example

`example/` is a single-file app that wires `TerminalView` to a toy shell
written in Dart, so it runs anywhere without a PTY:

```bash
cd example && flutter run
```

## Benchmarks

The emulator core has no Flutter dependency, so its throughput can be measured
on the plain Dart VM:

```bash
dart run benchmark/terminal_benchmark.dart
```

Each case writes a few MiB of a different shape of output into a fresh
terminal and reports the median of ten runs. On a desktop VM:

```
benchmark            median      throughput
--------------------------------------------
plain ascii           107.23 ms     37.3 MB/s
sgr colors            121.22 ms     33.0 MB/s
cursor moves           47.37 ms     42.2 MB/s
alt screen repaint     42.21 ms     47.4 MB/s
wide chars             41.55 ms     24.1 MB/s
scrollback churn       41.82 ms     47.8 MB/s
buffer getText         11.34 ms     56.0 MB/s
```

These cover parsing and buffer work only. Painting needs a Flutter binding and
is not measured here.

## Relationship to xterm.dart

This is a fork of [xterm.dart] 4.0.0. The parser, buffer and input handling
come from there and keep working the same way. What changed:

- Terminal writes are coalesced per frame instead of per chunk, and chunks are
  parsed in place rather than expanded into rune lists first.
- Neighbouring cells that share a style are drawn as one paragraph, and
  neighbouring backgrounds as one rect.
- Lines that stop changing are recorded as `Picture`s and replayed.
- The cursor blinks from the render object, so it repaints instead of
  rebuilding the widget tree and flushing the glyph cache.
- Selection can start on blank cells, and dragging either selection handle
  keeps both ends inclusive.

The public API is close enough that porting is mostly changing the import,
but it is not a drop-in replacement and versions are numbered separately.

## License

MIT. See [LICENSE](LICENSE) for the full text and [NOTICE](NOTICE) for the
fork's attribution.

[xterm.dart]: https://github.com/TerminalStudio/xterm.dart

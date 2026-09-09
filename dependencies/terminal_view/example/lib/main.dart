// The smallest useful terminal_view app: a terminal widget wired to a toy
// shell that runs in Dart. Swap _Shell for a PTY or an SSH channel and the
// rest of this file stays the same.

import 'package:flutter/material.dart';
import 'package:terminal_view/terminal_view.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'terminal_view demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const TerminalPage(),
    );
  }
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final terminal = Terminal(maxLines: 10000);
  final controller = TerminalController();
  late final _Shell shell;

  @override
  void initState() {
    super.initState();
    shell = _Shell(terminal);
    // Whatever the user types arrives here.
    terminal.onOutput = shell.onInput;
    shell.start();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('terminal_view'),
        actions: [
          IconButton(
            tooltip: 'Copy selection',
            icon: const Icon(Icons.copy),
            onPressed: _copySelection,
          ),
        ],
      ),
      body: SafeArea(
        child: TerminalView(
          terminal,
          controller: controller,
          autofocus: true,
          padding: const EdgeInsets.all(8),
          textStyle: const TerminalStyle(fontSize: 13),
          blinkInterval: const Duration(milliseconds: 600),
        ),
      ),
    );
  }

  void _copySelection() {
    final selection = controller.selection;
    final text = selection == null ? null : terminal.buffer.getText(selection);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          text == null || text.isEmpty
              ? 'Nothing selected. Long press the terminal to select.'
              : 'Selected ${text.length} characters',
        ),
      ),
    );
    controller.clearSelection();
  }
}

/// A toy shell. It echoes what is typed, edits the current line, and answers a
/// handful of commands, which is enough to show the terminal doing its job.
class _Shell {
  _Shell(this.terminal);

  final Terminal terminal;
  var _line = '';

  void start() {
    terminal.write(
      '\x1b[1;36mterminal_view\x1b[0m demo shell\r\n'
      'Type \x1b[1mhelp\x1b[0m for the list of commands.\r\n\r\n',
    );
    _prompt();
  }

  void onInput(String data) {
    for (final rune in data.runes) {
      switch (rune) {
        case 0x0d: // Enter
          terminal.write('\r\n');
          _execute(_line.trim());
          _line = '';
          _prompt();
        case 0x7f: // Backspace
          if (_line.isEmpty) break;
          _line = _line.substring(0, _line.length - 1);
          // Step back, overwrite with a space, step back again.
          terminal.write('\b \b');
        case 0x03: // Ctrl+C
          terminal.write('^C\r\n');
          _line = '';
          _prompt();
        default:
          if (rune < 0x20) break;
          final char = String.fromCharCode(rune);
          _line += char;
          terminal.write(char);
      }
    }
  }

  void _prompt() => terminal.write('\x1b[32m\$\x1b[0m ');

  void _execute(String command) {
    switch (command) {
      case '':
        return;
      case 'help':
        terminal.write(
          'help     this text\r\n'
          'colors   the 16 ANSI colors\r\n'
          'date     the current time\r\n'
          'clear    clear the screen\r\n',
        );
      case 'colors':
        for (var row = 0; row < 2; row++) {
          for (var column = 0; column < 8; column++) {
            final color = 30 + column + (row == 1 ? 60 : 0);
            terminal.write('\x1b[${color}m  ██  \x1b[0m');
          }
          terminal.write('\r\n');
        }
      case 'date':
        terminal.write('${DateTime.now()}\r\n');
      case 'clear':
        terminal.write('\x1b[2J\x1b[H');
      default:
        terminal.write('\x1b[31m$command: command not found\x1b[0m\r\n');
    }
  }
}

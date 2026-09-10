import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/mcp/stdio_arguments.dart';

void main() {
  test('plain arguments stay compact', () {
    expect(
      StdioArguments.format(['-y', '@modelcontextprotocol/server-filesystem']),
      '-y @modelcontextprotocol/server-filesystem',
    );
    expect(StdioArguments.parse('  -y   server  '), ['-y', 'server']);
  });
  test('round trips empty, multiline, escaped and Windows path arguments', () {
    const args = [
      '',
      '--yes',
      '  a b ',
      "it's",
      '"quoted"',
      '\n\r\n',
      r'C:\Users\My Files',
      r'$HOME',
      r'\',
      '中文 😀',
    ];
    expect(StdioArguments.parse(StdioArguments.format(args)), args);
    for (final arg in args) {
      expect(StdioArguments.parse(StdioArguments.format([arg])), [arg]);
    }
  });
  test(
    'supports adjacent quotes and escapes without expanding shell expressions',
    () {
      expect(
        StdioArguments.parse(
          r'''--yes "a b" '' c\ d pre"fix" '$HOME' "a\qb"''',
        ),
        ['--yes', 'a b', '', 'c d', 'prefix', r'$HOME', r'a\qb'],
      );
    },
  );
  test('rejects incomplete input without guessing at an argument', () {
    for (final text in ['"unfinished', "'unfinished", 'unfinished\\']) {
      expect(() => StdioArguments.parse(text), throwsFormatException);
    }
  });
}

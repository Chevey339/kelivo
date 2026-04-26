import 'package:mcp_client/src/transport/stdio_launch.dart';
import 'package:test/test.dart';

void main() {
  group('needsWindowsCmdWrapper', () {
    test('returns false when not running on Windows', () {
      expect(needsWindowsCmdWrapper('npx', isWindows: false), isFalse);
      expect(needsWindowsCmdWrapper('tool.cmd', isWindows: false), isFalse);
    });

    test('matches Windows shim commands case-insensitively', () {
      expect(needsWindowsCmdWrapper('npx', isWindows: true), isTrue);
      expect(needsWindowsCmdWrapper('Npm', isWindows: true), isTrue);
      expect(needsWindowsCmdWrapper('UV', isWindows: true), isTrue);
      expect(needsWindowsCmdWrapper('UvX', isWindows: true), isTrue);
    });

    test('matches batch file extensions case-insensitively', () {
      expect(needsWindowsCmdWrapper('server.CMD', isWindows: true), isTrue);
      expect(needsWindowsCmdWrapper('server.Bat', isWindows: true), isTrue);
      expect(needsWindowsCmdWrapper('server.exe', isWindows: true), isFalse);
    });
  });

  group('resolveStdioLaunch', () {
    test('wraps Windows shim commands with cmd.exe', () {
      final plan = resolveStdioLaunch('NPX', ['-y', 'pkg'], isWindows: true);

      expect(plan.executableCommand, 'cmd.exe');
      expect(plan.effectiveArgs, ['/c', 'NPX', '-y', 'pkg']);
    });

    test('leaves regular commands unchanged', () {
      final plan = resolveStdioLaunch(
        'python',
        ['-m', 'module'],
        isWindows: true,
      );

      expect(plan.executableCommand, 'python');
      expect(plan.effectiveArgs, ['-m', 'module']);
    });
  });
}

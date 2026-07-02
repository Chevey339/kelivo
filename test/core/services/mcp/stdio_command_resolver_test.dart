import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/services/mcp/stdio_command_resolver.dart';

void main() {
  group('mergePathValues', () {
    test('keeps the first occurrence and removes empty entries', () {
      final merged = mergePathValues(
        <String?>[r'C:\Tools;;C:\Node', r'c:\tools;D:\Bin', null],
        separator: ';',
        caseSensitive: false,
      );

      expect(merged, r'C:\Tools;C:\Node;D:\Bin');
    });
  });

  group('McpStdioCommandResolver.resolveEnvironmentWithPath', () {
    test('leaves a user-provided Windows Path key untouched', () async {
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        platformEnvironment: const {'PATH': r'C:\Platform'},
        windowsMachinePathReader: () async => r'C:\Machine',
        windowsUserPathReader: () async => r'C:\User',
      );

      final resolved = await resolver.resolveEnvironmentWithPath(const {
        'Path': r'C:\Custom',
      });

      expect(resolved, const {'Path': r'C:\Custom'});
    });

    test('merges current, machine, and user PATH on Windows', () async {
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        platformEnvironment: const {'Path': r'C:\Current;C:\Shared'},
        windowsMachinePathReader: () async => r'C:\Machine;C:\Shared',
        windowsUserPathReader: () async => r'C:\User',
      );

      final resolved = await resolver.resolveEnvironmentWithPath(const {});

      expect(resolved['PATH'], r'C:\Current;C:\Shared;C:\Machine;C:\User');
    });

    test('uses launchctl PATH on macOS', () async {
      final resolver = McpStdioCommandResolver(
        isWindows: false,
        isMacOS: true,
        macOSPathReader: () async => '/usr/local/bin:/usr/bin',
      );

      final resolved = await resolver.resolveEnvironmentWithPath(const {});

      expect(resolved['PATH'], '/usr/local/bin:/usr/bin');
    });
  });

  group('McpStdioCommandResolver.commandExists', () {
    test('checks full Windows command paths with the filesystem', () async {
      var pathLookupCount = 0;
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        fileExists: (path) => path == r'C:\Program Files\nodejs\npx.cmd',
        commandOnPathExists: (_, _) async {
          pathLookupCount += 1;
          return false;
        },
      );

      final exists = await resolver.commandExists(
        r'C:\Program Files\nodejs\npx.cmd',
        const {},
      );

      expect(exists, isTrue);
      expect(pathLookupCount, 0);
    });

    test('tries PATHEXT variants for full Windows paths without extension', () {
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        fileExists: (path) => path == r'C:\Tools\server.cmd',
      );

      expect(
        resolver.commandExists(r'C:\Tools\server', const {
          'PATHEXT': '.EXE;.CMD',
        }),
        completion(isTrue),
      );
    });

    test('uses PATH lookup for bare Windows commands', () async {
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        commandOnPathExists: (command, environment) async {
          return command == 'npx' &&
              environment['PATH'] == r'C:\Program Files\nodejs';
        },
      );

      final exists = await resolver.commandExists('npx', const {
        'PATH': r'C:\Program Files\nodejs',
      });

      expect(exists, isTrue);
    });

    test('returns false for missing command paths', () async {
      final resolver = McpStdioCommandResolver(
        isWindows: true,
        isMacOS: false,
        fileExists: (_) => false,
      );

      final exists = await resolver.commandExists(
        r'C:\Missing\npx.cmd',
        const {},
      );

      expect(exists, isFalse);
    });
  });
}

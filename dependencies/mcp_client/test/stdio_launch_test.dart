@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:mcp_client/src/transport/stdio_launch.dart';
import 'package:test/test.dart';

void main() {
  group('needsWindowsPathResolution', () {
    test('returns false off Windows', () {
      expect(needsWindowsPathResolution('npx', isWindows: false), isFalse);
      expect(needsWindowsPathResolution('tool.cmd', isWindows: false), isFalse);
    });

    test('matches common Windows package manager shims', () {
      expect(needsWindowsPathResolution('npx', isWindows: true), isTrue);
      expect(needsWindowsPathResolution('NPM', isWindows: true), isTrue);
      expect(needsWindowsPathResolution('uv', isWindows: true), isTrue);
      expect(needsWindowsPathResolution('UVX', isWindows: true), isTrue);
    });

    test('matches batch file extensions case-insensitively', () {
      expect(needsWindowsPathResolution('server.CMD', isWindows: true), isTrue);
      expect(needsWindowsPathResolution('server.Bat', isWindows: true), isTrue);
      expect(
        needsWindowsPathResolution('server.exe', isWindows: true),
        isFalse,
      );
    });
  });

  group('resolveWindowsExecutablePath', () {
    test('finds shim command using PATH and PATHEXT', () {
      final resolved = resolveWindowsExecutablePath(
        'npx',
        path: r'C:\Tools;C:\Program Files\nodejs',
        pathExt: '.COM;.EXE;.CMD;.BAT',
        isWindows: true,
        fileExists: (path) => path == r'C:\Program Files\nodejs\npx.cmd',
      );

      expect(resolved, r'C:\Program Files\nodejs\npx.cmd');
    });

    test('accepts an existing absolute command path', () {
      final resolved = resolveWindowsExecutablePath(
        r'C:\Program Files\nodejs\npx.cmd',
        isWindows: true,
        fileExists: (path) => path == r'C:\Program Files\nodejs\npx.cmd',
      );

      expect(resolved, r'C:\Program Files\nodejs\npx.cmd');
    });

    test('returns null for a missing absolute command path', () {
      final resolved = resolveWindowsExecutablePath(
        r'C:\Missing\npx.cmd',
        isWindows: true,
        fileExists: (_) => false,
      );

      expect(resolved, isNull);
    });

    test('tries PATHEXT variants for absolute paths without extension', () {
      final resolved = resolveWindowsExecutablePath(
        r'C:\Tools\server',
        pathExt: '.EXE;.CMD',
        isWindows: true,
        fileExists: (path) => path == r'C:\Tools\server.cmd',
      );

      expect(resolved, r'C:\Tools\server.cmd');
    });
  });

  group('resolveStdioLaunch', () {
    test('leaves non-Windows launch unchanged', () {
      final plan = resolveStdioLaunch('npx', ['-y', 'pkg'], isWindows: false);

      expect(plan.executableCommand, 'npx');
      expect(plan.effectiveArgs, ['-y', 'pkg']);
    });

    test('resolves Windows shim commands before launch', () {
      final plan = resolveStdioLaunch(
        'npx',
        ['-y', 'pkg'],
        environment: const {'PATH': r'C:\Program Files\nodejs'},
        isWindows: true,
        resolveWindowsPath:
            (command, {path, pathExt, isWindows}) =>
                r'C:\Program Files\nodejs\npx.cmd',
      );

      expect(plan.executableCommand, r'C:\Program Files\nodejs\npx.cmd');
      expect(plan.effectiveArgs, ['-y', 'pkg']);
    });

    test(
      'bypasses npm shims when the npm CLI entrypoint is available',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'mcp_npm_shim_test_',
        );
        try {
          final cliDir = Directory('${tempDir.path}\\node_modules\\npm\\bin');
          await cliDir.create(recursive: true);
          final shim = File('${tempDir.path}\\npx.cmd');
          final cli = File('${cliDir.path}\\npx-cli.js');
          await shim.writeAsString(
            '@echo off\r\n'
            'node "%~dp0\\node_modules\\npm\\bin\\npx-cli.js" %*\r\n',
          );
          await cli.writeAsString('void main() {}\n');

          final plan = resolveStdioLaunch(
            'npx',
            ['A&B', 'C|D', 'E>F', '<x'],
            environment: {'PATH': tempDir.path},
            isWindows: true,
          );

          expect(plan.executableCommand, 'node');
          expect(plan.effectiveArgs, [cli.path, 'A&B', 'C|D', 'E>F', '<x']);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
      skip: !Platform.isWindows,
    );

    test(
      'does not bypass custom scripts only named like npm shims',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'mcp_custom_npm_shim_test_',
        );
        try {
          final cliDir = Directory('${tempDir.path}\\node_modules\\npm\\bin');
          await cliDir.create(recursive: true);
          final shim = File('${tempDir.path}\\npx.cmd');
          final cli = File('${cliDir.path}\\npx-cli.js');
          await shim.writeAsString('@echo off\r\necho custom %*\r\n');
          await cli.writeAsString('void main() {}\n');

          final plan = resolveStdioLaunch(
            'npx',
            ['A&B'],
            environment: {'PATH': tempDir.path},
            isWindows: true,
          );

          expect(plan.executableCommand, shim.path);
          expect(plan.effectiveArgs, ['A^^^&B']);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
      skip: !Platform.isWindows,
    );

    test('escapes cmd metacharacters for Windows batch shims', () {
      final plan = resolveStdioLaunch(
        'tool.cmd',
        ['A&B', 'C|D', 'E>F', '<x', 'two & words'],
        isWindows: true,
        resolveWindowsPath:
            (command, {path, pathExt, isWindows}) => r'C:\Tools\tool.cmd',
      );

      expect(plan.executableCommand, r'C:\Tools\tool.cmd');
      expect(plan.effectiveArgs, [
        'A^^^&B',
        'C^^^|D',
        'E^^^>F',
        '^^^<x',
        'two & words',
      ]);
    });

    test(
      'rejects unsafe batch arguments that cannot be forwarded losslessly',
      () {
        expect(
          () => resolveStdioLaunch(
            'tool.cmd',
            [r'value %APPDATA%'],
            isWindows: true,
            resolveWindowsPath:
                (command, {path, pathExt, isWindows}) => r'C:\Tools\tool.cmd',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('does not escape regular executables', () {
      final plan = resolveStdioLaunch(
        'python',
        ['-m', 'server', 'A&B'],
        isWindows: true,
        resolveWindowsPath:
            (command, {path, pathExt, isWindows}) => r'C:\Python\python.exe',
      );

      expect(plan.executableCommand, r'C:\Python\python.exe');
      expect(plan.effectiveArgs, ['-m', 'server', 'A&B']);
    });
  });

  group('escapeWindowsBatchArgument', () {
    test('escapes shell metacharacters without changing ordinary text', () {
      expect(
        escapeWindowsBatchArgument('A&B|C<D>E(F)G^H'),
        'A^^^&B^^^|C^^^<D^^^>E^^^(F^^^)G^^^^H',
      );
      expect(escapeWindowsBatchArgument('two words'), 'two words');
      expect(escapeWindowsBatchArgument('two & words'), 'two & words');
    });

    test(
      'escapes environment variable expansion without changing URL escapes',
      () {
        expect(escapeWindowsBatchArgument('%APPDATA%'), '^^^%APPDATA^^^%');
        expect(escapeWindowsBatchArgument('%A%-%B%'), '^^^%A^^^%-^^^%B^^^%');
        expect(
          escapeWindowsBatchArgument(r'value %APPDATA%'),
          r'value ^%APPDATA^%',
        );
        expect(escapeWindowsBatchArgument('a%20b'), 'a%20b');
      },
    );
  });

  group('Windows batch integration', () {
    test(
      'forwards metacharacters through a real %* batch shim',
      () async {
        final args = <String>[
          'A&B',
          'C|D',
          'E>F',
          '<x',
          'two & words',
          'A(B)',
          'A^B',
          r'%APPDATA%:%USERPROFILE%',
          'a%20b',
        ];

        final forwardedArgs = await _runForwardingBatch(args);

        expect(forwardedArgs, args);
      },
      skip: !Platform.isWindows,
    );
  });
}

Future<List<String>> _runForwardingBatch(List<String> arguments) async {
  final tempDir = await Directory.systemTemp.createTemp(
    'mcp_batch_forward_test_',
  );
  try {
    final captureScript = File('${tempDir.path}\\capture.dart');
    await captureScript.writeAsString('''
import 'dart:convert';

void main(List<String> args) {
  print(jsonEncode(args));
}
''');

    final batchFile = File('${tempDir.path}\\forward.cmd');
    await batchFile.writeAsString(
      '@echo off\r\n'
      '"${Platform.resolvedExecutable}" "${captureScript.path}" %*\r\n',
      encoding: latin1,
    );

    final plan = resolveStdioLaunch(
      batchFile.path,
      arguments,
      isWindows: true,
      resolveWindowsPath: (command, {path, pathExt, isWindows}) => command,
    );
    final result = await Process.run(
      plan.executableCommand,
      plan.effectiveArgs,
      workingDirectory: tempDir.path,
    );

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    final decoded = jsonDecode((result.stdout as String).trim()) as List;
    return decoded.map((entry) => entry as String).toList();
  } finally {
    await tempDir.delete(recursive: true);
  }
}

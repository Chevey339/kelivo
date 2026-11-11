import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/workspace/desktop_shell.dart';

String decodeCommand(List<String> args) {
  final bytes = base64Decode(args.last);
  final data = ByteData.sublistView(bytes);
  return String.fromCharCodes([
    for (var i = 0; i < bytes.length; i += 2) data.getUint16(i, Endian.little),
  ]);
}

void main() {
  const alias = r'C:\Users\test\AppData\Local\Microsoft\WindowsApps\pwsh.exe';
  const pwsh = r'C:\Program Files\PowerShell\7\pwsh.exe';
  const legacy = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';

  test('runs Store aliases without rejecting their file existence', () async {
    final calls = <String>[];
    final resolver = DesktopShellResolver(
      windows: true,
      environment: const {},
      runProcess: (exe, args) async {
        calls.add(exe);
        if (exe == 'where.exe') {
          expect(args, ['pwsh']);
          return ProcessResult(1, 0, '$alias\r\n', '');
        }
        expect(exe, alias);
        expect(decodeCommand(args), contains(r'$PSVersionTable.PSVersion'));
        return ProcessResult(2, 0, '7.6.9\r\n', '');
      },
    );
    final shell = await resolver.resolve();
    expect(shell.executable, alias);
    expect(shell.version, '7.6.9');
    expect(shell.syntaxHint, contains('Chain with &&.'));
    expect(calls, ['where.exe', alias]);
  });

  test(
    'tries later pwsh matches before falling back to Windows PowerShell',
    () async {
      final resolver = DesktopShellResolver(
        windows: true,
        runProcess: (exe, args) async {
          if (exe == 'where.exe') {
            return ProcessResult(1, 0, '$alias\r\n$pwsh\r\n', '');
          }
          if (exe == alias) throw ProcessException(exe, args);
          expect(exe, pwsh);
          return ProcessResult(2, 0, '7.6.9', '');
        },
      );
      expect((await resolver.resolve()).executable, pwsh);
    },
  );

  test('fallback records PowerShell 5.1 syntax and version', () async {
    final resolver = DesktopShellResolver(
      windows: true,
      environment: const {},
      runProcess: (exe, args) async {
        if (exe == 'where.exe') {
          return args.single == 'pwsh'
              ? ProcessResult(1, 1, '', '')
              : ProcessResult(1, 0, legacy, '');
        }
        return ProcessResult(2, 0, '5.1.19041.1', '');
      },
    );
    final shell = await resolver.resolve();
    expect(shell.executable, legacy);
    expect(shell.syntaxHint, contains('Do not use && or ||'));
    expect(shell.environmentReference, r'$env:NAME');
  });

  test(
    'custom path with spaces is invoked directly and preserves command text',
    () async {
      final resolver = DesktopShellResolver(
        windows: true,
        runProcess: (exe, args) async {
          expect(exe, pwsh);
          return ProcessResult(1, 0, '7.6.9', '');
        },
      );
      final shell = await resolver.resolve(pwsh);
      const command =
          r'''$text = '中文 😀'; Write-Output "$text"; foreach ($n in @("a", "b")) { $n }''';
      final args = shell.arguments(command);
      expect(args, contains('-EncodedCommand'));
      expect(decodeCommand(args), endsWith(command));
    },
  );

  test('invalid configured path never silently falls back', () async {
    var calls = 0;
    final resolver = DesktopShellResolver(
      windows: true,
      runProcess: (exe, args) async {
        calls++;
        throw ProcessException(exe, args);
      },
    );
    await expectLater(resolver.resolve(pwsh), throwsA(isA<ProcessException>()));
    expect(calls, 1);
    await expectLater(resolver.resolve('pwsh.exe'), throwsFormatException);
    expect(calls, 1);
  });

  test('cmd uses cmd arguments and environment references', () async {
    const path = r'C:\Windows\System32\cmd.exe';
    final resolver = DesktopShellResolver(
      windows: true,
      runProcess: (exe, args) async {
        expect(exe, path);
        expect(args.take(3), ['/d', '/s', '/c']);
        return ProcessResult(1, 0, 'kelivo-shell-ready\r\n', '');
      },
    );
    final shell = await resolver.resolve(path);
    expect(shell.kind, DesktopShellKind.cmd);
    expect(shell.environmentReference, '%NAME%');
  });

  test(
    'Unix detection uses the configured login shell and probes -lc',
    () async {
      final resolver = DesktopShellResolver(
        windows: false,
        environment: const {'SHELL': '/bin/zsh'},
        runProcess: (exe, args) async {
          expect(exe, '/bin/zsh');
          expect(args.first, '-lc');
          return ProcessResult(1, 0, 'kelivo-shell-ready', '');
        },
      );
      final shell = await resolver.resolve();
      expect(shell.name, 'zsh');
      expect(shell.environmentReference, r'$NAME');
    },
  );

  test(
    'probe timeout stops background descendants after the shell exits',
    () async {
      final temp = await Directory.systemTemp.createTemp('kelivo_shell_probe_');
      final script = File('${temp.path}/shell');
      final pidFile = File('${script.path}.pid');
      int? child;
      try {
        await script.writeAsString(r'''#!/bin/sh
sleep 30 &
echo $! > "$0.pid"
printf '%s' 'kelivo-shell-ready'
''');
        await Process.run('/bin/chmod', ['+x', script.path]);
        await expectLater(
          DesktopShellResolver().resolve(script.path),
          throwsA(isA<TimeoutException>()),
        );
        child = int.parse((await pidFile.readAsString()).trim());
        final state = await Process.run('/bin/ps', [
          '-p',
          '$child',
          '-o',
          'stat=',
        ]);
        final status = state.stdout.toString().trim();
        expect(
          status.isEmpty || status.startsWith('Z'),
          isTrue,
          reason: 'probe left child $child running: $status',
        );
      } finally {
        if (child != null) Process.killPid(child, ProcessSignal.sigkill);
        await temp.delete(recursive: true);
      }
    },
    skip: !(Platform.isMacOS || Platform.isLinux),
  );

  test(
    'validation rejects executables that cannot run shell commands',
    () async {
      final resolver = DesktopShellResolver(
        windows: false,
        runProcess: (exe, args) async => ProcessResult(1, 0, 'not a shell', ''),
      );
      await expectLater(
        resolver.resolve('/usr/bin/true'),
        throwsA(isA<ProcessException>()),
      );
    },
  );
}

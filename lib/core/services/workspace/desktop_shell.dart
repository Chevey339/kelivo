import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'desktop_process.dart';

enum DesktopShellKind { posix, powerShell, cmd }

/// The executable and syntax used by the native workspace command runner.
class DesktopShell {
  const DesktopShell(this.executable, this.kind, {this.version});

  final String executable;
  final DesktopShellKind kind;
  final String? version;

  String get name => switch (kind) {
    DesktopShellKind.powerShell => 'PowerShell ${version ?? ''}'.trim(),
    DesktopShellKind.cmd => 'cmd.exe',
    DesktopShellKind.posix => p.posix.basename(
      executable.replaceAll('\\', '/'),
    ),
  };

  String get invocation => '$name (${jsonEncode(executable)})';

  String get syntaxHint => switch (kind) {
    DesktopShellKind.powerShell =>
      'Use PowerShell syntax. ${_supportsPipelineChains ? 'Chain with &&.' : 'Do not use && or ||; use ; and if (\$?) for conditional execution.'} '
          'Do not wrap commands in another powershell or pwsh invocation.',
    DesktopShellKind.cmd => 'Use cmd.exe syntax. Chain with &&.',
    DesktopShellKind.posix => 'Use $name syntax.',
  };

  bool get _supportsPipelineChains =>
      (int.tryParse(version?.split('.').first ?? '') ?? 0) >= 7;

  String get environmentReference => switch (kind) {
    DesktopShellKind.powerShell => r'$env:NAME',
    DesktopShellKind.cmd => '%NAME%',
    DesktopShellKind.posix => r'$NAME',
  };

  List<String> arguments(String command) => switch (kind) {
    DesktopShellKind.posix => ['-lc', command],
    DesktopShellKind.cmd => ['/d', '/s', '/c', 'chcp 65001>nul && $command'],
    DesktopShellKind.powerShell => [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-EncodedCommand',
      _encodePowerShell(command),
    ],
  };

  static String _encodePowerShell(String command) {
    const preamble =
        r'[Console]::OutputEncoding=[Text.Encoding]::UTF8; $OutputEncoding=[Text.Encoding]::UTF8; ';
    final units = '$preamble$command'.codeUnits;
    final bytes = Uint8List(units.length * 2);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < units.length; i++) {
      data.setUint16(i * 2, units[i], Endian.little);
    }
    return base64Encode(bytes);
  }
}

class DesktopShellResolver {
  DesktopShellResolver({
    bool? windows,
    Map<String, String>? environment,
    Future<ProcessResult> Function(String, List<String>)? runProcess,
  }) : windows = windows ?? Platform.isWindows,
       environment = environment ?? Platform.environment,
       _runProcess = runProcess ?? _runProbe;

  final bool windows;
  final Map<String, String> environment;
  final Future<ProcessResult> Function(String, List<String>) _runProcess;

  p.Context get _paths =>
      p.Context(style: windows ? p.Style.windows : p.Style.posix);

  Future<DesktopShell> resolve([String configuredPath = '']) async {
    final path = configuredPath.trim();
    if (path.isNotEmpty) {
      if (!_paths.isAbsolute(path) ||
          path.contains('\u0000') ||
          path.contains('\n') ||
          path.contains('\r')) {
        throw const FormatException('Enter an absolute shell executable path.');
      }
      // A configured path is authoritative. Never silently use another shell.
      return _probe(path);
    }
    final candidates = windows
        ? ['pwsh', 'powershell', 'cmd']
        : [
            if (environment['SHELL']?.isNotEmpty == true) environment['SHELL']!,
            '/bin/bash',
            '/bin/sh',
          ];
    for (final candidate in candidates) {
      final executables = _paths.isAbsolute(candidate)
          ? [candidate]
          : await findExecutables(candidate);
      for (final executable in executables) {
        try {
          return await _probe(executable);
        } on Exception {
          // Automatic mode tries the next candidate if this one cannot run.
        }
      }
    }
    throw const ProcessException('', [], 'No usable shell found.');
  }

  Future<DesktopShell> _probe(String executable) async {
    final name = _paths.basenameWithoutExtension(executable).toLowerCase();
    final kind = switch (name) {
      'pwsh' || 'powershell' => DesktopShellKind.powerShell,
      'cmd' => DesktopShellKind.cmd,
      _ => DesktopShellKind.posix,
    };
    final shell = DesktopShell(executable, kind);
    const marker = 'kelivo-shell-ready';
    final command = switch (kind) {
      DesktopShellKind.powerShell => r'$PSVersionTable.PSVersion.ToString()',
      DesktopShellKind.cmd => 'echo $marker',
      DesktopShellKind.posix => "printf '%s' '$marker'",
    };
    final result = await _runProcess(executable, shell.arguments(command));
    final output = result.stdout.toString().trim();
    final version = kind == DesktopShellKind.powerShell
        ? RegExp(
            r'^\d+\.\d+(?:\.\d+)*(?:-[\w.]+)?$',
            multiLine: true,
          ).firstMatch(output)?.group(0)
        : null;
    if (result.exitCode != 0 ||
        (kind == DesktopShellKind.powerShell
            ? version == null
            : !output.endsWith(marker))) {
      throw ProcessException(
        executable,
        [],
        'Shell validation failed.',
        result.exitCode,
      );
    }
    return DesktopShell(executable, kind, version: version);
  }

  Future<String?> findExecutable(String name) async {
    final paths = await findExecutables(name);
    return paths.isEmpty ? null : paths.first;
  }

  Future<List<String>> findExecutables(String name) async {
    try {
      final result = await _runProcess(windows ? 'where.exe' : 'which', [name]);
      if (result.exitCode == 0) {
        // Store app execution aliases can be runnable while File.exists
        // returns false (dart-lang/sdk#64535). The shell probe validates them.
        final paths = result.stdout
            .toString()
            .split(RegExp(r'\r?\n'))
            .map((line) => line.trim())
            .where((path) => path.isNotEmpty && _paths.isAbsolute(path))
            .toList();
        if (paths.isNotEmpty) return paths;
      }
    } on Exception {
      // Search PATH directly if the lookup command is unavailable.
    }
    final paths = <String>[];
    final names = [name];
    if (windows && !name.contains('.')) {
      names.addAll(
        (environment['PATHEXT'] ?? '.EXE;.CMD;.BAT;.COM')
            .split(';')
            .where((e) => e.isNotEmpty)
            .map((ext) => '$name$ext'),
      );
    }
    for (final dir in (environment['PATH'] ?? '').split(windows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      for (final file in names) {
        final candidate = _paths.join(dir, file);
        final type = FileSystemEntity.typeSync(candidate, followLinks: false);
        if (type == FileSystemEntityType.file ||
            type == FileSystemEntityType.link) {
          paths.add(candidate);
        }
      }
    }
    if (windows && name == 'cmd' && paths.isEmpty) {
      paths.add(
        _paths.join(
          environment['SystemRoot'] ?? r'C:\Windows',
          'System32',
          'cmd.exe',
        ),
      );
    }
    return paths;
  }

  static Future<ProcessResult> _runProbe(
    String executable,
    List<String> args,
  ) async {
    final launched = await startDesktopProcess(executable, args);
    final process = launched.process;
    var processExited = false;
    final exit = process.exitCode.then((code) {
      processExited = true;
      return code;
    });
    final output = <int>[];
    final stdout = launched.stdout.listen((bytes) {
      final remaining = 16384 - output.length;
      if (remaining > 0) output.addAll(bytes.take(remaining));
    });
    final stderr = process.stderr.listen((_) {});
    final stdoutDone = stdout.asFuture<void>();
    final stderrDone = stderr.asFuture<void>();
    try {
      if (launched.processGroup != null) {
        process.stdin.writeln();
        await process.stdin.flush();
      }
      await process.stdin.close();
      final result = await Future.wait<Object?>([
        exit,
        stdoutDone,
        stderrDone,
      ]).timeout(const Duration(seconds: 5));
      return ProcessResult(
        process.pid,
        result.first as int,
        executable == 'where.exe'
            ? systemEncoding.decode(output)
            : utf8.decode(output, allowMalformed: true),
        '',
      );
    } finally {
      final group = launched.processGroup;
      if (group != null) {
        await stopDesktopProcessGroup(group);
      } else if (!processExited) {
        try {
          await Process.run('taskkill', ['/T', '/F', '/PID', '${process.pid}']);
        } on Exception {
          process.kill();
        }
      }
      await stdout.cancel();
      await stderr.cancel();
    }
  }
}

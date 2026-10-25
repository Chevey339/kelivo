import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// A real Windows process whose current directory prevents an ancestor move.
class WindowsDirectoryHolder {
  WindowsDirectoryHolder._(this._process, this._release);

  final Process _process;
  final File _release;
  bool _closed = false;

  static Future<WindowsDirectoryHolder> start({
    required Directory directory,
    required Directory controls,
  }) async {
    final ready = File(p.join(controls.path, 'holder-ready'));
    final release = File(p.join(controls.path, 'holder-release'));
    await controls.create(recursive: true);
    String quote(String value) => "'${value.replaceAll("'", "''")}'";
    final script =
        '''
\$ErrorActionPreference = 'Stop'
[Environment]::CurrentDirectory = ${quote(directory.path)}
[IO.File]::WriteAllText(${quote(ready.path)}, 'ready')
\$deadline = [DateTime]::UtcNow.AddMinutes(2)
while (-not [IO.File]::Exists(${quote(release.path)}) -and [DateTime]::UtcNow -lt \$deadline) { Start-Sleep -Milliseconds 50 }
''';
    final encoded = base64Encode([
      for (final unit in script.codeUnits) ...[unit & 255, unit >> 8],
    ]);
    final process = await Process.start('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encoded,
    ], workingDirectory: directory.path);
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final holder = WindowsDirectoryHolder._(process, release);
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (!await ready.exists()) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError('Windows directory holder did not start');
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return holder;
    } catch (_) {
      await holder.close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _release.writeAsString('release');
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill();
      await _process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}

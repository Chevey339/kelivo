// ignore_for_file: prefer_initializing_formals

import 'dart:io' show File, Platform, Process, ProcessResult;

typedef StdioCommandLookup =
    Future<bool> Function(String command, Map<String, String> environment);
typedef StdioPathReader = Future<String?> Function();

class McpStdioCommandResolver {
  McpStdioCommandResolver({
    bool? isWindows,
    bool? isMacOS,
    Map<String, String>? platformEnvironment,
    bool Function(String path)? fileExists,
    StdioCommandLookup? commandOnPathExists,
    StdioPathReader? windowsMachinePathReader,
    StdioPathReader? windowsUserPathReader,
    StdioPathReader? macOSPathReader,
  }) : _isWindowsOverride = isWindows,
       _isMacOSOverride = isMacOS,
       _platformEnvironment = platformEnvironment,
       _fileExists = fileExists,
       _commandOnPathExists = commandOnPathExists,
       _windowsMachinePathReader = windowsMachinePathReader,
       _windowsUserPathReader = windowsUserPathReader,
       _macOSPathReader = macOSPathReader;

  final bool? _isWindowsOverride;
  final bool? _isMacOSOverride;
  final Map<String, String>? _platformEnvironment;
  final bool Function(String path)? _fileExists;
  final StdioCommandLookup? _commandOnPathExists;
  final StdioPathReader? _windowsMachinePathReader;
  final StdioPathReader? _windowsUserPathReader;
  final StdioPathReader? _macOSPathReader;

  String? _cachedSystemPath;
  Future<String?>? _systemPathFuture;

  Future<Map<String, String>> resolveEnvironmentWithPath(
    Map<String, String> userEnv,
  ) async {
    final merged = Map<String, String>.from(userEnv);
    if (_environmentValue(merged, 'PATH') != null) return merged;

    final systemPath = await _getSystemPath();
    if (systemPath != null && systemPath.isNotEmpty) {
      merged['PATH'] = systemPath;
    }
    return merged;
  }

  Future<bool> commandExists(
    String command,
    Map<String, String> environment,
  ) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return false;

    if (_isWindows) {
      if (_looksLikePath(trimmed)) {
        return _windowsPathExists(trimmed, environment);
      }
      return _commandOnPathExistsImpl(trimmed, environment);
    }

    return _commandOnPathExistsImpl(trimmed, environment);
  }

  Future<String?> _getSystemPath() {
    final cachedFuture = _systemPathFuture;
    if (cachedFuture != null) return cachedFuture;

    final future = () async {
      if (_cachedSystemPath != null) return _cachedSystemPath;

      if (_isMacOS) {
        final macOSPath = await (_macOSPathReader ?? _readMacOSLaunchPath)();
        if (macOSPath != null && macOSPath.isNotEmpty) {
          _cachedSystemPath = macOSPath;
          return _cachedSystemPath;
        }
      }

      if (_isWindows) {
        final platformPath = _environmentValue(_environment, 'PATH');
        final machinePath =
            await (_windowsMachinePathReader ??
                () => _readWindowsEnvironmentPath('Machine'))();
        final userPath =
            await (_windowsUserPathReader ??
                () => _readWindowsEnvironmentPath('User'))();
        final path = mergePathValues(
          <String?>[platformPath, machinePath, userPath],
          separator: ';',
          caseSensitive: false,
        );
        if (path.isNotEmpty) {
          _cachedSystemPath = path;
          return _cachedSystemPath;
        }
      }

      return null;
    }();

    _systemPathFuture = future;
    return future;
  }

  Future<bool> _commandOnPathExistsImpl(
    String command,
    Map<String, String> environment,
  ) async {
    final lookup = _commandOnPathExists;
    if (lookup != null) return lookup(command, environment);

    try {
      final result = await Process.run(
        _isWindows ? 'where' : 'which',
        <String>[command],
        environment: environment,
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  bool _windowsPathExists(String command, Map<String, String> environment) {
    final exists = _fileExists ?? ((path) => File(path).existsSync());
    if (exists(command)) return true;

    if (_hasExtension(command)) return false;

    final pathExt =
        _environmentValue(environment, 'PATHEXT') ??
        _environmentValue(_environment, 'PATHEXT');
    for (final extension in _windowsExecutableExtensions(pathExt)) {
      if (exists('$command$extension')) return true;
    }
    return false;
  }

  bool get _isWindows => _isWindowsOverride ?? Platform.isWindows;
  bool get _isMacOS => _isMacOSOverride ?? Platform.isMacOS;

  Map<String, String> get _environment =>
      _platformEnvironment ?? Platform.environment;
}

String mergePathValues(
  Iterable<String?> values, {
  required String separator,
  bool caseSensitive = true,
}) {
  final seen = <String>{};
  final merged = <String>[];

  for (final value in values) {
    if (value == null || value.trim().isEmpty) continue;
    for (final entry in value.split(separator)) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final key = caseSensitive ? trimmed : trimmed.toLowerCase();
      if (seen.add(key)) merged.add(trimmed);
    }
  }

  return merged.join(separator);
}

bool _looksLikePath(String command) {
  return command.contains(r'\') ||
      command.contains('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(command);
}

bool _hasExtension(String command) {
  final fileName = command.split(RegExp(r'[\\/]')).last;
  return fileName.contains('.');
}

String? _environmentValue(Map<String, String> environment, String key) {
  for (final entry in environment.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase()) {
      return entry.value;
    }
  }
  return null;
}

List<String> _windowsExecutableExtensions(String? pathExt) {
  const defaults = <String>['.exe', '.com', '.cmd', '.bat'];
  if (pathExt == null || pathExt.trim().isEmpty) return defaults;

  return <String>{
    ...pathExt
        .split(';')
        .map((entry) => entry.trim().toLowerCase())
        .where((entry) => entry.isNotEmpty),
    ...defaults,
  }.toList();
}

Future<String?> _readMacOSLaunchPath() async {
  try {
    final result = await Process.run('launchctl', <String>['getenv', 'PATH']);
    if (result.exitCode == 0) return (result.stdout as String).trim();
  } catch (_) {}
  return null;
}

Future<String?> _readWindowsEnvironmentPath(String target) async {
  try {
    final result = await Process.run('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      '[Environment]::GetEnvironmentVariable("PATH", "$target")',
    ]);
    return _stdoutIfSuccessful(result);
  } catch (_) {}
  return null;
}

String? _stdoutIfSuccessful(ProcessResult result) {
  if (result.exitCode != 0) return null;
  final stdout = (result.stdout as String).trim();
  return stdout.isEmpty ? null : stdout;
}

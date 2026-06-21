import 'dart:io' show File, Platform;

const List<String> _windowsShimCommands = <String>['npx', 'npm', 'uv', 'uvx'];
const List<String> _windowsExecutableExtensions = <String>[
  '.exe',
  '.com',
  '.cmd',
  '.bat',
];

bool isWindowsBatchCommand(String command, {bool? isWindows}) {
  final resolvedIsWindows = isWindows ?? Platform.isWindows;
  if (!resolvedIsWindows) return false;

  final lower = command.toLowerCase();
  return lower.endsWith('.cmd') || lower.endsWith('.bat');
}

bool needsWindowsPathResolution(String command, {bool? isWindows}) {
  final resolvedIsWindows = isWindows ?? Platform.isWindows;
  if (!resolvedIsWindows) return false;

  final lower = command.toLowerCase();
  return _windowsShimCommands.contains(lower) || isWindowsBatchCommand(command);
}

String escapeWindowsBatchArgument(String argument) {
  final out = StringBuffer();
  final shouldEscapeCommandControls = !_isQuotedByProcessStart(argument);
  for (var index = 0; index < argument.length; index += 1) {
    final char = argument[index];
    if (_isEnvironmentExpansionDelimiter(argument, index)) {
      out.write(shouldEscapeCommandControls ? '^^^' : '^');
    } else if (shouldEscapeCommandControls &&
        (char == '^' ||
            char == '&' ||
            char == '|' ||
            char == '<' ||
            char == '>' ||
            char == '(' ||
            char == ')')) {
      out.write('^^^');
    }
    out.write(char);
  }
  return out.toString();
}

String? resolveWindowsExecutablePath(
  String command, {
  String? path,
  String? pathExt,
  bool? isWindows,
  bool Function(String path)? fileExists,
}) {
  final resolvedIsWindows = isWindows ?? Platform.isWindows;
  if (!resolvedIsWindows) return null;

  final exists = fileExists ?? ((candidate) => File(candidate).existsSync());
  if (_looksLikePath(command)) {
    if (exists(command)) return command;
    if (_hasExtension(command)) return null;

    for (final extension in _windowsExtensionsFor(command, pathExt)) {
      final candidate = '$command$extension';
      if (exists(candidate)) return candidate;
    }
    return null;
  }

  final dirs = _splitPath(
    path ?? _environmentValue(Platform.environment, 'PATH') ?? '',
  );
  final extensions = _windowsExtensionsFor(command, pathExt);
  for (final dir in dirs) {
    for (final extension in extensions) {
      final candidate = _joinWindowsPath(dir, '$command$extension');
      if (exists(candidate)) return candidate;
    }
  }
  return null;
}

({String executableCommand, List<String> effectiveArgs}) resolveStdioLaunch(
  String command,
  List<String> arguments, {
  Map<String, String>? environment,
  bool? isWindows,
  String? Function(
    String command, {
    String? path,
    String? pathExt,
    bool? isWindows,
  })?
  resolveWindowsPath,
}) {
  final resolvedIsWindows = isWindows ?? Platform.isWindows;
  if (!resolvedIsWindows) {
    return (
      executableCommand: command,
      effectiveArgs: List<String>.of(arguments),
    );
  }

  final path =
      environment == null ? null : _environmentValue(environment, 'PATH');
  final pathExt =
      environment == null ? null : _environmentValue(environment, 'PATHEXT');
  final windowsPathResolver =
      resolveWindowsPath ?? resolveWindowsExecutablePath;
  final resolvedCommand =
      windowsPathResolver(
        command,
        path: path,
        pathExt: pathExt,
        isWindows: resolvedIsWindows,
      ) ??
      command;

  if (isWindowsBatchCommand(resolvedCommand, isWindows: resolvedIsWindows)) {
    final npmShimLaunch = _resolveNpmShimLaunch(
      resolvedCommand,
      arguments,
      fileExists: (path) => File(path).existsSync(),
      readBatchFile: (path) => File(path).readAsStringSync(),
    );
    if (npmShimLaunch != null) return npmShimLaunch;

    return (
      executableCommand: resolvedCommand,
      effectiveArgs: _escapeWindowsBatchArguments(arguments),
    );
  }

  return (
    executableCommand: resolvedCommand,
    effectiveArgs: List<String>.of(arguments),
  );
}

bool _looksLikePath(String command) {
  return command.contains(r'\') ||
      command.contains('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(command);
}

List<String> _splitPath(String path) {
  return path
      .split(';')
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

List<String> _windowsExtensionsFor(String command, String? pathExt) {
  if (_hasExtension(command)) return const <String>[''];

  final configured =
      (pathExt == null || pathExt.trim().isEmpty)
          ? _windowsExecutableExtensions
          : pathExt
              .split(';')
              .map((entry) => entry.trim().toLowerCase())
              .where((entry) => entry.isNotEmpty)
              .toList();

  return <String>{...configured, ..._windowsExecutableExtensions}.toList();
}

bool _hasExtension(String command) {
  final fileName = command.split(RegExp(r'[\\/]')).last;
  return fileName.contains('.');
}

String? _environmentValue(Map<String, String> environment, String key) {
  for (final entry in environment.entries) {
    if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
  }
  return null;
}

String _joinWindowsPath(String dir, String fileName) {
  if (dir.endsWith(r'\') || dir.endsWith('/')) return '$dir$fileName';
  return '$dir\\$fileName';
}

List<String> _escapeWindowsBatchArguments(List<String> arguments) {
  return arguments.map((argument) {
    if (_isQuotedByProcessStart(argument) &&
        _containsEnvironmentExpansion(argument)) {
      throw ArgumentError.value(
        argument,
        'arguments',
        'Windows batch files cannot safely forward whitespace arguments '
            'containing %VAR% expansion through %*',
      );
    }
    return escapeWindowsBatchArgument(argument);
  }).toList();
}

bool _isQuotedByProcessStart(String argument) {
  return argument.isEmpty ||
      (argument.contains(RegExp(r'\s')) && !argument.contains('"'));
}

bool _containsEnvironmentExpansion(String argument) {
  for (var index = 0; index < argument.length; index += 1) {
    if (_isEnvironmentExpansionDelimiter(argument, index)) return true;
  }
  return false;
}

bool _isEnvironmentExpansionDelimiter(String argument, int index) {
  if (argument[index] != '%') return false;

  var openingIndex = -1;
  for (
    var currentIndex = 0;
    currentIndex < argument.length;
    currentIndex += 1
  ) {
    if (argument[currentIndex] != '%') continue;

    if (openingIndex < 0) {
      openingIndex = currentIndex;
      continue;
    }

    if (index == openingIndex || index == currentIndex) return true;
    openingIndex = -1;
  }
  return false;
}

({String executableCommand, List<String> effectiveArgs})? _resolveNpmShimLaunch(
  String batchPath,
  List<String> arguments, {
  required bool Function(String path) fileExists,
  required String Function(String path) readBatchFile,
}) {
  final fileName = batchPath.split(RegExp(r'[\\/]')).last.toLowerCase();
  final cliFileName = switch (fileName) {
    'npx.cmd' || 'npx.bat' => 'npx-cli.js',
    'npm.cmd' || 'npm.bat' => 'npm-cli.js',
    _ => null,
  };
  if (cliFileName == null) return null;

  final shimDir = _windowsDirName(batchPath);
  if (shimDir == null) return null;

  String batchContents;
  try {
    batchContents = readBatchFile(batchPath).toLowerCase();
  } catch (_) {
    return null;
  }
  if (!batchContents.contains('%*') ||
      !batchContents.contains(cliFileName.toLowerCase()) ||
      !batchContents.contains('node')) {
    return null;
  }

  final nodePath = _joinWindowsPath(shimDir, 'node.exe');
  final executableCommand = fileExists(nodePath) ? nodePath : 'node';

  final localCliPath = _joinWindowsPath(
    _joinWindowsPath(_joinWindowsPath(shimDir, 'node_modules'), 'npm\\bin'),
    cliFileName,
  );
  if (fileExists(localCliPath)) {
    return (
      executableCommand: executableCommand,
      effectiveArgs: <String>[localCliPath, ...arguments],
    );
  }

  final prefixCliPath = _joinWindowsPath(
    _joinWindowsPath(
      _joinWindowsPath(_windowsDirName(shimDir) ?? shimDir, 'node_modules'),
      'npm\\bin',
    ),
    cliFileName,
  );
  if (fileExists(prefixCliPath)) {
    return (
      executableCommand: executableCommand,
      effectiveArgs: <String>[prefixCliPath, ...arguments],
    );
  }

  return null;
}

String? _windowsDirName(String path) {
  final index = path.lastIndexOf(RegExp(r'[\\/]'));
  if (index <= 0) return null;
  return path.substring(0, index);
}

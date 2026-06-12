import 'dart:io' show Platform;

bool needsWindowsCmdWrapper(String command, {bool? isWindows}) {
  final resolvedIsWindows = isWindows ?? Platform.isWindows;
  if (!resolvedIsWindows) return false;

  final lower = command.toLowerCase();
  return lower.endsWith('.cmd') ||
      lower.endsWith('.bat') ||
      lower == 'npx' ||
      lower == 'npm' ||
      lower == 'uv' ||
      lower == 'uvx';
}

({String executableCommand, List<String> effectiveArgs}) resolveStdioLaunch(
  String command,
  List<String> arguments, {
  bool? isWindows,
}) {
  if (needsWindowsCmdWrapper(command, isWindows: isWindows)) {
    return (
      executableCommand: 'cmd.exe',
      effectiveArgs: ['/c', command, ...arguments],
    );
  }

  return (
    executableCommand: command,
    effectiveArgs: [...arguments],
  );
}

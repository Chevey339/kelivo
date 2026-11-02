import 'package:path/path.dart' as p;

/// Arguments for opening a directory or selecting a file in Windows Explorer.
List<String> windowsExplorerArguments(
  String hostPath, {
  required bool isDirectory,
}) {
  // Explorer requires backslashes even though dart:io accepts mixed separators.
  final path = p.windows.normalize(hostPath);
  // Keep the switch separate so Process.start quotes only paths with spaces.
  return <String>[if (!isDirectory) '/select,', path];
}

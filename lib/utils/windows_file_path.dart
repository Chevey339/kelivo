import 'package:path/path.dart' as p;

/// Match dart:io's long-path handling when calling Win32 file APIs directly.
/// Explicit extended paths work without a manifest/registry opt-in.
String extendedWindowsFilePath(String absolutePath) {
  final path = absolutePath.replaceAll('/', r'\');
  if (path.startsWith(r'\\?\') || path.startsWith(r'\\.\')) return path;
  if (!p.windows.isAbsolute(path) || p.windows.isRootRelative(path)) {
    throw ArgumentError.value(
      absolutePath,
      'absolutePath',
      'Expected an absolute Windows path',
    );
  }
  final normalized = p.windows.normalize(path);
  if (normalized.startsWith(r'\\')) {
    return r'\\?\UNC\' + normalized.substring(2);
  }
  return r'\\?\' + normalized;
}

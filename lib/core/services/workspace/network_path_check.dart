import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Inspect link entries before following them. In particular, resolving a UNC
/// path or a mapped network drive can contact a server before a file is opened.
Future<String?> networkTargetForApproval(String path, String cwd) async {
  var candidate = p.normalize(p.isAbsolute(path) ? path : p.join(cwd, path));
  final seen = <String>{};
  for (var links = 0; links < 40; links++) {
    if (isNetworkPathSyntax(candidate)) return candidate;
    if (!seen.add(candidate)) return null; // The real resolver rejects cycles.
    final parts = p.split(candidate);
    if (parts.isEmpty) return null;
    if (Platform.isWindows && !_localWindowsDrive(parts.first)) {
      return candidate;
    }
    var replaced = false;
    for (var i = 0; i < parts.length; i++) {
      final prefix = p.joinAll(parts.take(i + 1));
      final type = await FileSystemEntity.type(prefix, followLinks: false);
      if (type == FileSystemEntityType.notFound) return null;
      if (type != FileSystemEntityType.link) continue;
      final target = await Link(prefix).target();
      candidate = p.normalize(
        p.join(
          p.isAbsolute(target) ? target : p.join(p.dirname(prefix), target),
          p.joinAll(parts.skip(i + 1)),
        ),
      );
      replaced = true;
      break;
    }
    if (!replaced) return null;
  }
  return candidate; // Do not contact an unresolved target without permission.
}

bool isNetworkPathSyntax(String path) =>
    path.startsWith(r'\\') ||
    path.startsWith('//') ||
    path == '/net' ||
    path.startsWith('/net/');

// GetDriveTypeW is a local volume lookup; no directory on that volume is opened.
// https://learn.microsoft.com/windows/win32/api/fileapi/nf-fileapi-getdrivetypew
final _getDriveType = DynamicLibrary.open('kernel32.dll')
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetDriveTypeW');

bool _localWindowsDrive(String root) {
  final native = (root.endsWith(r'\') ? root : '$root\\').toNativeUtf16();
  try {
    final type = _getDriveType(native);
    return type == 2 || type == 3 || type == 5 || type == 6;
  } finally {
    malloc.free(native);
  }
}

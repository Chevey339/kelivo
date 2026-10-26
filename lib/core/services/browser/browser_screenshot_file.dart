import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import '../../../utils/windows_file_path.dart';

/// Publish a complete file without opening, following or replacing the target
/// leaf. Dart's rename replaces existing targets on POSIX, and create(exclusive)
/// followed by writeAsBytes reopens a path that another process can replace.
/// Source and destination must be on the same filesystem. Metadata work also
/// stays off the UI isolate (a workspace may live on a slow external volume).
Future<void> publishBrowserScreenshot(String source, String target) =>
    Isolate.run(() => _publish(source, target));

void _publish(String source, String target) {
  final library = Platform.isWindows
      ? DynamicLibrary.open('kernel32.dll')
      : DynamicLibrary.process();
  final code = using((arena) {
    if (Platform.isWindows) {
      final move = library
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, Pointer<Utf16>, Uint32),
            int Function(Pointer<Utf16>, Pointer<Utf16>, int)
          >('MoveFileExW');
      final lastError = library
          .lookupFunction<Uint32 Function(), int Function()>('GetLastError');
      // No MOVEFILE_REPLACE_EXISTING or cross-volume copy fallback.
      return move(
                extendedWindowsFilePath(source).toNativeUtf16(allocator: arena),
                extendedWindowsFilePath(target).toNativeUtf16(allocator: arena),
                0,
              ) !=
              0
          ? 0
          : lastError();
    }
    final from = source.toNativeUtf8(allocator: arena),
        to = target.toNativeUtf8(allocator: arena);
    final apple = Platform.isMacOS || Platform.isIOS;
    final errno = library
        .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
          apple
              ? '__error'
              : Platform.isAndroid
              ? '__errno'
              : '__errno_location',
        );
    final int result;
    if (apple) {
      final rename = library
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Uint32),
            int Function(Pointer<Utf8>, Pointer<Utf8>, int)
          >('renamex_np');
      result = rename(from, to, 0x4); // RENAME_EXCL
    } else {
      final link = library
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)
          >('link');
      result = link(from, to); // atomic no-replace; caller removes staging name
    }
    return result == 0 ? 0 : errno().value;
  });
  if (code == 0) return;
  if (Platform.isWindows ? code == 80 || code == 183 : code == 17) {
    throw StateError('browser_workspace_file_exists');
  }
  throw FileSystemException(
    'Could not publish browser screenshot',
    target,
    OSError('', code),
  );
}

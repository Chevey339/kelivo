import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import '../../../utils/windows_file_path.dart';

/// Publish a complete file without opening or following the target
/// leaf. Dart's rename replaces existing targets on POSIX, and create(exclusive)
/// followed by writeAsBytes reopens a path that another process can replace.
/// Source and destination must be on the same filesystem. Metadata work also
/// stays off the UI isolate (a workspace may live on a slow external volume).
Future<void> publishNewFileAtomically(String source, String target) =>
    Isolate.run(() => publishFileAtomicallySync(source, target));

/// Call from a worker isolate. Replacing a leaf never follows a leaf symlink.
void publishFileAtomicallySync(
  String source,
  String target, {
  bool replace = false,
}) {
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
      // Never use a cross-volume copy fallback: publication must be atomic.
      return move(
                extendedWindowsFilePath(source).toNativeUtf16(allocator: arena),
                extendedWindowsFilePath(target).toNativeUtf16(allocator: arena),
                replace ? 1 : 0, // MOVEFILE_REPLACE_EXISTING
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
      result = rename(from, to, replace ? 0 : 0x4); // RENAME_EXCL
    } else if (Platform.isAndroid) {
      // Android's SELinux policy can deny hard links in app-private storage.
      // Use the atomic rename syscall directly; the libc renameat2 wrapper is
      // only exported from API 30, while supported kernels already provide it.
      final syscallNumber = switch (Abi.current()) {
        Abi.androidArm64 => 276,
        Abi.androidArm => 382,
        Abi.androidX64 => 316,
        Abi.androidIA32 => 353,
        _ => throw UnsupportedError('Unsupported Android ABI'),
      };
      final rename = library
          .lookupFunction<
            IntPtr Function(
              IntPtr,
              IntPtr,
              Pointer<Utf8>,
              IntPtr,
              Pointer<Utf8>,
              IntPtr,
            ),
            int Function(int, int, Pointer<Utf8>, int, Pointer<Utf8>, int)
          >('syscall');
      result = rename(syscallNumber, -100, from, -100, to, replace ? 0 : 1);
    } else if (replace) {
      final rename = library
          .lookupFunction<
            Int32 Function(Pointer<Utf8>, Pointer<Utf8>),
            int Function(Pointer<Utf8>, Pointer<Utf8>)
          >('rename');
      result = rename(from, to);
    } else {
      final rename = library
          .lookupFunction<
            Int32 Function(Int32, Pointer<Utf8>, Int32, Pointer<Utf8>, Uint32),
            int Function(int, Pointer<Utf8>, int, Pointer<Utf8>, int)
          >('renameat2');
      result = rename(-100, from, -100, to, 1); // AT_FDCWD, RENAME_NOREPLACE
    }
    return result == 0 ? 0 : errno().value;
  });
  if (code == 0) return;
  if (Platform.isWindows ? code == 80 || code == 183 : code == 17) {
    throw StateError('browser_workspace_file_exists');
  }
  throw FileSystemException(
    'Could not publish workspace file',
    target,
    OSError('', code),
  );
}

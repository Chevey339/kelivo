import 'dart:io';

/// Extra failure evidence without changing the exception's existing message
/// or the FormatException/FileSystemException checks used by restore recovery.
final class RestoreFormatException extends FormatException {
  RestoreFormatException(super.message, Map<String, String> details)
    : details = Map.unmodifiable(details);

  final Map<String, String> details;
}

final class RestoreFileSystemException extends FileSystemException {
  RestoreFileSystemException(
    FileSystemException cause,
    Map<String, String> details,
  ) : details = Map.unmodifiable(details),
      super(cause.message, cause.path, cause.osError);

  final Map<String, String> details;
}

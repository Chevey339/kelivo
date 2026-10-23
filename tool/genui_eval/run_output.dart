import 'dart:io';

/// The marker is intentionally retained after success, failure or interruption.
/// Claim before any paid request; concurrent first rounds cannot share outputs.
Future<void> claimEvaluationOutput(Directory directory) async {
  if (await directory.exists() && !await directory.list().isEmpty) {
    throw const FileSystemException('Output directory is not empty');
  }
  await directory.create(recursive: true);
  await File('${directory.path}/.first-round-claimed').create(exclusive: true);
}

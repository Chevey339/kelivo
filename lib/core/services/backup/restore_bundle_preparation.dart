import 'dart:io';

import 'restore_bundle_staging.dart';
import 'restore_receipt.dart';

final class PreparedRestoreBundle {
  const PreparedRestoreBundle({
    required this.runId,
    required this.workspace,
    required this.candidateDirectory,
    required this.receipt,
  });

  final String runId;
  final Directory workspace;
  final Directory candidateDirectory;
  final RestoreReceipt receipt;
}

final class _RestorePreparationCleanupException implements Exception {
  const _RestorePreparationCleanupException(this.error, this.cleanupError);

  final Object error;
  final Object cleanupError;

  @override
  String toString() =>
      'Restore preparation failed ($error) and cleanup failed ($cleanupError)';
}

/// Stages and logically publishes a validated restore bundle for startup.
///
/// Directory fsync and the startup cutover are separate protocol steps. A
/// successful result owns its workspace until startup recovery finalizes it.
final class RestoreBundlePreparation {
  RestoreBundlePreparation._();

  static Future<PreparedRestoreBundle> prepare({
    required Directory appDataDirectory,
    required Directory extractedDirectory,
    required String sourceManifestSha256,
    required bool bundleIncludesChats,
    required bool bundleIncludesFiles,
    required bool restoreChats,
    required bool restoreFiles,
    DateTime? createdAtUtc,
  }) async {
    StagedRestoreBundle? staged;
    var publicationStarted = false;
    try {
      staged = await RestoreBundleStaging.create(
        appDataDirectory: appDataDirectory,
        extractedDirectory: extractedDirectory,
        includeChats: bundleIncludesChats,
        includeFiles: bundleIncludesFiles,
        sourceManifestSha256: sourceManifestSha256,
      );
      final receipt = RestoreReceipt.prepared(
        runId: staged.runId,
        createdAtUtc: createdAtUtc ?? DateTime.now().toUtc(),
        restoreChats: restoreChats && bundleIncludesChats,
        restoreFiles: restoreFiles && bundleIncludesFiles,
        candidateManifestSha256: staged.candidateManifestSha256,
      );
      final store = RestoreReceiptStore(
        appDataDirectory: appDataDirectory,
        runId: staged.runId,
      );
      publicationStarted = true;
      await store.publish(receipt);
      final published = await store.readLatest();
      if (published == null || published.checksum != receipt.checksum) {
        throw StateError('restore_preparation_receipt');
      }
      return PreparedRestoreBundle(
        runId: staged.runId,
        workspace: staged.workspace,
        candidateDirectory: staged.payloadDirectory,
        receipt: published,
      );
    } catch (error, stackTrace) {
      if (staged != null && !publicationStarted) {
        try {
          await RestoreBundleStaging.discardUnpublished(
            appDataDirectory: appDataDirectory,
            runId: staged.runId,
          );
        } catch (cleanupError, cleanupStackTrace) {
          Error.throwWithStackTrace(
            _RestorePreparationCleanupException(error, cleanupError),
            cleanupStackTrace,
          );
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

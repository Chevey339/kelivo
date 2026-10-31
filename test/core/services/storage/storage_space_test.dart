import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:Kelivo/core/database/startup_failure_report.dart';
import 'package:Kelivo/core/services/storage/device_storage_probe.dart';
import 'package:Kelivo/core/services/storage/storage_space.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('app.device_storage'),
      null,
    );
  });

  test(
    'zero available capacity blocks writes instead of meaning unknown',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('app.device_storage'),
        (_) async => 0,
      );
      expect(await DeviceStorageProbe.freeBytes(), 0);
      await expectLater(
        InsufficientStorageSpace.require(1),
        throwsA(isA<InsufficientStorageSpace>()),
      );
    },
  );

  test(
    'disk-full errors are actionable while other errors remain distinct',
    () {
      final full = FileSystemException(
        'disk full',
        '/data',
        OSError('full', Platform.isWindows ? 112 : 28),
      );
      expect(restoreFailureDiagnosticCode(full), 'storage_insufficient_space');
      final report = StartupFailureReport.capture(
        stage: StartupFailureStage.databaseAdmission,
        error: const InsufficientStorageSpace(
          requiredBytes: 400,
          availableBytes: 100,
        ),
      );
      expect(report.storageSpace, (required: 400, available: 100));
      expect(report.diagnosticCode, 'storage_insufficient_space');
      expect(
        restoreFailureDiagnosticCode(
          sqlite.SqliteException(extendedResultCode: 13, message: 'full'),
        ),
        'storage_insufficient_space',
      );
      expect(
        InsufficientStorageSpace.causedBy(
          const FileSystemException(
            'access denied',
            '/data',
            OSError('denied', 13),
          ),
        ),
        isFalse,
      );
      expect(
        restoreFailureDiagnosticCode(
          sqlite.SqliteException(extendedResultCode: 11, message: 'malformed'),
        ),
        'sqlite_11',
      );
    },
  );
}

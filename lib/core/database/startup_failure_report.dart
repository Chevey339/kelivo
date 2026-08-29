import 'dart:convert';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'app_database.dart';
import 'database_installation_gate.dart';

/// Which startup gate failed closed.
///
/// The two gates run in sequence and fail for entirely different reasons, so
/// naming the stage is the single cheapest piece of diagnostic information:
/// it halves the search space before the error is even read.
enum StartupFailureStage {
  /// `RestoreStartupGate` — recovering or finishing a pending restore.
  restoreGate,

  /// `DatabaseInstallationGate` + `ChatDatabaseGateway` — admitting, migrating
  /// and opening the installed database.
  databaseAdmission,
}

extension StartupFailureStageLabel on StartupFailureStage {
  String get code => switch (this) {
    StartupFailureStage.restoreGate => 'restore_gate',
    StartupFailureStage.databaseAdmission => 'database_admission',
  };
}

/// One layer of an unwrapped error chain.
///
/// Errors that cross drift's worker isolate arrive wrapped in a
/// [DriftRemoteException] whose own type says nothing. Recording every layer —
/// with the wrapper's stack *and* the remote stack — is what turns an opaque
/// `DriftRemoteException` into an actionable report.
final class StartupFailureCause {
  const StartupFailureCause({
    required this.type,
    required this.message,
    this.details = const <String, String>{},
    this.stackTrace,
  });

  /// Runtime type name, e.g. `SqliteException`.
  final String type;

  /// The error's own message, already free of the type prefix where possible.
  final String message;

  /// Structured extras worth reading before the stack, e.g. the SQLite result
  /// code or the statement that failed.
  final Map<String, String> details;

  /// The stack recorded at this layer, when one survived.
  final StackTrace? stackTrace;
}

/// A single entry of the app data directory as it looked when startup failed.
final class StartupFailureFileFact {
  const StartupFailureFileFact({
    required this.name,
    required this.kind,
    this.sizeBytes,
    this.modified,
    this.note,
  });

  final String name;

  /// `file`, `dir`, `link` or `missing`.
  final String kind;
  final int? sizeBytes;
  final DateTime? modified;

  /// What this build makes of the entry, e.g. `user_version=1` for the
  /// database or `unparseable` for a broken installation receipt.
  final String? note;
}

/// Everything about the device and the data directory that helps explain a
/// fail-closed startup, collected without opening the app's normal services.
final class StartupFailureEnvironment {
  const StartupFailureEnvironment({
    required this.platform,
    required this.operatingSystemVersion,
    required this.expectedSchemaVersion,
    required this.publishedSchemaVersions,
    this.appVersion,
    this.buildNumber,
    this.dataDirectoryPath,
    this.installedSchemaVersion,
    this.installedSchemaError,
    this.files = const <StartupFailureFileFact>[],
  });

  final String platform;
  final String operatingSystemVersion;
  final int expectedSchemaVersion;
  final List<int> publishedSchemaVersions;
  final String? appVersion;
  final String? buildNumber;
  final String? dataDirectoryPath;

  /// `PRAGMA user_version` of the installed database, or null when it could
  /// not be read (missing, corrupt, or locked).
  final int? installedSchemaVersion;
  final String? installedSchemaError;
  final List<StartupFailureFileFact> files;

  /// True when the installed database is at a published schema older than this
  /// build's — the shape of "an upgrade was due and something about it failed".
  bool get installedSchemaIsBehind {
    final installed = installedSchemaVersion;
    return installed != null &&
        installed > 0 &&
        installed < expectedSchemaVersion;
  }

  static const _maximumListedEntries = 80;

  /// Reads the data directory without mutating anything. Every probe is
  /// individually guarded: a diagnostics collector that can itself throw is
  /// worse than no diagnostics at all.
  static Future<StartupFailureEnvironment> collect({
    Directory? appDataDirectory,
    String? appVersion,
    String? buildNumber,
  }) async {
    final files = <StartupFailureFileFact>[];
    int? installedSchemaVersion;
    String? installedSchemaError;

    if (appDataDirectory != null) {
      try {
        final entities = await appDataDirectory
            .list(followLinks: false)
            .toList();
        entities.sort(
          (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
        );
        for (final entity in entities.take(_maximumListedEntries)) {
          files.add(await _describe(entity));
        }
        if (entities.length > _maximumListedEntries) {
          files.add(
            StartupFailureFileFact(
              name: '… ${entities.length - _maximumListedEntries} more entries',
              kind: 'info',
            ),
          );
        }
      } catch (error) {
        files.add(
          StartupFailureFileFact(
            name: p.basename(appDataDirectory.path),
            kind: 'dir',
            note: 'unreadable: $error',
          ),
        );
      }

      final databaseFile = File(
        p.join(appDataDirectory.path, AppDatabase.databaseFileName),
      );
      try {
        if (databaseFile.existsSync()) {
          installedSchemaVersion = _readUserVersion(databaseFile);
        }
      } catch (error) {
        installedSchemaError = '$error';
      }
    }

    return StartupFailureEnvironment(
      platform: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      expectedSchemaVersion: AppDatabase.currentSchemaVersion,
      publishedSchemaVersions: AppDatabase.publishedSchemaVersions.toList(
        growable: false,
      )..sort(),
      appVersion: appVersion,
      buildNumber: buildNumber,
      dataDirectoryPath: appDataDirectory?.path,
      installedSchemaVersion: installedSchemaVersion,
      installedSchemaError: installedSchemaError,
      files: List.unmodifiable(files),
    );
  }

  static Future<StartupFailureFileFact> _describe(
    FileSystemEntity entity,
  ) async {
    final name = p.basename(entity.path);
    if (entity is Directory) {
      final note = <String>[];
      try {
        final children = await entity.list(followLinks: false).length;
        note.add('$children entries');
      } catch (_) {
        note.add('unreadable');
      }
      if (name == '.kelivo_restore') note.add('restore workspace');
      return StartupFailureFileFact(
        name: name,
        kind: 'dir',
        note: note.join(', '),
      );
    }
    if (entity is! File) {
      return StartupFailureFileFact(name: name, kind: 'link');
    }
    int? size;
    DateTime? modified;
    try {
      final stat = await entity.stat();
      size = stat.size;
      modified = stat.modified;
    } catch (_) {}
    return StartupFailureFileFact(
      name: name,
      kind: 'file',
      sizeBytes: size,
      modified: modified,
      note: await _noteFor(entity, name),
    );
  }

  static Future<String?> _noteFor(File file, String name) async {
    if (name == AppDatabase.databaseFileName) {
      try {
        return 'user_version=${_readUserVersion(file)}';
      } catch (error) {
        return 'unreadable: ${_shorten('$error', 80)}';
      }
    }
    if (name.startsWith('${AppDatabase.databaseFileName}.premigrate-v')) {
      return 'pre-migration copy — a schema upgrade did not finish';
    }
    if (name.startsWith('database_installation_receipt_') &&
        name.endsWith('.json')) {
      try {
        final receipt = DatabaseInstallationReceipt.fromJson(
          jsonDecode(await file.readAsString()),
        );
        return 'receipt for database ${receipt.databaseId}';
      } catch (_) {
        return 'receipt unparseable';
      }
    }
    return null;
  }

  static int _readUserVersion(File file) {
    final database = sqlite.sqlite3.open(
      file.absolute.path,
      mode: sqlite.OpenMode.readOnly,
    );
    try {
      return database.userVersion;
    } finally {
      database.close();
    }
  }
}

/// A structured, human-readable account of why startup failed closed.
final class StartupFailureReport {
  const StartupFailureReport({
    required this.stage,
    required this.diagnosticCode,
    required this.causes,
    required this.capturedAt,
    this.step,
    this.stackTrace,
    this.environment,
  });

  /// Builds a report from a caught error. Cheap and synchronous, so it can run
  /// on the failing path before anything else is known to work.
  factory StartupFailureReport.capture({
    required StartupFailureStage stage,
    required Object error,
    String? step,
    StackTrace? stackTrace,
    DateTime? capturedAt,
  }) {
    return StartupFailureReport(
      stage: stage,
      diagnosticCode: restoreFailureDiagnosticCode(error),
      causes: unwrapCauses(error, stackTrace),
      capturedAt: capturedAt ?? DateTime.now(),
      step: step,
      stackTrace: stackTrace,
    );
  }

  final StartupFailureStage stage;

  /// The short, path-free code shown on screen and quoted to support.
  final String diagnosticCode;

  /// Outermost error first, innermost (root) cause last.
  final List<StartupFailureCause> causes;
  final DateTime capturedAt;

  /// The individual call inside [stage] that threw, e.g. `business_migration`.
  /// A stage has several drift entry points that fail in indistinguishable
  /// ways, so naming the call is what separates them.
  final String? step;
  final StackTrace? stackTrace;
  final StartupFailureEnvironment? environment;

  StartupFailureReport withEnvironment(StartupFailureEnvironment value) =>
      StartupFailureReport(
        stage: stage,
        diagnosticCode: diagnosticCode,
        causes: causes,
        capturedAt: capturedAt,
        step: step,
        stackTrace: stackTrace,
        environment: value,
      );

  /// The one line worth showing without expanding anything: the root cause.
  String get summary {
    if (causes.isEmpty) return diagnosticCode;
    final root = causes.last;
    return root.message.isEmpty ? root.type : '${root.type}: ${root.message}';
  }

  /// Peels [DriftRemoteException] (and any nested wrapper) so the real error is
  /// never hidden behind the transport's type name.
  static List<StartupFailureCause> unwrapCauses(
    Object error, [
    StackTrace? stackTrace,
  ]) {
    final causes = <StartupFailureCause>[];
    Object? current = error;
    StackTrace? currentStack = stackTrace;
    final seen = <Object>{};
    while (current != null) {
      if (!seen.add(current)) break;
      causes.add(_describeCause(current, currentStack));
      if (current is DriftRemoteException) {
        currentStack = current.remoteStackTrace;
        current = current.remoteCause;
        continue;
      }
      break;
    }
    return List.unmodifiable(causes);
  }

  static StartupFailureCause _describeCause(Object error, StackTrace? stack) {
    if (error is DriftRemoteException) {
      return StartupFailureCause(
        type: 'DriftRemoteException',
        message: 'raised on drift\'s database worker isolate',
        stackTrace: stack,
      );
    }
    if (error is sqlite.SqliteException) {
      return StartupFailureCause(
        type: 'SqliteException',
        message: error.message,
        details: {
          'result code':
              '${error.resultCode} (extended ${error.extendedResultCode})',
          if (error.explanation case final explanation?)
            'explanation': explanation,
          if (error.operation case final operation?) 'operation': operation,
          if (error.causingStatement case final statement?)
            'statement': _shorten(statement, 400),
          // Values are deliberately omitted: statement parameters can carry
          // message content, and the count is all a diagnosis needs.
          if (error.parametersToStatement case final parameters?)
            'parameters': '${parameters.length} bound value(s)',
        },
        stackTrace: stack,
      );
    }
    if (error is FileSystemException) {
      return StartupFailureCause(
        type: 'FileSystemException',
        message: error.message,
        details: {
          if (error.path case final path? when path.isNotEmpty) 'path': path,
          if (error.osError case final osError?)
            'os error': '${osError.message} (${osError.errorCode})',
        },
        stackTrace: stack,
      );
    }
    if (error is StateError) {
      return StartupFailureCause(
        type: 'StateError',
        message: error.message,
        stackTrace: stack,
      );
    }
    if (error is FormatException) {
      return StartupFailureCause(
        type: 'FormatException',
        message: error.message,
        stackTrace: stack,
      );
    }
    return StartupFailureCause(
      type: error.runtimeType.toString(),
      message: '$error',
      stackTrace: stack,
    );
  }

  /// The full report as plain text — what gets copied, exported and written to
  /// disk. Everything a support conversation needs is in here.
  String toText() {
    final buffer = StringBuffer()
      ..writeln('Kelivo startup failure report')
      ..writeln('captured: ${capturedAt.toIso8601String()}')
      ..writeln('stage: ${stage.code}')
      ..writeln('step: ${step ?? 'unknown'}')
      ..writeln('diagnostic code: $diagnosticCode')
      ..writeln();

    buffer.writeln('== error ==');
    for (var index = 0; index < causes.length; index++) {
      final cause = causes[index];
      buffer.writeln('${index + 1}. ${cause.type}: ${cause.message}');
      cause.details.forEach((key, value) {
        buffer.writeln('   $key: $value');
      });
    }
    buffer.writeln();

    for (var index = 0; index < causes.length; index++) {
      final stack = causes[index].stackTrace;
      if (stack == null) continue;
      buffer
        ..writeln('== stack (${causes[index].type}) ==')
        ..writeln(_shorten(stack.toString().trimRight(), 8000))
        ..writeln();
    }

    final environment = this.environment;
    if (environment != null) {
      buffer
        ..writeln('== environment ==')
        ..writeln(
          'app: ${environment.appVersion ?? 'unknown'}'
          '${environment.buildNumber == null ? '' : ' (${environment.buildNumber})'}',
        )
        ..writeln('platform: ${environment.platform}')
        ..writeln('os: ${environment.operatingSystemVersion}')
        ..writeln(
          'schema: build expects ${environment.expectedSchemaVersion}, '
          'published ${environment.publishedSchemaVersions.join(', ')}',
        )
        ..writeln(
          'installed schema: '
          '${environment.installedSchemaVersion ?? environment.installedSchemaError ?? 'unknown'}',
        )
        ..writeln('data dir: ${environment.dataDirectoryPath ?? 'unknown'}')
        ..writeln()
        ..writeln('== data directory ==');
      for (final file in environment.files) {
        buffer.writeln(
          '${file.name}  [${file.kind}]'
          '${file.sizeBytes == null ? '' : '  ${formatBytes(file.sizeBytes!)}'}'
          '${file.modified == null ? '' : '  ${file.modified!.toIso8601String()}'}'
          '${file.note == null || file.note!.isEmpty ? '' : '  — ${file.note}'}',
        );
      }
    }
    return buffer.toString();
  }
}

/// Reduces an error to a short, stable, path-free identifier.
///
/// Stability is the point: the code is quoted in bug reports and compared
/// across installs, so it must never carry a sandbox path, a row id, or
/// anything else that differs per device. Anything that fails that test
/// degrades to the type name, and the full text lives in the report instead.
String restoreFailureDiagnosticCode(Object error) {
  if (error is DriftRemoteException) {
    // Drift's worker isolate is a transport, not a diagnosis; report what
    // actually failed and keep the marker that it happened off-isolate.
    return 'drift:${restoreFailureDiagnosticCode(error.remoteCause)}';
  }
  if (error is sqlite.SqliteException) {
    return 'sqlite_${error.extendedResultCode}';
  }
  if (error is FileSystemException) {
    final osCode = error.osError?.errorCode;
    return osCode == null ? 'filesystem' : 'filesystem_$osCode';
  }
  final Object? message = switch (error) {
    StateError() => error.message,
    FormatException() => error.message,
    _ => null,
  };
  final raw = message?.toString();
  if (raw != null && RegExp(r'^[a-zA-Z0-9_.:-]{1,160}$').hasMatch(raw)) {
    return raw;
  }
  return error.runtimeType.toString();
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unit]}';
}

String _shorten(String value, int limit) =>
    value.length <= limit ? value : '${value.substring(0, limit)}…';

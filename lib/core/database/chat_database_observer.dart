import 'dart:collection';
import 'dart:io';

import 'package:drift/isolate.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

enum ChatDatabaseOperation {
  gatewayOpen,
  connectionContract,
  queryConversationList,
  queryConversation,
  queryMessageCount,
  queryConversationCount,
  queryTotalMessageCount,
  queryMessageRange,
  queryMessagesByIds,
  queryMessagesForGroups,
  queryMessageIds,
  querySearch,
  queryMessageGraphPath,
  commandAppendMessage,
  commandCreateConversation,
  commandAppendVersion,
  commandSelectVersion,
  commandDeleteMessages,
  commandStreamingCheckpoint,
  commandFinalCheckpoint,
  commandSetContextBoundary,
  commandMessageGraphMutation,
  walCheckpoint,
  integrityCheck,
}

final class ChatDatabaseConnectionContract {
  const ChatDatabaseConnectionContract({
    required this.schemaVersion,
    required this.journalModeWal,
    required this.foreignKeysEnabled,
    required this.busyTimeoutMillis,
    required this.synchronous,
    required this.walAutoCheckpointPages,
    required this.journalSizeLimitBytes,
  });

  final int schemaVersion;
  final bool journalModeWal;
  final bool foreignKeysEnabled;
  final int busyTimeoutMillis;
  final int synchronous;
  final int walAutoCheckpointPages;
  final int journalSizeLimitBytes;

  Map<String, Object> toSafeJson() => {
    'schemaVersion': schemaVersion,
    'journalModeWal': journalModeWal,
    'foreignKeysEnabled': foreignKeysEnabled,
    'busyTimeoutMillis': busyTimeoutMillis,
    'synchronous': synchronous,
    'walAutoCheckpointPages': walAutoCheckpointPages,
    'journalSizeLimitBytes': journalSizeLimitBytes,
  };
}

enum ChatDatabaseFailureKind {
  sqlite,
  remoteDatabase,
  filesystem,
  state,
  input,
  unknown,
}

final class ChatDatabaseObservation {
  const ChatDatabaseObservation({
    required this.operation,
    required this.elapsedMicros,
    required this.succeeded,
    this.resultCount,
    this.failureKind,
    this.errorCode,
    this.walBytesBefore,
    this.walBytesAfter,
    this.checkpointBusy,
    this.checkpointLogFrames,
    this.checkpointedFrames,
  });

  final ChatDatabaseOperation operation;
  final int elapsedMicros;
  final bool succeeded;
  final int? resultCount;
  final ChatDatabaseFailureKind? failureKind;
  final int? errorCode;
  final int? walBytesBefore;
  final int? walBytesAfter;
  final int? checkpointBusy;
  final int? checkpointLogFrames;
  final int? checkpointedFrames;

  Map<String, Object?> toSafeJson() => {
    'operation': operation.name,
    'elapsedMicros': elapsedMicros,
    'succeeded': succeeded,
    if (resultCount != null) 'resultCount': resultCount,
    if (failureKind != null) 'failureKind': failureKind!.name,
    if (errorCode != null) 'errorCode': errorCode,
    if (walBytesBefore != null) 'walBytesBefore': walBytesBefore,
    if (walBytesAfter != null) 'walBytesAfter': walBytesAfter,
    if (checkpointBusy != null) 'checkpointBusy': checkpointBusy,
    if (checkpointLogFrames != null) 'checkpointLogFrames': checkpointLogFrames,
    if (checkpointedFrames != null) 'checkpointedFrames': checkpointedFrames,
  };
}

final class ChatDatabaseMetricSummary {
  const ChatDatabaseMetricSummary({
    required this.totalCount,
    required this.failureCount,
    required this.retainedSamples,
    required this.p50Micros,
    required this.p95Micros,
    required this.maxMicros,
    required this.totalResultCount,
    required this.lastFailureKind,
    required this.lastErrorCode,
  });

  final int totalCount;
  final int failureCount;
  final int retainedSamples;
  final int p50Micros;
  final int p95Micros;
  final int maxMicros;
  final int totalResultCount;
  final ChatDatabaseFailureKind? lastFailureKind;
  final int? lastErrorCode;

  Map<String, Object?> toSafeJson() => {
    'totalCount': totalCount,
    'failureCount': failureCount,
    'retainedSamples': retainedSamples,
    'p50Micros': p50Micros,
    'p95Micros': p95Micros,
    'maxMicros': maxMicros,
    'totalResultCount': totalResultCount,
    if (lastFailureKind != null) 'lastFailureKind': lastFailureKind!.name,
    if (lastErrorCode != null) 'lastErrorCode': lastErrorCode,
  };
}

final class ChatDatabaseMetricsSnapshot {
  const ChatDatabaseMetricsSnapshot({
    required this.operations,
    required this.connectionContract,
    required this.walPeakBytes,
    required this.walLatestBytes,
    required this.checkpointCount,
    required this.checkpointFailureCount,
    required this.lastCheckpointBusy,
    required this.lastCheckpointLogFrames,
    required this.lastCheckpointedFrames,
  });

  final Map<ChatDatabaseOperation, ChatDatabaseMetricSummary> operations;
  final ChatDatabaseConnectionContract? connectionContract;
  final int walPeakBytes;
  final int walLatestBytes;
  final int checkpointCount;
  final int checkpointFailureCount;
  final int? lastCheckpointBusy;
  final int? lastCheckpointLogFrames;
  final int? lastCheckpointedFrames;

  Map<String, Object?> toSafeJson() => {
    'format': 'kelivo-chat-database-metrics-v1',
    'operations': {
      for (final entry in operations.entries)
        entry.key.name: entry.value.toSafeJson(),
    },
    if (connectionContract != null)
      'connection': connectionContract!.toSafeJson(),
    'wal': {
      'peakBytes': walPeakBytes,
      'latestBytes': walLatestBytes,
      'checkpointCount': checkpointCount,
      'checkpointFailureCount': checkpointFailureCount,
      if (lastCheckpointBusy != null) 'lastCheckpointBusy': lastCheckpointBusy,
      if (lastCheckpointLogFrames != null)
        'lastCheckpointLogFrames': lastCheckpointLogFrames,
      if (lastCheckpointedFrames != null)
        'lastCheckpointedFrames': lastCheckpointedFrames,
    },
  };
}

final class ChatDatabaseObserver {
  ChatDatabaseObserver({this.maxSamplesPerOperation = 256})
    : assert(maxSamplesPerOperation > 0);

  static final ChatDatabaseObserver instance = ChatDatabaseObserver();

  final int maxSamplesPerOperation;
  final Map<ChatDatabaseOperation, _RollingDatabaseMetrics> _metrics = {};
  int _walPeakBytes = 0;
  int _walLatestBytes = 0;
  int _checkpointCount = 0;
  int _checkpointFailureCount = 0;
  int? _lastCheckpointBusy;
  int? _lastCheckpointLogFrames;
  int? _lastCheckpointedFrames;
  ChatDatabaseConnectionContract? _connectionContract;

  Future<T> measure<T>(
    ChatDatabaseOperation operation,
    Future<T> Function() action, {
    int Function(T value)? resultCount,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final value = await action();
      stopwatch.stop();
      record(
        ChatDatabaseObservation(
          operation: operation,
          elapsedMicros: stopwatch.elapsedMicroseconds,
          succeeded: true,
          resultCount: resultCount?.call(value),
        ),
      );
      return value;
    } catch (error) {
      stopwatch.stop();
      final failure = _classifyFailure(error);
      record(
        ChatDatabaseObservation(
          operation: operation,
          elapsedMicros: stopwatch.elapsedMicroseconds,
          succeeded: false,
          failureKind: failure.kind,
          errorCode: failure.errorCode,
        ),
      );
      rethrow;
    }
  }

  void record(ChatDatabaseObservation observation) {
    final metrics = _metrics.putIfAbsent(
      observation.operation,
      () => _RollingDatabaseMetrics(maxSamplesPerOperation),
    );
    metrics.add(observation);
    if (observation.operation == ChatDatabaseOperation.walCheckpoint) {
      _checkpointCount += 1;
      if (!observation.succeeded) _checkpointFailureCount += 1;
      final before = observation.walBytesBefore;
      final after = observation.walBytesAfter;
      if (before != null && before > _walPeakBytes) _walPeakBytes = before;
      if (after != null) {
        _walLatestBytes = after;
        if (after > _walPeakBytes) _walPeakBytes = after;
      }
      _lastCheckpointBusy = observation.checkpointBusy;
      _lastCheckpointLogFrames = observation.checkpointLogFrames;
      _lastCheckpointedFrames = observation.checkpointedFrames;
    }
  }

  void recordFailure({
    required ChatDatabaseOperation operation,
    required int elapsedMicros,
    required Object error,
    int? walBytesBefore,
    int? walBytesAfter,
  }) {
    final failure = _classifyFailure(error);
    record(
      ChatDatabaseObservation(
        operation: operation,
        elapsedMicros: elapsedMicros,
        succeeded: false,
        failureKind: failure.kind,
        errorCode: failure.errorCode,
        walBytesBefore: walBytesBefore,
        walBytesAfter: walBytesAfter,
      ),
    );
  }

  void recordConnectionContract(
    ChatDatabaseConnectionContract contract, {
    required int elapsedMicros,
  }) {
    _connectionContract = contract;
    record(
      ChatDatabaseObservation(
        operation: ChatDatabaseOperation.connectionContract,
        elapsedMicros: elapsedMicros,
        succeeded: true,
      ),
    );
  }

  ChatDatabaseMetricsSnapshot snapshot() => ChatDatabaseMetricsSnapshot(
    operations: Map.unmodifiable({
      for (final entry in _metrics.entries) entry.key: entry.value.snapshot(),
    }),
    connectionContract: _connectionContract,
    walPeakBytes: _walPeakBytes,
    walLatestBytes: _walLatestBytes,
    checkpointCount: _checkpointCount,
    checkpointFailureCount: _checkpointFailureCount,
    lastCheckpointBusy: _lastCheckpointBusy,
    lastCheckpointLogFrames: _lastCheckpointLogFrames,
    lastCheckpointedFrames: _lastCheckpointedFrames,
  );

  void reset() {
    _metrics.clear();
    _walPeakBytes = 0;
    _walLatestBytes = 0;
    _checkpointCount = 0;
    _checkpointFailureCount = 0;
    _lastCheckpointBusy = null;
    _lastCheckpointLogFrames = null;
    _lastCheckpointedFrames = null;
    _connectionContract = null;
  }
}

final class _RollingDatabaseMetrics {
  _RollingDatabaseMetrics(this.maximumSamples);

  final int maximumSamples;
  final Queue<int> _elapsedMicros = Queue<int>();
  int totalCount = 0;
  int failureCount = 0;
  int totalResultCount = 0;
  int maxMicros = 0;
  ChatDatabaseFailureKind? lastFailureKind;
  int? lastErrorCode;

  void add(ChatDatabaseObservation observation) {
    totalCount += 1;
    final elapsed = observation.elapsedMicros < 0
        ? 0
        : observation.elapsedMicros;
    _elapsedMicros.addLast(elapsed);
    if (_elapsedMicros.length > maximumSamples) _elapsedMicros.removeFirst();
    if (elapsed > maxMicros) maxMicros = elapsed;
    totalResultCount += observation.resultCount ?? 0;
    if (!observation.succeeded) {
      failureCount += 1;
      lastFailureKind = observation.failureKind;
      lastErrorCode = observation.errorCode;
    }
  }

  ChatDatabaseMetricSummary snapshot() {
    final sorted = _elapsedMicros.toList(growable: false)..sort();
    return ChatDatabaseMetricSummary(
      totalCount: totalCount,
      failureCount: failureCount,
      retainedSamples: sorted.length,
      p50Micros: _percentile(sorted, 0.50),
      p95Micros: _percentile(sorted, 0.95),
      maxMicros: maxMicros,
      totalResultCount: totalResultCount,
      lastFailureKind: lastFailureKind,
      lastErrorCode: lastErrorCode,
    );
  }
}

int _percentile(List<int> sorted, double percentile) {
  if (sorted.isEmpty) return 0;
  final rank = (percentile * sorted.length)
      .ceil()
      .clamp(1, sorted.length)
      .toInt();
  return sorted[rank - 1];
}

({ChatDatabaseFailureKind kind, int? errorCode}) _classifyFailure(
  Object error,
) {
  if (error is sqlite.SqliteException) {
    return (
      kind: ChatDatabaseFailureKind.sqlite,
      errorCode: error.extendedResultCode,
    );
  }
  if (error is DriftRemoteException) {
    return (kind: ChatDatabaseFailureKind.remoteDatabase, errorCode: null);
  }
  if (error is FileSystemException) {
    return (
      kind: ChatDatabaseFailureKind.filesystem,
      errorCode: error.osError?.errorCode,
    );
  }
  if (error is StateError) {
    return (kind: ChatDatabaseFailureKind.state, errorCode: null);
  }
  if (error is ArgumentError) {
    return (kind: ChatDatabaseFailureKind.input, errorCode: null);
  }
  return (kind: ChatDatabaseFailureKind.unknown, errorCode: null);
}

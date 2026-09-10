import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mcp_client/mcp_client.dart';
import 'package:uuid/uuid.dart';

import '../workspace/workspace_runtime.dart';

/// MCP over the guest's raw pipes. A PTY would echo input and mix stderr into
/// stdout, corrupting the newline-delimited JSON protocol.
class WorkspaceStdioTransport implements ClientTransport {
  WorkspaceStdioTransport._(this._runtime, this._runId);

  final WorkspaceStdioRuntime _runtime;
  final String _runId;
  final _messages = StreamController<dynamic>.broadcast();
  final _closed = Completer<void>();
  final _started = Completer<void>();
  StreamSubscription<CommandEvent>? _events;
  StreamSubscription<String>? _lines;
  final _stdout = StreamController<List<int>>();
  Future<void> _writes = Future<void>.value();
  bool _closing = false;
  Future<void>? _outputFinished;
  static const _stderrLimit = 16 * 1024;
  final _stderr = <int>[];
  Object? _failure;
  int? _exitCode;

  /// Keep diagnostics separate from stdout, which is exclusively MCP JSON.
  String describeError(Object error) {
    final reason = _exitCode == null
        ? (_failure ?? error).toString()
        : 'STDIO process exited (code $_exitCode)';
    final stderr = utf8.decode(_stderr, allowMalformed: true).trim();
    return stderr.isEmpty ? reason : '$reason\n\n$stderr';
  }

  bool get failed => _failure != null || _exitCode != null;

  void _recordStderr(List<int> bytes) {
    if (bytes.length >= _stderrLimit) {
      _stderr
        ..clear()
        ..addAll(bytes.skip(bytes.length - _stderrLimit));
    } else {
      final excess = _stderr.length + bytes.length - _stderrLimit;
      if (excess > 0) _stderr.removeRange(0, excess);
      _stderr.addAll(bytes);
    }
  }

  static Future<WorkspaceStdioTransport> start({
    required WorkspaceStdioRuntime runtime,
    required String command,
    List<String> arguments = const [],
    String cwd = '/root',
    Map<String, String> environment = const {},
    Duration startupTimeout = const Duration(seconds: 30),
    bool Function()? isCancelled,
  }) async {
    if (command.trim().isEmpty) throw ArgumentError('STDIO command is empty');
    final launch = 'exec ${[command, ...arguments].map(_quote).join(' ')}';
    final transport = WorkspaceStdioTransport._(
      runtime,
      'mcp-${const Uuid().v4()}',
    );
    transport._lines = transport._stdout.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.trim().isEmpty || transport._closing) return;
            try {
              transport._messages.add(jsonDecode(line));
            } catch (error, stack) {
              transport._failure = error;
              transport._messages.addError(error, stack);
              transport.close();
            }
          },
          onError: (Object error, StackTrace stack) {
            transport._failure = error;
            transport._messages.addError(error, stack);
            transport.close();
          },
        );
    transport._events = runtime
        .run(
          CommandRequest(
            runId: transport._runId,
            command: launch,
            cwd: cwd,
            env: environment,
            keepStdinOpen: true,
            timeout: Duration.zero,
            isCancelled: () =>
                transport._closing || isCancelled?.call() == true,
          ),
        )
        .listen(
          (event) {
            switch (event) {
              case CommandStarted():
                if (!transport._started.isCompleted) {
                  transport._started.complete();
                }
              case CommandOutput(kind: OutputStreamKind.stdout):
                if (!transport._closing) transport._stdout.add(event.bytes);
              case CommandOutput(kind: OutputStreamKind.stderr):
                transport._recordStderr(event.bytes);
              case CommandExited():
                transport._exitCode = event.exitCode;
                transport._failStartup(
                  StateError(transport.describeError('STDIO process exited')),
                );
                unawaited(transport._finishOutput());
            }
          },
          onError: (Object error, StackTrace stack) {
            transport._failure = error;
            transport._failStartup(error, stack);
            transport.close();
          },
          onDone: () {
            transport._failStartup(
              StateError('STDIO process closed before startup'),
            );
            unawaited(transport._finishOutput());
          },
        );
    try {
      await transport._started.future.timeout(startupTimeout);
      if (isCancelled?.call() == true || transport._closing) {
        throw StateError('STDIO startup cancelled');
      }
      return transport;
    } catch (_) {
      transport.close();
      rethrow;
    }
  }

  static String _quote(String value) {
    if (value.contains('\u0000')) throw ArgumentError('NUL in STDIO argument');
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  void _failStartup(Object error, [StackTrace? stack]) {
    if (!_started.isCompleted) _started.completeError(error, stack);
  }

  Future<void> _finishOutput() => _outputFinished ??= _drainOutput();

  Future<void> _drainOutput() async {
    if (!_stdout.isClosed) await _stdout.close();
    close();
  }

  @override
  Stream<dynamic> get onMessage => _messages.stream;
  @override
  Future<void> get onClose => _closed.future;

  @override
  TransportSendOperation send(dynamic message) {
    final bytes = Uint8List.fromList(utf8.encode('${jsonEncode(message)}\n'));
    var cancelled = false;
    final write = _writes.then((_) async {
      if (cancelled) return;
      if (_closing) throw StateError('STDIO transport closed');
      await _runtime.writeStdin(_runId, bytes);
    });
    _writes = write.catchError((Object error) {
      _failure ??= error;
      close();
    });
    return TransportSendOperation(write, cancel: () => cancelled = true);
  }

  @override
  void close() {
    if (_closing) return;
    _closing = true;
    _failStartup(StateError('STDIO transport closed'));
    unawaited(
      () async {
        try {
          await _runtime.cancel(_runId);
        } finally {
          await _events?.cancel();
          await _lines?.cancel();
          if (!_stdout.isClosed) unawaited(_stdout.close());
          unawaited(_messages.close());
          if (!_closed.isCompleted) _closed.complete();
        }
      }().catchError((Object _) {
        if (!_closed.isCompleted) _closed.complete();
      }),
    );
  }
}

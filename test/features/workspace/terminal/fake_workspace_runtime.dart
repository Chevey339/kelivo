import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';

class ScriptedPtySession implements PtySession {
  ScriptedPtySession();

  final StreamController<Uint8List> outputController =
      StreamController<Uint8List>();
  final Completer<int> exitCompleter = Completer<int>();
  final List<Uint8List> writes = <Uint8List>[];
  final List<(int cols, int rows)> resizes = <(int, int)>[];
  bool closed = false;

  void emit(List<int> bytes) {
    outputController.add(Uint8List.fromList(bytes));
  }

  void emitString(String text) => emit(utf8.encode(text));

  void completeExit(int code) {
    if (!exitCompleter.isCompleted) exitCompleter.complete(code);
  }

  String get writtenString => writes.map(utf8.decode).join();

  List<int> get writtenBytes =>
      writes.expand((chunk) => chunk).toList(growable: false);

  @override
  Stream<Uint8List> get output => outputController.stream;

  @override
  Future<void> write(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> resize(int cols, int rows) async {
    resizes.add((cols, rows));
  }

  @override
  Future<int> get exitCode => exitCompleter.future;

  @override
  Future<void> close() async {
    closed = true;
    if (!outputController.isClosed) {
      await outputController.close();
    }
    if (!exitCompleter.isCompleted) {
      exitCompleter.complete(0);
    }
  }
}

class FakeWorkspaceRuntime extends WorkspaceRuntime {
  FakeWorkspaceRuntime({
    this.ptySupported = true,
    this.ready = true,
    this.reason,
  });

  bool ptySupported;
  bool ready;
  String? reason;
  int statusCalls = 0;
  ScriptedPtySession? lastPty;
  final List<ScriptedPtySession> ptys = <ScriptedPtySession>[];
  String? lastSystemDir;
  String? lastRevealPath;
  List<Mount>? lastMounts;
  String? lastCwd;
  Map<String, String>? lastEnv;

  @override
  bool get supportsPty => ptySupported;

  @override
  bool get supportsSystemTerminal => !ptySupported;

  @override
  Future<RuntimeStatus> status() async {
    statusCalls += 1;
    return RuntimeStatus(
      ready: ready,
      reason: reason,
      engine: 'fake',
      sandboxed: true,
    );
  }

  @override
  Stream<CommandEvent> run(CommandRequest request) =>
      const Stream<CommandEvent>.empty();

  @override
  Future<void> cancel(String runId) async {}

  @override
  Future<PtySession> openPty({
    required List<Mount> mounts,
    required String cwd,
    required Map<String, String> env,
    required int cols,
    required int rows,
  }) async {
    lastMounts = mounts;
    lastCwd = cwd;
    lastEnv = env;
    final session = ScriptedPtySession();
    lastPty = session;
    ptys.add(session);
    return session;
  }

  @override
  Future<void> openInSystemTerminal(String hostDir) async {
    lastSystemDir = hostDir;
  }

  @override
  Future<void> revealInFileManager(String hostPath) async {
    lastRevealPath = hostPath;
  }
}

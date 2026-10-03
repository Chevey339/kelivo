part of 're_editor.dart';

typedef IsolateRunnable<Req, Res> = Res Function(Req req);
typedef IsolateCallback<Res> = void Function(Res res);

class _IsolateTasker<Req, Res> {
  final String name;
  late bool _closed;

  late IsolateManager<Res, Req>? _isolateManager;

  _IsolateTasker(this.name, IsolateRunnable<Req, Res> runnable) {
    _closed = false;
    _isolateManager = IsolateManager.create(
      runnable,
      concurrent: 1, // one is enough
    );
  }

  void run(Req req, IsolateCallback<Res> callback) async {
    if (_closed) {
      return;
    }
    _isolateManager?.compute(req, callback: (message) async {
      if (_closed) {
        return false;
      }
      callback(message);
      return true;
    });
  }

  void close() {
    _closed = true;
    _isolateManager?.stop();
    _isolateManager = null;
  }
}

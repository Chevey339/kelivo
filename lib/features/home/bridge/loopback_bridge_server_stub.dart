import 'kelivo_bridge_facade.dart';

final class LoopbackBridgeServer {
  LoopbackBridgeServer({
    required KelivoBridgeApi facade,
    required String secret,
    int port = 0,
    int maxBodyBytes = 1 << 20,
  });

  int? get boundPort => null;

  Future<int> start() =>
      Future<int>.error(UnsupportedError('desktop_bridge_only'));

  Future<void> stop() async {}
}

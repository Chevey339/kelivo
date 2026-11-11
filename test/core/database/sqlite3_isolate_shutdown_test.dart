import 'dart:isolate';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Exercise the upstream regression through the exact dependency we ship:
// https://github.com/simolus3/sqlite3.dart/pull/438
void main() {
  test('isolate shutdown cannot finalize a released statement again', () async {
    final random = Random(1402);
    for (var i = 0; i < 300; i++) {
      final ready = ReceivePort();
      final exited = ReceivePort();
      final isolate = await Isolate.spawn(
        _prepareAndCloseForever,
        ready.sendPort,
        onExit: exited.sendPort,
      );
      try {
        await ready.first;
        await Future<void>.delayed(
          Duration(microseconds: random.nextInt(2000)),
        );
        isolate.kill(priority: Isolate.immediate);
        await exited.first;
      } finally {
        isolate.kill(priority: Isolate.immediate);
        ready.close();
        exited.close();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

void _prepareAndCloseForever(SendPort ready) {
  final database = sqlite3.openInMemory();
  ready.send(null);
  for (var i = 0; ; i++) {
    final statement = database.prepare('SELECT ?');
    statement.select([i]);
    statement.close();
  }
}

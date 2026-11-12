// Run with: dart run test/perf/browser_workspace_storage_bench.dart
// A timing benchmark, not a test. Uses temporary files and never app data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/services/workspace/workspace_app_storage.dart';

Future<void> main() async {
  final directory = await Directory.systemTemp.createTemp(
    'kelivo-storage-bench-',
  );
  final store = WorkspaceAppStorage(
    root: await directory.resolveSymbolicLinks(),
    directory: 'bench.app.html.data',
    authorize: (_, __) async {},
  );
  final clock = Stopwatch()..start();
  var lastTick = clock.elapsedMicroseconds;
  var maximumDelay = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 4), (_) {
    final now = clock.elapsedMicroseconds;
    final delay = now - lastTick - 4000;
    if (delay > maximumDelay) maximumDelay = delay;
    lastTick = now;
  });
  try {
    final results = <Object?>[];
    for (final size in [10240, 102400, 2097152]) {
      final name = '$size.txt';
      String? version;
      final writes = <int>[], reads = <int>[];
      for (var i = 0; i < 25; i++) {
        final content = String.fromCharCode(65 + i % 26) * size;
        final elapsed = Stopwatch()..start();
        final result = await store.write(name, content, version);
        if (i >= 5) writes.add(elapsed.elapsedMicroseconds);
        version = result['version'] as String;
        elapsed.reset();
        await store.read(name);
        if (i >= 5) reads.add(elapsed.elapsedMicroseconds);
      }
      writes.sort();
      reads.sort();
      results.add({
        'bytes': size,
        'write_p50_ms': writes[10] / 1000,
        'write_p95_ms': writes[18] / 1000,
        'read_p50_ms': reads[10] / 1000,
        'read_p95_ms': reads[18] / 1000,
      });
    }
    stdout.writeln(
      jsonEncode({
        'platform': Platform.operatingSystem,
        'samples_per_size': 20,
        'results': results,
        'main_isolate_max_timer_delay_ms': maximumDelay / 1000,
        'scope':
            'file service only; excludes WebView IPC and production permission lookup',
      }),
    );
  } finally {
    timer.cancel();
    await directory.delete(recursive: true);
  }
}

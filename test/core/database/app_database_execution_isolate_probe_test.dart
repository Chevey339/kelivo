import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SQLite execution probe runs on the background database isolate',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kelivo_database_isolate_probe_',
      );
      final database = AppDatabase.open(
        file: File('${root.path}/${AppDatabase.databaseFileName}'),
      );
      try {
        final result = await database.probeExecutionIsolate(samples: 64);

        expect(result.samples, 64);
        expect(result.openingIsolateCalls, 0);
        expect(result.backgroundIsolateCalls, 64);
      } finally {
        await database.close();
        await root.delete(recursive: true);
      }
    },
  );

  test('SQLite execution probe rejects an empty sample', () async {
    final root = await Directory.systemTemp.createTemp(
      'kelivo_database_isolate_probe_boundary_',
    );
    final database = AppDatabase.open(
      file: File('${root.path}/${AppDatabase.databaseFileName}'),
    );
    try {
      expect(
        () => database.probeExecutionIsolate(samples: 0),
        throwsRangeError,
      );
    } finally {
      await database.close();
      await root.delete(recursive: true);
    }
  });
}

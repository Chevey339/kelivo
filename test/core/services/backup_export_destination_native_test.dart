import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS backups are copied only to destinations outside the app', () async {
    final temp = await Directory.systemTemp.createTemp('kelivo_export_test_');
    addTearDown(() => temp.delete(recursive: true));
    final binary = '${temp.path}/backup_export_test';
    final compile = await Process.run('xcrun', [
      'swiftc',
      'ios/Runner/BackupExportDestination.swift',
      'test/native/backup_export_destination_test.swift',
      '-o',
      binary,
    ]);
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    final result = await Process.run(binary, const []);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  }, skip: !Platform.isMacOS);
}

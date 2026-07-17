import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/legacy_data_retirement_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kelivo_retirement_');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('deletes only the fixed Hive artifacts on user request', () async {
    for (final name in LegacyDataRetirementService.hiveArtifactNames) {
      await File(p.join(directory.path, name)).writeAsString('legacy-$name');
    }
    final unrelated = File(p.join(directory.path, 'keep.me'));
    await unrelated.writeAsString('keep');
    final service = LegacyDataRetirementService(directory);

    final before = await service.inspectHiveArtifacts();
    final receipt = await service.retireHiveArtifacts();

    expect(before, hasLength(3));
    expect(receipt.state, LegacyRetirementState.completed);
    expect(receipt.deletedArtifacts, hasLength(3));
    expect(await unrelated.exists(), isTrue);
    expect(await service.inspectHiveArtifacts(), isEmpty);
  });

  test('does not require rollout age or diagnostic authorization', () async {
    await File(p.join(directory.path, 'messages.hive')).writeAsString('legacy');
    final service = LegacyDataRetirementService(directory);

    final receipt = await service.retireHiveArtifacts();

    expect(receipt.state, LegacyRetirementState.completed);
    expect(receipt.deletedArtifacts.single.name, 'messages.hive');
  });

  test('resumes an operation-ahead deletion after interruption', () async {
    for (final name in LegacyDataRetirementService.hiveArtifactNames) {
      await File(p.join(directory.path, name)).writeAsString('legacy-$name');
    }
    var interrupt = true;
    final service = LegacyDataRetirementService(
      directory,
      afterDeletingReceiptPublished: () async {
        if (interrupt) throw StateError('simulated_kill');
      },
    );

    await expectLater(
      service.retireHiveArtifacts(),
      throwsA(isA<StateError>()),
    );
    expect(
      (await service.readReceipt())!.state,
      LegacyRetirementState.deleting,
    );
    expect(await service.inspectHiveArtifacts(), hasLength(3));

    interrupt = false;
    final completed = await service.retireHiveArtifacts();
    expect(completed.state, LegacyRetirementState.completed);
    expect(await service.inspectHiveArtifacts(), isEmpty);
  });

  test('a completed cleanup can clear newly reappeared legacy files', () async {
    final service = LegacyDataRetirementService(directory);
    await File(p.join(directory.path, 'messages.hive')).writeAsString('first');
    final first = await service.retireHiveArtifacts();
    await File(p.join(directory.path, 'messages.hive')).writeAsString('second');

    final second = await service.retireHiveArtifacts();

    expect(second.sequence, first.sequence + 2);
    expect(await service.inspectHiveArtifacts(), isEmpty);
  });
}

import 'dart:io';

import 'package:Kelivo/core/services/backup/local_snapshot_schedule.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('DatabaseChangeFingerprint', () {
    late Directory root;
    late File database;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('kelivo_fingerprint_');
      database = File(p.join(root.path, 'kelivo.db'));
      await database.writeAsString('contents');
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('同一份未改动的数据库前后一致', () async {
      final first = await DatabaseChangeFingerprint.read(database);
      final second = await DatabaseChangeFingerprint.read(database);
      expect(second.matches(first), isTrue);
    });

    test('没有 -wal 也算"没变"，而不是每次都当作变了', () async {
      // 已 checkpoint 的库旁边没有 -wal。若把"文件不存在"当成"读不出来"，
      // 每次启动都会重新备份一遍，时间纵深会被同一天的多份副本挤没。
      expect(await File('${database.path}-wal').exists(), isFalse);
      final first = await DatabaseChangeFingerprint.read(database);
      expect(
        (await DatabaseChangeFingerprint.read(database)).matches(first),
        isTrue,
      );
    });

    test('WAL 出现即视为有改动', () async {
      final first = await DatabaseChangeFingerprint.read(database);
      await File('${database.path}-wal').writeAsBytes(List<int>.filled(64, 1));
      expect(
        (await DatabaseChangeFingerprint.read(database)).matches(first),
        isFalse,
      );
    });

    test('数据库变大即视为有改动', () async {
      final first = await DatabaseChangeFingerprint.read(database);
      await database.writeAsString('contents and more');
      expect(
        (await DatabaseChangeFingerprint.read(database)).matches(first),
        isFalse,
      );
    });

    test('读不出来的一律不算"没变"', () async {
      final unreadable = DatabaseChangeFingerprint.decode('-1:-1:-1:-1');
      expect(unreadable, isNotNull);
      expect(unreadable!.matches(unreadable), isFalse);
    });

    test('编解码往返', () async {
      final original = await DatabaseChangeFingerprint.read(database);
      final decoded = DatabaseChangeFingerprint.decode(original.encode());
      expect(decoded, isNotNull);
      expect(decoded!.matches(original), isTrue);
    });

    test('损坏的记录解不出来，也就不会被误判为一致', () {
      expect(DatabaseChangeFingerprint.decode(null), isNull);
      expect(DatabaseChangeFingerprint.decode('1:2:3'), isNull);
      expect(DatabaseChangeFingerprint.decode('a:b:c:d'), isNull);
    });
  });

  group('LocalSnapshotSchedule', () {
    final now = DateTime.utc(2026, 5, 10, 12);

    test('关闭时直接说明原因', () {
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: false,
          interval: const Duration(days: 1),
        ),
        LocalSnapshotSkipReason.disabled,
      );
    });

    test('从未备份过就是到期', () {
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: true,
          interval: const Duration(days: 1),
        ),
        isNull,
      );
    });

    test('未满周期不跑', () {
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: true,
          interval: const Duration(days: 1),
          lastSuccessAt: now.subtract(const Duration(hours: 5)),
        ),
        LocalSnapshotSkipReason.notDue,
      );
    });

    test('失败退避窗口内不重试', () {
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: true,
          interval: const Duration(days: 1),
          lastFailureAt: now.subtract(const Duration(minutes: 20)),
        ),
        LocalSnapshotSkipReason.backoff,
      );
    });

    test('时钟往回跳不会把日程卡在未来', () {
      // 上次成功时间在"现在"之后，说明时钟被改过；此时应当照常备份，
      // 而不是等到那个未来时间点过去。
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: true,
          interval: const Duration(days: 1),
          lastSuccessAt: now.add(const Duration(days: 30)),
        ),
        isNull,
      );
      expect(
        LocalSnapshotSchedule.dueSkipReason(
          now: now,
          enabled: true,
          interval: const Duration(days: 1),
          lastFailureAt: now.add(const Duration(days: 30)),
        ),
        isNull,
      );
    });

    test('预估所需空间随库大小增长且大于库本身', () {
      const bytes = 1024 * 1024 * 1024;
      expect(
        LocalSnapshotSchedule.estimatedSpaceRequired(bytes),
        greaterThan(bytes),
      );
    });
  });

  group('LocalSnapshotPaths', () {
    test('文件名按时间字典序排列', () {
      final earlier = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 1, 1));
      final later = LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 6, 1));
      expect(earlier.compareTo(later), lessThan(0));
    });

    test('文件名可解回时间', () {
      final at = DateTime.utc(2026, 5, 1, 8, 30);
      expect(
        LocalSnapshotPaths.createdAtFromFileName(
          LocalSnapshotPaths.fileNameFor(at),
        ),
        at,
      );
    });

    test('不认得的名字返回 null，不会被当成副本', () {
      expect(LocalSnapshotPaths.createdAtFromFileName('kelivo.db'), isNull);
      expect(
        LocalSnapshotPaths.createdAtFromFileName(
          '${LocalSnapshotPaths.filePrefix}nonsense'
          '${LocalSnapshotPaths.fileSuffix}',
        ),
        isNull,
      );
      expect(
        LocalSnapshotPaths.createdAtFromFileName(
          '${LocalSnapshotPaths.temporaryPrefix}'
          '${LocalSnapshotPaths.fileNameFor(DateTime.utc(2026, 5, 1))}',
        ),
        isNull,
      );
    });
  });
}

import 'package:Kelivo/core/services/backup/local_snapshot_retention.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalSnapshotRetentionPolicy', () {
    final now = DateTime.utc(2026, 6, 1, 12);

    SnapshotRetentionEntry entry(
      String id, {
      required Duration age,
      int messageCount = 100,
      int bytes = 1000,
      bool pinned = false,
    }) => SnapshotRetentionEntry(
      id: id,
      createdAt: now.subtract(age),
      bytes: bytes,
      messageCount: messageCount,
      pinned: pinned,
    );

    List<String> deleted(
      LocalSnapshotRetentionPolicy policy,
      List<SnapshotRetentionEntry> entries,
    ) => policy
        .selectForDeletion(entries, now: now)
        .map((entry) => entry.id)
        .toList();

    test('单份副本永远不删', () {
      expect(
        deleted(LocalSnapshotRetentionPolicy.gfsLite, [
          entry('only', age: const Duration(days: 400)),
        ]),
        isEmpty,
      );
    });

    test('GFS-lite 保留 近期3 + 周 + 月', () {
      final entries = [
        entry('d0', age: const Duration(hours: 1)),
        entry('d1', age: const Duration(days: 1)),
        entry('d2', age: const Duration(days: 2)),
        entry('d3', age: const Duration(days: 3)),
        entry('d5', age: const Duration(days: 5)),
        entry('w1', age: const Duration(days: 8)),
        entry('w2', age: const Duration(days: 20)),
        entry('m1', age: const Duration(days: 40)),
        entry('m2', age: const Duration(days: 200)),
      ];

      // 近期 d0/d1/d2；周槽取"最新的一份 >=7 天"= w1；月槽取"最新的一份 >=30 天"= m1。
      expect(deleted(LocalSnapshotRetentionPolicy.gfsLite, entries), [
        'm2',
        'w2',
        'd5',
        'd3',
      ]);
    });

    test('周/月槽取的是最新一份够龄的，不是最老的那份', () {
      final entries = [
        entry('new', age: const Duration(hours: 1)),
        entry('week-fresh', age: const Duration(days: 7, hours: 1)),
        entry('week-stale', age: const Duration(days: 25)),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['week-stale']);
    });

    test('空副本挤不掉最后一份有内容的', () {
      final entries = [
        entry('empty2', age: const Duration(hours: 1), messageCount: 0),
        entry('empty1', age: const Duration(hours: 2), messageCount: 0),
        entry('real', age: const Duration(hours: 3), messageCount: 5000),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['empty1']);
    });

    test('内容骤降时钉住高水位那一份', () {
      final entries = [
        entry('after2', age: const Duration(hours: 1), messageCount: 10),
        entry('after1', age: const Duration(hours: 2), messageCount: 10),
        entry('before', age: const Duration(hours: 3), messageCount: 5000),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['after1']);
    });

    test('内容平稳变化不触发高水位保护', () {
      final entries = [
        entry('c', age: const Duration(hours: 1), messageCount: 900),
        entry('b', age: const Duration(hours: 2), messageCount: 950),
        entry('a', age: const Duration(hours: 3), messageCount: 1000),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['a', 'b']);
    });

    test('高水位保护有期限，不会永久留着已删的数据', () {
      final entries = [
        entry('after', age: const Duration(days: 1), messageCount: 10),
        entry('before', age: const Duration(days: 120), messageCount: 5000),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['before']);
    });

    test('pinned 的副本不参与自动清理', () {
      final entries = [
        entry('new', age: const Duration(hours: 1)),
        entry('old', age: const Duration(days: 300)),
        entry('pinned', age: const Duration(days: 400), pinned: true),
      ];

      final policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
      );
      expect(deleted(policy, entries), ['old']);
    });

    test('超出总量上限时继续砍槽位，但不动受保护的', () {
      final entries = [
        entry('d0', age: const Duration(hours: 1), bytes: 400),
        entry('d1', age: const Duration(days: 1), bytes: 400),
        entry('d2', age: const Duration(days: 2), bytes: 400),
      ];

      const policy = LocalSnapshotRetentionPolicy(
        keepRecent: 3,
        keepWeekly: false,
        keepMonthly: false,
        maximumTotalBytes: 500,
      );
      // 预算只放得下一份，但 d0（最新）受保护，所以停在这里而不是清空。
      expect(deleted(policy, entries), ['d2', 'd1']);
    });

    test('总量上限压不掉最后一份有内容的副本', () {
      final entries = [
        entry('empty', age: const Duration(hours: 1), bytes: 900, messageCount: 0),
        entry('real', age: const Duration(days: 1), bytes: 900, messageCount: 42),
      ];

      const policy = LocalSnapshotRetentionPolicy(
        keepRecent: 1,
        keepWeekly: false,
        keepMonthly: false,
        maximumTotalBytes: 1000,
      );
      expect(deleted(policy, entries), isEmpty);
    });
  });
}

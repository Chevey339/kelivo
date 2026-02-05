import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/provider_group.dart';
import 'package:Kelivo/utils/provider_grouping_logic.dart';

void main() {
  group('Provider grouping logic', () {
    test('moveProviderInGroupedOrder reorders within the same group', () {
      final res = moveProviderInGroupedOrder(
        providersOrder: const ['p1', 'p2', 'p3', 'p4'],
        providerGroupMap: const {'p1': 'A', 'p2': 'A', 'p3': 'B'},
        knownProviderKeys: const {'p1', 'p2', 'p3', 'p4'},
        validGroupIds: const {'A', 'B'},
        providerKey: 'p2',
        targetGroupId: 'A',
        targetPos: 0,
      );
      expect(res.providersOrder, const ['p2', 'p1', 'p3', 'p4']);
      expect(res.providerGroupMap['p2'], 'A');
    });

    test('moveProviderInGroupedOrder moves provider across groups', () {
      final res = moveProviderInGroupedOrder(
        providersOrder: const ['p1', 'p2', 'p3', 'p4'],
        providerGroupMap: const {'p1': 'A', 'p2': 'A', 'p3': 'B'},
        knownProviderKeys: const {'p1', 'p2', 'p3', 'p4'},
        validGroupIds: const {'A', 'B'},
        providerKey: 'p1',
        targetGroupId: 'B',
        targetPos: 1,
      );
      expect(res.providersOrder, const ['p2', 'p3', 'p1', 'p4']);
      expect(res.providerGroupMap['p1'], 'B');
      expect(res.providerGroupMap['p2'], 'A');
      expect(res.providerGroupMap['p3'], 'B');
    });

    test('deleteProviderGroup removes provider mappings and collapse state', () {
      final res = deleteProviderGroup(
        groups: const [
          ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
          ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
        ],
        providerGroupMap: const {'p1': 'A', 'p2': 'A', 'p3': 'B'},
        collapsed: const {'A': true, 'B': false, '__ungrouped__': true},
        groupId: 'A',
      );

      expect([for (final g in res.groups) g.id], const ['B']);
      expect(res.providerGroupMap.containsKey('p1'), isFalse);
      expect(res.providerGroupMap.containsKey('p2'), isFalse);
      expect(res.providerGroupMap['p3'], 'B');
      expect(res.collapsed.containsKey('A'), isFalse);
      expect(res.collapsed['__ungrouped__'], true);
    });

    test('analyzeProviderGroupingReorder blocks moving into collapsed group', () {
      final rows = <ProviderGroupingRowVM>[
        const ProviderGroupingHeaderVM(groupKey: 'A'),
        const ProviderGroupingProviderVM(providerKey: 'p1', groupKey: 'A'),
        const ProviderGroupingHeaderVM(groupKey: 'B'),
      ];

      final analysis = analyzeProviderGroupingReorder(
        rows: rows,
        oldIndex: 1,
        newIndex: 3, // drop to end (after header B)
        isGroupCollapsed: (k) => k == 'B',
      );

      expect(analysis.blockedReason, ProviderGroupingReorderBlockedReason.targetGroupCollapsed);
      expect(analysis.intent, isNull);
    });

    test('analyzeProviderGroupingReorder computes target group + pos', () {
      final rows = <ProviderGroupingRowVM>[
        const ProviderGroupingHeaderVM(groupKey: 'A'),
        const ProviderGroupingProviderVM(providerKey: 'p1', groupKey: 'A'),
        const ProviderGroupingProviderVM(providerKey: 'p2', groupKey: 'A'),
        const ProviderGroupingHeaderVM(groupKey: 'B'),
        const ProviderGroupingProviderVM(providerKey: 'p3', groupKey: 'B'),
      ];

      final analysis = analyzeProviderGroupingReorder(
        rows: rows,
        oldIndex: 2, // p2
        newIndex: 4, // drop right under header B (before p3)
        isGroupCollapsed: (_) => false,
      );

      expect(analysis.intent, isNotNull);
      expect(analysis.intent!.providerKey, 'p2');
      expect(analysis.intent!.targetGroupKey, 'B');
      expect(analysis.intent!.targetPos, 0);
    });
  });
}


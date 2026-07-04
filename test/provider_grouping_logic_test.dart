import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/provider_group.dart';
import 'package:Cuplivo/utils/provider_grouping_logic.dart';

void main() {
  group('Provider grouping logic', () {
    test(
      'buildProviderGroupDisplayKeys inserts ungrouped at persisted index',
      () {
        final res = buildProviderGroupDisplayKeys(
          groups: const [
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ],
          ungroupedIndex: 1,
        );

        expect(res, const ['A', providerUngroupedGroupKey, 'B']);
      },
    );

    test(
      'buildProviderGroupDisplayKeys clamps out-of-range ungrouped index',
      () {
        final res = buildProviderGroupDisplayKeys(
          groups: const [ProviderGroup(id: 'A', name: 'Group A', createdAt: 0)],
          ungroupedIndex: 99,
        );

        expect(res, const ['A', providerUngroupedGroupKey]);
      },
    );

    test(
      'reorderProviderGroupDisplayWithUngrouped reorders other with groups',
      () {
        final res = reorderProviderGroupDisplayWithUngrouped(
          groups: const [
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ],
          ungroupedIndex: 2,
          oldIndex: 2,
          newIndex: 0,
        );

        expect([for (final g in res.groups) g.id], const ['A', 'B']);
        expect(res.ungroupedIndex, 0);
      },
    );

    test(
      'reorderProviderGroupDisplayWithUngrouped reorders a normal group around other',
      () {
        final res = reorderProviderGroupDisplayWithUngrouped(
          groups: const [
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ],
          ungroupedIndex: 1,
          oldIndex: 0,
          newIndex: 3,
        );

        expect([for (final g in res.groups) g.id], const ['B', 'A']);
        expect(res.ungroupedIndex, 0);
      },
    );

    test('insertProviderGroup preserves ungrouped at end when appending', () {
      final res = insertProviderGroup(
        groups: const [
          ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
          ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
        ],
        ungroupedIndex: 2,
        group: const ProviderGroup(id: 'C', name: 'Group C', createdAt: 0),
      );

      expect([for (final g in res.groups) g.id], const ['A', 'B', 'C']);
      expect(res.ungroupedIndex, 3);
    });

    test('buildProviderKeysInGroupedDisplayOrder uses group order first', () {
      final res = buildProviderKeysInGroupedDisplayOrder(
        providersOrder: const ['u1', 'a1', 'b1', 'a2', 'u2'],
        groups: const [
          ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
        ],
        ungroupedIndex: 2,
        providerGroupMap: const {'a1': 'A', 'a2': 'A', 'b1': 'B'},
        knownProviderKeys: const {'u1', 'a1', 'b1', 'a2', 'u2'},
      );

      expect(res, const ['b1', 'a1', 'a2', 'u1', 'u2']);
    });

    test(
      'buildProviderKeysInGroupedDisplayOrder appends missing known keys',
      () {
        final res = buildProviderKeysInGroupedDisplayOrder(
          providersOrder: const ['a1'],
          groups: const [ProviderGroup(id: 'A', name: 'Group A', createdAt: 0)],
          ungroupedIndex: 1,
          providerGroupMap: const {'a1': 'A', 'a2': 'A'},
          knownProviderKeys: const ['a1', 'u1', 'a2'],
        );

        expect(res, const ['a1', 'a2', 'u1']);
      },
    );

    test(
      'buildProviderKeysInGroupedDisplayOrder respects ungrouped position',
      () {
        final res = buildProviderKeysInGroupedDisplayOrder(
          providersOrder: const ['u1', 'a1', 'b1', 'a2', 'u2'],
          groups: const [
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
          ],
          ungroupedIndex: 0,
          providerGroupMap: const {'a1': 'A', 'a2': 'A', 'b1': 'B'},
          knownProviderKeys: const {'u1', 'a1', 'b1', 'a2', 'u2'},
        );

        expect(res, const ['u1', 'u2', 'b1', 'a1', 'a2']);
      },
    );

    test(
      'buildProviderKeysInGroupedDisplayOrder keeps new unrecorded providers visible',
      () {
        final res = buildProviderKeysInGroupedDisplayOrder(
          providersOrder: const ['a1'],
          groups: const [
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ],
          ungroupedIndex: 1,
          providerGroupMap: const {'a1': 'A', 'b1': 'B'},
          knownProviderKeys: const ['a1', 'new1', 'b1', 'new2'],
        );

        expect(res, const ['a1', 'new1', 'new2', 'b1']);
      },
    );

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

    test(
      'deleteProviderGroup removes provider mappings and collapse state',
      () {
        final res = deleteProviderGroup(
          groups: const [
            ProviderGroup(id: 'A', name: 'Group A', createdAt: 0),
            ProviderGroup(id: 'B', name: 'Group B', createdAt: 0),
          ],
          ungroupedIndex: 2,
          providerGroupMap: const {'p1': 'A', 'p2': 'A', 'p3': 'B'},
          collapsed: const {'A': true, 'B': false, '__ungrouped__': true},
          groupId: 'A',
        );

        expect([for (final g in res.groups) g.id], const ['B']);
        expect(res.ungroupedIndex, 1);
        expect(res.providerGroupMap.containsKey('p1'), isFalse);
        expect(res.providerGroupMap.containsKey('p2'), isFalse);
        expect(res.providerGroupMap['p3'], 'B');
        expect(res.collapsed.containsKey('A'), isFalse);
        expect(res.collapsed['__ungrouped__'], true);
      },
    );

    test(
      'analyzeProviderGroupingReorder blocks moving into collapsed group',
      () {
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

        expect(
          analysis.blockedReason,
          ProviderGroupingReorderBlockedReason.targetGroupCollapsed,
        );
        expect(analysis.intent, isNull);
      },
    );

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

    test(
      'analyzeProviderGroupingHeaderReorder returns target header order',
      () {
        final rows = <ProviderGroupingRowVM>[
          const ProviderGroupingHeaderVM(groupKey: 'A'),
          const ProviderGroupingProviderVM(providerKey: 'p1', groupKey: 'A'),
          const ProviderGroupingHeaderVM(groupKey: providerUngroupedGroupKey),
          const ProviderGroupingProviderVM(
            providerKey: 'p2',
            groupKey: providerUngroupedGroupKey,
          ),
          const ProviderGroupingHeaderVM(groupKey: 'B'),
        ];

        final intent = analyzeProviderGroupingHeaderReorder(
          rows: rows,
          oldIndex: 2,
          newIndex: 0,
        );

        expect(intent, isNotNull);
        expect(intent!.groupKey, providerUngroupedGroupKey);
        expect(intent.targetDisplayIndex, 0);
      },
    );

    test(
      'analyzeProviderGroupingHeaderReorder returns null for non-header row',
      () {
        final rows = <ProviderGroupingRowVM>[
          const ProviderGroupingHeaderVM(groupKey: 'A'),
          const ProviderGroupingProviderVM(providerKey: 'p1', groupKey: 'A'),
        ];

        final intent = analyzeProviderGroupingHeaderReorder(
          rows: rows,
          oldIndex: 1,
          newIndex: 0,
        );

        expect(intent, isNull);
      },
    );

    test(
      'mapVisibleGroupTargetToActualInsertIndex maps visible drop into full list order',
      () {
        final actualIndex = mapVisibleGroupTargetToActualInsertIndex(
          fullDisplayKeys: const ['A', providerUngroupedGroupKey, 'B', 'C'],
          visibleHeaderKeys: const ['A', 'C'],
          movedGroupKey: 'A',
          targetVisibleIndex: 1,
        );

        expect(actualIndex, 3);
      },
    );
  });
}

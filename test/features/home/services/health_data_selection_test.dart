import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/health_data_type.dart';
import 'package:Kelivo/features/home/services/health_data_selection.dart';
import 'package:Kelivo/features/home/services/local_tools_service.dart';

void main() {
  const available = HealthDataTypeIds.all;

  Assistant assistant({List<String>? tools, List<String>? types}) {
    return Assistant(
      id: 'a1',
      name: 'A',
      localToolIds: tools ?? const [LocalToolNames.healthSummary],
      healthDataTypeIds: types ?? HealthDataTypeIds.defaultSelected,
    );
  }

  test('master off keeps the previous type selection', () {
    final before = assistant(
      types: const [HealthDataTypeIds.steps, HealthDataTypeIds.sleep],
    );
    final after = HealthDataSelection.setMasterEnabled(
      before,
      enabled: false,
      availableIds: available,
    );
    expect(HealthDataSelection.isMasterEnabled(after), isFalse);
    expect(after.healthDataTypeIds, [
      HealthDataTypeIds.steps,
      HealthDataTypeIds.sleep,
    ]);
  });

  test('master on with empty selection restores defaults', () {
    final before = assistant(tools: const [], types: const []);
    final after = HealthDataSelection.setMasterEnabled(
      before,
      enabled: true,
      availableIds: available,
    );
    expect(HealthDataSelection.isMasterEnabled(after), isTrue);
    expect(after.healthDataTypeIds, HealthDataTypeIds.defaultSelected);
  });

  test('turning every type off also turns the master toggle off', () {
    var current = assistant(types: const [HealthDataTypeIds.steps]);
    current = HealthDataSelection.toggleType(
      current,
      HealthDataTypeIds.steps,
      enabled: false,
    );
    expect(current.healthDataTypeIds, isEmpty);
    expect(HealthDataSelection.isMasterEnabled(current), isFalse);
  });

  test('queryTypes cannot include unselected or unavailable ids', () {
    final current = assistant(
      types: const [
        HealthDataTypeIds.steps,
        HealthDataTypeIds.bloodGlucose,
        'not_a_type',
      ],
    );
    expect(
      HealthDataSelection.queryTypes(
        current,
        availableIds: [HealthDataTypeIds.steps, HealthDataTypeIds.sleep],
      ),
      [HealthDataTypeIds.steps],
    );
  });

  test('enableAll selects every available id and turns master on', () {
    final before = assistant(tools: const [], types: const []);
    final after = HealthDataSelection.enableAll(
      before,
      availableIds: [
        HealthDataTypeIds.steps,
        HealthDataTypeIds.sleep,
        HealthDataTypeIds.bloodGlucose,
      ],
    );
    expect(HealthDataSelection.isMasterEnabled(after), isTrue);
    expect(after.healthDataTypeIds, [
      HealthDataTypeIds.steps,
      HealthDataTypeIds.sleep,
      HealthDataTypeIds.bloodGlucose,
    ]);
    expect(
      HealthDataSelection.queryTypes(
        after,
        availableIds: [
          HealthDataTypeIds.steps,
          HealthDataTypeIds.sleep,
          HealthDataTypeIds.bloodGlucose,
        ],
      ),
      after.healthDataTypeIds,
    );
  });

  test('enableAll skips types that are not available on this OS', () {
    final after = HealthDataSelection.enableAll(
      assistant(),
      availableIds: HealthDataTypeIds.withoutOsVersionGate,
    );
    expect(after.healthDataTypeIds, HealthDataTypeIds.withoutOsVersionGate);
    expect(
      after.healthDataTypeIds,
      isNot(contains(HealthDataTypeIds.daylight)),
    );
    expect(
      HealthDataSelection.isEveryAvailableSelected(
        after.healthDataTypeIds,
        HealthDataTypeIds.withoutOsVersionGate,
      ),
      isTrue,
    );
  });

  test('disableAll clears types and turns master off', () {
    final after = HealthDataSelection.disableAll(assistant());
    expect(after.healthDataTypeIds, isEmpty);
    expect(HealthDataSelection.isMasterEnabled(after), isFalse);
    expect(
      HealthDataSelection.isNoneSelected(after.healthDataTypeIds, available),
      isTrue,
    );
  });
}

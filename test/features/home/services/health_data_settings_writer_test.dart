import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/health_data_type.dart';
import 'package:Kelivo/features/home/services/health_data_selection.dart';
import 'package:Kelivo/features/home/services/health_data_settings_writer.dart';
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

  test(
    'overlapping master-off then type toggle keeps master off and both writes',
    () async {
      var current = assistant(
        types: const [HealthDataTypeIds.steps, HealthDataTypeIds.sleep],
      );
      final writer = HealthDataSettingsWriter(
        readAssistant: () => current,
        updateAssistant: (next) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          current = next;
        },
      );

      final first = writer.apply((latest) async {
        return HealthDataSelection.setMasterEnabled(
          latest,
          enabled: false,
          availableIds: available,
        );
      });
      final second = writer.apply((latest) async {
        return HealthDataSelection.toggleType(
          latest,
          HealthDataTypeIds.steps,
          enabled: false,
        );
      });
      await Future.wait([first, second]);

      expect(HealthDataSelection.isMasterEnabled(current), isFalse);
      expect(current.healthDataTypeIds, [HealthDataTypeIds.sleep]);
    },
  );

  test('overlapping type toggles both persist', () async {
    var current = assistant();
    final writer = HealthDataSettingsWriter(
      readAssistant: () => current,
      updateAssistant: (next) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        current = next;
      },
    );

    final first = writer.apply((latest) async {
      return HealthDataSelection.toggleType(
        latest,
        HealthDataTypeIds.steps,
        enabled: false,
      );
    });
    final second = writer.apply((latest) async {
      return HealthDataSelection.toggleType(
        latest,
        HealthDataTypeIds.sleep,
        enabled: false,
      );
    });
    await Future.wait([first, second]);

    expect(current.healthDataTypeIds, isNot(contains(HealthDataTypeIds.steps)));
    expect(current.healthDataTypeIds, isNot(contains(HealthDataTypeIds.sleep)));
    expect(
      current.healthDataTypeIds,
      containsAll([
        HealthDataTypeIds.activeEnergy,
        HealthDataTypeIds.distance,
        HealthDataTypeIds.heartRate,
        HealthDataTypeIds.workouts,
      ]),
    );
    expect(HealthDataSelection.isMasterEnabled(current), isTrue);
  });
}

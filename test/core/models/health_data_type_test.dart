import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/health_data_type.dart';

void main() {
  group('HealthDataTypeIds', () {
    test('default selected is the original six metrics', () {
      expect(HealthDataTypeIds.defaultSelected, [
        HealthDataTypeIds.steps,
        HealthDataTypeIds.activeEnergy,
        HealthDataTypeIds.distance,
        HealthDataTypeIds.sleep,
        HealthDataTypeIds.heartRate,
        HealthDataTypeIds.workouts,
      ]);
      expect(HealthDataTypeIds.all, hasLength(17));
      expect(
        HealthDataTypeIds.defaultSelected,
        isNot(contains(HealthDataTypeIds.bloodGlucose)),
      );
      expect(
        HealthDataTypeIds.defaultSelected,
        isNot(contains(HealthDataTypeIds.daylight)),
      );
    });

    test('missing json uses defaults; empty list is preserved', () {
      expect(
        HealthDataTypeIds.parseStoredIds(null),
        HealthDataTypeIds.defaultSelected,
      );
      expect(HealthDataTypeIds.parseStoredIds(<String>[]), isEmpty);
      expect(
        HealthDataTypeIds.parseStoredIds([
          'steps',
          'unknown',
          'sleep',
          'steps',
        ]),
        [HealthDataTypeIds.steps, HealthDataTypeIds.sleep],
      );
    });

    test('intersectAvailable drops unknown and unselected types', () {
      expect(
        HealthDataTypeIds.intersectAvailable(
          ['steps', 'blood_glucose', 'not_a_type'],
          [HealthDataTypeIds.steps, HealthDataTypeIds.sleep],
        ),
        [HealthDataTypeIds.steps],
      );
    });

    test('sleep tool label is duration, not stages', () {
      expect(
        HealthDataTypeIds.toolLabel(HealthDataTypeIds.sleep),
        'last-night sleep',
      );
      expect(
        HealthDataTypeIds.toolLabel(HealthDataTypeIds.sleep).toLowerCase(),
        isNot(contains('stage')),
      );
    });
  });

  group('Assistant healthDataTypeIds', () {
    test('new assistants default to the original six types', () {
      const assistant = Assistant(id: 'a1', name: 'A');
      expect(assistant.healthDataTypeIds, HealthDataTypeIds.defaultSelected);
    });

    test('json round-trips a custom selection', () {
      final assistant = Assistant(
        id: 'a1',
        name: 'A',
        healthDataTypeIds: const [
          HealthDataTypeIds.steps,
          HealthDataTypeIds.bloodGlucose,
        ],
      );
      final decoded = Assistant.fromJson(assistant.toJson());
      expect(decoded.healthDataTypeIds, [
        HealthDataTypeIds.steps,
        HealthDataTypeIds.bloodGlucose,
      ]);
    });

    test('missing json field does not expand to every type', () {
      final decoded = Assistant.fromJson(const {'id': 'a1', 'name': 'A'});
      expect(decoded.healthDataTypeIds, HealthDataTypeIds.defaultSelected);
      expect(decoded.healthDataTypeIds, isNot(HealthDataTypeIds.all));
    });
  });
}

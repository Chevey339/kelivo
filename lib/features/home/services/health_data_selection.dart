import '../../../core/models/assistant.dart';
import '../../../core/models/health_data_type.dart';
import 'local_tools_service.dart';

/// Master-toggle and per-type selection rules for Health data.
abstract final class HealthDataSelection {
  HealthDataSelection._();

  static bool isMasterEnabled(Assistant assistant) {
    return assistant.localToolIds.contains(LocalToolNames.healthSummary);
  }

  /// Types the native query / authorization sheet may use.
  static List<String> queryTypes(
    Assistant assistant, {
    Iterable<String>? availableIds,
  }) {
    final available = availableIds ?? DeviceLocalTools.availableHealthTypeIds;
    return HealthDataTypeIds.intersectAvailable(
      assistant.healthDataTypeIds,
      available,
    );
  }

  static Assistant toggleType(
    Assistant assistant,
    String typeId, {
    required bool enabled,
  }) {
    if (!HealthDataTypeIds.isKnown(typeId)) return assistant;
    final selected = List<String>.from(assistant.healthDataTypeIds);
    if (enabled) {
      if (!selected.contains(typeId)) selected.add(typeId);
    } else {
      selected.remove(typeId);
    }
    final toolIds = assistant.localToolIds.toSet();
    if (selected.isEmpty) {
      toolIds.remove(LocalToolNames.healthSummary);
    }
    return assistant.copyWith(
      healthDataTypeIds: selected,
      localToolIds: toolIds.toList(growable: false),
    );
  }

  /// Turning master off keeps [Assistant.healthDataTypeIds]. Turning it on
  /// with an empty selection restores [HealthDataTypeIds.defaultSelected].
  static Assistant setMasterEnabled(
    Assistant assistant, {
    required bool enabled,
    Iterable<String> availableIds = const [],
  }) {
    final toolIds = assistant.localToolIds.toSet();
    var types = List<String>.from(assistant.healthDataTypeIds);
    if (enabled) {
      final available = availableIds.toList();
      if (available.isNotEmpty) {
        final effective = HealthDataTypeIds.intersectAvailable(
          types,
          available,
        );
        if (effective.isEmpty) {
          types = HealthDataTypeIds.intersectAvailable(
            HealthDataTypeIds.defaultSelected,
            available,
          );
        }
      } else if (types.isEmpty) {
        types = List<String>.from(HealthDataTypeIds.defaultSelected);
      }
      toolIds.add(LocalToolNames.healthSummary);
    } else {
      toolIds.remove(LocalToolNames.healthSummary);
    }
    return assistant.copyWith(
      localToolIds: toolIds.toList(growable: false),
      healthDataTypeIds: types,
    );
  }

  /// Turns on every type in [availableIds] and the health master toggle.
  /// Unavailable / unknown IDs are not stored.
  static Assistant enableAll(
    Assistant assistant, {
    required Iterable<String> availableIds,
  }) {
    final types = HealthDataTypeIds.intersectAvailable(
      HealthDataTypeIds.all,
      availableIds,
    );
    final toolIds = assistant.localToolIds.toSet();
    if (types.isNotEmpty) {
      toolIds.add(LocalToolNames.healthSummary);
    }
    return assistant.copyWith(
      healthDataTypeIds: types,
      localToolIds: toolIds.toList(growable: false),
    );
  }

  /// Clears every type. Master turns off because the selection is empty.
  static Assistant disableAll(Assistant assistant) {
    final toolIds = assistant.localToolIds.toSet()
      ..remove(LocalToolNames.healthSummary);
    return assistant.copyWith(
      healthDataTypeIds: const <String>[],
      localToolIds: toolIds.toList(growable: false),
    );
  }

  static bool isEveryAvailableSelected(
    Iterable<String> selectedIds,
    Iterable<String> availableIds,
  ) {
    final available = HealthDataTypeIds.intersectAvailable(
      HealthDataTypeIds.all,
      availableIds,
    );
    if (available.isEmpty) return true;
    final selected = HealthDataTypeIds.intersectAvailable(
      selectedIds,
      available,
    ).toSet();
    return available.every(selected.contains);
  }

  static bool isNoneSelected(
    Iterable<String> selectedIds,
    Iterable<String> availableIds,
  ) {
    return HealthDataTypeIds.intersectAvailable(
      selectedIds,
      availableIds,
    ).isEmpty;
  }
}

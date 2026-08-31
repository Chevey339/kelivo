import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/assistant.dart';
import '../../../core/providers/assistant_provider.dart';
import '../../home/services/health_data_selection.dart';
import '../../home/services/health_data_settings_writer.dart';
import '../../home/services/local_tools_service.dart';
import 'health_data_settings_view.dart';

/// Wires [HealthDataSettingsView] to the current collaborator.
class HealthDataSettingsConnected extends StatefulWidget {
  const HealthDataSettingsConnected({
    super.key,
    required this.assistantId,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final String assistantId;
  final EdgeInsetsGeometry padding;

  @override
  State<HealthDataSettingsConnected> createState() =>
      _HealthDataSettingsConnectedState();
}

class _HealthDataSettingsConnectedState
    extends State<HealthDataSettingsConnected> {
  late final HealthDataSettingsWriter _writer = HealthDataSettingsWriter(
    readAssistant: _latestAssistant,
    updateAssistant: _persist,
  );

  Assistant? _latestAssistant() {
    if (!mounted) return null;
    return context.read<AssistantProvider>().getById(widget.assistantId);
  }

  Future<void> _persist(Assistant next) async {
    if (!mounted) return;
    await context.read<AssistantProvider>().updateAssistant(next);
  }

  @override
  Widget build(BuildContext context) {
    final assistant = context.watch<AssistantProvider>().getById(
      widget.assistantId,
    );
    if (assistant == null) {
      return const SizedBox.shrink();
    }
    if (!DeviceLocalTools.iosDeviceToolsSupported) {
      return _view(assistant);
    }
    return FutureBuilder<bool>(
      future: DeviceLocalTools.prefetchIosCapabilities(),
      builder: (context, _) => _view(assistant),
    );
  }

  Widget _view(Assistant assistant) {
    return HealthDataSettingsView(
      masterEnabled: HealthDataSelection.isMasterEnabled(assistant),
      selectedIds: assistant.healthDataTypeIds,
      availableIds: DeviceLocalTools.availableHealthTypeIds,
      onToggleMaster: _setMaster,
      onToggleType: _setType,
      onEnableAll: _enableAll,
      onDisableAll: _disableAll,
      onOpenSystemSettings: DeviceLocalTools.openAppSettings,
      padding: widget.padding,
    );
  }

  Future<void> _setMaster(bool enabled) {
    return _writer.apply((current) async {
      final available = DeviceLocalTools.availableHealthTypeIds;
      final next = HealthDataSelection.setMasterEnabled(
        current,
        enabled: enabled,
        availableIds: available,
      );
      if (enabled && DeviceLocalTools.healthSupported) {
        final types = HealthDataSelection.queryTypes(
          next,
          availableIds: available,
        );
        final requested = await DeviceLocalTools.requestHealthPermission(
          types: types,
        );
        if (!requested) return null;
      }
      return next;
    });
  }

  Future<void> _setType(String typeId, bool enabled) {
    return _writer.apply((current) async {
      if (enabled &&
          HealthDataSelection.isMasterEnabled(current) &&
          DeviceLocalTools.healthSupported) {
        final requested = await DeviceLocalTools.requestHealthPermission(
          types: [typeId],
        );
        if (!requested) return null;
      }
      return HealthDataSelection.toggleType(current, typeId, enabled: enabled);
    });
  }

  Future<void> _enableAll() {
    return _writer.apply((current) async {
      final available = DeviceLocalTools.availableHealthTypeIds;
      if (HealthDataSelection.isEveryAvailableSelected(
        current.healthDataTypeIds,
        available,
      )) {
        return null;
      }
      final next = HealthDataSelection.enableAll(
        current,
        availableIds: available,
      );
      if (DeviceLocalTools.healthSupported) {
        final types = HealthDataSelection.queryTypes(
          next,
          availableIds: available,
        );
        final requested = await DeviceLocalTools.requestHealthPermission(
          types: types,
        );
        if (!requested) return null;
      }
      return next;
    });
  }

  Future<void> _disableAll() {
    return _writer.apply((current) async {
      final available = DeviceLocalTools.availableHealthTypeIds;
      if (HealthDataSelection.isNoneSelected(
        current.healthDataTypeIds,
        available,
      )) {
        return null;
      }
      return HealthDataSelection.disableAll(current);
    });
  }
}

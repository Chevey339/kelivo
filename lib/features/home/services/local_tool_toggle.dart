import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import 'health_data_selection.dart';
import 'local_tools_service.dart';

/// Flips one entry of [Assistant.localToolIds], asking for the OS permission
/// the tool needs first.
///
/// Turning a tool off never prompts. Turning one on writes the id only after
/// its permission is granted, except for screen time, where Usage Access opens
/// in Settings and the tool is enabled regardless so the switch matches what
/// the user just asked for.
Future<void> setLocalToolEnabled(
  BuildContext context, {
  required Assistant assistant,
  required String toolId,
  required bool value,
}) async {
  Future<void> write(bool enabled) {
    final ids = assistant.localToolIds.toSet();
    if (enabled) {
      ids.add(toolId);
    } else {
      ids.remove(toolId);
    }
    return context.read<AssistantProvider>().updateAssistant(
      assistant.copyWith(localToolIds: ids.toList(growable: false)),
    );
  }

  if (!value) {
    await write(false);
    return;
  }

  if (toolId == LocalToolNames.screenTime &&
      DeviceLocalTools.screenTimeSupported) {
    final granted = await DeviceLocalTools.hasUsageStatsPermission();
    if (!granted) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(
            context,
          )!.chatMessageWidgetScreenTimePermissionRequired,
          type: NotificationType.warning,
        );
      }
      await DeviceLocalTools.openUsageAccessSettings();
    }
    // Still enable even if Usage Access is not granted yet.
    await write(true);
    return;
  }

  if ((toolId == LocalToolNames.calendarQuery ||
          toolId == LocalToolNames.calendarCreate) &&
      DeviceLocalTools.calendarSupported) {
    final granted = await DeviceLocalTools.hasCalendarPermission();
    if (!granted) {
      final requested = await DeviceLocalTools.requestCalendarPermission();
      // Do not enable until the user grants calendar access.
      if (!requested) return;
    }
    await write(true);
    return;
  }

  if (toolId == LocalToolNames.currentLocation &&
      DeviceLocalTools.locationSupported) {
    final granted = await DeviceLocalTools.hasLocationPermission();
    if (!granted) {
      final requested = await DeviceLocalTools.requestLocationPermission();
      if (!requested) return;
    }
    await write(true);
    return;
  }

  if ((toolId == LocalToolNames.remindersQuery ||
          toolId == LocalToolNames.remindersCreate ||
          toolId == LocalToolNames.remindersComplete) &&
      DeviceLocalTools.remindersSupported) {
    final granted = await DeviceLocalTools.hasRemindersPermission();
    if (!granted) {
      final requested = await DeviceLocalTools.requestRemindersPermission();
      if (!requested) return;
    }
    await write(true);
    return;
  }

  if (toolId == LocalToolNames.healthSummary &&
      DeviceLocalTools.healthSupported) {
    final next = HealthDataSelection.setMasterEnabled(
      assistant,
      enabled: true,
      availableIds: DeviceLocalTools.availableHealthTypeIds,
    );
    final types = HealthDataSelection.queryTypes(
      next,
      availableIds: DeviceLocalTools.availableHealthTypeIds,
    );
    final requested = await DeviceLocalTools.requestHealthPermission(
      types: types,
    );
    if (!requested) return;
    if (!context.mounted) return;
    await context.read<AssistantProvider>().updateAssistant(next);
    return;
  }

  await write(true);
}

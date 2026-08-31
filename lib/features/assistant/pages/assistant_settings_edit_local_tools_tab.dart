part of 'assistant_settings_edit_page.dart';

class _LocalToolsTab extends StatelessWidget {
  const _LocalToolsTab({required this.assistantId});
  final String assistantId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ap = context.watch<AssistantProvider>();
    final assistant = ap.getById(assistantId)!;
    final timeEnabled = assistant.localToolIds.contains(
      LocalToolNames.timeInfo,
    );
    final clipboardEnabled = assistant.localToolIds.contains(
      LocalToolNames.clipboard,
    );
    final textToSpeechEnabled = assistant.localToolIds.contains(
      LocalToolNames.textToSpeech,
    );
    final askUserEnabled = assistant.localToolIds.contains(
      LocalToolNames.askUser,
    );
    final calculateEnabled = assistant.localToolIds.contains(
      LocalToolNames.calculate,
    );
    final screenTimeEnabled = assistant.localToolIds.contains(
      LocalToolNames.screenTime,
    );
    final calendarQueryEnabled = assistant.localToolIds.contains(
      LocalToolNames.calendarQuery,
    );
    final calendarCreateEnabled = assistant.localToolIds.contains(
      LocalToolNames.calendarCreate,
    );
    final locationEnabled = assistant.localToolIds.contains(
      LocalToolNames.currentLocation,
    );
    final weatherEnabled = assistant.localToolIds.contains(
      LocalToolNames.weather,
    );
    final healthEnabled = assistant.localToolIds.contains(
      LocalToolNames.healthSummary,
    );
    final remindersQueryEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersQuery,
    );
    final remindersCreateEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersCreate,
    );
    final remindersCompleteEnabled = assistant.localToolIds.contains(
      LocalToolNames.remindersComplete,
    );

    Future<void> updateTool(String toolId, bool value) {
      final ids = assistant.localToolIds.toSet();
      if (value) {
        ids.add(toolId);
      } else {
        ids.remove(toolId);
      }
      return context.read<AssistantProvider>().updateAssistant(
        assistant.copyWith(localToolIds: ids.toList(growable: false)),
      );
    }

    Future<void> toggleTool(String toolId, bool value) async {
      if (!value) {
        await updateTool(toolId, false);
        return;
      }

      if (toolId == LocalToolNames.screenTime &&
          DeviceLocalTools.screenTimeSupported) {
        final granted = await DeviceLocalTools.hasUsageStatsPermission();
        if (!granted) {
          if (context.mounted) {
            showAppSnackBar(
              context,
              message: l10n.chatMessageWidgetScreenTimePermissionRequired,
              type: NotificationType.warning,
            );
          }
          await DeviceLocalTools.openUsageAccessSettings();
        }
        // Still enable even if Usage Access is not granted yet.
        await updateTool(toolId, true);
        return;
      }

      if ((toolId == LocalToolNames.calendarQuery ||
              toolId == LocalToolNames.calendarCreate) &&
          DeviceLocalTools.calendarSupported) {
        final granted = await DeviceLocalTools.hasCalendarPermission();
        if (!granted) {
          final requested = await DeviceLocalTools.requestCalendarPermission();
          if (!requested) {
            // Do not enable until the user grants calendar access.
            return;
          }
        }
        await updateTool(toolId, true);
        return;
      }

      if (toolId == LocalToolNames.currentLocation &&
          DeviceLocalTools.locationSupported) {
        final granted = await DeviceLocalTools.hasLocationPermission();
        if (!granted) {
          final requested = await DeviceLocalTools.requestLocationPermission();
          if (!requested) {
            return;
          }
        }
        await updateTool(toolId, true);
        return;
      }

      if ((toolId == LocalToolNames.remindersQuery ||
              toolId == LocalToolNames.remindersCreate ||
              toolId == LocalToolNames.remindersComplete) &&
          DeviceLocalTools.remindersSupported) {
        final granted = await DeviceLocalTools.hasRemindersPermission();
        if (!granted) {
          final requested = await DeviceLocalTools.requestRemindersPermission();
          if (!requested) {
            return;
          }
        }
        await updateTool(toolId, true);
        return;
      }

      if (toolId == LocalToolNames.healthSummary &&
          DeviceLocalTools.healthSupported) {
        if (!value) {
          await updateTool(toolId, false);
          return;
        }
        var next = HealthDataSelection.setMasterEnabled(
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

      await updateTool(toolId, true);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        SectionCard(
          children: [
            _LocalToolRow(
              icon: Lucide.clock,
              title: l10n.assistantEditLocalToolTimeInfoTitle,
              subtitle: l10n.assistantEditLocalToolTimeInfoSubtitle,
              enabled: timeEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.timeInfo, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Clipboard,
              title: l10n.assistantEditLocalToolClipboardTitle,
              subtitle: l10n.assistantEditLocalToolClipboardSubtitle,
              enabled: clipboardEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.clipboard, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Volume2,
              title: l10n.assistantEditLocalToolTextToSpeechTitle,
              subtitle: l10n.assistantEditLocalToolTextToSpeechSubtitle,
              enabled: textToSpeechEnabled,
              onChanged: (value) =>
                  toggleTool(LocalToolNames.textToSpeech, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.MessageCircleQuestionMark,
              title: l10n.assistantEditLocalToolAskUserTitle,
              subtitle: l10n.assistantEditLocalToolAskUserSubtitle,
              enabled: askUserEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.askUser, value),
            ),
            _iosDivider(context),
            _LocalToolRow(
              icon: Lucide.Calculator,
              title: l10n.assistantEditLocalToolCalculateTitle,
              subtitle: l10n.assistantEditLocalToolCalculateSubtitle,
              enabled: calculateEnabled,
              onChanged: (value) => toggleTool(LocalToolNames.calculate, value),
            ),
            if (DeviceLocalTools.screenTimeSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.Smartphone,
                title: l10n.assistantEditLocalToolScreenTimeTitle,
                subtitle: l10n.assistantEditLocalToolScreenTimeSubtitle,
                enabled: screenTimeEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.screenTime, value),
              ),
            ],
            if (DeviceLocalTools.calendarSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.Calendar,
                title: l10n.assistantEditLocalToolCalendarQueryTitle,
                subtitle: l10n.assistantEditLocalToolCalendarQuerySubtitle,
                enabled: calendarQueryEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.calendarQuery, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.CalendarPlus,
                title: l10n.assistantEditLocalToolCalendarCreateTitle,
                subtitle: l10n.assistantEditLocalToolCalendarCreateSubtitle,
                enabled: calendarCreateEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.calendarCreate, value),
              ),
            ],
            if (DeviceLocalTools.locationSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.MapPin,
                title: l10n.assistantEditLocalToolLocationTitle,
                subtitle: l10n.assistantEditLocalToolLocationSubtitle,
                enabled: locationEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.currentLocation, value),
              ),
            ],
            if (DeviceLocalTools.iosDeviceToolsSupported)
              FutureBuilder<bool>(
                future: DeviceLocalTools.prefetchIosCapabilities(),
                builder: (context, snapshot) {
                  if (!DeviceLocalTools.weatherSupported) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iosDivider(context),
                      _LocalToolRow(
                        icon: Lucide.CloudSun,
                        title: l10n.assistantEditLocalToolWeatherTitle,
                        subtitle: l10n.assistantEditLocalToolWeatherSubtitle,
                        enabled: weatherEnabled,
                        onChanged: (value) =>
                            toggleTool(LocalToolNames.weather, value),
                      ),
                    ],
                  );
                },
              ),
            if (DeviceLocalTools.remindersSupported) ...[
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.ListTodo,
                title: l10n.assistantEditLocalToolRemindersQueryTitle,
                subtitle: l10n.assistantEditLocalToolRemindersQuerySubtitle,
                enabled: remindersQueryEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersQuery, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.ListPlus,
                title: l10n.assistantEditLocalToolRemindersCreateTitle,
                subtitle: l10n.assistantEditLocalToolRemindersCreateSubtitle,
                enabled: remindersCreateEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersCreate, value),
              ),
              _iosDivider(context),
              _LocalToolRow(
                icon: Lucide.CheckCircle,
                title: l10n.assistantEditLocalToolRemindersCompleteTitle,
                subtitle: l10n.assistantEditLocalToolRemindersCompleteSubtitle,
                enabled: remindersCompleteEnabled,
                onChanged: (value) =>
                    toggleTool(LocalToolNames.remindersComplete, value),
              ),
            ],
            if (DeviceLocalTools.iosDeviceToolsSupported)
              FutureBuilder<bool>(
                future: DeviceLocalTools.prefetchIosCapabilities(),
                builder: (context, snapshot) {
                  if (!DeviceLocalTools.healthSupported) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _iosDivider(context),
                      _HealthToolRow(
                        title: l10n.assistantEditLocalToolHealthTitle,
                        subtitle: l10n.assistantEditLocalToolHealthSubtitle,
                        selectedSummary: l10n
                            .assistantEditLocalToolHealthSelectedCount(
                              HealthDataTypeIds.intersectAvailable(
                                assistant.healthDataTypeIds,
                                DeviceLocalTools.availableHealthTypeIds,
                              ).length,
                              DeviceLocalTools.availableHealthTypeIds.length,
                            ),
                        enabled: healthEnabled,
                        onChanged: (value) =>
                            toggleTool(LocalToolNames.healthSummary, value),
                        onOpenSettings: () =>
                            HealthDataSettingsPage.open(context, assistantId),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _LocalToolRow extends StatelessWidget {
  const _LocalToolRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      onTap: () => onChanged(!enabled),
      builder: (pressed) {
        final baseColor = cs.onSurface.withValues(alpha: 0.9);
        return _AnimatedPressColor(
          pressed: pressed,
          base: baseColor,
          builder: (color) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    child: Icon(
                      icon,
                      size: 20,
                      color: enabled ? cs.primary : color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: color,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            color: cs.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IosSwitch(value: enabled, onChanged: onChanged),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HealthToolRow extends StatelessWidget {
  const _HealthToolRow({
    required this.title,
    required this.subtitle,
    required this.selectedSummary,
    required this.enabled,
    required this.onChanged,
    required this.onOpenSettings,
  });

  final String title;
  final String subtitle;
  final String selectedSummary;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _TactileRow(
              onTap: onOpenSettings,
              builder: (pressed) {
                final baseColor = cs.onSurface.withValues(alpha: 0.9);
                return _AnimatedPressColor(
                  pressed: pressed,
                  base: baseColor,
                  builder: (color) {
                    return Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Icon(
                            Lucide.HeartPulse,
                            size: 20,
                            color: enabled ? cs.primary : color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: color,
                                  fontWeight: AppFontWeights.semibold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: cs.onSurface.withValues(alpha: 0.62),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                selectedSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.25,
                                  color: cs.primary.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Lucide.ChevronRight,
                          size: 16,
                          color: cs.onSurface.withValues(alpha: 0.35),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          IosSwitch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

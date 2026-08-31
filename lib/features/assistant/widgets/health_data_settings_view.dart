import 'package:flutter/material.dart';

import '../../../core/models/health_data_type.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../home/services/health_data_selection.dart';

/// Presentational Health Data settings body (mobile, desktop, and previews).
class HealthDataSettingsView extends StatefulWidget {
  const HealthDataSettingsView({
    super.key,
    required this.masterEnabled,
    required this.selectedIds,
    required this.availableIds,
    required this.onToggleMaster,
    required this.onToggleType,
    required this.onEnableAll,
    required this.onDisableAll,
    required this.onOpenSystemSettings,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final bool masterEnabled;
  final List<String> selectedIds;
  final List<String> availableIds;
  final ValueChanged<bool> onToggleMaster;
  final void Function(String typeId, bool enabled) onToggleType;
  final VoidCallback onEnableAll;
  final VoidCallback onDisableAll;
  final VoidCallback onOpenSystemSettings;
  final EdgeInsetsGeometry padding;

  @override
  State<HealthDataSettingsView> createState() => _HealthDataSettingsViewState();
}

class _HealthDataSettingsViewState extends State<HealthDataSettingsView> {
  HealthDataCategory _category = HealthDataCategory.activity;

  @override
  void didUpdateWidget(covariant HealthDataSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final categories = _visibleCategories();
    if (categories.isNotEmpty && !categories.contains(_category)) {
      _category = categories.first;
    }
  }

  Set<String> get _availableSet => widget.availableIds.toSet();

  Set<String> get _selectedSet => widget.selectedIds.toSet();

  List<HealthDataCategory> _visibleCategories() {
    return [
      for (final category in HealthDataCategory.values)
        if (_typesIn(category).isNotEmpty) category,
    ];
  }

  List<HealthDataType> _typesIn(HealthDataCategory category) {
    return [
      for (final type in HealthDataTypeIds.typesIn(category))
        if (_availableSet.contains(HealthDataTypeIds.idFor(type))) type,
    ];
  }

  int _selectedCount(Iterable<HealthDataType> types) {
    var count = 0;
    for (final type in types) {
      if (_selectedSet.contains(HealthDataTypeIds.idFor(type))) count++;
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final categories = _visibleCategories();
    final selectedCategory = categories.contains(_category)
        ? _category
        : (categories.isNotEmpty ? categories.first : _category);
    final total = widget.availableIds.length;
    final selected = HealthDataTypeIds.intersectAvailable(
      widget.selectedIds,
      widget.availableIds,
    ).length;
    final categoryTypes = _typesIn(selectedCategory);

    return ListView(
      padding: widget.padding,
      children: [
        SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Icon(
                    Lucide.HeartPulse,
                    size: 20,
                    color: widget.masterEnabled ? cs.primary : cs.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.healthDataSettingsTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.semibold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  _StatusBadge(
                    label: l10n.healthDataSettingsBadge(selected, total),
                  ),
                  const SizedBox(width: 8),
                  IosSwitch(
                    value: widget.masterEnabled,
                    onChanged: widget.onToggleMaster,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                l10n.healthDataSettingsDescription,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: 0.62),
                ),
              ),
            ),
            Divider(
              height: 1,
              thickness: 0.6,
              indent: 12,
              endIndent: 12,
              color: cs.outlineVariant.withValues(alpha: 0.18),
            ),
            _SystemStatusRow(
              title: l10n.healthDataSettingsIosReadTitle,
              subtitle: l10n.healthDataSettingsIosReadSubtitle,
              semanticLabel: l10n.healthDataSettingsOpenSystemSettings,
              onOpenSettings: widget.onOpenSystemSettings,
            ),
            Divider(
              height: 1,
              thickness: 0.6,
              indent: 12,
              endIndent: 12,
              color: cs.outlineVariant.withValues(alpha: 0.18),
            ),
            _BulkActionsRow(
              enableEnabled:
                  total > 0 &&
                  !HealthDataSelection.isEveryAvailableSelected(
                    widget.selectedIds,
                    widget.availableIds,
                  ),
              disableEnabled: !HealthDataSelection.isNoneSelected(
                widget.selectedIds,
                widget.availableIds,
              ),
              onEnableAll: widget.onEnableAll,
              onDisableAll: widget.onDisableAll,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (categories.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = categories[index];
                final types = _typesIn(item);
                return _CategoryPill(
                  key: Key('health_category_${item.name}'),
                  icon: _categoryIcon(item),
                  label: _categoryLabel(l10n, item),
                  selectedCount: _selectedCount(types),
                  totalCount: types.length,
                  selected: item == selectedCategory,
                  onTap: () => setState(() => _category = item),
                );
              },
            ),
          ),
        if (categoryTypes.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionCard(
            children: [
              for (var i = 0; i < categoryTypes.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 6,
                    thickness: 0.6,
                    indent: 54,
                    endIndent: 12,
                    color: cs.outlineVariant.withValues(alpha: 0.18),
                  ),
                _TypeRow(
                  type: categoryTypes[i],
                  enabled: _selectedSet.contains(
                    HealthDataTypeIds.idFor(categoryTypes[i]),
                  ),
                  onChanged: (value) => widget.onToggleType(
                    HealthDataTypeIds.idFor(categoryTypes[i]),
                    value,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: AppFontWeights.medium,
          color: cs.onSurface.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _SystemStatusRow extends StatelessWidget {
  const _SystemStatusRow({
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.onOpenSettings,
  });

  final String title;
  final String subtitle;
  final String semanticLabel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    color: cs.onSurface.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          IosIconButton(
            icon: Lucide.Settings,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.55),
            semanticLabel: semanticLabel,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _BulkActionsRow extends StatelessWidget {
  const _BulkActionsRow({
    required this.enableEnabled,
    required this.disableEnabled,
    required this.onEnableAll,
    required this.onDisableAll,
  });

  final bool enableEnabled;
  final bool disableEnabled;
  final VoidCallback onEnableAll;
  final VoidCallback onDisableAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: _BulkActionButton(
              key: const Key('health_enable_all'),
              label: l10n.healthDataSettingsEnableAll,
              enabled: enableEnabled,
              onTap: onEnableAll,
            ),
          ),
          Expanded(
            child: _BulkActionButton(
              key: const Key('health_disable_all'),
              label: l10n.healthDataSettingsDisableAll,
              enabled: disableEnabled,
              onTap: onDisableAll,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkActionButton extends StatelessWidget {
  const _BulkActionButton({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary.withValues(alpha: enabled ? 1 : 0.35);
    return IosCardPress(
      onTap: enabled ? onTap : null,
      haptics: false,
      borderRadius: BorderRadius.circular(10),
      baseColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: AppFontWeights.medium,
          color: color,
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    super.key,
    required this.icon,
    required this.label,
    required this.selectedCount,
    required this.totalCount,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int selectedCount;
  final int totalCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return IosCardPress(
      onTap: onTap,
      haptics: false,
      borderRadius: BorderRadius.circular(20),
      baseColor: selected
          ? cs.primary.withValues(alpha: 0.14)
          : colors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? cs.primary : cs.onSurface),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.medium,
              color: cs.onSurface.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$selectedCount/$totalCount',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({
    required this.type,
    required this.enabled,
    required this.onChanged,
  });

  final HealthDataType type;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final id = HealthDataTypeIds.idFor(type);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              healthDataTypeIcon(type),
              size: 18,
              color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthDataTypeTitle(l10n, type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.semibold,
                    color: cs.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  healthDataTypeSubtitle(l10n, type),
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
          IosSwitch(
            key: Key('health_type_$id'),
            value: enabled,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(HealthDataCategory category) {
  return switch (category) {
    HealthDataCategory.activity => Lucide.PersonStanding,
    HealthDataCategory.rest => Lucide.Bed,
    HealthDataCategory.heart => Lucide.Heart,
    HealthDataCategory.body => Lucide.Weight,
  };
}

String _categoryLabel(AppLocalizations l10n, HealthDataCategory category) {
  return switch (category) {
    HealthDataCategory.activity => l10n.healthDataSettingsCategoryActivity,
    HealthDataCategory.rest => l10n.healthDataSettingsCategoryRest,
    HealthDataCategory.heart => l10n.healthDataSettingsCategoryHeart,
    HealthDataCategory.body => l10n.healthDataSettingsCategoryBody,
  };
}

IconData healthDataTypeIcon(HealthDataType type) {
  return switch (type) {
    HealthDataType.steps => Lucide.Footprints,
    HealthDataType.daylight => Lucide.Sun,
    HealthDataType.activeEnergy => Lucide.Flame,
    HealthDataType.exerciseMinutes => Lucide.Timer,
    HealthDataType.standTime => Lucide.PersonStanding,
    HealthDataType.distance => Lucide.Route,
    HealthDataType.workouts => Lucide.Dumbbell,
    HealthDataType.sleep => Lucide.Bed,
    HealthDataType.mindfulness => Lucide.Moon,
    HealthDataType.heartRate => Lucide.Heart,
    HealthDataType.restingHeartRate => Lucide.Activity,
    HealthDataType.bloodOxygen => Lucide.Wind,
    HealthDataType.dietaryEnergy => Lucide.Utensils,
    HealthDataType.water => Lucide.Droplets,
    HealthDataType.weight => Lucide.Weight,
    HealthDataType.bmi => Lucide.Hash,
    HealthDataType.bloodGlucose => Lucide.Syringe,
  };
}

String healthDataTypeTitle(AppLocalizations l10n, HealthDataType type) {
  return switch (type) {
    HealthDataType.steps => l10n.healthDataSettingsTypeStepsTitle,
    HealthDataType.daylight => l10n.healthDataSettingsTypeDaylightTitle,
    HealthDataType.activeEnergy => l10n.healthDataSettingsTypeActiveEnergyTitle,
    HealthDataType.exerciseMinutes =>
      l10n.healthDataSettingsTypeExerciseMinutesTitle,
    HealthDataType.standTime => l10n.healthDataSettingsTypeStandTimeTitle,
    HealthDataType.distance => l10n.healthDataSettingsTypeDistanceTitle,
    HealthDataType.workouts => l10n.healthDataSettingsTypeWorkoutsTitle,
    HealthDataType.sleep => l10n.healthDataSettingsTypeSleepTitle,
    HealthDataType.mindfulness => l10n.healthDataSettingsTypeMindfulnessTitle,
    HealthDataType.heartRate => l10n.healthDataSettingsTypeHeartRateTitle,
    HealthDataType.restingHeartRate =>
      l10n.healthDataSettingsTypeRestingHeartRateTitle,
    HealthDataType.bloodOxygen => l10n.healthDataSettingsTypeBloodOxygenTitle,
    HealthDataType.dietaryEnergy =>
      l10n.healthDataSettingsTypeDietaryEnergyTitle,
    HealthDataType.water => l10n.healthDataSettingsTypeWaterTitle,
    HealthDataType.weight => l10n.healthDataSettingsTypeWeightTitle,
    HealthDataType.bmi => l10n.healthDataSettingsTypeBmiTitle,
    HealthDataType.bloodGlucose => l10n.healthDataSettingsTypeBloodGlucoseTitle,
  };
}

String healthDataTypeSubtitle(AppLocalizations l10n, HealthDataType type) {
  return switch (type) {
    HealthDataType.steps => l10n.healthDataSettingsTypeStepsSubtitle,
    HealthDataType.daylight => l10n.healthDataSettingsTypeDaylightSubtitle,
    HealthDataType.activeEnergy =>
      l10n.healthDataSettingsTypeActiveEnergySubtitle,
    HealthDataType.exerciseMinutes =>
      l10n.healthDataSettingsTypeExerciseMinutesSubtitle,
    HealthDataType.standTime => l10n.healthDataSettingsTypeStandTimeSubtitle,
    HealthDataType.distance => l10n.healthDataSettingsTypeDistanceSubtitle,
    HealthDataType.workouts => l10n.healthDataSettingsTypeWorkoutsSubtitle,
    HealthDataType.sleep => l10n.healthDataSettingsTypeSleepSubtitle,
    HealthDataType.mindfulness =>
      l10n.healthDataSettingsTypeMindfulnessSubtitle,
    HealthDataType.heartRate => l10n.healthDataSettingsTypeHeartRateSubtitle,
    HealthDataType.restingHeartRate =>
      l10n.healthDataSettingsTypeRestingHeartRateSubtitle,
    HealthDataType.bloodOxygen =>
      l10n.healthDataSettingsTypeBloodOxygenSubtitle,
    HealthDataType.dietaryEnergy =>
      l10n.healthDataSettingsTypeDietaryEnergySubtitle,
    HealthDataType.water => l10n.healthDataSettingsTypeWaterSubtitle,
    HealthDataType.weight => l10n.healthDataSettingsTypeWeightSubtitle,
    HealthDataType.bmi => l10n.healthDataSettingsTypeBmiSubtitle,
    HealthDataType.bloodGlucose =>
      l10n.healthDataSettingsTypeBloodGlucoseSubtitle,
  };
}

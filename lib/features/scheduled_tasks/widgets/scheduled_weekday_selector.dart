import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/ios_tactile.dart';

class ScheduledWeekdaySelector extends StatelessWidget {
  const ScheduledWeekdaySelector({
    super.key,
    required this.days,
    required this.onChanged,
  });

  final Set<int> days;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    return Row(
      children: [
        for (var day = 1; day <= 7; day++) ...[
          if (day > 1) const SizedBox(width: 5),
          Expanded(
            child: Semantics(
              selected: days.contains(day),
              label: DateFormat.EEEE(locale).format(DateTime(2024, 1, day)),
              child: IosCardPress(
                key: ValueKey('scheduled-weekday-$day'),
                borderRadius: BorderRadius.circular(10),
                baseColor: colors.primary.withValues(
                  alpha: days.contains(day) ? .13 : .035,
                ),
                onTap: () {
                  final selected = {...days};
                  if (!selected.remove(day)) selected.add(day);
                  onChanged(selected);
                },
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormat.E(locale).format(DateTime(2024, 1, day)),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: days.contains(day)
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: days.contains(day)
                              ? colors.primary
                              : colors.onSurface.withValues(alpha: .6),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

@Preview(name: 'Schedule weekdays', size: Size(340, 70))
@Preview(
  name: 'Schedule weekdays dark',
  brightness: Brightness.dark,
  size: Size(340, 70),
)
Widget scheduledWeekdaysPreview() {
  var days = {1, 2, 3, 4, 5};
  return StatefulBuilder(
    builder: (context, setState) => Padding(
      padding: const EdgeInsets.all(12),
      child: ScheduledWeekdaySelector(
        days: days,
        onChanged: (value) => setState(() => days = value),
      ),
    ),
  );
}

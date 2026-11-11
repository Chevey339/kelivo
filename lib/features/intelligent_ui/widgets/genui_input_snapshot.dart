import 'package:flutter/widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import '../runtime/ui_resolved_node.dart';
import '../text/ui_number.dart';
import 'genui_field_frame.dart';
import 'genui_localizations.dart';
import 'genui_theme.dart';

/// Export fields contain only paintable text: no editable client, cursor,
/// focus registration, selection popover or increment/decrement action.
class GenUiInputSnapshot extends StatelessWidget {
  const GenUiInputSnapshot({super.key, required this.node});
  final UiResolvedNode node;
  @override
  Widget build(BuildContext context) {
    final props = node.properties;
    final theme = GenUiTheme.of(context);
    final labels = genUiProjectionLabels(AppLocalizations.of(context)!);
    final value = props['bind'];
    var text = switch (value) {
      bool v => v ? labels.yes : labels.no,
      num v => genUiNumber(v),
      null => labels.empty,
      _ => value.toString(),
    };
    if (props['options'] case final List options) {
      for (final option in options.whereType<Map>()) {
        if (option['value'] == value) {
          text = option['label'] as String;
          break;
        }
      }
    }
    if (props['unit'] case final String unit) text = '$text $unit';
    final label = props['label'] as String;
    return Semantics(
      label: label,
      value: text,
      readOnly: true,
      child: ExcludeSemantics(
        child: GenUiFieldFrame(
          label: label,
          requiredField: props['required'] == true,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(theme.sm),
            decoration: BoxDecoration(
              color: theme.fill,
              borderRadius: BorderRadius.circular(theme.controlRadius),
              border: Border.all(color: theme.hairlineStrong),
            ),
            child: Text(
              text,
              style: theme.body,
              textDirection: value is num ? TextDirection.ltr : null,
              textAlign: value is num ? TextAlign.end : TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

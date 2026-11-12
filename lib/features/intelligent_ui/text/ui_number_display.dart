import '../runtime/ui_numeric_step.dart';
import 'ui_number.dart';

/// Human-readable output only. Raw values, editing drafts, sort order and
/// frozen context keep their original precision. Only near-identical short
/// representations (within floating-point rounding noise) replace a long tail.
String genUiDisplayNumber(num? value, {int? digits}) {
  if (value == null ||
      digits != null ||
      value is int ||
      value == value.truncateToDouble()) {
    return genUiNumber(value, digits: digits);
  }
  final rounded = double.parse(value.toStringAsPrecision(12));
  final noise = value.abs() * 8 * 2.220446049250313e-16;
  return genUiNumber(
    rounded.isFinite && (value - rounded).abs() <= noise ? rounded : value,
  );
}

String genUiDisplayTotal(Iterable<num> values) {
  final items = values.toList();
  final exact = uiNumericTotalText(items);
  final sum = double.tryParse(exact);
  return sum != null && sum.isFinite
      ? genUiDisplayNumber(sum)
      : genUiDisplayNumber(
          items.fold<double>(0.0, (sum, value) => sum + value),
        );
}

import 'package:decimal/decimal.dart';

/// Input steps are decimal quantities. Do not commit the binary arithmetic
/// residue from e.g. -5 + 19 * 0.1 to a shared NumberField binding.
double uiNumericStep(num origin, num step, num count) => double.parse(
  (Decimal.parse(origin.toString()) +
          Decimal.parse(step.toString()) * Decimal.parse(count.toString()))
      .toString(),
);

/// Presentation only: keep a decimal total exact without changing the validated
/// floating-point normalization used by the chart (including its finite range).
String uiNumericTotalText(Iterable<num> values) => values
    .fold(Decimal.zero, (sum, value) => sum + Decimal.parse(value.toString()))
    .toString();

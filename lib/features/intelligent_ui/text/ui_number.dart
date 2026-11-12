String genUiNumber(num? value, {int? digits}) {
  if (value == null) return '—';
  if (digits != null) return value.toStringAsFixed(digits);
  final text = value.toString();
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

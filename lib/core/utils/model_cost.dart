import '../models/model_spec.dart';
import '../models/token_usage.dart';

class ModelCost {
  const ModelCost({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ModelCost &&
            amount == other.amount &&
            currency == other.currency);
  }

  @override
  int get hashCode => Object.hash(amount, currency);
}

ModelCost? estimateModelCost(TokenUsage usage, ModelPricing? pricing) {
  if (pricing == null || (pricing.input == null && pricing.output == null)) {
    return null;
  }

  final input = pricing.input ?? 0;
  final output = pricing.output ?? 0;
  final cacheReadPrice = pricing.cacheRead ?? input;
  final cacheWritePrice = pricing.cacheWrite ?? input;
  final cacheRead = usage.cachedTokens;
  final cachedInput = cacheRead + usage.cacheWriteTokens;
  final billedPrompt = usage.promptTokens > cachedInput
      ? usage.promptTokens - cachedInput
      : 0;

  final amount =
      (billedPrompt * input +
          cacheRead * cacheReadPrice +
          usage.cacheWriteTokens * cacheWritePrice +
          usage.completionTokens * output) /
      1000000;
  return ModelCost(amount: amount, currency: pricing.currency);
}

String formatModelCost(ModelCost cost) {
  final symbol = _currencySymbol(cost.currency);
  final formatted = _formatAmount(cost.amount);
  if (symbol != null) {
    return formatted.startsWith('<')
        ? '<$symbol${formatted.substring(1)}'
        : '$symbol$formatted';
  }
  return '$formatted ${cost.currency}';
}

String? _currencySymbol(String currency) {
  return switch (currency) {
    'USD' => r'$',
    'CNY' || 'JPY' => '¥',
    'EUR' => '€',
    'GBP' => '£',
    _ => null,
  };
}

String _formatAmount(double amount) {
  if (amount == 0) return '0';
  final sign = amount < 0 ? '-' : '';
  final abs = amount.abs();
  if (abs < 0.0001) return '$sign<0.0001';
  var text = abs.toStringAsFixed(4);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '');
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
  }
  return '$sign$text';
}

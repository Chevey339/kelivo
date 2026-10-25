String formatTokenCount(int tokens) {
  if (tokens < 1000) return '$tokens';
  if (tokens < 1000000) return '${_oneDecimal(tokens / 1000)}k';
  return '${_oneDecimal(tokens / 1000000)}M';
}

String _oneDecimal(double value) {
  final truncated = (value * 10).truncateToDouble() / 10;
  if (truncated == truncated.truncateToDouble()) {
    return '${truncated.toInt()}';
  }
  return truncated.toStringAsFixed(1);
}

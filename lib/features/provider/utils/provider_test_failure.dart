/// Extracts the status line while preserving useful non-HTTP failures.
class ProviderTestFailure {
  ProviderTestFailure(Object error) {
    final text = error.toString();
    final match = RegExp(r'HTTP\s+(\d{3})(?:\s+([^:\r\n]+))?').firstMatch(text);
    statusCode = int.tryParse(match?.group(1) ?? '');
    final reason = match?.group(2)?.trim();
    summary = statusCode == null
        ? text
        : '$statusCode${reason == null || reason.isEmpty ? '' : ' $reason'}';
    detail = statusCode == null ? null : text;
  }
  late final int? statusCode;
  late final String summary;
  late final String? detail;
}

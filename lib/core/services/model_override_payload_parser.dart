import 'dart:convert';

/// Shared parser for per-model override payloads (headers/body/api model mapping).
class ModelOverridePayloadParser {
  static Map<String, dynamic> modelOverride(
    Map<String, dynamic> modelOverrides,
    String modelId,
  ) {
    final ov = modelOverrides[modelId];
    if (ov is Map<String, dynamic>) return ov;
    if (ov is Map) {
      return {for (final entry in ov.entries) entry.key.toString(): entry.value};
    }
    return const <String, dynamic>{};
  }

  static Map<String, String> customHeaders(Map<String, dynamic> ov) {
    final list = (ov['headers'] as List?) ?? const <dynamic>[];
    final out = <String, String>{};
    for (final e in list) {
      if (e is Map) {
        final name = (e['name'] ?? e['key'] ?? '').toString().trim();
        final value = (e['value'] ?? '').toString();
        if (name.isNotEmpty) out[name] = value;
      }
    }
    return out;
  }

  static dynamic parseOverrideValue(String v) {
    final s = v.trim();
    if (s.isEmpty) return s;
    if (s == 'true') return true;
    if (s == 'false') return false;
    if (s == 'null') return null;
    final i = int.tryParse(s);
    if (i != null) return i;
    final d = double.tryParse(s);
    if (d != null) return d;
    if ((s.startsWith('{') && s.endsWith('}')) ||
        (s.startsWith('[') && s.endsWith(']'))) {
      try {
        return jsonDecode(s);
      } catch (_) {}
    }
    return v;
  }

  static Map<String, dynamic> customBody(Map<String, dynamic> ov) {
    final list = (ov['body'] as List?) ?? const <dynamic>[];
    final out = <String, dynamic>{};
    for (final e in list) {
      if (e is Map) {
        final key = (e['key'] ?? e['name'] ?? '').toString().trim();
        final val = (e['value'] ?? '').toString();
        if (key.isNotEmpty) out[key] = parseOverrideValue(val);
      }
    }
    return out;
  }
}

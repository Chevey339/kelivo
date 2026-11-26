import '../../providers/settings_provider.dart';
import '../../../utils/utf16_safe_cut.dart';
import 'request_token_estimate.dart';

int _carriedTokens(Map item, ProviderKind kind) => estimateRequestInput({
  'input': [item],
}, kind);

/// Only plain text can be shortened locally. Keep media and unknown content
/// whole, and never alter the provider's encrypted compaction item.
Map<String, dynamic>? truncateCarriedText(
  Map<String, dynamic> item,
  int maxTokens, {
  ProviderKind kind = ProviderKind.openai,
}) {
  if (maxTokens <= 0 || (item['type'] != null && item['type'] != 'message')) {
    return null;
  }
  final content = item['content'];
  final List<Map<String, dynamic>> parts;
  if (content is String) {
    parts = [
      {'text': content},
    ];
  } else if (content is List &&
      content.isNotEmpty &&
      content.every(
        (part) =>
            part is Map &&
            (part['type'] == 'input_text' || part['type'] == 'output_text') &&
            part['text'] is String,
      )) {
    parts = content
        .map((part) => Map<String, dynamic>.from(part as Map))
        .toList();
  } else {
    return null;
  }

  Map<String, dynamic> withParts(List<Map<String, dynamic>> kept) => {
    ...item,
    'content': content is String ? kept.single['text'] : kept,
  };

  final kept = <Map<String, dynamic>>[];
  for (final part in parts) {
    final whole = withParts([...kept, part]);
    if (_carriedTokens(whole, kind) <= maxTokens) {
      kept.add(part);
      continue;
    }
    // Recount the complete item, including JSON framing and the marker. A
    // character/token ratio alone can overflow for CJK, emoji or escaped text.
    const marker = '\n[…truncated…]\n';
    final text = part['text'] as String;
    var low = marker.length + 1;
    var high = text.length - 1;
    Map<String, dynamic>? best = kept.isEmpty ? null : withParts(kept);
    while (low <= high) {
      final length = (low + high) ~/ 2;
      final shortened = truncateHeadTailUtf16Safe(text, length, marker: marker);
      final candidate = withParts([
        ...kept,
        {...part, 'text': shortened},
      ]);
      if (_carriedTokens(candidate, kind) <= maxTokens) {
        if (kept.isNotEmpty || shortened != marker) best = candidate;
        low = length + 1;
      } else {
        high = length - 1;
      }
    }
    return best;
  }
  return kept.isEmpty ? null : withParts(kept);
}

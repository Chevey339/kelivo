/// Normalizes OpenRouter-style `reasoning_details` before they are replayed to
/// an Anthropic-backed upstream.
///
/// Streamed details arrive as one entry per delta: a long run of
/// `reasoning.text` fragments, with the signature usually arriving last in an
/// entry that carries no text at all. Echoing that raw sequence back makes
/// OpenAI-compatible proxies rebuild one thinking block per fragment, and the
/// signature-only entry becomes a block with a null text — which upstream
/// Claude (Bedrock in particular) rejects with
/// "reasoningContent.reasoningText.text ... must not be null".
///
/// Merging the fragments back into whole blocks reproduces the non-streamed
/// shape: one entry per reasoning block, text joined, signature attached.
/// Other vendors (OpenRouter's own routes included) want the block sequence
/// replayed verbatim, so this only runs on Claude upstreams or on details the
/// provider tagged with an Anthropic format.
library;

/// True when [raw] carries at least one Anthropic-formatted entry.
bool reasoningDetailsLookAnthropic(dynamic raw) {
  if (raw is! List) return false;
  for (final item in raw) {
    if (item is! Map) continue;
    final format = item['format'];
    if (format is String && format.toLowerCase().contains('anthropic')) {
      return true;
    }
  }
  return false;
}

/// True when details are Anthropic-tagged or carry a thinking signature.
/// Those payloads must be rebuilt into whole signed blocks; the parallel
/// `reasoning_content` text echo is rejected by the same upstreams.
bool reasoningDetailsNeedSignedReplay(dynamic raw) {
  if (reasoningDetailsLookAnthropic(raw)) return true;
  if (raw is! List) return false;
  for (final item in raw) {
    if (item is! Map) continue;
    final signature = item['signature'];
    if (signature is String && signature.isNotEmpty) return true;
  }
  return false;
}

/// Returns the merged details list, or null when nothing replayable remains.
List<Map<String, dynamic>>? normalizeReasoningDetailsForReplay(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;

  final merged = <_Block>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final entry = item.map((key, value) => MapEntry(key.toString(), value));
    final block = _Block(entry);
    if (block.textKey == null) {
      // Opaque payloads (e.g. `reasoning.encrypted`) must travel verbatim.
      merged.add(block);
      continue;
    }
    final previous = merged.isEmpty ? null : merged.last;
    if (previous != null && previous.canAbsorb(block)) {
      previous.absorb(block);
    } else {
      merged.add(block);
    }
  }

  final out = <Map<String, dynamic>>[];
  for (final block in merged) {
    final textKey = block.textKey;
    if (textKey == null) {
      out.add(block.entry);
      continue;
    }
    // A block whose text never materialized (signature-only leftovers) has
    // nothing valid to rebuild from; sending it null-texts the whole request.
    if (block.text.isEmpty) continue;
    block.entry[textKey] = block.text;
    out.add(block.entry);
  }

  return out.isEmpty ? null : out;
}

class _Block {
  _Block(this.entry)
    : type = (entry['type'] ?? 'reasoning.text').toString(),
      textKey = _textKeyFor(entry) {
    final value = textKey == null ? null : entry[textKey];
    text = value is String ? value : '';
  }

  final Map<String, dynamic> entry;
  final String type;

  /// Which field carries this entry's prose, or null for opaque payloads.
  final String? textKey;
  late String text;

  String? get signature => _asNonEmptyString(entry['signature']);

  bool canAbsorb(_Block next) {
    if (next.type != type) return false;
    if (next.textKey != textKey) return false;
    if (!_sameOptional(entry['id'], next.entry['id'])) return false;
    if (!_sameOptional(entry['index'], next.entry['index'])) return false;
    if (!_sameOptional(entry['format'], next.entry['format'])) return false;

    final current = signature;
    if (current == null) return true;
    // A signature closes its block: an identical one is just the same
    // signature repeated on every fragment, a different one starts a new
    // block, and unsigned prose after it belongs to the next block.
    final incoming = next.signature;
    if (incoming != null) return incoming == current;
    return next.text.isEmpty;
  }

  void absorb(_Block next) {
    text += next.text;
    final incoming = next.signature;
    if (incoming != null) entry['signature'] = incoming;
    for (final field in next.entry.entries) {
      if (field.key == textKey || field.key == 'signature') continue;
      // Later fragments often fill in metadata the first one left null.
      if (entry[field.key] == null && field.value != null) {
        entry[field.key] = field.value;
      } else {
        entry.putIfAbsent(field.key, () => field.value);
      }
    }
  }
}

/// `reasoning.summary` entries carry their prose in `summary`, but some
/// providers put it in `text` instead; opaque types have no prose at all.
String? _textKeyFor(Map<String, dynamic> entry) {
  final type = (entry['type'] ?? 'reasoning.text').toString();
  if (type == 'reasoning.text') return 'text';
  if (type != 'reasoning.summary') return null;
  if (entry['summary'] is String) return 'summary';
  if (entry['text'] is String) return 'text';
  return 'summary';
}

bool _sameOptional(dynamic a, dynamic b) {
  if (a == null || b == null) return true;
  return a == b;
}

String? _asNonEmptyString(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return value;
}

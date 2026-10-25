/// Reassembles OpenRouter-style `reasoning_details` into complete blocks.
///
/// Streamed details arrive as one entry per delta: a long run of
/// `reasoning.text` fragments, with the signature usually arriving last in an
/// entry that carries no text at all. Echoing that raw sequence back makes
/// OpenAI-compatible proxies rebuild one thinking block per fragment, and the
/// signature-only entry becomes a block with a null text — which upstream
/// Claude (Bedrock in particular) rejects with
/// "reasoningContent.reasoningText.text ... must not be null".
///
/// Text and summary deltas belong to their logical block, not to separate
/// history entries. Preserve their text exactly, without adding separators.
/// Signatures close text blocks; encrypted and unknown blocks stay opaque.
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
/// These upstreams reject a plain text echo even when no replayable signed
/// block remains (for example, an orphaned signature-only entry).
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

/// Joins stream fragments while retaining metadata, including orphan signatures.
/// Persistence must keep those signatures so request shaping can still detect
/// signed upstreams when the configured model name is an alias.
List<Map<String, dynamic>>? mergeReasoningDetails(dynamic raw) {
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
    final text = block.text;
    if (text.isNotEmpty) block.entry[textKey] = text;
    out.add(block.entry);
  }

  return out.isEmpty ? null : out;
}

/// Returns complete replayable blocks. A signature-only leftover has no text
/// to rebuild; sending it would fail the upstream thinking-block validation.
List<Map<String, dynamic>>? normalizeReasoningDetailsForReplay(dynamic raw) {
  final blocks = mergeReasoningDetails(raw);
  if (blocks == null) return null;
  final out = blocks.where((entry) {
    final textKey = _textKeyFor(entry);
    if (textKey == null) return true;
    final text = entry[textKey];
    return text is String && text.isNotEmpty;
  }).toList();
  return out.isEmpty ? null : out;
}

class _Block {
  _Block(this.entry)
    : type = (entry['type'] ?? 'reasoning.text').toString(),
      textKey = _textKeyFor(entry) {
    final value = textKey == null ? null : entry[textKey];
    if (value is String) _text.write(value);
  }

  final Map<String, dynamic> entry;
  final String type;

  /// Which field carries this entry's prose, or null for opaque payloads.
  final String? textKey;
  final StringBuffer _text = StringBuffer();
  String get text => _text.toString();

  String? get signature => _asNonEmptyString(entry['signature']);

  bool canAbsorb(_Block next) {
    if (next.type != type) return false;
    if (next.textKey != textKey) return false;
    if (!_sameOptional(entry['id'], next.entry['id'])) return false;
    if (!_sameOptional(entry['index'], next.entry['index'])) return false;
    if (!_sameOptional(entry['format'], next.entry['format'])) return false;

    final current = signature;
    if (current == null) return true;
    // New prose after a signature belongs to another block, even if the
    // signature is repeated. Only redundant signature-only metadata can fold
    // into a closed block; changing its text would invalidate the signature.
    final incoming = next.signature;
    return next._text.isEmpty && (incoming == null || incoming == current);
  }

  void absorb(_Block next) {
    _text.write(next._text);
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

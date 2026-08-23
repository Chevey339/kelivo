/// Shared JSON Schema helpers for tool parameter handling.
///
/// MCP servers routinely describe nested objects through local `$ref`s into a
/// `$defs` / `definitions` block. A reader that does not follow the reference
/// sees an empty node, so the schema we advertise to the model has to inline
/// those references first — otherwise the whole nested object is invisible and
/// the model fills in nothing.
library;

/// Maximum `$ref` nesting depth to expand.
const int _maxRefDepth = 12;

/// Maximum number of `$ref` expansions per schema. Schemas where each level
/// fans out into several references grow exponentially when inlined; past this
/// budget the remaining references are passed through instead.
const int _maxRefExpansions = 512;

const String _refKey = r'$ref';

/// Keywords whose value is a map of *names* to subschemas the sanitizer keeps.
const Set<String> _schemaMapKeywords = {'properties'};

/// Combinators the sanitizer flattens to the first variant. Tuple-form `items`
/// is flattened the same way.
const Set<String> _schemaListKeywords = {
  'anyOf',
  'oneOf',
  'allOf',
  'any_of',
  'one_of',
  'all_of',
  'items',
};

/// Keywords whose value is a single subschema that the sanitizer keeps.
/// `additionalProperties` is walked only when [expandAdditionalProperties] is
/// true (OpenAI / Claude keep that keyword; Google drops it).
const Set<String> _subSchemaKeywords = {'items', 'additionalProperties'};

/// Definition blocks are reachable only through pointers, which resolve against
/// the untouched root, so they are dropped from the output rather than walked.
const Set<String> _definitionKeywords = {r'$defs', 'definitions'};

/// Keywords that describe rather than constrain. A sibling of `$ref` may
/// restate these; they do not change which values are valid.
const Set<String> _annotationKeywords = {
  'description',
  'title',
  'default',
  'examples',
  'deprecated',
  'readOnly',
  'writeOnly',
  r'$comment',
};

class _RefBudget {
  _RefBudget({this.expandAdditionalProperties = true});

  int expansions = 0;
  final bool expandAdditionalProperties;
}

/// Inline every resolvable local `$ref` in [schema] against its own root.
///
/// The walk is schema-aware: it descends only through keywords the provider
/// sanitizer keeps, so a *parameter* named `definitions` or a `default` value
/// that happens to contain a `$ref` key is left alone, and discarded branches
/// cannot exhaust the expansion budget.
///
/// A `$ref` with no validation siblings is replaced by its target. Annotation
/// siblings (`description`, `title`, `default`, ...) overlay that target.
/// Validation siblings are not merged: folding them would require a general
/// schema conjunction, which this helper does not attempt.
///
/// References that cannot be resolved — remote URLs, plain-name anchors,
/// dangling pointers, boolean schemas, cycles, or anything past the
/// depth/expansion budget — are passed through with the `$ref` dropped and no
/// type invented: guessing a type here would misdescribe the parameter to the
/// model. Boolean targets are not inlined; providers require a schema object.
///
/// [expandAdditionalProperties] should be true when the caller will keep that
/// keyword (OpenAI, Claude) and false when it will drop it (Google), so a
/// discarded branch cannot exhaust the expansion budget.
Map<String, dynamic> resolveJsonSchemaRefs(
  Map<String, dynamic> schema, {
  bool expandAdditionalProperties = true,
}) {
  final resolved = _resolveSchema(
    schema,
    schema,
    const <String>{},
    0,
    _RefBudget(expandAdditionalProperties: expandAdditionalProperties),
  );
  return resolved is Map<String, dynamic> ? resolved : schema;
}

dynamic _resolveSchema(
  dynamic node,
  Map<String, dynamic> root,
  Set<String> active,
  int depth,
  _RefBudget budget,
) {
  if (node is List) {
    return [
      for (final e in node) _resolveSchema(e, root, active, depth, budget),
    ];
  }
  if (node is! Map) return node;

  final m = Map<String, dynamic>.from(node);
  final ref = m[_refKey];
  if (ref is String && ref.trim().isNotEmpty) {
    final pointer = ref.trim();
    final exhausted =
        active.contains(pointer) ||
        depth >= _maxRefDepth ||
        budget.expansions >= _maxRefExpansions;
    m.remove(_refKey);
    if (!exhausted) {
      final target = _lookupRef(pointer, root);
      // Boolean schemas are valid JSON Schema but not expressible as a
      // provider property Schema object. Treat them like unresolved refs.
      if (target != null && target is! bool) {
        budget.expansions++;
        final resolved = _resolveSchema(
          target is Map ? Map<String, dynamic>.from(target) : target,
          root,
          <String>{...active, pointer},
          depth + 1,
          budget,
        );
        if (resolved is Map<String, dynamic>) {
          return _overlayAnnotations(resolved, m);
        }
        return resolved;
      }
    }
  }

  return _walkKeywords(m, root, active, depth, budget);
}

/// Copy annotation siblings over [target]. Validation keywords next to a
/// `$ref` are ignored rather than intersected.
Map<String, dynamic> _overlayAnnotations(
  Map<String, dynamic> target,
  Map<String, dynamic> siblings,
) {
  var out = target;
  var copied = false;
  siblings.forEach((key, value) {
    if (!_annotationKeywords.contains(key)) return;
    if (!copied) {
      out = Map<String, dynamic>.from(target);
      copied = true;
    }
    out[key] = value;
  });
  return out;
}

Map<String, dynamic> _walkKeywords(
  Map<String, dynamic> node,
  Map<String, dynamic> root,
  Set<String> active,
  int depth,
  _RefBudget budget,
) {
  final out = <String, dynamic>{};
  node.forEach((key, value) {
    if (_definitionKeywords.contains(key)) return;
    if (_schemaMapKeywords.contains(key) && value is Map) {
      out[key] = <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _resolveSchema(
            entry.value,
            root,
            active,
            depth,
            budget,
          ),
      };
      return;
    }
    if (_schemaListKeywords.contains(key) && value is List) {
      // Sanitizer keeps only the first variant; do not spend budget on the rest.
      out[key] = [
        if (value.isNotEmpty)
          _resolveSchema(value.first, root, active, depth, budget),
        if (value.length > 1) ...value.skip(1),
      ];
      return;
    }
    if (key == 'additionalProperties' && !budget.expandAdditionalProperties) {
      out[key] = value;
      return;
    }
    if (_subSchemaKeywords.contains(key) && (value is Map || value is List)) {
      out[key] = _resolveSchema(value, root, active, depth, budget);
      return;
    }
    // Anything else — `default`, `enum`, `const`, `examples`, vendor keys — is
    // data, not schema, and is copied verbatim.
    out[key] = value;
  });
  return out;
}

/// Resolve a local JSON Pointer such as `#/$defs/Payload`.
///
/// Only pointer-form local references are supported; `#Anchor` style refs and
/// remote URLs return null so the caller can pass the node through untouched.
///
/// RFC 6901 §6: percent-decode the whole fragment, then split on `/`, then
/// unescape `~1` / `~0` per segment.
dynamic _lookupRef(String ref, Map<String, dynamic> root) {
  if (!ref.startsWith('#')) return null; // remote refs are not fetchable
  final rawFragment = ref.substring(1);
  // '#' is the document root. '#/' is the member whose name is the empty
  // string, not the root — RFC 6901.
  if (rawFragment.isEmpty) return root;
  String fragment;
  try {
    fragment = Uri.decodeComponent(rawFragment);
  } catch (_) {
    fragment = rawFragment;
  }
  if (!fragment.startsWith('/')) return null; // plain-name anchor
  dynamic current = root;
  for (final rawSegment in fragment.substring(1).split('/')) {
    final segment = rawSegment.replaceAll('~1', '/').replaceAll('~0', '~');
    if (current is Map) {
      if (!current.containsKey(segment)) return null;
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

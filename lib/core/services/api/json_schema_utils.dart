/// Shared JSON Schema helpers for tool parameter handling.
///
/// MCP servers routinely describe nested objects through local `$ref`s into a
/// `$defs` / `definitions` block. A reader that does not follow the reference
/// sees an empty node, so simple local references are inlined for the model.
/// If expansion cannot preserve reference semantics, JSON Schema providers get
/// the original document, including its definitions and reference scopes.
library;

/// Some MCPs declare a record once, then use `anyOf` to require different
/// sets of its fields. Gemini expects each alternative to be a standalone
/// typed schema. Distribute the record only when the refinements can be
/// combined without overwriting an existing constraint.
List<Map<String, dynamic>>? geminiRequiredObjectAlternatives(
  Map<String, dynamic> record, {
  bool native = false,
}) {
  // A nullable record can be expressed as anyOf/oneOf [record, null]. Its
  // alternatives are disjoint from null, so the outer union can be flattened.
  if (record['type'] == null) {
    final key = record.containsKey('anyOf') ? 'anyOf' : 'oneOf';
    final branches = record[key];
    if (branches is! List) return null;
    final nullIndex = _nullableBranchIndex(record, key, branches);
    if (nullIndex < 0) return null;
    final other = branches[1 - nullIndex];
    if (other is! Map<String, dynamic> ||
        !_nonNullTypes.contains(other['type'])) {
      return null;
    }
    final options = other['type'] == 'object'
        ? geminiRequiredObjectAlternatives(other)
        : null;
    if (options == null && !native) return null;
    final annotations = Map<String, dynamic>.of(record)..remove(key);
    final nullBranch = <String, dynamic>{
      ...annotations,
      ...branches[nullIndex] as Map,
    };
    return [
      if (nullIndex == 0) nullBranch,
      for (final option in options ?? [other]) {...annotations, ...option},
      if (nullIndex == 1) nullBranch,
    ];
  }
  final options = record['anyOf'];
  final fields = record['properties'];
  final required = record['required'] ?? const [];
  if (options is! List || options.isEmpty) return null;
  if (record['type'] != 'object' ||
      fields is! Map ||
      fields.isEmpty ||
      required is! List ||
      !required.every(fields.containsKey)) {
    return null;
  }
  // A shared field can itself be an object or an array. Count its subschemas
  // before repeating it, and avoid duplicating resource IDs or nested unions.
  var remaining = _maxSchemaExpansions ~/ options.length;
  if (fields.values.any(
    (field) =>
        field is! Map ||
        field['type'] is! String ||
        _anySchemaNode(
          field,
          (node) =>
              --remaining < 0 ||
              node.containsKey(_refKey) ||
              _referenceContextKeywords.any(node.containsKey) ||
              _definitionKeywords.any(node.containsKey) ||
              _schemaListKeywords.any((k) => node[k] is List),
        ),
  )) {
    return null;
  }
  const recordKeys = {
    'type',
    'properties',
    'required',
    'anyOf',
    'additionalProperties',
    'minProperties',
    'maxProperties',
    'propertyOrdering',
  };
  if (record.keys.any(
        (key) =>
            !recordKeys.contains(key) && !_annotationKeywords.contains(key),
      ) ||
      record['additionalProperties'] is Map) {
    return null;
  }

  final shared = Map<String, dynamic>.of(record)..remove('anyOf');
  final alternatives = <Map<String, dynamic>>[];
  for (final option in options) {
    if (option is! Map ||
        option.keys.any((k) => k != 'required' && k != 'properties')) {
      return null;
    }
    final keys = option['required'];
    final refinements = option['properties'] ?? const {};
    if (keys is! List ||
        keys.isEmpty ||
        !keys.every(fields.containsKey) ||
        refinements is! Map) {
      return null;
    }
    final properties = Map<String, dynamic>.from(fields);
    for (final entry in refinements.entries) {
      final field = fields[entry.key];
      final rawConstraint = entry.value;
      if (field is! Map ||
          rawConstraint is! Map ||
          rawConstraint.keys.any(
            (k) =>
                !_fieldRefinementKeywords.contains(k) &&
                !_annotationKeywords.contains(k),
          )) {
        return null;
      }
      // These keywords only constrain a sibling `contains` in the same
      // schema. Moving them next to the shared field's contains changes it.
      final constraint = Map<String, dynamic>.from(rawConstraint)
        ..remove('minContains')
        ..remove('maxContains');
      if (constraint.keys.any(
        (k) => field.containsKey(k) && field[k] != constraint[k],
      )) {
        return null;
      }
      properties[entry.key] = <String, dynamic>{...field, ...constraint};
    }
    alternatives.add({
      ...shared,
      'properties': properties,
      'required': {...required, ...keys}.toList(),
    });
  }
  return alternatives;
}

const _nonNullTypes = {
  'object',
  'array',
  'string',
  'number',
  'integer',
  'boolean',
};
const _fieldRefinementKeywords = {
  'type',
  'const',
  'enum',
  'pattern',
  'format',
  'minLength',
  'maxLength',
  'minimum',
  'maximum',
  'multipleOf',
  'minItems',
  'maxItems',
  'uniqueItems',
  'minProperties',
  'maxProperties',
  'minContains',
  'maxContains',
};

int _nullableBranchIndex(Map schema, String key, List branches) {
  if ((key != 'anyOf' && key != 'oneOf') ||
      branches.length != 2 ||
      schema.keys.any((k) => k != key && !_annotationKeywords.contains(k))) {
    return -1;
  }
  return branches.indexWhere(
    (branch) =>
        branch is Map &&
        branch['type'] == 'null' &&
        branch.keys.every(
          (k) => k == 'type' || _annotationKeywords.contains(k),
        ),
  );
}

/// Maximum `$ref` nesting depth to expand.
const int _maxRefDepth = 12;

/// Limit on inlined references per schema or property copies per object union.
const int _maxSchemaExpansions = 512;

const String _refKey = r'$ref';

// These keywords require dialect/resource/dynamic-scope handling. Moving their
// subschemas during inlining can change reference targets or duplicate anchors.
const Set<String> _referenceContextKeywords = {
  r'$schema',
  r'$id',
  'id',
  r'$anchor',
  r'$dynamicRef',
  r'$dynamicAnchor',
  r'$recursiveRef',
  r'$recursiveAnchor',
};

/// Keywords whose value is a map of *names* to subschemas the sanitizer keeps.
const Set<String> _schemaMapKeywords = {
  'properties',
  'patternProperties',
  'dependentSchemas',
  'dependencies',
};

/// Combinators and tuple entries the sanitizer preserves for JSON Schema
/// providers. Google's native conversion keeps nullable pairs and otherwise
/// only expands refs in the first variant.
const jsonSchemaCompositionKeywords = [
  'anyOf',
  'oneOf',
  'allOf',
  'any_of',
  'one_of',
  'all_of',
];

const Set<String> _schemaListKeywords = {
  ...jsonSchemaCompositionKeywords,
  'items',
  'prefixItems',
};

/// Keywords whose value is a single subschema that the sanitizer keeps.
/// Google drops these except `items`, so it skips their reference expansion.
const Set<String> _subSchemaKeywords = {
  'items',
  'additionalProperties',
  'not',
  'if',
  'then',
  'else',
  'contains',
  'propertyNames',
  'additionalItems',
  'unevaluatedItems',
  'unevaluatedProperties',
  'contentSchema',
};

/// Fully inlined documents no longer need definitions. If any reference cannot
/// be inlined, the whole original document is retained instead.
const Set<String> _definitionKeywords = {r'$defs', 'definitions'};

/// A retained reference may point to a property that would move into a branch.
/// Resource identifiers on fields being copied are checked at the copy site.
bool hasJsonSchemaReferences(Object? node) => _anySchemaNode(
  node,
  (schema) =>
      schema.containsKey(_refKey) ||
      schema.containsKey(r'$dynamicRef') ||
      schema.containsKey(r'$recursiveRef'),
);

bool _anySchemaNode(Object? node, bool Function(Map) matches) {
  if (node is! Map) return false;
  if (matches(node)) return true;
  bool visit(Object? child) => _anySchemaNode(child, matches);
  for (final entry in node.entries) {
    final child = entry.value;
    if ((_schemaMapKeywords.contains(entry.key) ||
            _definitionKeywords.contains(entry.key)) &&
        child is Map &&
        child.values.any(visit)) {
      return true;
    }
    if (_schemaListKeywords.contains(entry.key) ||
        _subSchemaKeywords.contains(entry.key)) {
      if (child is List ? child.any(visit) : visit(child)) {
        return true;
      }
    }
  }
  return false;
}

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

/// A wrapper with no sibling validation can delegate to its first branch on
/// the native Gemini transport. Only description is a native tool annotation.
Map<String, dynamic>? firstStandaloneGoogleBranch(Map<String, dynamic> schema) {
  final keyword = schema.keys
      .where((key) => !_annotationKeywords.contains(key))
      .singleOrNull;
  final branches = schema[keyword];
  if (!jsonSchemaCompositionKeywords.contains(keyword) ||
      branches is! List ||
      branches.isEmpty ||
      branches.first is! Map) {
    return null;
  }
  return {
    if (schema.containsKey('description')) 'description': schema['description'],
    ...Map<String, dynamic>.from(branches.first as Map),
  };
}

class _RefBudget {
  _RefBudget({required this.preserveJsonSchema});

  int expansions = 0;
  bool keepOriginal = false;
  final bool preserveJsonSchema;
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
/// Validation siblings are retained alongside an `allOf` containing the target,
/// so overlapping constraints stay conjunctive instead of overwriting each other.
/// Google's native Schema conversion keeps only annotation siblings.
///
/// With [preserveJsonSchema], unresolved/recursive references, expansion limits,
/// and dialect/resource/dynamic-scope keywords (including reference ancestors)
/// retain the entire original document. Keeping only the last unexpanded ref
/// would leave dangling pointers after definitions were removed or referenced
/// subschemas moved. Google's native Schema conversion continues to drop
/// unsupported refs without guessing a type. Boolean targets are inlined only
/// for JSON Schema providers.
///
/// [preserveJsonSchema] should be false only for Google's native conversion,
/// which expands refs in retained nullable pairs and the first composition/tuple
/// entry. The required-field alternatives it distributes are otherwise ref-free.
Map<String, dynamic> resolveJsonSchemaRefs(
  Map<String, dynamic> schema, {
  bool preserveJsonSchema = true,
}) {
  final budget = _RefBudget(preserveJsonSchema: preserveJsonSchema);
  final resolved = _resolveSchema(schema, schema, const <String>{}, 0, budget);
  if (budget.keepOriginal) return schema;
  if (resolved is Map<String, dynamic>) return resolved;
  if (preserveJsonSchema && resolved is bool) {
    return {
      'allOf': [resolved],
    };
  }
  return schema;
}

dynamic _resolveSchema(
  dynamic node,
  Map<String, dynamic> root,
  Set<String> active,
  int depth,
  _RefBudget budget,
) {
  if (budget.keepOriginal) return node;
  if (node is List) {
    return [
      for (final e in node) _resolveSchema(e, root, active, depth, budget),
    ];
  }
  if (node is! Map) return node;

  final m = Map<String, dynamic>.from(node);
  if (budget.preserveJsonSchema &&
      _referenceContextKeywords.any(m.containsKey)) {
    budget.keepOriginal = true;
    return node;
  }
  final ref = m[_refKey];
  if (ref is String && (budget.preserveJsonSchema || ref.trim().isNotEmpty)) {
    final pointer = budget.preserveJsonSchema ? ref : ref.trim();
    final exhausted =
        active.contains(pointer) ||
        depth >= _maxRefDepth ||
        budget.expansions >= _maxSchemaExpansions;
    m.remove(_refKey);
    if (!exhausted) {
      final target = _lookupRef(
        pointer,
        root,
        preserveJsonSchema: budget.preserveJsonSchema,
      );
      if (target != null && (budget.preserveJsonSchema || target is! bool)) {
        budget.expansions++;
        final resolved = _resolveSchema(
          target is Map ? Map<String, dynamic>.from(target) : target,
          root,
          <String>{...active, pointer},
          depth + 1,
          budget,
        );
        if (budget.keepOriginal) return node;
        final hasValidationSiblings = m.keys.any(
          (key) =>
              !_annotationKeywords.contains(key) &&
              !_definitionKeywords.contains(key) &&
              key != r'$schema',
        );
        if (budget.preserveJsonSchema &&
            (hasValidationSiblings || (resolved is bool && m.isNotEmpty))) {
          final siblings = _walkKeywords(m, root, active, depth, budget);
          final allOf = siblings.remove('allOf');
          return {
            ...siblings,
            'allOf': [resolved, if (allOf is List) ...allOf],
          };
        }
        if (resolved is Map<String, dynamic>) {
          return _overlayAnnotations(resolved, m);
        }
        return resolved;
      }
    }
    if (budget.preserveJsonSchema) {
      budget.keepOriginal = true;
      return node;
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
    final outputKey =
        budget.preserveJsonSchema &&
            const {'any_of', 'one_of', 'all_of'}.contains(key)
        ? key.replaceAll('_of', 'Of')
        : key;
    if (_schemaMapKeywords.contains(key) &&
        (budget.preserveJsonSchema || key == 'properties') &&
        value is Map) {
      out[outputKey] = <String, dynamic>{
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
    if (_schemaListKeywords.contains(key) &&
        (budget.preserveJsonSchema || key != 'prefixItems') &&
        value is List) {
      if (!budget.preserveJsonSchema) {
        // Do not spend the expansion budget on branches the sanitizer drops.
        if (_nullableBranchIndex(node, key, value) == 0 &&
            _hasNonNullTarget(value[1], root, active, depth, budget)) {
          final other = _resolveSchema(value[1], root, active, depth, budget);
          if (other is Map && _nonNullTypes.contains(other['type'])) {
            out[outputKey] = [value.first, other];
            return;
          }
        }
        out[outputKey] = [
          if (value.isNotEmpty)
            _resolveSchema(value.first, root, active, depth, budget),
          if (value.length > 1) ...value.skip(1),
        ];
      } else {
        out[outputKey] = [
          for (final variant in value)
            _resolveSchema(variant, root, active, depth, budget),
        ];
      }
      return;
    }
    if (key == 'additionalProperties' && !budget.preserveJsonSchema) {
      out[outputKey] = value;
      return;
    }
    if (_subSchemaKeywords.contains(key) &&
        (budget.preserveJsonSchema ||
            key == 'items' ||
            key == 'additionalProperties') &&
        (value is Map || value is List)) {
      out[outputKey] = _resolveSchema(value, root, active, depth, budget);
      return;
    }
    // Anything else — `default`, `enum`, `const`, `examples`, vendor keys — is
    // data, not schema, and is copied verbatim.
    out[outputKey] = value;
  });
  return out;
}

/// Inspect the target's type before spending the shared budget expanding its
/// children. A nullable branch can be an alias chain, including a cycle.
bool _hasNonNullTarget(
  dynamic node,
  Map<String, dynamic> root,
  Set<String> active,
  int depth,
  _RefBudget budget,
) {
  final seen = {...active};
  var remaining = _maxSchemaExpansions - budget.expansions;
  while (node is Map) {
    final ref = node[_refKey];
    if (ref is! String || ref.trim().isEmpty) {
      return _nonNullTypes.contains(node['type']);
    }
    final pointer = ref.trim();
    if (remaining <= 0 || depth >= _maxRefDepth || !seen.add(pointer)) {
      return false;
    }
    node = _lookupRef(pointer, root, preserveJsonSchema: false);
    remaining--;
    depth++;
  }
  return false;
}

/// Resolve a local JSON Pointer such as `#/$defs/Payload`.
///
/// Only pointer-form local references are supported; `#Anchor` style refs and
/// remote URLs return null so the caller can pass the node through untouched.
/// For JSON Schema providers, ancestor reference context also returns null:
/// inlining a descendant alone would lose its inherited resource/dialect scope.
///
/// RFC 6901 §6: percent-decode the whole fragment, then split on `/`, then
/// unescape `~1` / `~0` per segment.
dynamic _lookupRef(
  String ref,
  Map<String, dynamic> root, {
  required bool preserveJsonSchema,
}) {
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
  var isNamedSchemaMap = false;
  for (final rawSegment in fragment.substring(1).split('/')) {
    final segment = rawSegment.replaceAll('~1', '/').replaceAll('~0', '~');
    if (current is Map) {
      if (preserveJsonSchema &&
          !isNamedSchemaMap &&
          _referenceContextKeywords.any(current.containsKey)) {
        return null;
      }
      if (!current.containsKey(segment)) return null;
      // Keys inside properties/$defs/etc. are names, even when named `$id`.
      isNamedSchemaMap =
          !isNamedSchemaMap &&
          (_schemaMapKeywords.contains(segment) ||
              _definitionKeywords.contains(segment));
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      isNamedSchemaMap = false;
      current = current[index];
    } else {
      return null;
    }
  }
  return current;
}

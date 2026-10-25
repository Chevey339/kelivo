typedef ToolSchemaReferenceCase = ({
  String name,
  Map<String, dynamic> schema,
  List<Object?> valid,
  List<Object?> invalid,
});

List<ToolSchemaReferenceCase> toolSchemaReferenceCases() => [
  (
    name: 'anchor under not',
    schema: {
      r'$defs': {
        'Text': {r'$anchor': 'text', 'type': 'string'},
      },
      'type': 'object',
      'properties': {
        'value': {
          'type': 'integer',
          'not': {r'$ref': '#text'},
        },
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {'value': -1},
    ],
    invalid: [
      {'value': 'a'},
      <String, dynamic>{},
    ],
  ),
  (
    name: 'recursive reference under not',
    schema: {
      r'$defs': {
        'Arrays': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/Arrays'},
        },
      },
      'type': 'object',
      'properties': {
        'value': {
          'not': {r'$ref': r'#/$defs/Arrays'},
        },
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {
        'value': [1],
      },
    ],
    invalid: [
      {'value': []},
      {
        'value': [[]],
      },
    ],
  ),
  (
    name: 'dynamic reference to a definition',
    schema: {
      r'$defs': {
        'Count': {'type': 'integer', 'minimum': 1},
      },
      'type': 'object',
      'properties': {
        'value': {r'$dynamicRef': r'#/$defs/Count'},
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {'value': 2},
    ],
    invalid: [
      {'value': 'a'},
      {'value': 0},
    ],
  ),
  (
    name: 'dynamic anchor',
    schema: {
      r'$defs': {
        'Count': {r'$dynamicAnchor': 'count', 'type': 'integer'},
      },
      'type': 'object',
      'properties': {
        'value': {r'$dynamicRef': '#count'},
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {'value': -1},
    ],
    invalid: [
      {'value': 'a'},
      {'value': null},
    ],
  ),
  (
    name: 'dynamic reference reached through a static reference',
    schema: {
      r'$defs': {
        'Count': {'type': 'integer'},
        'Alias': {r'$dynamicRef': r'#/$defs/Count'},
      },
      'type': 'object',
      'properties': {
        'value': {r'$ref': r'#/$defs/Alias'},
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
    ],
    invalid: [
      {'value': 'a'},
      {'value': null},
    ],
  ),
  (
    name: 'nested resource has its own reference base',
    schema: {
      r'$defs': {
        'Count': {'type': 'string'},
        'Inner': {
          r'$id': 'https://example.test/inner',
          r'$defs': {
            'Count': {'type': 'integer'},
          },
          'type': 'object',
          'properties': {
            'value': {r'$ref': r'#/$defs/Count'},
          },
          'required': ['value'],
        },
      },
      'type': 'object',
      'properties': {
        'payload': {r'$ref': r'#/$defs/Inner'},
      },
      'required': ['payload'],
    },
    valid: [
      {
        'payload': {'value': 1},
      },
    ],
    invalid: [
      {
        'payload': {'value': 'a'},
      },
    ],
  ),
  (
    name: 'JSON Pointer skips a resource ancestor under not',
    schema: _crossResourcePointerSchema(r'#/$defs/Inner/properties/value'),
    valid: [
      {'value': 1},
      {'value': -1},
    ],
    invalid: [
      {'value': 'a'},
      <String, dynamic>{},
    ],
  ),
  (
    name: 'encoded JSON Pointer skips a resource ancestor under not',
    schema: _crossResourcePointerSchema('#/%24defs/Inner/properties/value'),
    valid: [
      {'value': 1},
      {'value': -1},
    ],
    invalid: [
      {'value': 'a'},
      <String, dynamic>{},
    ],
  ),
  (
    name: 'JSON Pointer skips a resource inside an array branch under not',
    schema: _crossResourcePointerSchema(
      r'#/$defs/Inner/allOf/0/properties/value',
      insideArray: true,
    ),
    valid: [
      {'value': 1},
      {'value': -1},
    ],
    invalid: [
      {'value': 'a'},
      <String, dynamic>{},
    ],
  ),
  (
    name: 'declared dialect keeps its reference sibling semantics',
    schema: {
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      'definitions': {
        'Text': {'type': 'string'},
      },
      'type': 'object',
      'properties': {
        'value': {r'$ref': '#/definitions/Text', 'maxLength': 1},
      },
      'required': ['value'],
    },
    valid: [
      {'value': 'long text'},
    ],
    invalid: [
      {'value': 1},
    ],
  ),
  (
    name: 'reference depth limit under not',
    schema: {
      r'$defs': {
        for (var i = 0; i < 14; i++)
          'Level$i': {r'$ref': '#/\$defs/Level${i + 1}'},
        'Level14': {'type': 'string'},
      },
      'type': 'object',
      'properties': {
        'value': {
          'not': {r'$ref': r'#/$defs/Level0'},
        },
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {'value': null},
    ],
    invalid: [
      {'value': 'a'},
    ],
  ),
  (
    name: 'reference budget before a later not',
    schema: {
      r'$defs': {
        for (var level = 0; level < 4; level++)
          'Level$level': {
            'type': 'object',
            'properties': {
              for (var field = 0; field < 10; field++)
                'field$field': {r'$ref': '#/\$defs/Level${level + 1}'},
            },
          },
        'Level4': {'type': 'string'},
        'Text': {'type': 'string'},
      },
      'type': 'object',
      'properties': {
        'large': {r'$ref': r'#/$defs/Level0'},
        'value': {
          'not': {r'$ref': r'#/$defs/Text'},
        },
      },
      'required': ['value'],
    },
    valid: [
      {'value': 1},
      {'value': null},
    ],
    invalid: [
      {'value': 'a'},
    ],
  ),
];

Map<String, dynamic> _crossResourcePointerSchema(
  String ref, {
  bool insideArray = false,
}) {
  final inner = {
    r'$id': 'https://example.test/inner',
    r'$defs': {
      'Count': {'type': 'string'},
    },
    'properties': {
      'value': {r'$ref': r'#/$defs/Count'},
    },
  };
  return {
    r'$defs': {
      'Count': {'type': 'integer'},
      'Inner': insideArray
          ? {
              'allOf': [inner],
            }
          : inner,
    },
    'type': 'object',
    'properties': {
      'value': {
        'type': 'integer',
        'not': {r'$ref': ref},
      },
    },
    'required': ['value'],
  };
}

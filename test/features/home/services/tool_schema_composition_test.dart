import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

void main() {
  const fields = {
    'email': {'type': 'string'},
    'name': {'type': 'string', 'description': 'Full name'},
    'domain': {'type': 'string'},
    'source': {'type': 'string'},
    'info': {
      'type': 'object',
      'properties': {
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
    },
  };
  const nonBlank = {'pattern': r'\S'};
  const item = {
    'type': 'object',
    'properties': fields,
    'additionalProperties': false,
    'required': ['source'],
    'anyOf': [
      {
        'required': ['email'],
        'properties': {'email': nonBlank},
      },
      {
        'required': ['name', 'domain'],
        'properties': {'name': nonBlank, 'domain': nonBlank},
      },
    ],
  };
  const schema = <String, dynamic>{
    r'$id': 'https://example.test/tools/enrich',
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    'type': 'object',
    'properties': {
      'people': {'type': 'array', 'items': item},
    },
  };
  test('Gemini keeps every identifier set of an MCP record', () {
    for (final (kind, id, family) in [
      (ProviderKind.google, 'gemini-4', null),
      (ProviderKind.openai, 'google/gemini-4', null),
      (ProviderKind.openai, 'databricks-gemini-3-1-pro', null),
      (ProviderKind.openai, 'deep-research-max-preview-04-2026', 'gemini-pro'),
    ]) {
      final output = ToolHandlerService.sanitizeToolParametersForProvider(
        schema,
        kind,
        upstreamModelId: id,
        upstreamModelFamily: family,
      );
      final items = output['properties']['people']['items'] as Map;
      expect(items.keys, ['anyOf']);
      final branches = items['anyOf'] as List;
      expect(branches, hasLength(2));
      for (final (index, keys) in [
        ['email'],
        ['name', 'domain'],
      ].indexed) {
        expect(branches[index], {
          'type': 'object',
          if (kind == ProviderKind.openai) 'additionalProperties': false,
          'properties': {
            for (final field in fields.entries)
              field.key: {
                ...field.value,
                if (keys.contains(field.key)) ...nonBlank,
              },
          },
          'required': ['source', ...keys],
        });
      }
    }
    for (final (kind, id) in [
      (ProviderKind.openai, 'gpt-5'),
      (ProviderKind.openai, 'my-gemini-router/gpt-5'),
      (ProviderKind.openai, 'notgemini-4'),
      (ProviderKind.claude, 'google/gemini-4'),
    ]) {
      expect(
        ToolHandlerService.sanitizeToolParametersForProvider(
          schema,
          kind,
          upstreamModelId: id,
        ),
        schema,
      );
    }
    const withPointer = {
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      'type': 'object',
      'properties': {
        'people': {'type': 'array', 'items': item},
        'alsoEmail': {r'$ref': '#/properties/people/items/properties/email'},
      },
    };
    expect(
      ToolHandlerService.sanitizeToolParametersForProvider(
        withPointer,
        ProviderKind.openai,
        upstreamModelId: 'gemini-4',
      ),
      withPointer,
      reason: 'The original location is still used by a JSON Pointer',
    );
  });

  for (final kind in [ProviderKind.google, ProviderKind.openai]) {
    test(
      '$kind keeps null and all identifier alternatives in a nullable record',
      () {
        for (final keyword in ['anyOf', 'oneOf']) {
          for (final nullFirst in [false, true]) {
            final output = ToolHandlerService.sanitizeToolParametersForProvider(
              {
                'type': 'object',
                'properties': {
                  'who': {
                    'description': 'Optional identifier',
                    keyword: [
                      if (nullFirst) {'type': 'null'},
                      item,
                      if (!nullFirst) {'type': 'null'},
                    ],
                  },
                },
              },
              kind,
              upstreamModelId: 'gemini-4',
            );
            final who = output['properties']['who'] as Map;
            expect(who.keys, ['anyOf']);
            final branches = (who['anyOf'] as List).cast<Map>();
            expect(
              branches.map((b) => b['type']),
              nullFirst
                  ? ['null', 'object', 'object']
                  : ['object', 'object', 'null'],
            );
            expect(
              branches
                  .where((b) => b['type'] == 'object')
                  .map((b) => b['required']),
              [
                ['source', 'email'],
                ['source', 'name', 'domain'],
              ],
            );
            expect(
              branches.every((b) => b['description'] == 'Optional identifier'),
              isTrue,
            );
          }
        }
      },
    );
  }

  test('native composition selection also normalizes a selected record', () {
    final output = ToolHandlerService.sanitizeToolParametersForProvider({
      r'$defs': {
        'Person': {
          ...item,
          'examples': [
            {'email': 'person@example.test'},
          ],
        },
      },
      'type': 'object',
      'properties': {
        'who': {
          'description': 'Contact',
          'default': {'name': 'unassigned'},
          'allOf': [
            {r'$ref': r'#/$defs/Person'},
          ],
        },
      },
    }, ProviderKind.google);
    final options = output['properties']['who']['anyOf'] as List;
    expect(
      options.every(
        (branch) =>
            branch['description'] == 'Contact' &&
            !branch.containsKey('default') &&
            !branch.containsKey('examples'),
      ),
      isTrue,
    );
    expect(options.map((branch) => branch['required']), [
      ['source', 'email'],
      ['source', 'name', 'domain'],
    ]);
  });

  test('native selection preserves parent and child composition scopes', () {
    final output = ToolHandlerService.sanitizeToolParametersForProvider({
      'type': 'object',
      'properties': {
        'size': {
          'allOf': [
            {
              'type': 'string',
              'enum': ['small', 'large'],
            },
          ],
          'anyOf': [
            {
              'allOf': [
                {'type': 'string', 'description': 'Size'},
              ],
            },
            {'type': 'null'},
          ],
        },
      },
    }, ProviderKind.google);
    expect(output['properties']['size'], {
      'type': 'string',
      'description': 'Size',
      'enum': ['small', 'large'],
    });
  });

  test('native resolves the non-null record reference in either position', () {
    for (final nullFirst in [false, true]) {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        r'$defs': {
          'Record': item,
          'Alias': {r'$ref': r'#/$defs/Record'},
        },
        'type': 'object',
        'properties': {
          'who': {
            'anyOf': [
              if (nullFirst) {'type': 'null'},
              {r'$ref': r'#/$defs/Alias'},
              if (!nullFirst) {'type': 'null'},
            ],
          },
        },
      }, ProviderKind.google);
      final variants = (output['properties']['who']['anyOf'] as List)
          .cast<Map>();
      expect(
        variants.map((v) => v['type']),
        nullFirst ? ['null', 'object', 'object'] : ['object', 'object', 'null'],
      );
      expect(
        variants.where((v) => v['type'] == 'object').map((v) => v['required']),
        [
          ['source', 'email'],
          ['source', 'name', 'domain'],
        ],
      );
    }
  });

  test('Gemini relay keeps contains bounds scoped to their own subschema', () {
    const tags = {
      'type': 'array',
      'contains': {'const': 'known'},
      'maxContains': 3,
    };
    final output = ToolHandlerService.sanitizeToolParametersForProvider(
      {
        'type': 'object',
        'properties': {
          'entry': {
            'type': 'object',
            'properties': {
              'tags': tags,
              'id': {'type': 'string'},
            },
            'anyOf': [
              {
                'required': ['tags'],
                'properties': {
                  'tags': {'minContains': 2, 'maxContains': 2},
                },
              },
              {
                'required': ['id'],
              },
            ],
          },
        },
      },
      ProviderKind.openai,
      upstreamModelId: 'gemini-4',
    );
    final branches = (output['properties']['entry']['anyOf'] as List)
        .cast<Map>();
    expect(branches.map((b) => b['properties']['tags']), [tags, tags]);
    expect(branches.map((b) => b['required']), [
      ['tags'],
      ['id'],
    ]);
  });

  for (final kind in [ProviderKind.openai, ProviderKind.claude]) {
    for (final entry in <String, List<Map<String, dynamic>>>{
      'pattern': [
        {'type': 'string', 'pattern': '^a'},
        {'type': 'string', 'pattern': '^b'},
      ],
      'numeric range': [
        {'type': 'number', 'minimum': -10, 'maximum': 0},
        {'type': 'number', 'exclusiveMinimum': 10, 'exclusiveMaximum': 20},
      ],
      'multiples': [
        {'type': 'integer', 'multipleOf': 3},
        {'type': 'integer', 'multipleOf': 5},
      ],
      'string length': [
        {'type': 'string', 'maxLength': 2},
        {'type': 'string', 'minLength': 4},
      ],
      'array length': [
        {'type': 'array', 'maxItems': 1, 'uniqueItems': true},
        {'type': 'array', 'minItems': 3},
      ],
      'object size': [
        {'type': 'object', 'maxProperties': 1},
        {'type': 'object', 'minProperties': 3},
      ],
      'negation': [
        {
          'type': 'string',
          'not': {'pattern': '^a'},
        },
        {'type': 'string', 'pattern': '^a'},
      ],
      'constant values': [
        {'const': null},
        {
          'const': {'kind': 'a'},
        },
        {
          'const': ['b'],
        },
      ],
      'constant and enum intersection': [
        {
          'const': 'a',
          'enum': ['a', 'b'],
        },
        {
          'const': 'b',
          'enum': ['a'],
        },
      ],
    }.entries) {
      test('$kind preserves oneOf discriminators based on ${entry.key}', () {
        final input = <String, dynamic>{
          'type': 'object',
          'properties': {
            'value': {'oneOf': entry.value},
          },
        };
        expect(
          ToolHandlerService.sanitizeToolParametersForProvider(input, kind),
          input,
        );
      });
    }

    test('$kind preserves constraints next to refs in oneOf branches', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        r'$defs': {
          'Text': {'type': 'string'},
        },
        'type': 'object',
        'properties': {
          'value': {
            'oneOf': [
              {r'$ref': r'#/$defs/Text', 'pattern': '^a'},
              {r'$ref': r'#/$defs/Text', 'pattern': '^b'},
            ],
          },
        },
      }, kind);
      expect(output['properties']['value'], {
        'oneOf': [
          {
            'pattern': '^a',
            'allOf': [
              {'type': 'string'},
            ],
          },
          {
            'pattern': '^b',
            'allOf': [
              {'type': 'string'},
            ],
          },
        ],
      });
    });

    test('$kind resolves refs inside branch validation keywords', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        r'$defs': {
          'StartsWithA': {'pattern': '^a'},
          'Count': {'type': 'integer', 'minimum': 1},
        },
        'type': 'object',
        'properties': {
          'value': {
            'oneOf': [
              {
                'type': 'string',
                'not': {r'$ref': r'#/$defs/StartsWithA'},
              },
              {'type': 'string', 'pattern': '^a'},
            ],
          },
          'object': {
            'type': 'object',
            'patternProperties': {
              '^x': {r'$ref': r'#/$defs/Count'},
            },
            'dependentRequired': {
              'x': ['y'],
            },
          },
          'array': {
            'type': 'array',
            'contains': {r'$ref': r'#/$defs/Count'},
            'minContains': 1,
            'maxContains': 2,
          },
        },
      }, kind);
      expect(output['properties']['value']['oneOf'][0]['not'], {
        'pattern': '^a',
      });
      expect(output['properties']['object']['patternProperties']['^x'], {
        'type': 'integer',
        'minimum': 1,
      });
      expect(output['properties']['object']['dependentRequired'], {
        'x': ['y'],
      });
      expect(output['properties']['array'], {
        'type': 'array',
        'contains': {'type': 'integer', 'minimum': 1},
        'minContains': 1,
        'maxContains': 2,
      });
    });

    for (final keyword in ['anyOf', 'oneOf', 'allOf']) {
      test('$kind preserves every $keyword branch and resolves its refs', () {
        final input = <String, dynamic>{
          'type': 'object',
          r'$defs': {
            'First': {
              'type': 'object',
              'properties': {
                'a': {'type': 'string'},
              },
              'required': ['a'],
            },
            'Second': {
              'type': 'object',
              'properties': {
                'b': {r'$ref': r'#/$defs/Count'},
              },
              'required': ['b'],
            },
            'Count': {'type': 'integer'},
          },
          'properties': {
            'params': {
              'type': 'object',
              'description': 'shared constraints',
              'properties': {
                'shared': {'type': 'boolean'},
              },
              'required': ['shared'],
              keyword: [
                {r'$ref': r'#/$defs/First'},
                {r'$ref': r'#/$defs/Second'},
              ],
            },
          },
        };

        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          input,
          kind,
        );

        expect(output['properties']['params'], {
          'type': 'object',
          'description': 'shared constraints',
          'properties': {
            'shared': {'type': 'boolean'},
          },
          'required': ['shared'],
          keyword: [
            {
              'type': 'object',
              'properties': {
                'a': {'type': 'string'},
              },
              'required': ['a'],
            },
            {
              'type': 'object',
              'properties': {
                'b': {'type': 'integer'},
              },
              'required': ['b'],
            },
          ],
        });
        expect(input['properties']['params'][keyword], [
          {r'$ref': r'#/$defs/First'},
          {r'$ref': r'#/$defs/Second'},
        ]);
        expect(output, isNot(contains(r'$defs')));
      });
    }

    test('$kind preserves unions in arrays and additionalProperties', () {
      final input = <String, dynamic>{
        'type': 'object',
        'properties': {
          'values': {
            'type': 'array',
            'items': {
              'anyOf': [
                {'type': 'string'},
                {'type': 'integer'},
              ],
            },
          },
          'settings': {
            'type': 'object',
            'additionalProperties': {
              'oneOf': [
                {'type': 'boolean'},
                {
                  'type': 'object',
                  'properties': {
                    'value': {
                      'type': ['string', 'null'],
                    },
                  },
                  'additionalProperties': false,
                },
              ],
            },
          },
        },
      };
      final output = ToolHandlerService.sanitizeToolParametersForProvider(
        input,
        kind,
      );
      expect(output, input);
    });

    test('$kind preserves tuple entries and boolean branch constraints', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        r'$defs': {
          'Text': {'type': 'string', 'pattern': '^a'},
          'Count': {'type': 'integer', 'minimum': 1},
          'Denied': false,
        },
        'type': 'object',
        'properties': {
          'tuple': {
            'type': 'array',
            'items': [
              {r'$ref': r'#/$defs/Count'},
              {r'$ref': r'#/$defs/Text'},
            ],
            'additionalItems': false,
          },
          'value': {
            'oneOf': [
              {r'$ref': r'#/$defs/Denied'},
              {r'$ref': r'#/$defs/Count'},
            ],
          },
        },
      }, kind);
      expect(output['properties'], {
        'tuple': {
          'type': 'array',
          'items': [
            {'type': 'integer', 'minimum': 1},
            {'type': 'string', 'pattern': '^a'},
          ],
          'additionalItems': false,
        },
        'value': {
          'oneOf': [
            false,
            {'type': 'integer', 'minimum': 1},
          ],
        },
      });
    });

    test('$kind preserves branch dialects without changing the input', () {
      final input = <String, dynamic>{
        'type': 'object',
        'properties': {
          'value': {
            'anyOf': [
              {'const': 'auto'},
              {'const': 5, r'$schema': 'https://json-schema.org/schema'},
            ],
          },
        },
      };
      final output = ToolHandlerService.sanitizeToolParametersForProvider(
        input,
        kind,
      );
      expect(output['properties']['value'], {
        'anyOf': [
          {'const': 'auto'},
          {'const': 5, r'$schema': 'https://json-schema.org/schema'},
        ],
      });
      expect(input['properties']['value']['anyOf'][1], {
        'const': 5,
        r'$schema': 'https://json-schema.org/schema',
      });
    });

    for (final entry in const {
      'any_of': 'anyOf',
      'one_of': 'oneOf',
      'all_of': 'allOf',
    }.entries) {
      test('$kind normalizes ${entry.key} without dropping branches', () {
        final output = ToolHandlerService.sanitizeToolParametersForProvider({
          'type': 'object',
          'properties': {
            'value': {
              entry.key: [
                {'type': 'number'},
                {'type': 'integer'},
              ],
            },
          },
        }, kind);
        expect(output['properties']['value'], {
          entry.value: [
            {'type': 'number'},
            {'type': 'integer'},
          ],
        });
      });
    }
  }

  test('Google keeps its existing native Schema conversion', () {
    for (final keyword in ['anyOf', 'oneOf', 'allOf']) {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        'properties': {
          'value': {
            keyword: [
              {'type': 'string'},
              {'type': 'integer'},
            ],
          },
          'nullable': {
            'type': ['string', 'null'],
          },
        },
      }, ProviderKind.google);
      expect(output['properties'], {
        'value': {'type': 'string'},
        'nullable': {'type': 'string'},
      });
    }
  });

  test('Google does not expand refs in discarded composition branches', () {
    for (final keyword in ['anyOf', 'oneOf', 'allOf']) {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
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
          'Count': {'type': 'integer'},
        },
        'type': 'object',
        'properties': {
          'early': {
            keyword: [
              {'type': 'string'},
              {r'$ref': r'#/$defs/Level0'},
            ],
          },
          'later': {r'$ref': r'#/$defs/Count'},
        },
      }, ProviderKind.google);

      expect(output['properties'], {
        'early': {'type': 'string'},
        'later': {'type': 'integer'},
      });
    }
  });
}

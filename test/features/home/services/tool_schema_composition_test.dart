import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

void main() {
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

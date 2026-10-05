import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/json_schema_utils.dart';

void main() {
  group('resolveJsonSchemaRefs', () {
    test('inlines a \$defs reference and drops the definition block', () {
      final resolved = resolveJsonSchemaRefs({
        'type': 'object',
        r'$defs': {
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
            },
          },
        },
        'properties': {
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
      });

      final payload =
          (resolved['properties'] as Map)['payload'] as Map<String, dynamic>;
      expect(payload['type'], 'object');
      expect((payload['properties'] as Map).containsKey('post'), isTrue);
      expect(resolved, isNot(contains(r'$defs')));
    });

    test('overlays annotation siblings onto an inlined \$ref', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Base': {
            'type': 'string',
            'description': 'from target',
            'minLength': 3,
          },
        },
        'properties': {
          'name': {
            r'$ref': r'#/$defs/Base',
            'description': 'from sibling',
            'title': 'Name',
            'default': 'x',
          },
        },
      });

      expect((resolved['properties'] as Map)['name'], {
        'type': 'string',
        'description': 'from sibling',
        'minLength': 3,
        'title': 'Name',
        'default': 'x',
      });
    });

    test('retains validation siblings of a ref as a conjunction', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Base': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
            },
            'required': ['id'],
          },
          'Tag': {'type': 'string'},
        },
        'properties': {
          'target': {
            r'$ref': r'#/$defs/Base',
            'description': 'sibling annotation',
            'properties': {
              'tag': {r'$ref': r'#/$defs/Tag'},
            },
            'required': ['tag'],
            'minLength': 10,
          },
        },
      });

      final target =
          (resolved['properties'] as Map)['target'] as Map<String, dynamic>;
      expect(target['description'], 'sibling annotation');
      expect(target['properties'], {
        'tag': {'type': 'string'},
      });
      expect(target['required'], ['tag']);
      expect(target['minLength'], 10);
      expect(target['allOf'], [
        {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
          },
          'required': ['id'],
        },
      ]);
    });

    test('resolves nested refs inside the referenced target', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Base': {
            'type': 'object',
            'properties': {
              'tag': {r'$ref': r'#/$defs/Tag'},
            },
          },
          'Tag': {'type': 'string'},
        },
        'properties': {
          'target': {r'$ref': r'#/$defs/Base'},
        },
      });

      final target =
          (resolved['properties'] as Map)['target'] as Map<String, dynamic>;
      expect((target['properties'] as Map)['tag'], {'type': 'string'});
    });

    test('does not treat a parameter named like a keyword as schema', () {
      final resolved = resolveJsonSchemaRefs({
        'type': 'object',
        r'$defs': {
          'Tag': {'type': 'string'},
        },
        'properties': {
          'definitions': {'type': 'string'},
          r'$defs': {'type': 'integer'},
          'tag': {r'$ref': r'#/$defs/Tag'},
        },
      });

      final props = resolved['properties'] as Map;
      expect(props.keys.toSet(), {'definitions', r'$defs', 'tag'});
      expect(props['definitions'], {'type': 'string'});
      expect(props[r'$defs'], {'type': 'integer'});
      expect(props['tag'], {'type': 'string'});
      expect(resolved, isNot(contains(r'$defs')));
    });

    test('copies data keywords verbatim', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Payload': {'type': 'string'},
        },
        'properties': {
          'body': {
            'type': 'object',
            'default': {
              r'$ref': r'#/$defs/Payload',
              r'$dynamicRef': '#not-a-schema',
            },
            'enum': [
              {'definitions': 1},
            ],
            'const': {r'$ref': 'anything'},
          },
        },
      });

      final body = (resolved['properties'] as Map)['body'] as Map;
      expect(body['default'], {
        r'$ref': r'#/$defs/Payload',
        r'$dynamicRef': '#not-a-schema',
      });
      expect(resolved, isNot(contains(r'$defs')));
      expect(body['enum'], [
        {'definitions': 1},
      ]);
      expect(body['const'], {r'$ref': 'anything'});
    });

    test('pointer ancestors distinguish schema names from scope keywords', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          r'$id': false,
          'id': {'type': 'integer'},
          'Box': {
            'properties': {
              r'$id': false,
              'id': true,
              'value': {r'$ref': r'#/$defs/id'},
            },
          },
        },
        'properties': {
          'value': {r'$ref': r'#/$defs/Box/properties/value'},
          'blocked': {r'$ref': r'#/$defs/Box/properties/$id'},
        },
      });

      expect(resolved, {
        'properties': {
          'value': {'type': 'integer'},
          'blocked': false,
        },
      });
    });

    test('resolves references inside union members and items', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Tag': {'type': 'string'},
        },
        'properties': {
          'a': {
            'anyOf': [
              {r'$ref': r'#/$defs/Tag'},
              {'type': 'null'},
            ],
          },
          'b': {
            'type': 'array',
            'items': {r'$ref': r'#/$defs/Tag'},
          },
        },
      });

      final props = resolved['properties'] as Map;
      expect((props['a'] as Map)['anyOf'], [
        {'type': 'string'},
        {'type': 'null'},
      ]);
      expect((props['b'] as Map)['items'], {'type': 'string'});
    });

    for (final keyword in ['anyOf', 'oneOf', 'allOf']) {
      test('resolves references after the first $keyword branch', () {
        final resolved = resolveJsonSchemaRefs({
          r'$defs': {
            'Text': {'type': 'string'},
            'Count': {'type': 'integer'},
          },
          'properties': {
            'value': {
              keyword: [
                {r'$ref': r'#/$defs/Text'},
                {r'$ref': r'#/$defs/Count'},
              ],
            },
          },
        });

        expect(resolved['properties']['value'][keyword], [
          {'type': 'string'},
          {'type': 'integer'},
        ]);
        expect(resolved, isNot(contains(r'$defs')));
      });
    }

    test('retains recursive refs in later branches with their definitions', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Node': {
            'type': 'object',
            'properties': {
              'child': {
                'anyOf': [
                  {'type': 'null'},
                  {r'$ref': r'#/$defs/Node'},
                ],
              },
            },
          },
        },
        'type': 'object',
        'properties': {
          'root': {r'$ref': r'#/$defs/Node'},
        },
      });

      expect(resolved['properties']['root'], {r'$ref': r'#/$defs/Node'});
      expect(resolved[r'$defs']['Node']['properties']['child']['anyOf'], [
        {'type': 'null'},
        {r'$ref': r'#/$defs/Node'},
      ]);
    });

    test('inlines boolean schema targets without losing their constraints', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {'Anything': true, 'Nothing': false},
        'properties': {
          'ok': {r'$ref': r'#/$defs/Anything', 'description': 'kept'},
          'never': {r'$ref': r'#/$defs/Nothing'},
        },
      });

      final props = resolved['properties'] as Map;
      expect(props['ok'], {
        'description': 'kept',
        'allOf': [true],
      });
      expect(props['never'], isFalse);
    });

    test('percent-decodes the fragment before splitting the pointer', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
            },
          },
        },
        'properties': {
          'plain': {r'$ref': r'#/$defs/Payload'},
          'encoded': {r'$ref': r'#%2F%24defs%2FPayload'},
        },
      });

      final props = resolved['properties'] as Map;
      expect(props['encoded'], props['plain']);
      expect(props['encoded'], {
        'type': 'object',
        'properties': {
          'post': {'type': 'integer'},
        },
      });
    });

    test('skips discarded Google schema keywords', () {
      Map<String, dynamic> fanout(String next) => {
        'type': 'object',
        'properties': {
          for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
        },
      };

      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'A': fanout('B'),
          'B': fanout('C'),
          'C': fanout('D'),
          'D': fanout('E'),
          'E': {'type': 'string'},
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
            },
          },
        },
        'type': 'object',
        'patternProperties': {
          'x': {r'$ref': r'#/$defs/A'},
        },
        'not': {r'$ref': r'#/$defs/A'},
        'properties': {
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
      }, preserveJsonSchema: false);

      final payload =
          (resolved['properties'] as Map)['payload'] as Map<String, dynamic>;
      expect(payload['type'], 'object');
      expect((payload['properties'] as Map).containsKey('post'), isTrue);
    });

    test('skips discarded Google tuple entries', () {
      Map<String, dynamic> fanout(String next) => {
        'type': 'object',
        'properties': {
          for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
        },
      };

      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'A': fanout('B'),
          'B': fanout('C'),
          'C': fanout('D'),
          'D': fanout('E'),
          'E': {'type': 'string'},
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
            },
          },
        },
        'type': 'object',
        'properties': {
          'early': {
            'type': 'array',
            'items': [
              {'type': 'string'},
              {r'$ref': r'#/$defs/A'},
            ],
          },
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
      }, preserveJsonSchema: false);

      final payload =
          (resolved['properties'] as Map)['payload'] as Map<String, dynamic>;
      expect(payload['type'], 'object');
      expect((payload['properties'] as Map).containsKey('post'), isTrue);
      expect((resolved['properties'] as Map)['early'], {
        'type': 'array',
        'items': [
          {'type': 'string'},
          {r'$ref': r'#/$defs/A'},
        ],
      });
    });

    test(
      'does not spend the expansion budget on additionalProperties when dropped',
      () {
        Map<String, dynamic> fanout(String next) => {
          'type': 'object',
          'properties': {
            for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
          },
        };

        final schema = <String, dynamic>{
          r'$defs': {
            'A': fanout('B'),
            'B': fanout('C'),
            'C': fanout('D'),
            'D': fanout('E'),
            'E': {'type': 'string'},
            'Payload': {
              'type': 'object',
              'properties': {
                'post': {'type': 'integer'},
              },
            },
          },
          'type': 'object',
          'additionalProperties': {r'$ref': r'#/$defs/A'},
          'properties': {
            'payload': {r'$ref': r'#/$defs/Payload'},
          },
        };

        final google = resolveJsonSchemaRefs(schema, preserveJsonSchema: false);
        final googlePayload =
            (google['properties'] as Map)['payload'] as Map<String, dynamic>;
        expect(googlePayload['type'], 'object');
        expect(
          (googlePayload['properties'] as Map).containsKey('post'),
          isTrue,
        );
        expect(google['additionalProperties'], {r'$ref': r'#/$defs/A'});

        final openai = resolveJsonSchemaRefs(schema);
        expect(openai, schema);
      },
    );

    test('unescapes pointer segments', () {
      final resolved = resolveJsonSchemaRefs({
        'definitions': {
          'a/b~c': {'type': 'string'},
        },
        'properties': {
          'x': {r'$ref': '#/definitions/a~1b~0c'},
        },
      });

      expect((resolved['properties'] as Map)['x'], {'type': 'string'});
    });

    test('looks up the empty-string member for #/ rather than the root', () {
      final resolved = resolveJsonSchemaRefs({
        'type': 'object',
        '': {'type': 'integer'},
        'properties': {
          'emptyName': {r'$ref': '#/'},
        },
      });

      final emptyName = (resolved['properties'] as Map)['emptyName'];
      expect(emptyName, {'type': 'integer'});
      expect(emptyName, isNot(contains('properties')));
    });

    test('treats a dangling #/ as unresolvable', () {
      final resolved = resolveJsonSchemaRefs({
        'properties': {
          'x': {r'$ref': '#/'},
        },
      });

      expect((resolved['properties'] as Map)['x'], {r'$ref': '#/'});
    });

    test('preserves unresolved references instead of empty schemas', () {
      final resolved = resolveJsonSchemaRefs({
        'properties': {
          'remote': {
            r'$ref': 'https://example.com/schema.json',
            'description': 'kept',
          },
          'anchor': {r'$ref': '#Payload'},
          'missing': {r'$ref': r'#/$defs/Nope'},
        },
      });

      final props = resolved['properties'] as Map;
      expect(props['remote'], {
        r'$ref': 'https://example.com/schema.json',
        'description': 'kept',
      });
      expect(props['anchor'], {r'$ref': '#Payload'});
      expect(props['missing'], {r'$ref': r'#/$defs/Nope'});
    });

    test('terminates on a self-referencing schema', () {
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'Node': {
            'type': 'object',
            'properties': {
              'child': {r'$ref': r'#/$defs/Node'},
            },
          },
        },
        'properties': {
          'root': {r'$ref': r'#/$defs/Node'},
        },
      });

      expect(resolved['properties']['root'], {r'$ref': r'#/$defs/Node'});
      expect(resolved[r'$defs']['Node']['properties']['child'], {
        r'$ref': r'#/$defs/Node',
      });
    });

    test('stays bounded when every level fans out into more references', () {
      // A -> 10x B -> 10x C -> 10x D: naive inlining explodes combinatorially.
      Map<String, dynamic> level(String next) => {
        'type': 'object',
        'properties': {
          for (var i = 0; i < 10; i++) 'f$i': {r'$ref': '#/\$defs/$next'},
        },
      };

      final stopwatch = Stopwatch()..start();
      final resolved = resolveJsonSchemaRefs({
        r'$defs': {
          'A': level('B'),
          'B': level('C'),
          'C': level('D'),
          'D': level('E'),
          'E': {'type': 'string'},
        },
        'type': 'object',
        'properties': {
          'root': {r'$ref': r'#/$defs/A'},
        },
      });
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(_countNodes(resolved), lessThan(5000));
      // The budget stops expansion and retains the whole original graph.
      expect(resolved['properties']['root'], {r'$ref': r'#/$defs/A'});
      expect((resolved[r'$defs'] as Map).keys, ['A', 'B', 'C', 'D', 'E']);
    });
  });
}

int _countNodes(dynamic node) {
  if (node is Map) {
    var total = 1;
    for (final v in node.values) {
      total += _countNodes(v);
    }
    return total;
  }
  if (node is List) {
    var total = 1;
    for (final v in node) {
      total += _countNodes(v);
    }
    return total;
  }
  return 1;
}

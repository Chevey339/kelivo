import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolHandlerService tool schema sanitization', () {
    for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
      test('preserves and sanitizes additionalProperties for $kind', () {
        final input = <String, dynamic>{
          'type': 'object',
          'additionalProperties': true,
          'properties': {
            'config': {
              'type': 'object',
              'additionalProperties': {
                r'$schema': 'https://json-schema.org/draft/2020-12/schema',
                'type': 'string',
                'const': 'enabled',
              },
            },
            'entries': {
              'type': 'array',
              'items': {'type': 'object', 'additionalProperties': false},
            },
          },
        };

        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          input,
          kind,
        );

        expect(output['additionalProperties'], isTrue);
        final properties = output['properties'] as Map<String, dynamic>;
        expect(
          (properties['config'] as Map)['additionalProperties'],
          <String, dynamic>{
            'type': 'string',
            'enum': ['enabled'],
          },
        );
        expect(
          ((properties['entries'] as Map)['items']
              as Map)['additionalProperties'],
          isFalse,
        );
      });
    }

    test('inlines local \$ref targets so nested objects survive', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Payload': {
            'type': 'object',
            'properties': {
              'post': {'type': 'integer'},
              'text': {'type': 'string'},
            },
            'required': ['post', 'text'],
          },
        },
        'properties': {
          'action': {'type': 'string'},
          'payload': {r'$ref': r'#/$defs/Payload'},
        },
        'required': ['action', 'payload'],
      }, ProviderKind.openai);

      final payload = output['properties']['payload'] as Map<String, dynamic>;
      expect(payload['type'], 'object');
      expect((payload['properties'] as Map).keys.toSet(), {'post', 'text'});
      expect(payload['required'], ['post', 'text']);
      expect(output, isNot(contains(r'$defs')));
    });

    test('keeps a sibling description after inlining a \$ref', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
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
          'payload': {r'$ref': r'#/$defs/Payload', 'description': 'the body'},
        },
      }, ProviderKind.openai);

      expect(output['properties']['payload'], {
        'type': 'object',
        'description': 'the body',
        'properties': {
          'post': {'type': 'integer'},
        },
      });
    });

    test('passes an unresolvable \$ref through without inventing a type', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        'properties': {
          'remote': {
            r'$ref': 'https://example.com/s.json',
            'description': 'kept',
          },
          'dangling': {r'$ref': r'#/$defs/Missing'},
          'anchor': {r'$ref': '#Payload'},
        },
      }, ProviderKind.openai);

      final props = output['properties'] as Map<String, dynamic>;
      expect(props['remote'], {'description': 'kept'});
      expect(props['dangling'], isEmpty);
      expect(props['anchor'], isEmpty);
    });

    test('cuts a recursive \$ref without inventing a type', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
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
      }, ProviderKind.openai);

      var node = output['properties']['root'] as Map<String, dynamic>;
      expect(node['type'], 'object');
      var depth = 0;
      while (node['properties'] is Map &&
          (node['properties'] as Map)['child'] is Map &&
          ((node['properties'] as Map)['child'] as Map).isNotEmpty) {
        node = (node['properties'] as Map)['child'] as Map<String, dynamic>;
        depth++;
        if (depth > 40) break;
      }
      expect(depth, lessThan(40));
    });

    test('keeps a parameter that is named like a schema keyword', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        r'$defs': {
          'Tag': {'type': 'string'},
        },
        'properties': {
          'definitions': {'type': 'string', 'description': 'a real parameter'},
          r'$defs': {'type': 'integer'},
          'tag': {r'$ref': r'#/$defs/Tag'},
        },
        'required': ['definitions'],
      }, ProviderKind.openai);

      final props = output['properties'] as Map<String, dynamic>;
      expect(props.keys.toSet(), {'definitions', r'$defs', 'tag'});
      expect(props['definitions'], {
        'type': 'string',
        'description': 'a real parameter',
      });
      expect(props['tag'], {'type': 'string'});
      expect(output, isNot(contains(r'$defs')));
    });

    test(
      'does not advertise a boolean property from a \$ref to true or false',
      () {
        for (final kind in const [ProviderKind.google, ProviderKind.openai]) {
          final output = ToolHandlerService.sanitizeToolParametersForProvider({
            'type': 'object',
            r'$defs': {'Denied': false, 'Anything': true},
            'properties': {
              'blocked': {r'$ref': r'#/$defs/Denied'},
              'ok': {r'$ref': r'#/$defs/Anything', 'description': 'all values'},
            },
          }, kind);

          final props = output['properties'] as Map<String, dynamic>;
          expect(props['blocked'], isA<Map>());
          expect(props['blocked'], isNot(isTrue));
          expect(props['blocked'], isNot(isFalse));
          expect(props['ok'], isA<Map>());
          expect(props['ok'], isNot(isTrue));
          expect(props['ok'], isNot(isFalse));
          expect(props['ok']['description'], 'all values');
        }
      },
    );

    test('tuple-form items fan-out still advertises a later payload', () {
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
              'text': {'type': 'string'},
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
      };

      for (final kind in ProviderKind.values) {
        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          schema,
          kind,
        );
        final payload = output['properties']['payload'] as Map<String, dynamic>;
        expect(payload['type'], 'object', reason: '$kind');
        expect((payload['properties'] as Map).keys.toSet(), {
          'post',
          'text',
        }, reason: '$kind');
        expect((output['properties']['early'] as Map)['items'], {
          'type': 'string',
        });
      }
    });

    test(
      'Google additionalProperties fan-out still advertises payload fields',
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
                'text': {'type': 'string'},
              },
            },
          },
          'type': 'object',
          'additionalProperties': {r'$ref': r'#/$defs/A'},
          'properties': {
            'payload': {r'$ref': r'#/$defs/Payload'},
          },
        };

        final google = ToolHandlerService.sanitizeToolParametersForProvider(
          schema,
          ProviderKind.google,
        );
        expect(google, isNot(contains('additionalProperties')));
        final googlePayload =
            google['properties']['payload'] as Map<String, dynamic>;
        expect(googlePayload['type'], 'object');
        expect((googlePayload['properties'] as Map).keys.toSet(), {
          'post',
          'text',
        });

        for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
          final output = ToolHandlerService.sanitizeToolParametersForProvider(
            schema,
            kind,
          );
          final extra = output['additionalProperties'] as Map;
          expect(extra['type'], 'object', reason: '$kind');
          expect(extra.containsKey(r'$ref'), isFalse, reason: '$kind');
        }
      },
    );

    test('continues to drop additionalProperties for Google', () {
      final output = ToolHandlerService.sanitizeToolParametersForProvider({
        'type': 'object',
        'additionalProperties': true,
        'properties': {
          'config': {'type': 'object', 'additionalProperties': true},
        },
      }, ProviderKind.google);

      expect(output, isNot(contains('additionalProperties')));
      expect(
        output['properties']['config'],
        isNot(contains('additionalProperties')),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/provider_kind.dart';
import 'package:Kelivo/features/home/services/tool_schema_sanitizer.dart';

/// Regression tests for the tool-parameter JSON Schema sanitizer.
///
/// Bug: `additionalProperties` (a standard JSON Schema keyword) was stripped
/// for every provider because it was not on the allow-list. MCP servers that
/// declare open/free-form object params were silently narrowed to closed
/// objects, so strict models (e.g. GLM-5.1) refused to fill undeclared params.
///
/// Fix: keep `additionalProperties` for OpenAI/Claude-style providers; Gemini
/// (Google) still drops it because that API rejects the key.
void main() {
  // A nested schema whose object params are open via additionalProperties.
  Map<String, dynamic> sampleSchema() => {
    r'$schema': 'http://json-schema.org/draft-07/schema#',
    'type': 'object',
    'description': 'MCP tool params',
    'additionalProperties': true,
    'required': ['config'],
    'properties': {
      'config': {
        'type': 'object',
        'description': 'Free-form config bag',
        // Open object: values may be any of the declared props plus extras.
        'additionalProperties': true,
        'properties': {
          'name': {'type': 'string'},
        },
      },
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': true,
          'properties': {
            'id': {'type': 'string'},
          },
        },
      },
    },
  };

  group('ToolSchemaSanitizer (OpenAI/Claude)', () {
    for (final kind in const [ProviderKind.openai, ProviderKind.claude]) {
      test(
        'preserves additionalProperties (top-level and nested) for $kind',
        () {
          final out = ToolSchemaSanitizer.sanitizeToolParametersForProvider(
            sampleSchema(),
            kind,
          );

          // Top-level open object preserved.
          expect(
            out['additionalProperties'],
            isTrue,
            reason: 'top-level additionalProperties must survive',
          );

          // properties are not lost.
          final props = out['properties'] as Map<String, dynamic>;
          expect(props.keys, containsAll(<String>['config', 'items']));

          // Nested object keeps additionalProperties AND its properties.
          final config = props['config'] as Map<String, dynamic>;
          expect(config['additionalProperties'], isTrue);
          expect((config['properties'] as Map).containsKey('name'), isTrue);

          // Nested-in-array object keeps additionalProperties too.
          final arrItem =
              (props['items'] as Map)['items'] as Map<String, dynamic>;
          expect(arrItem['additionalProperties'], isTrue);
          expect((arrItem['properties'] as Map).containsKey('id'), isTrue);

          // $schema is still stripped; standard fields still normalized/kept.
          expect(out.containsKey(r'$schema'), isFalse);
          expect(out['type'], 'object');
          expect(out['required'], ['config']);
        },
      );
    }

    test(
      'preserves a subschema-valued additionalProperties and sanitizes it',
      () {
        final schema = {
          'type': 'object',
          'additionalProperties': {
            r'$schema': 'should-be-removed',
            'type': 'string',
            'const': 'x', // should be normalized to enum: ['x']
          },
        };

        final out = ToolSchemaSanitizer.sanitizeToolParametersForProvider(
          schema,
          ProviderKind.openai,
        );

        final ap = out['additionalProperties'] as Map<String, dynamic>;
        expect(
          ap.containsKey(r'$schema'),
          isFalse,
          reason: 'subschema must be recursively sanitized',
        );
        expect(ap['type'], 'string');
        expect(ap['enum'], ['x']);
      },
    );

    test('does not mutate the input schema (deep clone)', () {
      final input = sampleSchema();
      ToolSchemaSanitizer.sanitizeToolParametersForProvider(
        input,
        ProviderKind.openai,
      );
      // Original still has $schema and its nested open objects untouched.
      expect(input.containsKey(r'$schema'), isTrue);
      expect(input['additionalProperties'], isTrue);
    });
  });

  group('ToolSchemaSanitizer (Google/Gemini)', () {
    test('drops additionalProperties because Gemini rejects it', () {
      final out = ToolSchemaSanitizer.sanitizeToolParametersForProvider(
        sampleSchema(),
        ProviderKind.google,
      );

      expect(out.containsKey('additionalProperties'), isFalse);
      // But real params are still preserved.
      final props = out['properties'] as Map<String, dynamic>;
      expect(props.keys, containsAll(<String>['config', 'items']));
      expect(
        (props['config'] as Map).containsKey('additionalProperties'),
        isFalse,
      );
      expect((props['config'] as Map)['properties'], isA<Map>());
    });
  });
}

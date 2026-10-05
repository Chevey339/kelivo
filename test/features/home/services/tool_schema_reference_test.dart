import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/features/home/services/tool_handler_service.dart';

import '../../../support/tool_schema_reference_cases.dart';

void main() {
  for (final kind in [ProviderKind.openai, ProviderKind.claude]) {
    for (final example in toolSchemaReferenceCases()) {
      test('$kind preserves ${example.name} with its reference context', () {
        final before = jsonEncode(example.schema);
        final output = ToolHandlerService.sanitizeToolParametersForProvider(
          example.schema,
          kind,
        );
        // Preserving the whole document also preserves pointer locations,
        // anchor identities, and dynamic scope across the retained references.
        expect(output, example.schema);
        expect(jsonEncode(example.schema), before);
      });
    }
  }
}

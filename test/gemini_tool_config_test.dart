import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/gemini_tool_config.dart';

void main() {
  group('shouldAttachGeminiFunctionCallingConfig', () {
    test('returns false for google_search built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'google_search': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns false for url_context built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'url_context': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns false for code_execution built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'code_execution': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns true when function_declarations exists and non-empty', () {
      final tools = <Map<String, dynamic>>[
        {
          'function_declarations': [
            {'name': 'toolA', 'description': 'A tool'},
          ],
        },
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isTrue);
    });
  });
}

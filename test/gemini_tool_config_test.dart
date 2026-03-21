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

  group('hasBuiltInAndFunctionDeclarations', () {
    test('returns false for only built-in tools', () {
      final tools = <Map<String, dynamic>>[
        {'google_search': {}},
        {'url_context': {}},
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns false for only function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {
          'function_declarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns true for google_search + function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {'google_search': {}},
        {
          'function_declarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns true for code_execution + function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {'code_execution': {}},
        {
          'function_declarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns true for url_context + function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {'url_context': {}},
        {
          'function_declarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns false for empty function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {'google_search': {}},
        {'function_declarations': <dynamic>[]},
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns false for empty tools list', () {
      final tools = <Map<String, dynamic>>[];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });
  });

  group('buildGeminiToolConfig', () {
    test('returns null when no function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {'google_search': {}},
      ];
      expect(
        buildGeminiToolConfig(tools: tools, isGemini3: true),
        isNull,
      );
    });

    test('returns null for only built-in tools even on Gemini 2.x', () {
      final tools = <Map<String, dynamic>>[
        {'code_execution': {}},
      ];
      expect(
        buildGeminiToolConfig(tools: tools, isGemini3: false),
        isNull,
      );
    });

    test('returns AUTO mode for Gemini 2.x with function_declarations', () {
      final tools = <Map<String, dynamic>>[
        {
          'function_declarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      final config = buildGeminiToolConfig(tools: tools, isGemini3: false);
      expect(config, isNotNull);
      expect(config!['function_calling_config']['mode'], equals('AUTO'));
      expect(config.containsKey('includeServerSideToolInvocations'), isFalse);
    });

    test(
      'returns AUTO mode for Gemini 3 with only function_declarations (no built-in)',
      () {
        final tools = <Map<String, dynamic>>[
          {
            'function_declarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(tools: tools, isGemini3: true);
        expect(config, isNotNull);
        expect(config!['function_calling_config']['mode'], equals('AUTO'));
        expect(
          config.containsKey('includeServerSideToolInvocations'),
          isFalse,
        );
      },
    );

    test(
      'returns VALIDATED mode with includeServerSideToolInvocations for Gemini 3 combined tools',
      () {
        final tools = <Map<String, dynamic>>[
          {'google_search': {}},
          {
            'function_declarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(tools: tools, isGemini3: true);
        expect(config, isNotNull);
        expect(
          config!['function_calling_config']['mode'],
          equals('VALIDATED'),
        );
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );

    test(
      'returns AUTO mode for Gemini 2.x even with combined tools (mutual exclusion prevents this case, but test function in isolation)',
      () {
        final tools = <Map<String, dynamic>>[
          {'google_search': {}},
          {
            'function_declarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(tools: tools, isGemini3: false);
        expect(config, isNotNull);
        expect(config!['function_calling_config']['mode'], equals('AUTO'));
        expect(
          config.containsKey('includeServerSideToolInvocations'),
          isFalse,
        );
      },
    );

    test(
      'returns VALIDATED mode for Gemini 3 with code_execution + function_declarations',
      () {
        final tools = <Map<String, dynamic>>[
          {'code_execution': {}},
          {
            'function_declarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(tools: tools, isGemini3: true);
        expect(config, isNotNull);
        expect(
          config!['function_calling_config']['mode'],
          equals('VALIDATED'),
        );
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );

    test(
      'returns VALIDATED mode for Gemini 3 with multiple built-in + function_declarations',
      () {
        final tools = <Map<String, dynamic>>[
          {'google_search': {}},
          {'url_context': {}},
          {'code_execution': {}},
          {
            'function_declarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(tools: tools, isGemini3: true);
        expect(config, isNotNull);
        expect(
          config!['function_calling_config']['mode'],
          equals('VALIDATED'),
        );
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );
  });
}

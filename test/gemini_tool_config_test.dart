import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/api/gemini_tool_config.dart';

void main() {
  group('supportsMixedBuiltInAndFunctionTools', () {
    test('covers the Gemini 3 and 4 generations', () {
      expect(supportsMixedBuiltInAndFunctionTools('gemini-3.6-flash'), isTrue);
      expect(
        supportsMixedBuiltInAndFunctionTools('models/gemini-3-pro-preview'),
        isTrue,
      );
      expect(supportsMixedBuiltInAndFunctionTools('gemini-4-argon'), isTrue);
      expect(supportsMixedBuiltInAndFunctionTools('gemini-2.5-flash'), isFalse);
      expect(supportsMixedBuiltInAndFunctionTools('gemma-4-31B-it'), isFalse);
    });
  });

  group('shouldAttachGeminiFunctionCallingConfig', () {
    test('returns false for googleSearch built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'googleSearch': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns false for urlContext built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'urlContext': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns false for codeExecution built-in tool', () {
      final tools = <Map<String, dynamic>>[
        {'codeExecution': {}},
      ];
      expect(shouldAttachGeminiFunctionCallingConfig(tools), isFalse);
    });

    test('returns true when functionDeclarations exists and non-empty', () {
      final tools = <Map<String, dynamic>>[
        {
          'functionDeclarations': [
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
        {'googleSearch': {}},
        {'urlContext': {}},
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns false for only functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {
          'functionDeclarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns true for googleSearch + functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {'googleSearch': {}},
        {
          'functionDeclarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns true for codeExecution + functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {'codeExecution': {}},
        {
          'functionDeclarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns true for urlContext + functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {'urlContext': {}},
        {
          'functionDeclarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isTrue);
    });

    test('returns false for empty functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {'googleSearch': {}},
        {'functionDeclarations': <dynamic>[]},
      ];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });

    test('returns false for empty tools list', () {
      final tools = <Map<String, dynamic>>[];
      expect(hasBuiltInAndFunctionDeclarations(tools), isFalse);
    });
  });

  group('buildGeminiToolConfig', () {
    test('returns null when no functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {'googleSearch': {}},
      ];
      expect(
        buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: true,
        ),
        isNull,
      );
    });

    test('returns null for only built-in tools even on Gemini 2.x', () {
      final tools = <Map<String, dynamic>>[
        {'codeExecution': {}},
      ];
      expect(
        buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: false,
        ),
        isNull,
      );
    });

    test('returns AUTO mode for Gemini 2.x with functionDeclarations', () {
      final tools = <Map<String, dynamic>>[
        {
          'functionDeclarations': [
            {'name': 'fn1'},
          ],
        },
      ];
      final config = buildGeminiToolConfig(
        tools: tools,
        allowServerSideToolInvocations: false,
      );
      expect(config, isNotNull);
      expect(config!['functionCallingConfig']['mode'], equals('AUTO'));
      expect(config.containsKey('includeServerSideToolInvocations'), isFalse);
    });

    test(
      'returns AUTO mode for Gemini 3 with only functionDeclarations (no built-in)',
      () {
        final tools = <Map<String, dynamic>>[
          {
            'functionDeclarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: true,
        );
        expect(config, isNotNull);
        expect(config!['functionCallingConfig']['mode'], equals('AUTO'));
        expect(config.containsKey('includeServerSideToolInvocations'), isFalse);
      },
    );

    test(
      'returns VALIDATED mode with includeServerSideToolInvocations for Gemini 3 combined tools',
      () {
        final tools = <Map<String, dynamic>>[
          {'googleSearch': {}},
          {
            'functionDeclarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: true,
        );
        expect(config, isNotNull);
        expect(config!['functionCallingConfig']['mode'], equals('VALIDATED'));
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );

    test(
      'returns AUTO mode for Gemini 2.x even with combined tools (mutual exclusion prevents this case, but test function in isolation)',
      () {
        final tools = <Map<String, dynamic>>[
          {'googleSearch': {}},
          {
            'functionDeclarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: false,
        );
        expect(config, isNotNull);
        expect(config!['functionCallingConfig']['mode'], equals('AUTO'));
        expect(config.containsKey('includeServerSideToolInvocations'), isFalse);
      },
    );

    test(
      'returns VALIDATED mode for Gemini 3 with codeExecution + functionDeclarations',
      () {
        final tools = <Map<String, dynamic>>[
          {'codeExecution': {}},
          {
            'functionDeclarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: true,
        );
        expect(config, isNotNull);
        expect(config!['functionCallingConfig']['mode'], equals('VALIDATED'));
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );

    test(
      'returns VALIDATED mode for Gemini 3 with multiple built-in + functionDeclarations',
      () {
        final tools = <Map<String, dynamic>>[
          {'googleSearch': {}},
          {'urlContext': {}},
          {'codeExecution': {}},
          {
            'functionDeclarations': [
              {'name': 'fn1'},
            ],
          },
        ];
        final config = buildGeminiToolConfig(
          tools: tools,
          allowServerSideToolInvocations: true,
        );
        expect(config, isNotNull);
        expect(config!['functionCallingConfig']['mode'], equals('VALIDATED'));
        expect(config['includeServerSideToolInvocations'], isTrue);
      },
    );
  });
}

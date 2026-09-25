import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/logging/context_log_models.dart';
import 'package:Kelivo/core/utils/token_estimator.dart';
import 'package:Kelivo/features/home/services/context_assembly.dart';
import 'package:Kelivo/features/home/services/context_usage_service.dart';

Map<String, dynamic> tagged(
  String role,
  List<(ContextSource, String)> segments,
) => {
  'role': role,
  'content': segments.map((s) => s.$2).join(),
  kelivoContextSegmentsKey: [
    for (final segment in segments)
      ContextSegmentTags.item(source: segment.$1, length: segment.$2.length),
  ],
};

void main() {
  for (final hasTags in [false, true]) {
    test('usage keeps raw data URIs while logs elide them, tagged=$hasTags', () {
      final body =
          'Decode data:text/plain;base64,${base64Encode(utf8.encode(List.filled(2000, 'hello ').join()))}';
      final message = hasTags
          ? tagged('user', [(ContextSource.chatHistory, body)])
          : <String, dynamic>{'role': 'user', 'content': body};
      final preview = ContextAssemblyPreview.fromApiMessages(
        apiMessages: [message],
        tools: [],
        mcpToolNames: {},
        images: [],
      );
      final estimate = estimateContextBuckets(
        ContextEstimateJob(preview: preview, kind: ProviderKind.openai),
      );
      expect(preview.historyText, body);
      expect(estimate.history, estimateTokens(body));
      expect(estimate.history, greaterThan(2000));
      expect(
        segmentsFromTaggedMessage(message).single.text.length,
        lessThan(body.length),
      );
    });
  }

  test(
    'attributes mixed prompts and non-system lore without double counting',
    () {
      final preview = ContextAssemblyPreview.fromApiMessages(
        apiMessages: [
          tagged('system', [
            (ContextSource.worldBook, 'before lore\n'),
            (ContextSource.systemPrompt, 'base prompt'),
            (ContextSource.memoryRules, '\n\nmemory rules'),
            (ContextSource.worldBook, '\nafter lore'),
            (ContextSource.skills, '\n\navailable skills'),
            (ContextSource.workspace, '\n\nworkspace rules'),
            (ContextSource.searchPrompt, '\n\nsearch rules'),
            (ContextSource.instructionInjection, '\n\ncustom instruction'),
          ]),
          tagged('user', [(ContextSource.worldBook, 'user lore')]),
          tagged('assistant', [(ContextSource.worldBook, 'assistant lore')]),
          tagged('user', [
            (ContextSource.memorySnapshot, 'personal facts\n'),
            (ContextSource.chatHistory, 'question'),
          ]),
          {
            'role': 'assistant',
            'content': 'answer',
            'reasoning_content': 'thought',
          },
        ],
        tools: const [],
        mcpToolNames: const {},
        images: const [],
      );
      expect(preview.systemText, 'base prompt');
      expect(
        preview.worldBookText,
        'before lore\n\nafter loreuser loreassistant lore',
      );
      expect(preview.memoryText, '\n\nmemory rulespersonal facts\n');
      expect(preview.historyText, 'questionanswerthought');
      expect(preview.injectionsText, '\n\ncustom instruction');
      expect(preview.skillsText, '\n\navailable skills');
      expect(preview.workspaceText, '\n\nworkspace rules');
      expect(preview.searchText, '\n\nsearch rules');
    },
  );

  test(
    'only exposed MCP schemas enter MCP bucket; tool results stay in history',
    () {
      const builtIn = {
        'type': 'function',
        'function': {'name': 'shell'},
      };
      const remote = {
        'type': 'function',
        'function': {'name': 'external_shell'},
      };
      final preview = ContextAssemblyPreview.fromApiMessages(
        apiMessages: [
          {
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call',
                'function': {'name': 'external_shell'},
              },
            ],
          },
          {'role': 'tool', 'content': 'tool result'},
        ],
        tools: const [builtIn, remote],
        mcpToolNames: const {'external_shell', 'disabled_tool'},
        images: const [],
      );
      final estimate = estimateContextBuckets(
        ContextEstimateJob(preview: preview, kind: ProviderKind.openai),
      );
      expect(preview.tools, [builtIn]);
      expect(preview.mcpTools, [remote]);
      expect(estimate.tools, estimateToolsTokens([builtIn]));
      expect(estimate.mcpTools, estimateToolsTokens([remote]));
      expect(preview.historyText, contains('external_shell'));
      expect(preview.historyText, contains('tool result'));
      expect(estimate.history, greaterThan(0));
    },
  );

  test(
    'all categories participate in totals and calibration without negatives',
    () {
      const estimated = ContextUsageBuckets(
        system: 1,
        injections: 1,
        history: 1,
        tools: 1,
        attachments: 1,
        memory: 1,
        worldBook: 1,
        skills: 1,
        workspace: 1,
        search: 1,
        mcpTools: 1,
        draft: 7,
      );
      expect(estimated.nonDraftTotal, 11);
      expect(estimated.total, 18);
      for (var total = 0; total <= 25; total++) {
        final calibrated = calibrateContextUsageBuckets(
          estimated: estimated,
          anchorTotal: total,
        )!;
        expect(calibrated.nonDraftTotal, total);
        expect(calibrated.draft, 7);
        expect([
          calibrated.system,
          calibrated.injections,
          calibrated.history,
          calibrated.tools,
          calibrated.attachments,
          calibrated.memory,
          calibrated.worldBook,
          calibrated.skills,
          calibrated.workspace,
          calibrated.search,
          calibrated.mcpTools,
        ], everyElement(greaterThanOrEqualTo(0)));
      }
    },
  );
}

import 'package:Kelivo/core/models/native_compaction.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/api/request_history_context.dart';
import 'package:Kelivo/core/services/api/request_token_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native replay metadata does not change the input estimate', () {
    final user = {'role': 'user', 'content': 'the same user text'};
    int estimate(Map item) => estimateRequestInput({
      'input': [item],
    }, ProviderKind.openai);

    expect(estimate({...user, historySourceKey: 'original'}), estimate(user));
    expect(
      estimate({
        ...user,
        historySourceKey: 'compacted',
        nativeCompactionWireKey: true,
      }),
      estimate(user),
    );
  });

  test('tool provenance is excluded only where the wire removes it', () {
    Map<String, dynamic> body({required bool tagged, bool native = false}) => {
      'input': [
        {
          'role': 'user',
          if (native) nativeCompactionWireKey: true,
          'content': [
            {
              'type': 'input_text',
              'text': 'tool result',
              if (tagged) toolSourceKey: 'tool-call-provenance',
            },
          ],
        },
      ],
    };
    final plain = estimateRequestInput(
      body(tagged: false),
      ProviderKind.openai,
    );
    expect(
      estimateRequestInput(body(tagged: true), ProviderKind.openai),
      plain,
    );
    // Canonical provider content is passed through, including nested fields
    // that happen to share a local metadata name.
    expect(
      estimateRequestInput(
        body(tagged: true, native: true),
        ProviderKind.openai,
      ),
      greaterThan(plain),
    );
  });
}

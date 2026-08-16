import 'package:Kelivo/core/models/token_usage.dart';
import 'package:Kelivo/core/services/api/stream/stream_chunk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ReasoningDelta carries Kelivo-specific details snapshot', () {
    const details = <Map<String, String>>[
      {'type': 'reasoning.text', 'text': 'sig'},
    ];
    const chunk = ReasoningDelta(
      id: 'r1',
      text: 'think',
      details: details,
      reasoningType: ReasoningType.summaryText,
    );

    expect(chunk.id, 'r1');
    expect(chunk.text, 'think');
    expect(chunk.details, same(details));
    expect(chunk.reasoningType, ReasoningType.summaryText);
  });

  test('ImageSnapshot is a distinct replace event', () {
    const snapshot = ImageSnapshot(id: 'img', data: 'abc');
    const delta = ImageDelta(id: 'img', data: 'abc');

    expect(snapshot, isA<ImageSnapshot>());
    expect(snapshot, isNot(isA<ImageDelta>()));
    expect(delta.data, snapshot.data);
  });

  test('Usage and Finish carry token totals and terminal metadata', () {
    const usage = Usage(
      TokenUsage(promptTokens: 3, completionTokens: 5, totalTokens: 8),
    );
    const finish = Finish(
      finishReason: 'stop',
      responseId: 'resp_1',
      model: 'test-model',
    );

    expect(usage.usage.totalTokens, 8);
    expect(finish.finishReason, 'stop');
    expect(finish.responseId, 'resp_1');
    expect(finish.model, 'test-model');
  });
}

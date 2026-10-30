import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/chat/utils/reasoning_preview.dart';

void main() {
  test('uses the newest fragment from concatenated summary updates', () {
    expect(
      latestReasoningPreview('**Planning**Checking constraints**'),
      'Checking constraints',
    );
  });

  test('uses the last non-empty line or sentence', () {
    expect(latestReasoningPreview('first step\nsecond step'), 'second step');
    expect(latestReasoningPreview('first step. second step.'), 'second step');
  });

  test('trims a long preview from the current tail', () {
    final preview = latestReasoningPreview(
      'A very long accumulated reasoning summary that keeps growing',
      maxCharacters: 24,
    );
    expect(preview, startsWith('…'));
    expect(preview, endsWith('keeps growing'));
  });
}

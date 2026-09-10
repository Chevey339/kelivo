import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/memory/memory_prompts.dart';

void main() {
  test(
    'default memory contract is preserved when all operations are available',
    () {
      for (final lang in MemoryPromptLang.values) {
        final prompt = MemoryPrompts.rulesFor(lang);
        expect(
          MemoryPrompts.forAvailableTools(prompt, lang, {
            'memory_search_profile',
            'memory_update',
            'memory_edit',
            'memory_delete',
          }),
          prompt,
        );
      }
    },
  );
  test('custom memory instructions are not rewritten', () {
    expect(
      MemoryPrompts.forAvailableTools(
        'custom memory_update instructions',
        MemoryPromptLang.en,
        {},
      ),
      'custom memory_update instructions',
    );
  });
}

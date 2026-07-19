import 'package:Kelivo/core/services/instruction_injection_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/business_preferences_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleting the last instruction stays empty after reopen', () async {
    final fixture = await BusinessPreferencesTestHarness.create();
    addTearDown(fixture.dispose);

    final first = await fixture.open();
    final store = InstructionInjectionStore(first.preferences);
    final initiallySeeded = await store.getAll();
    expect(initiallySeeded, hasLength(1));

    await store.delete(initiallySeeded.single.id);
    expect(await store.getAll(), isEmpty);
    await first.close();

    final reopened = await fixture.open();
    final restored = InstructionInjectionStore(reopened.preferences);
    expect(await restored.getAll(), isEmpty);
  });

  test(
    'clearing instructions and active mappings stays empty after reopen',
    () async {
      final fixture = await BusinessPreferencesTestHarness.create();
      addTearDown(fixture.dispose);

      final first = await fixture.open();
      final store = InstructionInjectionStore(first.preferences);
      final initiallySeeded = await store.getAll();
      await store.setActiveIds(<String>[
        initiallySeeded.single.id,
      ], assistantId: 'assistant-a');

      await store.clear();
      expect(await store.getAll(), isEmpty);
      expect(await store.getActiveIds(assistantId: 'assistant-a'), isEmpty);
      await first.close();

      final reopened = await fixture.open();
      final restored = InstructionInjectionStore(reopened.preferences);
      expect(await restored.getAll(), isEmpty);
      expect(await restored.getActiveIds(assistantId: 'assistant-a'), isEmpty);
    },
  );
}

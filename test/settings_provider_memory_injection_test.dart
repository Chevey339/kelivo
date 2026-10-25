import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';

import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'full injection defaults to empty and persists an immutable selection',
    () async {
      final storage = await createBusinessTestHarness();
      final settings = SettingsProvider(storage.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.memoryFullInjectionTypes, isEmpty);

      final selected = {MemoryType.instruction, MemoryType.voice};
      await settings.setMemoryFullInjectionTypes(selected);
      selected.clear();
      expect(settings.memoryFullInjectionTypes, {
        MemoryType.voice,
        MemoryType.instruction,
      });
      expect(
        () => settings.memoryFullInjectionTypes.clear(),
        throwsUnsupportedError,
      );
      expect(
        storage.preferences.getStringList('memory_full_injection_types_v1'),
        ['voice', 'instruction'],
      );

      final reloaded = SettingsProvider(
        BusinessPreferences(storage.repository),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(
        reloaded.memoryFullInjectionTypes,
        settings.memoryFullInjectionTypes,
      );

      final copy = settings.copyWith();
      addTearDown(copy.dispose);
      await settings.setMemoryFullInjectionTypes({});
      expect(copy.memoryFullInjectionTypes, {
        MemoryType.voice,
        MemoryType.instruction,
      });
      expect(
        storage.preferences.getStringList('memory_full_injection_types_v1'),
        isEmpty,
      );
    },
  );

  test(
    'selection order is canonical and unchanged selections do not notify',
    () async {
      final storage = await createBusinessTestHarness(
        initial: {
          'memory_full_injection_types_v1': [
            'instruction',
            'unknown',
            'voice',
            'voice',
          ],
        },
      );
      final settings = SettingsProvider(storage.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      expect(settings.memoryFullInjectionTypes.toList(), [
        MemoryType.voice,
        MemoryType.instruction,
      ]);
      var notifications = 0;
      settings.addListener(() => notifications++);
      await settings.setMemoryFullInjectionTypes({
        MemoryType.instruction,
        MemoryType.voice,
      });
      expect(notifications, 0);
      await settings.setMemoryFullInjectionTypes({MemoryType.voice});
      expect(notifications, 1);
    },
  );

  test('full injection selection survives backup export and restore', () async {
    final source = await createBusinessTestHarness();
    final settings = SettingsProvider(source.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;
    await settings.setMemoryInjectionMaxItems(3);
    await settings.setMemoryFullInjectionTypes({
      MemoryType.voice,
      MemoryType.workflow,
    });

    final exported = BusinessSettingsRouter.exportSnapshot(
      await source.repository.readSnapshot(),
    );
    BackupSettingsValidator.normalizeAndValidate(exported);
    final restored = await createBusinessTestHarness(initial: exported);
    final restoredSettings = SettingsProvider(restored.preferences);
    addTearDown(restoredSettings.dispose);
    await restoredSettings.loaded;
    expect(restoredSettings.memoryFullInjectionTypes, {
      MemoryType.workflow,
      MemoryType.voice,
    });
    expect(restoredSettings.memoryInjectionMaxItems, 3);
  });
}

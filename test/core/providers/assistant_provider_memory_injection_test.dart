import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/memory_entry.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/backup/backup_settings_validator.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'full injection selections persist independently for each assistant',
    () async {
      final storage = await createBusinessTestHarness(
        initial: {
          'memory_full_injection_types_v1': ['voice'],
          'assistants_v1': Assistant.encodeList([
            const Assistant(id: 'a', name: 'A'),
            const Assistant(id: 'b', name: 'B'),
          ]),
        },
      );
      final assistants = AssistantProvider(preferences: storage.preferences);
      addTearDown(assistants.dispose);
      await assistants.loaded;
      expect(assistants.getById('a')!.memoryFullInjectionTypes, isEmpty);
      await assistants.updateAssistant(
        assistants
            .getById('a')!
            .copyWith(
              memoryFullInjectionTypes: {MemoryType.voice, MemoryType.identity},
            ),
      );
      await assistants.updateAssistant(
        assistants
            .getById('b')!
            .copyWith(
              memoryFullInjectionTypes: {
                MemoryType.workflow,
                MemoryType.instruction,
              },
            ),
      );
      await assistants.updateAssistant(
        assistants.getById('a')!.copyWith(memoryFullInjectionTypes: {}),
      );

      final reloaded = AssistantProvider(
        preferences: BusinessPreferences(storage.repository),
      );
      addTearDown(reloaded.dispose);
      await reloaded.loaded;
      expect(reloaded.getById('a')!.memoryFullInjectionTypes, isEmpty);
      expect(reloaded.getById('b')!.memoryFullInjectionTypes, {
        MemoryType.workflow,
        MemoryType.instruction,
      });
    },
  );

  test(
    'assistant selections and global item limit survive backup restore',
    () async {
      final source = await createBusinessTestHarness(
        initial: {
          'assistants_v1': Assistant.encodeList([
            const Assistant(
              id: 'a',
              name: 'A',
              memoryFullInjectionTypes: {MemoryType.voice},
            ),
            const Assistant(
              id: 'b',
              name: 'B',
              memoryFullInjectionTypes: {MemoryType.workflow},
            ),
          ]),
        },
      );
      final settings = SettingsProvider(source.preferences);
      addTearDown(settings.dispose);
      await settings.loaded;
      await settings.setMemoryInjectionMaxItems(3);
      final exported = BusinessSettingsRouter.exportSnapshot(
        await source.repository.readSnapshot(),
      );
      BackupSettingsValidator.normalizeAndValidate(exported);
      final restored = await createBusinessTestHarness(initial: exported);
      final assistants = AssistantProvider(preferences: restored.preferences);
      final restoredSettings = SettingsProvider(restored.preferences);
      addTearDown(assistants.dispose);
      addTearDown(restoredSettings.dispose);
      await Future.wait([assistants.loaded, restoredSettings.loaded]);
      expect(assistants.getById('a')!.memoryFullInjectionTypes, {
        MemoryType.voice,
      });
      expect(assistants.getById('b')!.memoryFullInjectionTypes, {
        MemoryType.workflow,
      });
      expect(restoredSettings.memoryInjectionMaxItems, 3);
      expect(exported.containsKey('memory_full_injection_types_v1'), isFalse);
    },
  );
}

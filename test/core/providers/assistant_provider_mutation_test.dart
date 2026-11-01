import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';

import '../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late BusinessTestHarness harness;
  late AssistantProvider provider;

  setUp(() async {
    harness = await createBusinessTestHarness(
      initial: {
        'assistants_v1': Assistant.encodeList([
          const Assistant(id: 'a', name: 'Original'),
          const Assistant(id: 'b', name: 'Other'),
        ]),
      },
    );
    provider = AssistantProvider(preferences: harness.preferences);
    await provider.loaded;
    addTearDown(provider.dispose);
  });

  Future<void> expectDurableState() async {
    final reloaded = BusinessPreferences(harness.repository);
    await reloaded.load();
    expect(
      reloaded.getString('assistants_v1'),
      Assistant.encodeList(provider.assistants),
    );
  }

  test(
    'consecutive reread edits preserve both fields before persistence finishes',
    () async {
      final search = provider.updateAssistant(
        provider.getById('a')!.copyWith(searchEnabled: true),
      );
      final rename = provider.updateAssistant(
        provider.getById('a')!.copyWith(name: 'Renamed'),
      );
      expect(provider.getById('a')!.searchEnabled, isTrue);
      expect(provider.getById('a')!.name, 'Renamed');
      await Future.wait([search, rename]);
      await expectDurableState();
    },
  );

  test(
    'edits made during a pending SQLite write retain earlier changes',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = harness.database.transaction(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final temperature = provider.updateAssistant(
        provider.getById('a')!.copyWith(temperature: 0.25),
      );
      await pumpEventQueue();
      final rename = provider.updateAssistant(
        provider.getById('a')!.copyWith(name: 'Renamed'),
      );
      await pumpEventQueue();
      final search = provider.updateAssistant(
        provider.getById('a')!.copyWith(searchEnabled: true),
      );
      release.complete();
      await held;
      await Future.wait([temperature, rename, search]);
      expect(provider.getById('a')!.temperature, 0.25);
      expect(provider.getById('a')!.name, 'Renamed');
      expect(provider.getById('a')!.searchEnabled, isTrue);
      await expectDurableState();
    },
  );

  test(
    'edits during a copy commit retain both the edits and the new assistant',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = harness.database.transaction(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final copy = provider.duplicateAssistant('a');
      await pumpEventQueue();
      final rename = provider.updateAssistant(
        provider.getById('a')!.copyWith(name: 'Renamed'),
      );
      final search = provider.updateAssistant(
        provider.getById('a')!.copyWith(searchEnabled: true),
      );
      release.complete();
      await held;
      final id = await copy;
      await Future.wait([rename, search]);
      expect(id, isNotNull);
      expect(provider.getById(id!)!.name, 'Original Copy');
      expect(provider.getById('a')!.name, 'Renamed');
      expect(provider.getById('a')!.searchEnabled, isTrue);
      expect(provider.assistants, hasLength(3));
      await expectDurableState();
    },
  );

  test(
    'deleting the source during a copy commit still retains the committed copy',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = harness.database.transaction(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final copy = provider.duplicateAssistant('a');
      await pumpEventQueue();
      final deletion = provider.deleteAssistant('a');
      await pumpEventQueue();
      expect(provider.getById('a'), isNull);
      release.complete();
      await held;
      final id = await copy;
      expect(await deletion, isTrue);
      expect(id, isNotNull);
      expect(provider.getById(id!), isNotNull);
      expect(provider.getById('a'), isNull);
      expect(provider.assistants, hasLength(2));
      await expectDurableState();
    },
  );

  test(
    'source deletion before the copy transaction starts creates no copy',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = harness.preferences.runExclusiveMutation(() async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final copy = provider.duplicateAssistant('a');
      await pumpEventQueue();
      final deletion = provider.deleteAssistant('a');
      await pumpEventQueue();
      expect(provider.getById('a'), isNull);
      release.complete();
      await held;
      expect(await copy, isNull);
      expect(await deletion, isTrue);
      expect(provider.assistants.single.id, 'b');
      await expectDurableState();
    },
  );
}

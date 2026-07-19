import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/assistant_provider.dart';

import '../../support/business_preferences_test_harness.dart';

Future<AssistantProvider> _createLoadedAssistantProvider({
  required BusinessPreferencesTestSession session,
  required List<Map<String, Object?>> assistants,
  String currentAssistantId = 'assistant-a',
  bool? legacySearchEnabled,
}) async {
  await session.preferences.setString('assistants_v1', jsonEncode(assistants));
  await session.preferences.setString(
    'current_assistant_id_v1',
    currentAssistantId,
  );
  if (legacySearchEnabled != null) {
    await session.preferences.setBool('search_enabled_v1', legacySearchEnabled);
  }

  final provider = AssistantProvider(preferences: session.preferences);
  for (var i = 0; i < 25; i++) {
    if (provider.assistants.length == assistants.length) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BusinessPreferencesTestHarness harness;
  late BusinessPreferencesTestSession session;

  setUp(() async {
    harness = await BusinessPreferencesTestHarness.create();
    session = await harness.open();
  });

  tearDown(() => harness.dispose());

  group('AssistantProvider per-assistant search', () {
    test('does not apply the legacy global preference at runtime', () async {
      final provider = await _createLoadedAssistantProvider(
        session: session,
        legacySearchEnabled: true,
        assistants: const [
          {'id': 'assistant-a', 'name': 'A'},
          {'id': 'assistant-b', 'name': 'B'},
        ],
      );

      expect(provider.assistants.map((a) => a.searchEnabled), [
        isFalse,
        isFalse,
      ]);
    });

    test(
      'keeps explicit assistant search values without consulting legacy state',
      () async {
        final provider = await _createLoadedAssistantProvider(
          session: session,
          legacySearchEnabled: true,
          assistants: const [
            {'id': 'assistant-a', 'name': 'A', 'searchEnabled': false},
            {'id': 'assistant-b', 'name': 'B'},
          ],
        );

        expect(provider.getById('assistant-a')?.searchEnabled, isFalse);
        expect(provider.getById('assistant-b')?.searchEnabled, isFalse);
      },
    );

    test('updates only the current assistant search value', () async {
      final provider = await _createLoadedAssistantProvider(
        session: session,
        assistants: const [
          {'id': 'assistant-a', 'name': 'A'},
          {'id': 'assistant-b', 'name': 'B'},
        ],
      );

      await provider.setSearchEnabledForCurrentAssistant(true);

      expect(provider.getById('assistant-a')?.searchEnabled, isTrue);
      expect(provider.getById('assistant-b')?.searchEnabled, isFalse);

      await provider.setCurrentAssistant('assistant-b');

      expect(provider.currentSearchEnabled, isFalse);
    });
  });
}

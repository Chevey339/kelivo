import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/providers/assistant_provider.dart';

const _assistantsKey = 'assistants_v1';
const _currentAssistantKey = 'current_assistant_id_v1';

Future<AssistantProvider> _createProviderWithLoadedAssistants(
  List<Map<String, Object?>> assistants, {
  String? currentAssistantId,
}) async {
  SharedPreferences.setMockInitialValues({
    _assistantsKey: jsonEncode(assistants),
    if (currentAssistantId != null) _currentAssistantKey: currentAssistantId,
  });
  final provider = AssistantProvider();
  for (var i = 0; i < 25; i++) {
    if (provider.assistants.length == assistants.length) return provider;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assistant deletable field migration', () {
    test('does not export deletable in assistant JSON', () {
      const assistant = Assistant(id: 'assistant-1', name: 'Assistant 1');

      expect(assistant.toJson(), isNot(contains('deletable')));
      expect(
        Assistant.encodeList(const [assistant]),
        isNot(contains('deletable')),
      );
    });

    test('ignores legacy deletable field and persists without it', () async {
      final provider = await _createProviderWithLoadedAssistants(const [
        {'id': 'legacy-default', 'name': 'Legacy Default', 'deletable': false},
        {'id': 'regular', 'name': 'Regular Assistant', 'deletable': true},
      ], currentAssistantId: 'legacy-default');

      expect(provider.assistants.map((a) => a.id), [
        'legacy-default',
        'regular',
      ]);

      expect(await provider.deleteAssistant('legacy-default'), isTrue);
      expect(provider.currentAssistantId, 'regular');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_assistantsKey), isNot(contains('deletable')));
    });

    test(
      'keeps the last remaining assistant undeletable by count only',
      () async {
        final provider = await _createProviderWithLoadedAssistants(const [
          {'id': 'only-assistant', 'name': 'Only Assistant', 'deletable': true},
        ], currentAssistantId: 'only-assistant');

        expect(await provider.deleteAssistant('only-assistant'), isFalse);
        expect(provider.assistants.map((a) => a.id), ['only-assistant']);
      },
    );
  });
}

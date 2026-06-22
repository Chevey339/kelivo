import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';

void main() {
  group('Assistant proactive care fields', () {
    test('toJson and fromJson round-trip proactive care fields', () {
      final at = DateTime.utc(2026, 6, 12, 9, 30);
      const assistant = Assistant(
        id: 'a1',
        name: 'Test',
        enableProactiveCare: true,
        proactiveCareNextMessageAt: null,
        proactiveCarePrompt: 'care prompt',
        proactiveCareDecisionPrompt: 'decision prompt',
      );
      final withTime = assistant.copyWith(proactiveCareNextMessageAt: at);

      final decoded = Assistant.fromJson(withTime.toJson());
      expect(decoded.enableProactiveCare, isTrue);
      expect(decoded.proactiveCarePrompt, 'care prompt');
      expect(decoded.proactiveCareDecisionPrompt, 'decision prompt');
      expect(decoded.proactiveCareNextMessageAt?.toUtc(), at);
    });

    test('fromJson uses defaults when proactive care fields are missing', () {
      final assistant = Assistant.fromJson(const {
        'id': 'legacy',
        'name': 'Legacy',
      });

      expect(assistant.enableProactiveCare, isFalse);
      expect(assistant.proactiveCareNextMessageAt, isNull);
      expect(assistant.proactiveCarePrompt, '');
      expect(assistant.proactiveCareDecisionPrompt, '');
    });

    test('fromJson ignores invalid proactiveCareNextMessageAt', () {
      final assistant = Assistant.fromJson(const {
        'id': 'legacy',
        'name': 'Legacy',
        'proactiveCareNextMessageAt': 'not-a-date',
      });

      expect(assistant.proactiveCareNextMessageAt, isNull);
    });

    test('copyWith can clear proactiveCareNextMessageAt', () {
      final at = DateTime(2026, 6, 12, 10);
      final assistant = Assistant(
        id: 'a1',
        name: 'Test',
        enableProactiveCare: true,
        proactiveCareNextMessageAt: at,
      );

      final cleared = assistant.copyWith(clearProactiveCareNextMessageAt: true);
      expect(cleared.proactiveCareNextMessageAt, isNull);
      expect(cleared.enableProactiveCare, isTrue);
    });
  });
}

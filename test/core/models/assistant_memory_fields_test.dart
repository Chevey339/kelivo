import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';
import 'package:Kelivo/core/models/memory_entry.dart';

void main() {
  group('Assistant memory fields (§4.1)', () {
    test('defaults match the design doc', () {
      const a = Assistant(id: 'a', name: 'A');
      expect(a.enableMemory, isFalse);
      expect(a.memoryFullInjectionTypes, isEmpty);
      expect(a.autoOrganizeMemory, isFalse);
      expect(a.memoryOrganizeEveryNTurns, 1);
      expect(a.memorySmartAddMode, MemorySmartAddMode.batched);
      expect(a.memoryWriteScope, MemoryWriteScope.alwaysGlobal);
      expect(a.allowPastConversationRecall, isFalse);
      expect(a.generateConversationSummary, isFalse);
      expect(a.appendCurrentTimeToUserMessage, isFalse);
      expect(a.useIso8601TimeFormat, isFalse);
    });

    test('full injection selection survives serialization and copies', () {
      final selected = {MemoryType.instruction, MemoryType.voice};
      const original = Assistant(id: 'a', name: 'A');
      final updated = original.copyWith(memoryFullInjectionTypes: selected);
      selected.clear();
      expect(original.memoryFullInjectionTypes, isEmpty);
      expect(updated.toJson()['memoryFullInjectionTypes'], [
        'voice',
        'instruction',
      ]);
      final restored = Assistant.decodeList(
        Assistant.encodeList([updated]),
      ).single;
      final copy = restored.copyWith(id: 'b');
      expect(copy.memoryFullInjectionTypes, updated.memoryFullInjectionTypes);
      expect(
        () => copy.memoryFullInjectionTypes.clear(),
        throwsUnsupportedError,
      );
      expect(
        copy.copyWith(memoryFullInjectionTypes: {}).memoryFullInjectionTypes,
        isEmpty,
      );
      expect(restored.memoryFullInjectionTypes, {
        MemoryType.voice,
        MemoryType.instruction,
      });
    });

    test('full injection defaults empty and ignores unknown types', () {
      expect(
        Assistant.fromJson({'id': 'a', 'name': 'A'}).memoryFullInjectionTypes,
        isEmpty,
      );
      final assistant = Assistant.fromJson({
        'id': 'a',
        'name': 'A',
        'memoryFullInjectionTypes': [
          'instruction',
          'unknown',
          'voice',
          'voice',
        ],
      });
      expect(assistant.memoryFullInjectionTypes.toList(), [
        MemoryType.voice,
        MemoryType.instruction,
      ]);
      expect(
        () => assistant.memoryFullInjectionTypes.clear(),
        throwsUnsupportedError,
      );
    });

    test('time format defaults off and survives serialization and copies', () {
      final a = Assistant.fromJson({'id': 'a', 'name': 'A'});
      expect(a.useIso8601TimeFormat, isFalse);
      final enabled = a.copyWith(useIso8601TimeFormat: true);
      final restored = Assistant.decodeList(
        Assistant.encodeList([enabled]),
      ).single;
      expect(restored.useIso8601TimeFormat, isTrue);
      expect(restored.copyWith(name: 'B').useIso8601TimeFormat, isTrue);
      expect(
        restored.copyWith(useIso8601TimeFormat: false).useIso8601TimeFormat,
        isFalse,
      );
    });

    test('fromJson maps legacy enableRecentChatsReference', () {
      final a = Assistant.fromJson({
        'id': 'a',
        'name': 'A',
        'enableRecentChatsReference': true,
      });
      expect(a.allowPastConversationRecall, isTrue);
      expect(a.toJson().containsKey('enableRecentChatsReference'), isFalse);
      expect(a.toJson()['allowPastConversationRecall'], isTrue);
    });

    test('explicit allowPastConversationRecall wins over legacy key', () {
      final a = Assistant.fromJson({
        'id': 'a',
        'name': 'A',
        'allowPastConversationRecall': false,
        'enableRecentChatsReference': true,
      });
      expect(a.allowPastConversationRecall, isFalse);
    });

    test('enum wire strings round-trip', () {
      final a = Assistant(
        id: 'a',
        name: 'A',
        memorySmartAddMode: MemorySmartAddMode.perItem,
        memoryWriteScope: MemoryWriteScope.toolDefaultAssistant,
      );
      final json = a.toJson();
      expect(json['memorySmartAddMode'], 'perItem');
      expect(json['memoryWriteScope'], 'toolDefaultAssistant');
      final roundTrip = Assistant.fromJson(json);
      expect(roundTrip.memorySmartAddMode, MemorySmartAddMode.perItem);
      expect(roundTrip.memoryWriteScope, MemoryWriteScope.toolDefaultAssistant);
    });
  });
}

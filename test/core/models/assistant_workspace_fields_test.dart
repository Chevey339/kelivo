import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';

void main() {
  group('Assistant workspace fields', () {
    test('skillIds null means all skills and round-trips', () {
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        defaultWorkspaceId: 'ws-1',
      );
      expect(assistant.skillIds, isNull);
      final json = assistant.toJson();
      expect(json.containsKey('skillIds'), isTrue);
      expect(json['skillIds'], isNull);
      expect(json['defaultWorkspaceId'], 'ws-1');
      final decoded = Assistant.fromJson(json);
      expect(decoded.skillIds, isNull);
      expect(decoded.defaultWorkspaceId, 'ws-1');
    });

    test('skillIds list round-trips', () {
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        skillIds: <String>['skill-1', 'skill-2'],
      );
      final decoded = Assistant.fromJson(assistant.toJson());
      expect(decoded.skillIds, <String>['skill-1', 'skill-2']);
    });

    test('copyWith can clear the new fields', () {
      const assistant = Assistant(
        id: 'a',
        name: 'A',
        defaultWorkspaceId: 'ws-1',
        skillIds: <String>['skill-1'],
      );
      final cleared = assistant.copyWith(
        clearDefaultWorkspaceId: true,
        clearSkillIds: true,
      );
      expect(cleared.defaultWorkspaceId, isNull);
      expect(cleared.skillIds, isNull);
    });
  });
}

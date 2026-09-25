import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/assistant.dart';

void main() {
  group('Assistant workspace fields', () {
    test('new assistants remember once, existing assistants only suggest', () {
      const fresh = Assistant(id: 'new', name: 'New');
      expect(fresh.defaultWorkspaceSetup, DefaultWorkspaceSetup.automatic);
      expect(
        Assistant.fromJson(fresh.toJson()).defaultWorkspaceSetup,
        DefaultWorkspaceSetup.automatic,
      );
      expect(
        Assistant.fromJson({'id': 'old', 'name': 'Old'}).defaultWorkspaceSetup,
        DefaultWorkspaceSetup.suggest,
      );
      expect(
        Assistant.fromJson({
          'id': 'old',
          'name': 'Old',
          'defaultWorkspaceId': 'workspace',
        }).defaultWorkspaceSetup,
        DefaultWorkspaceSetup.completed,
      );
    });

    test('explicitly setting or clearing a default finishes setup', () {
      const fresh = Assistant(id: 'new', name: 'New');
      for (final configured in [
        fresh.copyWith(defaultWorkspaceId: 'workspace'),
        fresh.copyWith(clearDefaultWorkspaceId: true),
      ]) {
        expect(
          Assistant.fromJson(configured.toJson()).defaultWorkspaceSetup,
          DefaultWorkspaceSetup.completed,
        );
      }
      expect(
        fresh.copyWith(name: 'Renamed').defaultWorkspaceSetup,
        DefaultWorkspaceSetup.automatic,
      );
    });

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

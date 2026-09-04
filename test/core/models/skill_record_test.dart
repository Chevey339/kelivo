import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skill_record.dart';

void main() {
  group('SkillRecord', () {
    test('JSON round trip', () {
      final record = SkillRecord(
        id: 'skill-1',
        enabled: false,
        useCount: 4,
        source: SkillSource.github,
        installedAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 2),
      );
      final decoded = SkillRecord.fromJson(record.toJson());
      expect(decoded.id, record.id);
      expect(decoded.enabled, record.enabled);
      expect(decoded.useCount, record.useCount);
      expect(decoded.source, SkillSource.github);
      expect(decoded.installedAt, record.installedAt);
      expect(decoded.updatedAt, record.updatedAt);
    });

    test('fromJson defaults optional fields', () {
      final record = SkillRecord.fromJson({
        'id': 'skill-2',
        'source': 'paste',
        'installedAt': '2026-09-01T00:00:00.000Z',
        'updatedAt': '2026-09-02T00:00:00.000Z',
      });
      expect(record.enabled, isTrue);
      expect(record.useCount, 0);
      expect(record.source, SkillSource.paste);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/skills_binding.dart';

void main() {
  test('round-trips a concrete override', () {
    const binding = SkillsBinding(skillIds: ['pdf-tools', 'git']);
    final extras = binding.applyTo({'keep': true});
    expect(extras[SkillsBinding.keyIds], ['pdf-tools', 'git']);
    expect(extras['keep'], isTrue);
    final read = SkillsBinding.fromExtras(extras);
    expect(read.skillIds, ['pdf-tools', 'git']);
  });

  test('null skillIds inherits and removes the key', () {
    final extras = const SkillsBinding().applyTo({
      SkillsBinding.keyIds: ['old'],
      'keep': 1,
    });
    expect(extras.containsKey(SkillsBinding.keyIds), isFalse);
    expect(extras['keep'], 1);
    expect(SkillsBinding.fromExtras(extras).skillIds, isNull);
  });

  test('empty list is a stored override', () {
    final extras = const SkillsBinding(skillIds: []).applyTo({});
    expect(extras[SkillsBinding.keyIds], isEmpty);
    expect(SkillsBinding.fromExtras(extras).skillIds, isEmpty);
  });

  test('missing extras key inherits', () {
    expect(SkillsBinding.fromExtras(const {}).skillIds, isNull);
  });
}

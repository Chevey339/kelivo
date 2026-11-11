import 'package:Kelivo/features/intelligent_ui/catalog/ui_guidance.dart';
import '../../../utils/utf16_safe_cut.dart';
import '../../models/skill_record.dart';
import 'skill.dart';

const int kAvailableSkillsCap = 20;
const int kAvailableSkillsDescriptionChars = 200;

/// [skills] has already passed enabled/assistant/conversation filtering. Explicit
/// selections affect visibility within the cap, never bypass that filtering.
String buildAvailableSkillsFragment(
  List<Skill> skills, {
  required String skillsModelRoot,
  Iterable<String> selectedSkillIds = const [],
}) {
  final selected = selectedSkillIds.toSet();
  bool visualize(Skill skill) =>
      skill.record.id == 'visualize' &&
      skill.record.source == SkillSource.bundled;
  int priority(Skill skill) => visualize(skill)
      ? 0
      : selected.contains(skill.record.id)
      ? 1
      : 2;
  final ordered = List<Skill>.from(skills)
    ..sort((a, b) {
      final byPriority = priority(a).compareTo(priority(b));
      if (byPriority != 0) return byPriority;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.record.id.compareTo(b.record.id);
    });
  final visible = ordered.take(kAvailableSkillsCap);
  final overflow = ordered
      .skip(kAvailableSkillsCap)
      .where((s) => selected.contains(s.record.id));
  final root = skillsModelRoot.endsWith('/')
      ? skillsModelRoot.substring(0, skillsModelRoot.length - 1)
      : skillsModelRoot;
  final buf = StringBuffer()
    ..writeln('<available_skills>')
    ..writeln(
      'Use a skill when the task matches its description: call read_file on '
      'its SKILL.md first and follow it. Files referenced by a skill live in '
      'the same directory.',
    );
  if (ordered.any(visualize)) {
    buf.writeln(UiGuidance.capabilitySummary);
  }
  for (final skill in visible) {
    final description = truncateHeadUtf16Safe(
      skill.description,
      kAvailableSkillsDescriptionChars,
    );
    buf.writeln(
      '- ${skill.record.id} — $description ($root/${skill.record.id}/SKILL.md)',
    );
  }
  if (overflow.isNotEmpty) {
    buf.writeln(
      'Additional explicitly selected skills remain readable with read_file:',
    );
    for (final skill in overflow) {
      buf.writeln('  ${skill.record.id}: $root/${skill.record.id}/SKILL.md');
    }
  }
  buf.write('</available_skills>');
  return buf.toString();
}

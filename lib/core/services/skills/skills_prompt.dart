import '../../../utils/utf16_safe_cut.dart';
import 'skill.dart';

const int kAvailableSkillsCap = 20;
const int kAvailableSkillsDescriptionChars = 200;

/// Prompt block listing installed skills the model may `read_file`.
String buildAvailableSkillsFragment(
  List<Skill> skills, {
  required String skillsModelRoot,
}) {
  final ordered = List<Skill>.from(skills)
    ..sort((a, b) {
      final byUse = b.record.useCount.compareTo(a.record.useCount);
      if (byUse != 0) return byUse;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  if (ordered.length > kAvailableSkillsCap) {
    ordered.removeRange(kAvailableSkillsCap, ordered.length);
  }

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
  for (final skill in ordered) {
    final description = truncateHeadUtf16Safe(
      skill.description,
      kAvailableSkillsDescriptionChars,
    );
    buf.writeln(
      '- ${skill.record.id} — $description ($root/${skill.record.id}/SKILL.md)',
    );
  }
  buf.write('</available_skills>');
  return buf.toString();
}

import '../../models/skill_record.dart';

class Skill {
  const Skill({
    required this.record,
    required this.name,
    required this.description,
    required this.dir,
    required this.skillMdPath,
  });

  final SkillRecord record;
  final String name;
  final String description;
  final String dir;
  final String skillMdPath;
}

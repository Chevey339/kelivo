class SkillPaths {
  SkillPaths._();

  static final RegExp _validNamePattern = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

  static const int maxNameLength = 64;
  static const int maxDescriptionLength = 1024;

  static String? validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Skill name cannot be empty';
    if (trimmed.length > maxNameLength) {
      return 'Skill name must be at most $maxNameLength characters';
    }
    if (!_validNamePattern.hasMatch(trimmed)) {
      return 'Skill name must contain only lowercase letters, digits, '
          'and hyphens, and must not start or end with a hyphen';
    }
    return null;
  }

  static String? validateDescription(String description) {
    if (description.trim().isEmpty) return 'Skill description cannot be empty';
    if (description.length > maxDescriptionLength) {
      return 'Skill description must be at most $maxDescriptionLength characters';
    }
    return null;
  }

  static bool isNameSafe(String name) {
    if (name.trim().isEmpty) return false;
    if (name.contains('/') || name.contains('\\')) return false;
    if (name.contains('..')) return false;
    if (name.startsWith('.') || name.endsWith('.')) return false;
    if (name.contains(' ')) return false;
    return true;
  }

  static String skillDirPath(String skillsRoot, String name) {
    return '${skillsRoot.replaceAll('\\', '/')}/$name';
  }

  static String skillFilePath(String skillsRoot, String name) {
    return '${skillDirPath(skillsRoot, name)}/SKILL.md';
  }
}

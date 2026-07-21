import 'dart:io';
import 'package:path/path.dart' as p;
import '../../utils/app_directories.dart';
import 'skill_paths.dart';

class SkillMetadata {
  final String name;
  final String description;
  final String body;

  const SkillMetadata({
    required this.name,
    required this.description,
    required this.body,
  });
}

class FrontmatterResult {
  final Map<String, String> fields;
  final String body;
  const FrontmatterResult({required this.fields, required this.body});
}

class SkillSaveError {
  final String code;
  final Map<String, String> params;
  const SkillSaveError(this.code, [this.params = const {}]);
}

class SkillManager {
  SkillManager._();

  static FrontmatterResult? parseFrontmatter(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('---')) return null;

    final endIndex = trimmed.indexOf('---', 3);
    if (endIndex == -1) return null;

    final raw = trimmed.substring(3, endIndex).trim();
    final body = trimmed.substring(endIndex + 3).trim();

    final fields = <String, String>{};
    for (final line in raw.split('\n')) {
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final key = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      if (key.isNotEmpty) {
        fields[key] = value;
      }
    }

    return FrontmatterResult(fields: fields, body: body);
  }

  static Future<String?> _readFileContent(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  static String? _skillsRoot;

  static Future<String> _getSkillsRoot() async {
    if (_skillsRoot != null) return _skillsRoot!;
    final dir = await AppDirectories.getSkillsDirectory();
    _skillsRoot = dir.path;
    return _skillsRoot!;
  }

  static Future<void> _ensureSkillsDir() async {
    final dir = await AppDirectories.getSkillsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  static String? _dirNameFor(String name) {
    final safe = SkillPaths.isNameSafe(name) ? name.trim() : null;
    return safe;
  }

  static Future<List<SkillMetadata>> listSkills() async {
    final root = _skillsRoot;
    if (root == null) return [];

    final dir = Directory(root);
    if (!await dir.exists()) return [];

    final skills = <SkillMetadata>[];
    final entries = dir.listSync(followLinks: false);
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final name = p.basename(entry.path);
      if (!SkillPaths.isNameSafe(name)) continue;

      final skillFile = File(p.join(entry.path, 'SKILL.md'));

      final content = await _readFileContent(skillFile.path);
      if (content == null) continue;

      final parsed = parseFrontmatter(content);
      if (parsed == null) continue;

      final skillName = parsed.fields['name'] ?? name;
      final description = parsed.fields['description'] ?? '';
      skills.add(
        SkillMetadata(
          name: skillName,
          description: description,
          body: parsed.body,
        ),
      );
    }
    return skills;
  }

  static Future<SkillMetadata?> readSkill(String name) async {
    final dirName = _dirNameFor(name);
    if (dirName == null) return null;

    final root = _skillsRoot;
    if (root == null) return null;

    final filePath = SkillPaths.skillFilePath(root, dirName);
    final content = await _readFileContent(filePath);
    if (content == null) return null;

    final parsed = parseFrontmatter(content);
    if (parsed == null) return null;

    final skillName = parsed.fields['name'] ?? name;
    final description = parsed.fields['description'] ?? '';
    return SkillMetadata(
      name: skillName,
      description: description,
      body: parsed.body,
    );
  }

  static Future<String?> readSkillBody(String name) async {
    final meta = await readSkill(name);
    return meta?.body;
  }

  static Future<SkillMetadata?> readSkillMetadata(String name) async {
    return readSkill(name);
  }

  static Future<bool> skillExists(String name) async {
    final dirName = _dirNameFor(name);
    if (dirName == null) return false;
    final root = _skillsRoot;
    if (root == null) return false;
    return File(SkillPaths.skillFilePath(root, dirName)).exists();
  }

  static Future<SkillSaveError?> saveSkill({
    required String name,
    required String content,
  }) async {
    final nameError = SkillPaths.validateName(name);
    if (nameError != null) {
      return SkillSaveError('name_invalid', {'detail': nameError});
    }

    await _ensureSkillsDir();
    final root = await _getSkillsRoot();

    final parsed = parseFrontmatter(content);
    if (parsed == null) {
      return const SkillSaveError('invalid_frontmatter');
    }

    final skillName = parsed.fields['name'] ?? '';
    if (skillName.isEmpty) {
      return const SkillSaveError('name_missing');
    }
    if (skillName != name) {
      return SkillSaveError('name_mismatch', {
        'frontmatterName': skillName,
        'dirName': name,
      });
    }
    final desc = parsed.fields['description'] ?? '';
    final descError = SkillPaths.validateDescription(desc);
    if (descError != null) {
      return SkillSaveError('io_error', {'detail': descError});
    }

    final dirPath = SkillPaths.skillDirPath(root, name);

    // Atomic write: staging → backup → target → cleanup
    final tmpId = DateTime.now().microsecondsSinceEpoch;
    final stagingDir = Directory('$dirPath.staging.$tmpId.tmp');
    final targetDir = Directory(dirPath);

    try {
      // Create staging
      await stagingDir.create(recursive: true);
      await File(
        p.join(stagingDir.path, 'SKILL.md'),
      ).writeAsString(content, flush: true);

      // Verify staging has SKILL.md
      if (!await File(p.join(stagingDir.path, 'SKILL.md')).exists()) {
        await _deleteDirQuietly(stagingDir);
        return const SkillSaveError('io_error', {
          'detail': 'Failed to write SKILL.md to staging',
        });
      }

      // If target exists, rename to backup
      Directory? backupDir;
      if (await targetDir.exists()) {
        final backupPath = '$dirPath.backup.$tmpId.tmp';
        await targetDir.rename(backupPath);
        backupDir = Directory(backupPath);
      }

      // Rename staging → target
      try {
        await stagingDir.rename(dirPath);
      } catch (e) {
        // Rename failed, restore backup
        if (backupDir != null && await backupDir.exists()) {
          await backupDir.rename(dirPath);
        }
        await _deleteDirQuietly(stagingDir);
        return SkillSaveError('io_error', {
          'detail': 'Failed to finalize skill directory: $e',
        });
      }

      // Cleanup backup
      if (backupDir != null) {
        await _deleteDirQuietly(backupDir);
      }
    } catch (e) {
      await _deleteDirQuietly(stagingDir);
      return SkillSaveError('io_error', {'detail': 'Failed to save skill: $e'});
    }

    return null; // success
  }

  static Future<void> deleteSkill(String name) async {
    final dirName = _dirNameFor(name);
    if (dirName == null) return;

    final root = _skillsRoot;
    if (root == null) return;

    final dir = Directory(SkillPaths.skillDirPath(root, dirName));
    if (await dir.exists()) {
      await _deleteDirQuietly(dir);
    }
  }

  static Future<void> _deleteDirQuietly(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  static Future<void> initRoot() async {
    if (_skillsRoot != null) return;
    try {
      final dir = await AppDirectories.getSkillsDirectory();
      _skillsRoot = dir.path;
    } catch (_) {}
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'skill_models.dart';
import 'skill_parser.dart';
import 'bundled_skills_data.dart';

/// Outcome of a skill import operation.
///
/// On success [success] is `true` and [meta] carries the registered
/// [SkillMeta]. On failure [success] is `false`, [meta] is `null`, and [error]
/// holds a concrete, user-facing message describing what went wrong.
class SkillImportResult {
  final SkillMeta? meta;
  final String? error;
  final bool success;

  const SkillImportResult.success(this.meta) : error = null, success = true;

  const SkillImportResult.error(this.error) : meta = null, success = false;
}

/// Imports, registers and reads Agent Skills (https://agentskills.io).
///
/// Skills live on disk under `<app_support>/skills/<name>/`. A skill folder
/// always contains a `SKILL.md` whose YAML frontmatter identifies the skill.
/// Registration state (the [SkillMeta] for each imported skill) is persisted
/// in a Hive box named `skills`, keyed by skill name and stored as JSON.
///
/// The service is a singleton: callers use [SkillService.instance]. The Hive
/// box is opened lazily on first use; ensure Hive is initialized at app start
/// (see `ChatService.init`) before calling any method.
class SkillService {
  SkillService._();
  static final SkillService instance = SkillService._();

  static const String _boxName = 'skills';
  static const String _skillsFolderName = 'skills';
  static const String _skillMdFileName = 'SKILL.md';

  /// Maximum cumulative uncompressed size of a skill zip (50 MB).
  static const int _maxZipTotalBytes = 50 * 1024 * 1024;

  /// Maximum number of file entries in a skill zip.
  static const int _maxZipFileCount = 1000;

  Box<String>? _box;

  Future<Box<String>> _ensureBox() async {
    final box = _box;
    if (box != null && box.isOpen) return box;
    _box = await Hive.openBox<String>(_boxName);
    return _box!;
  }

  /// Absolute path of the skills root: `<app_support>/skills/`.
  ///
  /// The directory is created if missing.
  Future<String> getSkillsRoot() async {
    final support = await getApplicationSupportDirectory();
    final root = p.join(support.path, _skillsFolderName);
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return root;
  }

  Future<String> _skillDirPath(String name) async {
    final root = await getSkillsRoot();
    return p.join(root, name);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Imports a single `SKILL.md` file as a new skill.
  ///
  /// The source file is read, parsed, and (on success) copied into
  /// `<skills_root>/<name>/SKILL.md`. Only the `SKILL.md` is imported; no
  /// additional resources are bundled. The newly registered skill has
  /// `globalEnabled = true`.
  ///
  /// On any failure the source file is left untouched and no skill directory
  /// is created.
  Future<SkillImportResult> importFromSkillMd(String sourceFilePath) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        return SkillImportResult.error(
          'Source file not found: $sourceFilePath',
        );
      }
      final content = await sourceFile.readAsString();

      final parseResult = SkillParser.parseSkillMd(content, directoryPath: '');
      if (parseResult.isError || parseResult.meta == null) {
        return SkillImportResult.error(parseResult.error ?? 'Parse failed');
      }

      final name = parseResult.meta!.name;
      if (await getSkill(name) != null) {
        return SkillImportResult.error("Skill '$name' already exists");
      }

      final targetDirPath = await _skillDirPath(name);
      final targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      await sourceFile.copy(p.join(targetDirPath, _skillMdFileName));

      final meta = parseResult.meta!.copyWith(
        directoryPath: targetDirPath,
        globalEnabled: true,
      );
      await _register(meta);
      return SkillImportResult.success(meta);
    } catch (e) {
      return SkillImportResult.error('Failed to import SKILL.md: $e');
    }
  }

  /// Imports a `.zip` archive containing a skill.
  ///
  /// The zip is extracted into a temporary directory after Zip Slip, total
  /// size and file count validation. A `SKILL.md` must be present either at
  /// the zip root or inside a single top-level folder. The skill folder is
  /// then moved to `<skills_root>/<name>/` and registered with
  /// `globalEnabled = true`.
  ///
  /// On any failure the temporary directory is cleaned up and the skills
  /// root is left untouched.
  Future<SkillImportResult> importFromZip(String zipFilePath) async {
    Directory? tempDir;
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        return SkillImportResult.error('Zip file not found: $zipFilePath');
      }
      final bytes = await zipFile.readAsBytes();

      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        return SkillImportResult.error('Invalid or corrupted zip: $e');
      }

      final fileEntries = archive.where((f) => f.isFile).toList();
      if (fileEntries.length > _maxZipFileCount) {
        return SkillImportResult.error(
          'Zip contains too many files '
          '(${fileEntries.length} > $_maxZipFileCount)',
        );
      }
      var totalBytes = 0;
      for (final f in fileEntries) {
        totalBytes += f.size;
      }
      if (totalBytes > _maxZipTotalBytes) {
        return SkillImportResult.error(
          'Zip uncompressed size exceeds limit '
          '(${totalBytes ~/ (1024 * 1024)} MB > 50 MB)',
        );
      }

      final skillsRoot = await getSkillsRoot();
      final tempRoot = await Directory.systemTemp.createTemp('kelivo_skill_');
      tempDir = tempRoot;
      final tempRootPath = p.normalize(tempRoot.absolute.path);

      // Extract with Zip Slip validation.
      for (final entry in archive) {
        final entryName = entry.name.replaceAll('\\', '/');
        if (entryName.isEmpty) continue;
        final targetPath = p.normalize(p.join(tempRootPath, entryName));
        if (!p.isWithin(tempRootPath, targetPath)) {
          await _safeDelete(tempRoot);
          tempDir = null;
          return SkillImportResult.error('Zip contains path traversal');
        }
        if (entry.isFile) {
          final file = File(targetPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.content as List<int>);
        } else {
          await Directory(targetPath).create(recursive: true);
        }
      }

      // Locate SKILL.md: zip root first, then a single top-level folder.
      final rootSkillMd = File(p.join(tempRootPath, _skillMdFileName));
      String skillSourceDirPath;
      if (await rootSkillMd.exists()) {
        skillSourceDirPath = tempRootPath;
      } else {
        Directory? subMatch;
        final entries = await tempRoot.list(followLinks: false).toList();
        for (final e in entries) {
          if (e is! Directory) continue;
          final candidate = File(p.join(e.path, _skillMdFileName));
          if (await candidate.exists()) {
            subMatch = e;
            break;
          }
        }
        if (subMatch == null) {
          await _safeDelete(tempRoot);
          tempDir = null;
          return SkillImportResult.error(
            'SKILL.md not found in zip root or single subdirectory',
          );
        }
        skillSourceDirPath = subMatch.path;
      }

      // Parse SKILL.md to obtain the skill name.
      final skillMdFile = File(p.join(skillSourceDirPath, _skillMdFileName));
      final content = await skillMdFile.readAsString();
      final parseResult = SkillParser.parseSkillMd(content, directoryPath: '');
      if (parseResult.isError || parseResult.meta == null) {
        await _safeDelete(tempRoot);
        tempDir = null;
        return SkillImportResult.error(parseResult.error ?? 'Parse failed');
      }

      final name = parseResult.meta!.name;
      if (await getSkill(name) != null) {
        await _safeDelete(tempRoot);
        tempDir = null;
        return SkillImportResult.error("Skill '$name' already exists");
      }

      // Move the skill folder into <skills_root>/<name>/.
      final targetDirPath = p.join(skillsRoot, name);
      final targetDir = Directory(targetDirPath);
      if (await targetDir.exists()) {
        // Not registered but present on disk: clear it before moving.
        await targetDir.delete(recursive: true);
      }
      await _moveDirectory(Directory(skillSourceDirPath), targetDir);

      await _safeDelete(tempRoot);
      tempDir = null;

      final meta = parseResult.meta!.copyWith(
        directoryPath: targetDirPath,
        globalEnabled: true,
      );
      await _register(meta);
      return SkillImportResult.success(meta);
    } catch (e) {
      if (tempDir != null) {
        await _safeDelete(tempDir);
      }
      return SkillImportResult.error('Failed to import zip: $e');
    }
  }

  Future<void> _moveDirectory(Directory src, Directory dest) async {
    // Fast path: rename works when source and destination share a volume.
    try {
      await src.rename(dest.path);
      return;
    } catch (_) {
      // Fall through to copy + delete (e.g. cross-volume move).
    }
    await _copyDirectory(src, dest);
    await _safeDelete(src);
  }

  Future<void> _copyDirectory(Directory src, Directory dest) async {
    if (!await dest.exists()) {
      await dest.create(recursive: true);
    }
    await for (final entity in src.list(recursive: false, followLinks: false)) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  Future<void> _safeDelete(Directory dir) async {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('SkillService: failed to clean up ${dir.path}: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence helpers
  // ---------------------------------------------------------------------------

  Future<void> _register(SkillMeta meta) async {
    final box = await _ensureBox();
    await box.put(meta.name, jsonEncode(meta.toJson()));
  }

  Future<void> _unregister(String name) async {
    final box = await _ensureBox();
    await box.delete(name);
  }

  Future<List<SkillMeta>> _allFromBox() async {
    final box = await _ensureBox();
    final result = <SkillMeta>[];
    for (final value in box.values) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        result.add(SkillMeta.fromJson(json));
      } catch (e) {
        debugPrint('SkillService: failed to decode skill entry: $e');
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Query & management
  // ---------------------------------------------------------------------------

  /// Lists all registered skills.
  ///
  /// The result is reconciled with disk: any skill whose directory was
  /// removed manually is unregistered before returning.
  Future<List<SkillMeta>> listSkills() async {
    final skills = await _allFromBox();
    final root = await getSkillsRoot();
    final toRemove = <String>[];
    for (final s in skills) {
      final dir = Directory(p.join(root, s.name));
      if (!await dir.exists()) {
        toRemove.add(s.name);
      }
    }
    if (toRemove.isEmpty) {
      return skills;
    }
    for (final name in toRemove) {
      await _unregister(name);
    }
    final removedSet = toRemove.toSet();
    return skills.where((s) => !removedSet.contains(s.name)).toList();
  }

  /// Returns the registered [SkillMeta] for [name], or `null` if not found.
  Future<SkillMeta?> getSkill(String name) async {
    final box = await _ensureBox();
    final raw = box.get(name);
    if (raw == null) return null;
    try {
      return SkillMeta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('SkillService: failed to decode skill "$name": $e');
      return null;
    }
  }

  /// Recursively deletes the skill directory and unregisters the skill.
  Future<void> deleteSkill(String name) async {
    final dirPath = await _skillDirPath(name);
    final dir = Directory(dirPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await _unregister(name);
  }

  /// Updates the `globalEnabled` flag of an already-registered skill.
  Future<void> setEnabled(String name, bool enabled) async {
    final meta = await getSkill(name);
    if (meta == null) return;
    await _register(meta.copyWith(globalEnabled: enabled));
  }

  /// Reads the full text of `<skills_root>/<name>/SKILL.md`.
  ///
  /// Returns `null` if the skill is not registered or the file does not exist.
  Future<String?> readSkillMd(String name) async {
    if (await getSkill(name) == null) return null;
    final dirPath = await _skillDirPath(name);
    final file = File(p.join(dirPath, _skillMdFileName));
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  /// Reads a text resource located at `<skills_root>/<name>/<relativePath>`.
  ///
  /// Safety:
  ///  * [relativePath] is normalized and must resolve *inside* the skill
  ///    folder. Any traversal attempt (e.g. `../`) returns `null`.
  ///  * Paths under a `scripts/` prefix are rejected and return `null`.
  ///  * Returns `null` when the skill is not registered or the file is
  ///    missing.
  Future<String?> readSkillResource(String name, String relativePath) async {
    if (await getSkill(name) == null) return null;
    if (relativePath.isEmpty) return null;

    final skillDirPath = await _skillDirPath(name);
    final skillDirNorm = p.normalize(skillDirPath);

    // Reject `scripts/` prefix (normalize + unify separators before checking).
    final normalizedRelative = p.normalize(relativePath);
    final forwardRelative = normalizedRelative.replaceAll('\\', '/');
    if (forwardRelative == 'scripts' ||
        forwardRelative.startsWith('scripts/')) {
      return null;
    }

    // Path-traversal guard: resolved target must remain within the skill dir.
    final targetPath = p.normalize(p.join(skillDirPath, relativePath));
    if (!p.isWithin(skillDirNorm, targetPath)) {
      return null;
    }

    final file = File(targetPath);
    if (!await file.exists()) return null;
    return await file.readAsString();
  }

  // ---------------------------------------------------------------------------
  // Bundled defaults
  // ---------------------------------------------------------------------------

  /// The list of built-in default skills that ship with the application.
  ///
  /// Each entry is a `(name, {file -> content})` tuple. These skills are
  /// installed on first app startup and can be deleted by the user like any
  /// other skill. Add new entries in [bundledDefaultSkills] to ship additional
  /// default skills in future releases.
  List<BundledSkill> get _getBundledDefaultSkills => bundledDefaultSkills;

  /// Installs all [bundled default skills] on first launch.
  ///
  /// Each default skill's files are written to a temporary directory and then
  /// imported via [importFromSkillMd]. Skills that are already registered are
  /// skipped silently. The temporary files are cleaned up afterwards.
  ///
  /// Returns a human-readable summary of how many were imported vs skipped.
  Future<String> installBundledDefaults() async {
    int imported = 0;
    int skipped = 0;
    final tempRoot = Directory(
      p.join(Directory.systemTemp.path, 'kelivo_default_skills'),
    );

    try {
      for (final (name, files) in _getBundledDefaultSkills) {
        if (await getSkill(name) != null) {
          skipped++;
          continue;
        }
        final skillDir = Directory(p.join(tempRoot.path, name));
        await skillDir.create(recursive: true);
        String? skillMdPath;
        for (final entry in files.entries) {
          final filePath = p.join(skillDir.path, entry.key);
          await File(filePath).writeAsString(entry.value);
          if (entry.key == 'SKILL.md') {
            skillMdPath = filePath;
          }
        }
        if (skillMdPath == null) {
          debugPrint('SkillService: no SKILL.md in bundled skill "$name"');
          skipped++;
          continue;
        }
        final result = await importFromSkillMd(skillMdPath);
        if (result.success) {
          imported++;
        } else {
          skipped++;
          debugPrint(
            'SkillService: failed to install default skill "$name": '
            '${result.error}',
          );
        }
      }
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
    return 'Bundled defaults: $imported imported, $skipped skipped.';
  }

  // ---------------------------------------------------------------------------
  // Disk reconciliation
  // ---------------------------------------------------------------------------

  /// Reconciles registered skills with the contents of [getSkillsRoot].
  ///
  ///  * Registered skills whose directory no longer exists are unregistered.
  ///  * Skill directories present on disk but not registered are auto-imported:
  ///    the directory name becomes the skill `name`, and `SKILL.md` is parsed
  ///    to obtain the description and other metadata. Auto-imported skills
  ///    default to `globalEnabled = false` for safety.
  ///
  /// Call this once at app startup, after Hive has been initialized.
  Future<void> syncWithDisk() async {
    final root = await getSkillsRoot();
    final rootDir = Directory(root);
    if (!await rootDir.exists()) return;

    final box = await _ensureBox();
    final registeredNames = box.keys.map((k) => k.toString()).toSet();

    final diskNames = <String>{};
    await for (final entity in rootDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      diskNames.add(p.basename(entity.path));
    }

    // Unregister missing skills.
    for (final name in registeredNames) {
      if (!diskNames.contains(name)) {
        await box.delete(name);
      }
    }

    // Auto-register disk-only skills.
    for (final name in diskNames) {
      if (registeredNames.contains(name)) continue;
      final skillMd = File(p.join(root, name, _skillMdFileName));
      if (!await skillMd.exists()) continue;
      try {
        final content = await skillMd.readAsString();
        final parseResult = SkillParser.parseSkillMd(
          content,
          directoryPath: p.join(root, name),
        );
        if (parseResult.isError || parseResult.meta == null) continue;
        // Directory name is the canonical skill identifier per disk truth.
        final meta = parseResult.meta!.copyWith(
          name: name,
          directoryPath: p.join(root, name),
          globalEnabled: false,
        );
        await box.put(name, jsonEncode(meta.toJson()));
      } catch (e) {
        debugPrint('SkillService.syncWithDisk: failed to register "$name": $e');
      }
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../../utils/app_directories.dart';
import '../../database/extension_entity_store.dart';
import '../../models/assistant.dart';
import '../../models/skill_record.dart';
import 'github_skill_ref.dart';
import 'skill.dart';
import 'skill_archive.dart';
import 'skill_frontmatter.dart';

export 'skill.dart';
export 'skill_frontmatter.dart' show SkillFrontmatter, slugify;
export 'skills_prompt.dart' show buildAvailableSkillsFragment;

class SkillsService extends ChangeNotifier {
  SkillsService({
    required this.store,
    Directory? skillsDirectory,
    http.Client? httpClient,
  }) : _injectedSkillsDirectory = skillsDirectory,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    loaded = _load();
  }

  final ExtensionEntityStore store;
  final Directory? _injectedSkillsDirectory;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<Skill> _skills = <Skill>[];

  late final Future<void> loaded;

  Directory? _skillsDirectory;

  List<Skill> get skills => List.unmodifiable(_skills);

  Directory get skillsDirectory {
    final dir = _skillsDirectory ?? _injectedSkillsDirectory;
    if (dir == null) {
      throw StateError('SkillsService.loaded has not completed');
    }
    return dir;
  }

  Future<void> _load() async {
    await rescan();
  }

  Future<Directory> _ensureRoot() async {
    final dir =
        _injectedSkillsDirectory ?? await AppDirectories.getSkillsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _skillsDirectory = dir;
    return dir;
  }

  Future<void> rescan() async {
    final root = await _ensureRoot();
    final entities = await store.listByKind(ExtensionEntityStore.kindSkill);
    final records = <String, SkillRecord>{
      for (final entity in entities)
        entity.id: SkillRecord.fromJson(entity.payload),
    };

    final diskIds = <String>{};
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (id.isEmpty || id.startsWith('.')) continue;
      diskIds.add(id);
    }

    for (final id in List<String>.from(records.keys)) {
      final md = File(p.join(root.path, id, 'SKILL.md'));
      if (!await md.exists()) {
        await store.delete(ExtensionEntityStore.kindSkill, id);
        records.remove(id);
      }
    }

    for (final id in diskIds) {
      if (records.containsKey(id)) continue;
      final md = File(p.join(root.path, id, 'SKILL.md'));
      if (!await md.exists()) continue;
      final now = DateTime.now().toUtc();
      final record = SkillRecord(
        id: id,
        source: SkillSource.file,
        installedAt: now,
        updatedAt: now,
      );
      await store.upsert(ExtensionEntityStore.kindSkill, id, record.toJson());
      records[id] = record;
    }

    final next = <Skill>[];
    for (final record in records.values) {
      next.add(await _skillFromDisk(root, record));
    }
    next.sort((a, b) => a.record.id.compareTo(b.record.id));
    _skills
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<Skill> importFromText(String markdown) {
    return _importMarkdown(markdown, SkillSource.paste);
  }

  Future<Skill> importFromFile(String hostPath) async {
    await loaded;
    final file = File(hostPath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', hostPath);
    }
    final ext = p.extension(hostPath).toLowerCase();
    if (ext == '.md') {
      return _importMarkdown(await file.readAsString(), SkillSource.file);
    }
    if (ext == '.zip') {
      final bytes = await file.readAsBytes();
      if (bytes.length > kSkillImportMaxBytes) {
        throw const FormatException('zip exceeds 20 MB');
      }
      final tree = extractSkillArchive(bytes);
      return _importTree(tree, SkillSource.file);
    }
    throw FormatException('Unsupported skill file type: $ext');
  }

  Future<Skill> importFromGitHub(String url) async {
    await loaded;
    final ref = GitHubSkillRef.parse(url);
    final branch = await _resolveGitHubRef(ref);
    final zipBytes = await _downloadGitHubZip(ref, branch);
    final tree = extractSkillArchive(
      zipBytes,
      subdir: ref.subdir,
      stripSingleRoot: true,
    );
    return _importTree(tree, SkillSource.github);
  }

  Future<File> exportZip(String id, Directory outDir) async {
    await loaded;
    final skill = _require(id);
    final files = <String, List<int>>{};
    final dir = Directory(skill.dir);
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final rel = p
          .relative(entity.path, from: skill.dir)
          .replaceAll('\\', '/');
      if (rel.split('/').contains('..')) {
        throw const FormatException('zip-slip');
      }
      files[rel] = await entity.readAsBytes();
    }
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final out = File(p.join(outDir.path, '$id.zip'));
    await out.writeAsBytes(encodeSkillZip(files), flush: true);
    return out;
  }

  Future<void> delete(String id) async {
    await loaded;
    await store.delete(ExtensionEntityStore.kindSkill, id);
    final dir = Directory(p.join((await _ensureRoot()).path, id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _skills.removeWhere((skill) => skill.record.id == id);
    notifyListeners();
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await loaded;
    final skill = _require(id);
    final next = skill.record.copyWith(
      enabled: enabled,
      updatedAt: DateTime.now().toUtc(),
    );
    await _upsertRecord(next);
    _replace(skill, record: next);
    notifyListeners();
  }

  Future<void> incrementUseCount(String id) async {
    try {
      await loaded;
      final index = _skills.indexWhere((skill) => skill.record.id == id);
      if (index < 0) return;
      final skill = _skills[index];
      final next = skill.record.copyWith(
        useCount: skill.record.useCount + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await _upsertRecord(next);
      _skills[index] = Skill(
        record: next,
        name: skill.name,
        description: skill.description,
        dir: skill.dir,
        skillMdPath: skill.skillMdPath,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('incrementUseCount failed: $e');
    }
  }

  Future<void> updateBody(String id, String markdown) async {
    await loaded;
    final skill = _require(id);
    final parsed = SkillFrontmatter.parse(markdown);
    await File(skill.skillMdPath).writeAsString(markdown, flush: true);
    final next = skill.record.copyWith(updatedAt: DateTime.now().toUtc());
    await _upsertRecord(next);
    _replace(
      skill,
      record: next,
      name: parsed.name.trim().isEmpty ? skill.name : parsed.name.trim(),
      description: parsed.description,
    );
    notifyListeners();
  }

  List<Skill> resolveForAssistant(
    Assistant? assistant, {
    List<String>? conversationOverride,
  }) {
    final filter = conversationOverride ?? assistant?.skillIds;
    final enabled = [
      for (final skill in _skills)
        if (skill.record.enabled) skill,
    ];
    if (filter == null) return enabled;
    final allowed = filter.toSet();
    return [
      for (final skill in enabled)
        if (allowed.contains(skill.record.id)) skill,
    ];
  }

  @override
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }

  Future<Skill> _importMarkdown(String markdown, SkillSource source) async {
    await loaded;
    final parsed = SkillFrontmatter.parse(markdown);
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    final files = <String, List<int>>{'SKILL.md': utf8.encode(markdown)};
    return _commitImport(name: parsed.name, files: files, source: source);
  }

  Future<Skill> _importTree(ExtractedSkillTree tree, SkillSource source) async {
    await loaded;
    final raw = tree.files['SKILL.md'];
    if (raw == null) {
      throw const FormatException('SKILL.md not found');
    }
    final parsed = SkillFrontmatter.parse(utf8.decode(raw));
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    return _commitImport(name: parsed.name, files: tree.files, source: source);
  }

  Future<Skill> _commitImport({
    required String name,
    required Map<String, List<int>> files,
    required SkillSource source,
  }) async {
    final root = await _ensureRoot();
    final id = await _allocateId(slugify(name));
    await _writeSkillFiles(root, id, files);
    final now = DateTime.now().toUtc();
    final record = SkillRecord(
      id: id,
      source: source,
      installedAt: now,
      updatedAt: now,
    );
    await _upsertRecord(record);
    final skill = await _skillFromDisk(root, record);
    _skills
      ..removeWhere((item) => item.record.id == id)
      ..add(skill)
      ..sort((a, b) => a.record.id.compareTo(b.record.id));
    notifyListeners();
    return skill;
  }

  Future<void> _writeSkillFiles(
    Directory root,
    String id,
    Map<String, List<int>> files,
  ) async {
    final dest = Directory(p.join(root.path, id));
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }
    await dest.create(recursive: true);
    final canonRoot = p.canonicalize(dest.path);
    for (final entry in files.entries) {
      final destPath = p.join(dest.path, entry.key);
      final canonDest = p.canonicalize(destPath);
      if (!p.equals(canonRoot, canonDest) &&
          !p.isWithin(canonRoot, canonDest)) {
        throw const FormatException('zip-slip');
      }
      await Directory(p.dirname(destPath)).create(recursive: true);
      await File(destPath).writeAsBytes(entry.value, flush: true);
    }
  }

  Future<String> _allocateId(String base) async {
    final root = await _ensureRoot();
    var id = base;
    var n = 2;
    while (await _idTaken(root, id)) {
      id = '$base-$n';
      n++;
    }
    return id;
  }

  Future<bool> _idTaken(Directory root, String id) async {
    if (_skills.any((skill) => skill.record.id == id)) return true;
    if (await store.get(ExtensionEntityStore.kindSkill, id) != null) {
      return true;
    }
    return Directory(p.join(root.path, id)).exists();
  }

  Future<Skill> _skillFromDisk(Directory root, SkillRecord record) async {
    final dir = p.join(root.path, record.id);
    final mdPath = p.join(dir, 'SKILL.md');
    var name = record.id;
    var description = '';
    try {
      final parsed = SkillFrontmatter.parse(await File(mdPath).readAsString());
      if (parsed.name.trim().isNotEmpty) name = parsed.name.trim();
      description = parsed.description;
    } catch (_) {}
    return Skill(
      record: record,
      name: name,
      description: description,
      dir: dir,
      skillMdPath: mdPath,
    );
  }

  Skill _require(String id) {
    for (final skill in _skills) {
      if (skill.record.id == id) return skill;
    }
    throw StateError('Unknown skill: $id');
  }

  void _replace(
    Skill skill, {
    SkillRecord? record,
    String? name,
    String? description,
  }) {
    final next = Skill(
      record: record ?? skill.record,
      name: name ?? skill.name,
      description: description ?? skill.description,
      dir: skill.dir,
      skillMdPath: skill.skillMdPath,
    );
    final index = _skills.indexWhere(
      (item) => item.record.id == skill.record.id,
    );
    if (index >= 0) {
      _skills[index] = next;
    } else {
      _skills.add(next);
    }
  }

  Future<void> _upsertRecord(SkillRecord record) {
    return store.upsert(
      ExtensionEntityStore.kindSkill,
      record.id,
      record.toJson(),
    );
  }

  Future<String> _resolveGitHubRef(GitHubSkillRef ref) async {
    if (ref.ref != null && ref.ref!.isNotEmpty) return ref.ref!;
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/${ref.owner}/${ref.repo}',
      );
      final response = await _httpClient.get(uri, headers: _githubHeaders);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['default_branch'] != null) {
          final branch = decoded['default_branch'].toString().trim();
          if (branch.isNotEmpty) return branch;
        }
      }
    } catch (e) {
      debugPrint('GitHub default_branch lookup failed: $e');
    }
    return 'main';
  }

  Future<List<int>> _downloadGitHubZip(
    GitHubSkillRef ref,
    String branch,
  ) async {
    Future<http.Response> getZip(String resolved) {
      final uri = Uri.https(
        'codeload.github.com',
        '/${ref.owner}/${ref.repo}/zip/$resolved',
      );
      return _httpClient.get(uri, headers: _githubHeaders);
    }

    var response = await getZip(branch);
    if (response.statusCode == 404 && ref.ref == null && branch == 'main') {
      response = await getZip('master');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GitHub zip download failed (${response.statusCode})',
        uri: response.request?.url,
      );
    }
    final bytes = response.bodyBytes;
    if (bytes.length > kSkillImportMaxBytes) {
      throw const FormatException('zip exceeds 20 MB');
    }
    return bytes;
  }

  static const Map<String, String> _githubHeaders = {
    'User-Agent': 'Kelivo',
    'Accept': 'application/vnd.github+json',
  };
}

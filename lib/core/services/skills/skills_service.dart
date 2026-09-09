import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'skill_import_progress.dart';

export 'skill.dart';
export 'skill_import_progress.dart';
export 'skill_frontmatter.dart' show SkillFrontmatter, slugify;
export 'skills_prompt.dart' show buildAvailableSkillsFragment;

class SkillsService extends ChangeNotifier {
  SkillsService({
    required this.store,
    Directory? skillsDirectory,
    http.Client? httpClient,
    this._bundledAssets,
  }) : _injectedSkillsDirectory = skillsDirectory,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null {
    loaded = _load();
  }

  final ExtensionEntityStore store;
  final Directory? _injectedSkillsDirectory;
  final AssetBundle? _bundledAssets;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<Skill> _skills = <Skill>[];

  late final Future<void> loaded;

  Directory? _skillsDirectory;
  Future<void> _mutationTail = Future<void>.value();
  bool _disposed = false;

  // Command-triggered rescans share the same queue as imports and settings
  // changes so an older disk snapshot cannot replace newer user choices.
  Future<T> _serializeMutation<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  List<Skill> get skills => List.unmodifiable(_skills);

  Directory get skillsDirectory {
    final dir = _skillsDirectory ?? _injectedSkillsDirectory;
    if (dir == null) {
      throw StateError('SkillsService.loaded has not completed');
    }
    return dir;
  }

  Future<void> _load() => _serializeMutation(() async {
    final assets = _bundledAssets;
    if (assets != null) {
      await _seedSkillCreator(await _ensureRoot(), assets);
    }
    await _rescan();
  });

  Future<void> _seedSkillCreator(Directory root, AssetBundle assets) async {
    const id = 'skill-creator';
    // Keep this receipt beside the skills so backup/restore also preserves a
    // user's deletion. Seeding never replaces an existing skill or its settings.
    final receipt = File(p.join(root.path, '.bundled-skill-creator'));
    if (await receipt.exists()) return;
    final dest = Directory(p.join(root.path, id));
    final destType = await FileSystemEntity.type(dest.path, followLinks: false);
    final md = File(p.join(dest.path, 'SKILL.md'));
    if ((destType == FileSystemEntityType.notFound ||
            destType == FileSystemEntityType.directory) &&
        !await md.exists()) {
      final entity = await store.get(ExtensionEntityStore.kindSkill, id);
      final previous = entity == null
          ? null
          : SkillRecord.fromJson(entity.payload);
      final markdown = await assets.loadString('assets/skills/$id/SKILL.md');
      final errors = SkillFrontmatter.parse(markdown).validate();
      if (errors.isNotEmpty) {
        throw FormatException('Invalid bundled SKILL.md: ${errors.join(', ')}');
      }
      final staging = await root.createTemp('.bundled-');
      try {
        await File(
          p.join(staging.path, 'SKILL.md'),
        ).writeAsString(markdown, flush: true);
        if (destType == FileSystemEntityType.notFound) {
          await staging.rename(dest.path);
        } else {
          await File(p.join(staging.path, 'SKILL.md')).rename(md.path);
        }
        try {
          final now = DateTime.now().toUtc();
          await _upsertRecord(
            previous?.copyWith(source: SkillSource.bundled, updatedAt: now) ??
                SkillRecord(
                  id: id,
                  source: SkillSource.bundled,
                  installedAt: now,
                  updatedAt: now,
                ),
          );
        } catch (_) {
          if (destType == FileSystemEntityType.notFound) {
            await dest.delete(recursive: true);
          } else {
            await md.delete();
          }
          rethrow;
        }
      } finally {
        if (await staging.exists()) await staging.delete(recursive: true);
      }
    }
    await receipt.writeAsString('1\n', flush: true);
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

  Future<void> rescan() => _serializeMutation(_rescan);

  Future<void> _rescan() async {
    if (_disposed) return;
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
    if (_disposed) return;
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
      final root = await _ensureRoot();
      final staging = await root.createTemp('.import-');
      try {
        return await _importArchive(file, staging, SkillSource.file);
      } finally {
        await staging.delete(recursive: true);
      }
    }
    throw FormatException('Unsupported skill file type: $ext');
  }

  Future<Skill> importFromGitHub(
    String url, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    var cancelled = false;
    unawaited(cancelSignal?.then((_) => cancelled = true));
    void checkCancelled() {
      if (cancelled) throw http.RequestAbortedException();
    }

    await loaded;
    checkCancelled();
    final ref = GitHubSkillRef.parse(url);
    onProgress?.call(const SkillImportProgress(SkillImportPhase.resolving));
    final branch = await _resolveGitHubRef(ref, cancelSignal: cancelSignal);
    checkCancelled();
    final root = await _ensureRoot();
    final staging = await root.createTemp('.import-');
    try {
      final zip = File(p.join(staging.path, 'download.zip'));
      await _downloadGitHubZip(
        ref,
        branch,
        zip,
        onProgress: onProgress,
        cancelSignal: cancelSignal,
      );
      checkCancelled();
      return await _importArchive(
        zip,
        staging,
        SkillSource.github,
        subdir: ref.subdir,
        stripSingleRoot: true,
        onProgress: onProgress,
        checkCancelled: checkCancelled,
      );
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<Skill> _importArchive(
    File zip,
    Directory staging,
    SkillSource source, {
    String? subdir,
    bool stripSingleRoot = false,
    ValueChanged<SkillImportProgress>? onProgress,
    VoidCallback? checkCancelled,
  }) async {
    onProgress?.call(const SkillImportProgress(SkillImportPhase.extracting));
    final extracted = Directory(p.join(staging.path, 'files'));
    await compute(_extractArchive, (
      zip.path,
      extracted.path,
      subdir,
      stripSingleRoot,
    ));
    checkCancelled?.call();
    onProgress?.call(const SkillImportProgress(SkillImportPhase.installing));
    final parsed = SkillFrontmatter.parse(
      await File(p.join(extracted.path, 'SKILL.md')).readAsString(),
    );
    final errors = parsed.validate();
    if (errors.isNotEmpty) {
      throw FormatException('Invalid SKILL.md: ${errors.join(', ')}');
    }
    return _serializeMutation(() async {
      final root = await _ensureRoot();
      final id = await _allocateId(slugify(parsed.name));
      checkCancelled?.call();
      final dest = await extracted.rename(p.join(root.path, id));
      try {
        checkCancelled?.call();
        return await _registerImport(root, id, source);
      } catch (_) {
        await dest.delete(recursive: true);
        rethrow;
      }
    });
  }

  static void _extractArchive((String, String, String?, bool) args) {
    extractSkillArchive(
      args.$1,
      args.$2,
      subdir: args.$3,
      stripSingleRoot: args.$4,
    );
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
    await _serializeMutation(() async {
      await store.delete(ExtensionEntityStore.kindSkill, id);
      final dir = Directory(p.join((await _ensureRoot()).path, id));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _skills.removeWhere((skill) => skill.record.id == id);
      notifyListeners();
    });
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await loaded;
    await _serializeMutation(() async {
      final skill = _require(id);
      final next = skill.record.copyWith(
        enabled: enabled,
        updatedAt: DateTime.now().toUtc(),
      );
      await _upsertRecord(next);
      _replace(skill, record: next);
      notifyListeners();
    });
  }

  Future<void> incrementUseCount(String id) async {
    try {
      await loaded;
      await _serializeMutation(() async {
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
      });
    } catch (e) {
      debugPrint('incrementUseCount failed: $e');
    }
  }

  Future<void> updateBody(String id, String markdown) async {
    await loaded;
    await _serializeMutation(() async {
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
    });
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
    _disposed = true;
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

  Future<Skill> _commitImport({
    required String name,
    required Map<String, List<int>> files,
    required SkillSource source,
  }) => _serializeMutation(() async {
    final root = await _ensureRoot();
    final id = await _allocateId(slugify(name));
    await _writeSkillFiles(root, id, files);
    return _registerImport(root, id, source);
  });

  Future<Skill> _registerImport(
    Directory root,
    String id,
    SkillSource source,
  ) async {
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

  Future<String> _resolveGitHubRef(
    GitHubSkillRef ref, {
    Future<void>? cancelSignal,
  }) async {
    if (ref.ref != null && ref.ref!.isNotEmpty) return ref.ref!;
    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/${ref.owner}/${ref.repo}',
      );
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: cancelSignal,
      )..headers.addAll(_githubHeaders);
      final response = await http.Response.fromStream(
        await _httpClient.send(request),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['default_branch'] != null) {
          final branch = decoded['default_branch'].toString().trim();
          if (branch.isNotEmpty) return branch;
        }
      }
    } on http.RequestAbortedException {
      rethrow;
    } catch (e) {
      debugPrint('GitHub default_branch lookup failed: $e');
    }
    return 'main';
  }

  Future<void> _downloadGitHubZip(
    GitHubSkillRef ref,
    String branch,
    File destination, {
    ValueChanged<SkillImportProgress>? onProgress,
    Future<void>? cancelSignal,
  }) async {
    Future<http.StreamedResponse> getZip(String resolved) {
      final uri = Uri.https(
        'codeload.github.com',
        '/${ref.owner}/${ref.repo}/zip/$resolved',
      );
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: cancelSignal,
      )..headers.addAll(_githubHeaders);
      return _httpClient.send(request);
    }

    onProgress?.call(const SkillImportProgress(SkillImportPhase.downloading));
    var response = await getZip(branch);
    if (response.statusCode == 404 && ref.ref == null && branch == 'main') {
      await response.stream.listen(null).cancel();
      response = await getZip('master');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.stream.listen(null).cancel();
      throw HttpException(
        'GitHub zip download failed (${response.statusCode})',
        uri: response.request?.url,
      );
    }
    final total = response.contentLength;
    if (total != null && total > kSkillImportMaxBytes) {
      await response.stream.listen(null).cancel();
      throw const FormatException('zip exceeds 200 MB');
    }
    var received = 0;
    final clock = Stopwatch()..start();
    void report() {
      onProgress?.call(
        SkillImportProgress(
          SkillImportPhase.downloading,
          receivedBytes: received,
          totalBytes: total,
        ),
      );
      clock.reset();
    }

    report();
    final output = await destination.open(mode: FileMode.write);
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        if (received > kSkillImportMaxBytes) {
          throw const FormatException('zip exceeds 200 MB');
        }
        await output.writeFrom(chunk);
        if (clock.elapsedMilliseconds >= 100) report();
      }
      report();
    } finally {
      await output.close();
    }
  }

  static const Map<String, String> _githubHeaders = {
    'User-Agent': 'Kelivo',
    'Accept': 'application/vnd.github+json',
  };
}

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const int kSkillImportMaxBytes = 20 * 1024 * 1024;

/// Files of one skill, keyed by posix paths relative to the skill root.
class ExtractedSkillTree {
  const ExtractedSkillTree(this.files);

  final Map<String, List<int>> files;
}

/// Decode a zip, reject zip-slip / oversize, and isolate the skill directory.
///
/// [subdir] is a posix path under the archive (after an optional single-root
/// strip used for GitHub `codeload` zips). The skill is `SKILL.md` at that
/// root or one directory below it.
ExtractedSkillTree extractSkillArchive(
  List<int> bytes, {
  String? subdir,
  bool stripSingleRoot = false,
}) {
  if (bytes.length > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 20 MB');
  }
  final archive = ZipDecoder().decodeBytes(Uint8List.fromList(bytes));
  final entries = <String, List<int>>{};
  var total = 0;
  for (final file in archive) {
    if (!file.isFile || file.isSymbolicLink) continue;
    final name = safeZipEntryName(file.name);
    if (name == null) continue;
    final data = file.content;
    total += data.length;
    if (total > kSkillImportMaxBytes) {
      throw const FormatException('zip exceeds 20 MB');
    }
    entries[name] = data;
  }
  if (entries.isEmpty) {
    throw const FormatException('zip contains no files');
  }
  var map = entries;
  if (stripSingleRoot) {
    map = _stripSingleRoot(map);
  }
  if (subdir != null && subdir.isNotEmpty) {
    map = _takePrefix(map, _posixRel(subdir));
  }
  return ExtractedSkillTree(_narrowToSkillRoot(map));
}

List<int> encodeSkillZip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// Returns a normalized relative path, or `null` for a directory entry.
/// Throws [FormatException] on zip-slip.
String? safeZipEntryName(String raw) {
  var name = raw.replaceAll('\\', '/');
  while (name.startsWith('./')) {
    name = name.substring(2);
  }
  while (name.startsWith('/')) {
    name = name.substring(1);
  }
  if (name.isEmpty || name.endsWith('/')) return null;
  final normalized = p.posix.normalize(name);
  if (normalized.isEmpty ||
      normalized == '.' ||
      normalized.startsWith('/') ||
      normalized.split('/').contains('..')) {
    throw const FormatException('zip-slip');
  }
  return normalized;
}

String _posixRel(String value) {
  var path = value.replaceAll('\\', '/');
  while (path.startsWith('/')) {
    path = path.substring(1);
  }
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return p.posix.normalize(path);
}

Map<String, List<int>> _stripSingleRoot(Map<String, List<int>> files) {
  final roots = <String>{};
  for (final name in files.keys) {
    roots.add(name.split('/').first);
  }
  if (roots.length != 1) return files;
  final root = roots.single;
  if (root == 'SKILL.md') return files;
  return _takePrefix(files, root);
}

Map<String, List<int>> _takePrefix(
  Map<String, List<int>> files,
  String prefix,
) {
  if (prefix.isEmpty || prefix == '.') return files;
  final lead = '$prefix/';
  final out = <String, List<int>>{};
  for (final entry in files.entries) {
    if (entry.key == prefix) continue;
    if (entry.key.startsWith(lead)) {
      out[entry.key.substring(lead.length)] = entry.value;
    }
  }
  if (out.isEmpty) {
    throw FormatException('zip is missing $prefix');
  }
  return out;
}

Map<String, List<int>> _narrowToSkillRoot(Map<String, List<int>> files) {
  if (files.containsKey('SKILL.md')) return files;
  final dirs = <String>{};
  for (final name in files.keys) {
    final parts = name.split('/');
    if (parts.length == 2 && parts[1] == 'SKILL.md') {
      dirs.add(parts[0]);
    }
  }
  if (dirs.isEmpty) {
    throw const FormatException('SKILL.md not found');
  }
  final chosen = (dirs.toList()..sort()).first;
  return _takePrefix(files, chosen);
}

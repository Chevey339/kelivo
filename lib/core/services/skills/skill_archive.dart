import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

const int kSkillImportMaxBytes = 200 * 1024 * 1024;
const int kSkillImportMaxExtractedBytes = 500 * 1024 * 1024;

/// Extract only the selected skill to disk. Run in an isolate so large archives
/// do not block the UI or keep the whole download and extracted tree in memory.
void extractSkillArchive(
  String archivePath,
  String outputDirectory, {
  String? subdir,
  bool stripSingleRoot = false,
}) {
  if (File(archivePath).lengthSync() > kSkillImportMaxBytes) {
    throw const FormatException('zip exceeds 200 MB');
  }
  final input = InputFileStream(archivePath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final entries = <String, ArchiveFile>{};
    for (final file in archive) {
      if (!file.isFile || file.isSymbolicLink) continue;
      final name = safeZipEntryName(file.name);
      if (name != null) entries[name] = file;
    }
    if (entries.isEmpty) {
      throw const FormatException('zip contains no files');
    }
    var files = stripSingleRoot ? _stripSingleRoot(entries) : entries;
    if (subdir != null && subdir.isNotEmpty) {
      files = _takePrefix(files, _posixRel(subdir));
    }
    files = _narrowToSkillRoot(files);
    // Check metadata before decompressing; files outside the skill are skipped.
    final total = files.values.fold<int>(0, (sum, file) => sum + file.size);
    if (total > kSkillImportMaxExtractedBytes) {
      throw const FormatException('extracted skill exceeds 500 MB');
    }
    var written = 0;
    for (final entry in files.entries) {
      final dest = p.join(outputDirectory, entry.key);
      if (!p.isWithin(p.canonicalize(outputDirectory), p.canonicalize(dest))) {
        throw const FormatException('zip-slip');
      }
      Directory(p.dirname(dest)).createSync(recursive: true);
      final output = _LimitedSkillOutputStream(
        dest,
        kSkillImportMaxExtractedBytes - written,
      );
      try {
        entry.value.writeContent(output);
        written += output.length;
      } finally {
        output.closeSync();
      }
    }
  } finally {
    input.closeSync();
  }
}

/// Enforce the actual output size too, even if a zip's size metadata is wrong.
class _LimitedSkillOutputStream extends OutputFileStream {
  _LimitedSkillOutputStream(String path, this.maxBytes)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  final int maxBytes;

  void _check(int count) {
    if (length + count > maxBytes) {
      throw const FormatException('extracted skill exceeds 500 MB');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }
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

Map<String, ArchiveFile> _stripSingleRoot(Map<String, ArchiveFile> files) {
  final roots = <String>{};
  for (final name in files.keys) {
    roots.add(name.split('/').first);
  }
  if (roots.length != 1) return files;
  final root = roots.single;
  if (root == 'SKILL.md') return files;
  return _takePrefix(files, root);
}

Map<String, ArchiveFile> _takePrefix(
  Map<String, ArchiveFile> files,
  String prefix,
) {
  if (prefix.isEmpty || prefix == '.') return files;
  final lead = '$prefix/';
  final out = <String, ArchiveFile>{};
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

Map<String, ArchiveFile> _narrowToSkillRoot(Map<String, ArchiveFile> files) {
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

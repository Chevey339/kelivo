import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/skills/skill_archive.dart';

void main() {
  late Directory tmp;
  late File zip;
  late String output;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('skill_archive_test_');
    zip = File(p.join(tmp.path, 'input.zip'));
    output = p.join(tmp.path, 'output');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('rejects a >200 MB local zip before decoding', () {
    final handle = zip.openSync(mode: FileMode.write);
    handle.truncateSync(kSkillImportMaxBytes + 1);
    handle.closeSync();
    expect(
      () => extractSkillArchive(zip.path, output),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'zip exceeds 200 MB',
        ),
      ),
    );
  });

  test('rejects expanded size before writing files', () {
    final bytes = encodeSkillZip({'SKILL.md': utf8.encode('skill')});
    _setDeclaredSize(bytes, 'SKILL.md', kSkillImportMaxExtractedBytes + 1);
    zip.writeAsBytesSync(bytes);
    expect(
      () => extractSkillArchive(zip.path, output),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'extracted skill exceeds 500 MB',
        ),
      ),
    );
    expect(Directory(output).existsSync(), isFalse);
  });

  test('unrelated repository files are not decompressed or counted', () {
    final bytes = encodeSkillZip({
      'repo-main/skills/demo/SKILL.md': utf8.encode('skill'),
      'repo-main/skills/demo/helper.py': utf8.encode('print(1)'),
      'repo-main/other/large.bin': [1],
    });
    _setDeclaredSize(
      bytes,
      'repo-main/other/large.bin',
      kSkillImportMaxExtractedBytes + 1,
    );
    zip.writeAsBytesSync(bytes);
    extractSkillArchive(
      zip.path,
      output,
      subdir: 'skills/demo',
      stripSingleRoot: true,
    );
    expect(File(p.join(output, 'SKILL.md')).readAsStringSync(), 'skill');
    expect(File(p.join(output, 'helper.py')).readAsStringSync(), 'print(1)');
    expect(Directory(p.join(output, 'other')).existsSync(), isFalse);
  });

  test('zip-slip is still rejected and symlinks are not installed', () {
    final archive = Archive()
      ..addFile(ArchiveFile.string('../escape/SKILL.md', 'skill'));
    zip.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    expect(() => extractSkillArchive(zip.path, output), throwsFormatException);
    final link = ArchiveFile.string('outside', '../outside')
      ..mode = 0xa1ff
      ..symbolicLink = '../outside';
    final linkedZip = ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.string('SKILL.md', 'skill'))
        ..addFile(link),
    );
    // ZipEncoder writes DOS headers; mark this fixture as a Unix archive.
    final data = ByteData.sublistView(linkedZip);
    for (var i = 0; i + 46 <= linkedZip.length; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        data.setUint8(i + 5, 3);
      }
    }
    zip.writeAsBytesSync(linkedZip);
    extractSkillArchive(zip.path, output);
    expect(File(p.join(output, 'SKILL.md')).existsSync(), isTrue);
    expect(
      FileSystemEntity.typeSync(p.join(output, 'outside'), followLinks: false),
      FileSystemEntityType.notFound,
    );
  });
}

// Change the central-directory size without allocating a huge test payload.
void _setDeclaredSize(List<int> bytes, String name, int size) {
  final data = ByteData.sublistView(bytes as Uint8List);
  for (var i = 0; i + 46 <= bytes.length; i++) {
    if (data.getUint32(i, Endian.little) != 0x02014b50) continue;
    final length = data.getUint16(i + 28, Endian.little);
    if (utf8.decode(bytes.sublist(i + 46, i + 46 + length)) == name) {
      data.setUint32(i + 24, size, Endian.little);
      return;
    }
  }
  fail('missing zip entry: $name');
}

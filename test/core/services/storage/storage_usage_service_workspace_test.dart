import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/core/services/storage/storage_usage_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;

  @override
  Future<String?> getApplicationCachePath() async => p.join(path, 'cache');

  @override
  Future<String?> getTemporaryPath() async => p.join(path, 'tmp');
}

Future<void> _writeSizedFile(Directory root, String relative, int size) async {
  final file = File(p.join(root.path, relative));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(List<int>.filled(size, 1), flush: true);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform previousPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'kelivo_storage_workspace_test_',
    );
    previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = previousPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'workspace categories report isolate-measured bytes and file counts',
    () async {
      await _writeSizedFile(
        tempDir,
        p.join('workspaces', 'ws-1', 'files', 'notes.txt'),
        40,
      );
      await _writeSizedFile(
        tempDir,
        p.join('workspaces', 'ws-1', 'files', 'nested', 'readme.md'),
        20,
      );
      await _writeSizedFile(tempDir, p.join('environment', 'meta.db'), 80);
      await _writeSizedFile(
        tempDir,
        p.join('environment', 'rootfs', 'bin', 'sh'),
        16,
      );
      await _writeSizedFile(
        tempDir,
        p.join('skills', 'skill-a', 'SKILL.md'),
        32,
      );
      await _writeSizedFile(
        tempDir,
        p.join('sessions', 'conv-live', 'attachments', 'a.png'),
        64,
      );
      await _writeSizedFile(
        tempDir,
        p.join('sessions', 'conv-gone', 'outputs', 'out.txt'),
        8,
      );
      await _writeSizedFile(tempDir, p.join('upload', 'keep.pdf'), 12);

      final alpine = await Directory.systemTemp.createTemp(
        'kelivo_storage_alpine_',
      );
      addTearDown(() async {
        if (await alpine.exists()) await alpine.delete(recursive: true);
      });
      await _writeSizedFile(alpine, p.join('etc', 'os-release'), 24);

      final report = await StorageUsageService.computeReport(
        rootfsUsageDirectory: () async => alpine,
      );

      StorageUsageCategory cat(StorageUsageCategoryKey key) =>
          report.categories.singleWhere((category) => category.key == key);

      expect(cat(StorageUsageCategoryKey.workspaceFiles).stats.bytes, 60);
      expect(cat(StorageUsageCategoryKey.workspaceFiles).stats.fileCount, 2);
      expect(cat(StorageUsageCategoryKey.sandboxEnvironment).stats.bytes, 120);
      expect(
        cat(StorageUsageCategoryKey.sandboxEnvironment).stats.fileCount,
        3,
      );
      expect(cat(StorageUsageCategoryKey.skills).stats.bytes, 32);
      expect(cat(StorageUsageCategoryKey.skills).stats.fileCount, 1);
      expect(cat(StorageUsageCategoryKey.sessionFiles).stats.bytes, 72);
      expect(cat(StorageUsageCategoryKey.sessionFiles).stats.fileCount, 2);
      expect(cat(StorageUsageCategoryKey.files).stats.bytes, 12);
      expect(cat(StorageUsageCategoryKey.other).stats.bytes, 0);
      for (final key in [
        StorageUsageCategoryKey.workspaceFiles,
        StorageUsageCategoryKey.skills,
        StorageUsageCategoryKey.sessionFiles,
        StorageUsageCategoryKey.sandboxEnvironment,
      ]) {
        final category = cat(key);
        expect(category.subcategories, isNotEmpty);
        expect(
          category.subcategories.fold<int>(
            0,
            (sum, entry) => sum + entry.stats.bytes,
          ),
          category.stats.bytes,
        );
        expect(
          category.subcategories.fold<int>(
            0,
            (sum, entry) => sum + entry.stats.fileCount,
          ),
          category.stats.fileCount,
        );
        for (final entry in category.subcategories) {
          expect(
            FileSystemEntity.typeSync(entry.path!),
            entry.isDirectory
                ? FileSystemEntityType.directory
                : FileSystemEntityType.file,
          );
        }
      }
      expect(
        cat(
          StorageUsageCategoryKey.sessionFiles,
        ).subcategories.map((s) => s.id),
        ['conv-live', 'conv-gone'],
      );
    },
  );

  test(
    'sandbox measurement dedupes a rootfs nested under environment',
    () async {
      await _writeSizedFile(tempDir, p.join('environment', 'meta.db'), 10);
      await _writeSizedFile(
        tempDir,
        p.join('environment', 'rootfs', 'bin', 'sh'),
        15,
      );
      final nestedRootfs = Directory(
        p.join(tempDir.path, 'environment', 'rootfs'),
      );

      final report = await StorageUsageService.computeReport(
        rootfsUsageDirectory: () async => nestedRootfs,
      );
      final sandbox = report.categories.singleWhere(
        (category) =>
            category.key == StorageUsageCategoryKey.sandboxEnvironment,
      );
      expect(sandbox.stats.bytes, 25);
      expect(sandbox.stats.fileCount, 2);
    },
  );

  test(
    'orphan session cleaner deletes only unmatched conversation dirs',
    () async {
      await _writeSizedFile(
        tempDir,
        p.join('sessions', 'keep-me', 'attachments', 'a.bin'),
        50,
      );
      await _writeSizedFile(
        tempDir,
        p.join('sessions', 'orphan-a', 'outputs', 'gone.bin'),
        30,
      );
      await _writeSizedFile(
        tempDir,
        p.join('sessions', 'orphan-b', 'note.txt'),
        10,
      );

      final before = await StorageUsageService.measureOrphanSessionFiles(
        conversationIds: {'keep-me'},
      );
      expect(before.bytes, 40);
      expect(before.fileCount, 2);

      final cleared = await StorageUsageService.clearOrphanSessionFiles(
        conversationIds: {'keep-me'},
      );
      expect(cleared.bytes, 40);
      expect(cleared.fileCount, 2);

      expect(
        Directory(p.join(tempDir.path, 'sessions', 'keep-me')).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(tempDir.path, 'sessions', 'keep-me', 'attachments', 'a.bin'),
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(p.join(tempDir.path, 'sessions', 'orphan-a')).existsSync(),
        isFalse,
      );
      expect(
        Directory(p.join(tempDir.path, 'sessions', 'orphan-b')).existsSync(),
        isFalse,
      );

      final after = await StorageUsageService.measureOrphanSessionFiles(
        conversationIds: {'keep-me'},
      );
      expect(after.bytes, 0);
      expect(after.fileCount, 0);
    },
  );
}

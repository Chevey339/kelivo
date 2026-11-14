import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/backup_partials.dart';
import 'package:Kelivo/core/services/backup/backup_staging.dart';
import 'package:Kelivo/core/services/backup/local_folder_backup.dart';

import '../../../support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'startup reclaims fresh backup debris without following links or deleting user files',
    () async {
      final tmp = await Directory.systemTemp.createTemp();
      addTearDown(() => tmp.delete(recursive: true));
      final root = await BackupStaging.root(temporary: tmp);
      final user = File('${tmp.path}/user.kbackup')..writeAsStringSync('keep');
      final snap = File('${tmp.path}/snapshots/today.zip')
        ..createSync(recursive: true);
      final live = Directory('${root.path}/working')..createSync();
      final source = File('${live.path}/database')..createSync();
      final debris = [
        File('${root.path}/discard.kbackup'),
        File('${tmp.path}/kelivo_backup_old.kbackup'),
        File('${tmp.path}/kelivo_restore_interrupted.zip'),
        File('${tmp.path}/_bk_kelivo.db'),
      ];
      for (final file in debris) {
        file.createSync();
      }
      if (!Platform.isWindows) {
        await Link('${root.path}/foreign').create(user.path);
      }
      BackupStaging.register(source.path);
      try {
        await BackupStaging.sweep(temporary: tmp);
      } finally {
        BackupStaging.release(source.path);
      }
      expect(source.existsSync(), isTrue);
      expect(snap.existsSync(), isTrue);
      expect(user.readAsStringSync(), 'keep');
      expect(debris.where((f) => f.existsSync()), isEmpty);
    },
  );

  test(
    'marked and aged partials are cleaned; live, recent, unknown and final objects survive',
    () async {
      final prefs = (await createBusinessTestHarness()).preferences;
      final journal = BackupPartials(prefs);
      const scope = 'scope';
      const marked = 'kelivo_backup_marked.zip.partial';
      const old = 'kelivo_backup_old.zip.partial';
      const live = 'kelivo_backup_live.kbackup.partial';
      final now = DateTime.utc(2026, 1, 2);
      final older = now.subtract(const Duration(hours: 7));
      final started = Completer<void>(), finish = Completer<void>();
      await prefs.setStringList(BackupPartials.preferenceKey, [
        '$scope/$marked',
      ]);
      final publish = journal.publish(
        scope: scope,
        name: live,
        write: () async {
          started.complete();
          await finish.future;
        },
        removePartial: () async {},
      );
      await started.future;
      expect(journal.marked(scope), contains(live));
      final deleted = <String>[];
      await journal.sweep(
        scope: scope,
        now: now,
        owns: BackupPartials.isRemoteName,
        list: () async => {
          old: older,
          live: older,
          'kelivo_backup_recent.zip.partial': now,
          'kelivo_backup_no_date.zip.partial': null,
          'kelivo_backup_final.zip': older,
          'foreign.zip.partial': older,
        },
        remove: (n) async => deleted.add(n),
      );
      expect(deleted, unorderedEquals([marked, old]));
      finish.complete();
      await publish;
      expect(journal.marked(scope), isEmpty);
    },
  );

  test(
    'local publication repairs manifest, prunes only after success and skips foreign files',
    () async {
      const id = '12345678-1234-1234-1234-123456789abc';
      final temp = await Directory.systemTemp.createTemp();
      addTearDown(() => temp.delete(recursive: true));
      final dest = await Directory('${temp.path}/chosen').create();
      final src = File('${temp.path}/archive.zip')
        ..writeAsStringSync('archive');
      final local = LocalFolderBackup(dest, id, const BackupPartials(null));
      final epoch = DateTime.utc(2026);
      File output(int i) => File(
        '${dest.path}/kelivo_auto_${id}_${epoch.add(Duration(seconds: i)).microsecondsSinceEpoch}.zip',
      );
      final manual = File('${dest.path}/kelivo_backup_manual.zip')
        ..createSync();
      final other = File(
        '${dest.path}/kelivo_auto_87654321-1234-1234-1234-123456789abc_1767225600000000.zip',
      )..createSync();
      final manifest = File('${dest.path}/.kelivo-autobackup-$id.json');
      output(0).writeAsStringSync('survived crash');
      await local.cleanup();
      expect(
        jsonDecode(manifest.readAsStringSync())['files'],
        contains(output(0).uri.pathSegments.last),
      );
      for (var i = 1; i <= 10; i++) {
        await local.publish(
          src,
          retention: 0,
          now: epoch.add(Duration(seconds: i)),
        );
      }
      expect(output(0).existsSync(), isTrue);
      await expectLater(
        local.publish(
          File('${temp.path}/missing.zip'),
          retention: 3,
          now: epoch.add(const Duration(seconds: 11)),
        ),
        throwsA(isA<FileSystemException>()),
      );
      final token = BackupCancelToken()..cancel();
      addTearDown(token.dispose);
      await expectLater(
        local.publish(
          src,
          retention: 3,
          now: epoch.add(const Duration(seconds: 11)),
          cancelToken: token,
        ),
        throwsA(isA<BackupCancelledException>()),
      );
      expect(output(0).existsSync(), isTrue);
      for (final (i, keep) in [(11, 10), (12, 5), (13, 3)]) {
        await local.publish(
          src,
          retention: keep,
          now: epoch.add(Duration(seconds: i)),
        );
        expect(
          jsonDecode(manifest.readAsStringSync())['files'],
          hasLength(keep),
        );
        expect(output(i - keep).existsSync(), isFalse);
        expect(output(i).readAsStringSync(), 'archive');
      }
      expect(manual.existsSync() && other.existsSync(), isTrue);
      expect(
        dest.listSync().where((f) => f.path.endsWith('.partial')),
        isEmpty,
      );
    },
  );
}

import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';
import 'package:Kelivo/shared/widgets/restore_failure_screen.dart';
import '../../support/recovery_snapshot_fixture.dart';
import 'restore_failure_screen_test.dart' as helpers;

class _TemporaryPaths extends PathProviderPlatform {
  _TemporaryPaths(this.root);
  final Directory root;
  @override
  Future<String?> getTemporaryPath() async => '${root.path}/tmp';
}

class _UnavailableTemporaryDirectory implements Directory {
  _UnavailableTemporaryDirectory(this.path, this.diskFull);
  final bool diskFull;
  @override
  final String path;
  @override
  Future<Directory> createTemp([String? prefix]) async =>
      throw FileSystemException(
        diskFull ? 'No space left on device' : 'Permission denied',
        path,
        OSError(
          'temporary I/O failure',
          diskFull
              ? (Platform.isWindows ? 112 : 28)
              : (Platform.isWindows ? 5 : 13),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'newer database copies guide an app update without calling them invalid',
    (tester) async {
      helpers.useTallSurface(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('newer-recovery-'),
      ))!;
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TemporaryPaths(root);
      addTearDown(() => PathProviderPlatform.instance = previousPaths);
      addTearDown(() => root.delete(recursive: true));
      final snapshot = File(
        '${root.path}/kelivo-snapshot-1792421104232879.zip',
      );
      final database = File('${root.path}/kelivo 2.db');
      late List<int> retainedDatabase;
      late List<int> retainedSnapshot;
      await tester.runAsync(() async {
        await writeRecoverySnapshot(snapshot);
        final zip = ZipDecoder().decodeBytes(await snapshot.readAsBytes());
        await database.writeAsBytes(
          zip.findFile('database/kelivo.db')!.readBytes()!,
        );
        final raw = sqlite.sqlite3.open(database.path);
        try {
          raw.userVersion = 6;
        } finally {
          raw.close();
        }
        retainedDatabase = await database.readAsBytes();
        final manifest =
            jsonDecode(utf8.decode(zip.findFile('manifest.json')!.readBytes()!))
                as Map<String, dynamic>;
        (manifest['database'] as Map)['schemaVersion'] = 6;
        (manifest['entries'] as Map)['database/kelivo.db'] = {
          'bytes': retainedDatabase.length,
          'sha256': sha256.convert(retainedDatabase).toString(),
        };
        final replacement = Archive();
        for (final file in zip.files.where((f) => f.isFile)) {
          final data = file.name == 'manifest.json'
              ? utf8.encode(jsonEncode(manifest))
              : file.name == 'database/kelivo.db'
              ? retainedDatabase
              : file.readBytes()!;
          replacement.addFile(ArchiveFile(file.name, data.length, data));
        }
        retainedSnapshot = ZipEncoder().encode(replacement);
        await snapshot.writeAsBytes(retainedSnapshot);
        await expectLater(
          DataSync.inspectRecoverySnapshot(snapshot),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'code',
              'manifest_database_schema_too_new',
            ),
          ),
        );
        await expectLater(
          DataSync.prepareRecoveryDatabaseArchive(database),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'code',
              'database_schema_too_new',
            ),
          ),
        );
      });
      await tester.pumpWidget(
        helpers.wrap(
          RestoreFailureScreen(
            report: helpers.reportFor(
              StateError('database_missing_with_prior_data'),
            ),
            restart: () async {},
            appDataDirectory: root,
            appVersionLoader: helpers.stubVersion,
          ),
        ),
      );
      await helpers.settleDiagnostics(tester);
      expect(
        find.textContaining('Update Kelivo before restoring them'),
        findsOneWidget,
      );
      expect(find.textContaining('validation failed'), findsNothing);
      expect(find.text('Choose a copy to recover'), findsNothing);
      await tester.runAsync(() async {
        expect(await database.readAsBytes(), retainedDatabase);
        expect(await snapshot.readAsBytes(), retainedSnapshot);
      });
    },
  );
  for (final diskFull in [true, false]) {
    testWidgets(
      '${diskFull ? "disk-full" : "access-denied"} checks preserve copies and can be retried on the same screen',
      (tester) async {
        helpers.useTallSurface(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('release132-ui-'),
        ))!;
        addTearDown(() => root.delete(recursive: true));
        final snapshot = File(
          '${root.path}/snapshots 2/kelivo-snapshot-1792421104232879.zip',
        );
        String? before;
        await tester.runAsync(() async {
          await writeRecoverySnapshot(snapshot);
          final info = await DataSync.inspectRecoverySnapshot(snapshot);
          expect(info.conversationCount, 2);
          expect(info.messageCount, 42);
          before = (await sha256.bind(snapshot.openRead()).first).toString();
        });
        Widget screen(Key key) => helpers.wrap(
          RestoreFailureScreen(
            key: key,
            report: helpers.reportFor(
              StateError('database_missing_with_prior_data'),
            ),
            restart: () async {},
            appDataDirectory: root,
            appVersionLoader: helpers.stubVersion,
          ),
        );
        final temporaryPath = Directory.systemTemp.path;
        await IOOverrides.runZoned(
          () async {
            await tester.pumpWidget(screen(const ValueKey('full')));
            await helpers.settleDiagnostics(tester);
            expect(
              find.text('Some free space is needed'),
              diskFull ? findsOneWidget : findsNothing,
            );
            expect(
              find.textContaining(
                diskFull
                    ? 'This does not mean they are damaged'
                    : 'Some local copies could not be checked yet',
              ),
              findsOneWidget,
            );
            expect(
              find.textContaining(
                'validation failed. The original file has been kept.',
              ),
              findsNothing,
            );
            expect(find.text('Choose a copy to recover'), findsNothing);
            expect(
              find.textContaining('No space left on device'),
              findsNothing,
            );
            if (diskFull) {
              await tester.ensureVisible(find.text('Other options'));
              await tester.tap(find.text('Other options'));
              await tester.pumpAndSettle();
              final reset = find.widgetWithText(
                OutlinedButton,
                'Start with an empty chat list',
              );
              expect(tester.widget<OutlinedButton>(reset).onPressed, isNull);
            }
          },
          getSystemTempDirectory: () =>
              _UnavailableTemporaryDirectory(temporaryPath, diskFull),
        );
        await tester.runAsync(() async {
          expect(
            (await sha256.bind(snapshot.openRead()).first).toString(),
            before,
          );
          expect(
            (await DataSync.inspectRecoverySnapshot(snapshot)).messageCount,
            42,
          );
        });
        await tester.ensureVisible(find.text('Check local copies again'));
        await tester.tap(find.text('Check local copies again'));
        await tester.pump();
        await helpers.settleDiagnostics(tester);
        expect(find.textContaining('Found 1 validated copies'), findsOneWidget);
        expect(find.text('Choose a copy to recover'), findsOneWidget);
      },
    );
  }
}

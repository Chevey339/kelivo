import 'dart:async';
import 'dart:isolate';

import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/core/services/storage/attachment_file_lock.dart';
import 'package:Kelivo/core/services/storage/storage_usage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../support/storage_images_test_fixture.dart';

AttachmentReferenceReader _workerReader(SendPort appIsolate, String? path) =>
    () {
      if (Isolate.current.controlPort == appIsolate) {
        throw StateError('Temporary history was parsed on the app isolate');
      }
      return {
        if (path != null) path: {'draft': 'Temporary conversation'},
      };
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageImagesFixture fixture;
  setUp(() async => fixture = await StorageImagesFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'directory refreshes share one walk and discard a superseded inventory',
    () async {
      final session = StorageUploadSession();
      final original = await fixture.file('upload/old.txt');
      final first = session.refreshDirectory();
      session.invalidateDirectory();
      expect(identical(session.refreshDirectory(), first), isTrue);
      session.invalidateDirectory();
      expect(identical(session.refreshDirectory(), first), isTrue);
      expect(await first, isNull);
      expect(session.directory.isEmpty, isTrue);

      await original.delete();
      await fixture.file('upload/new.txt');
      final next = session.refreshDirectory();
      expect(identical(session.refreshDirectory(), next), isTrue);
      expect((await next)!.files.single.name, 'new.txt');
      expect(session.directory.files.single.name, 'new.txt');
    },
  );

  test(
    'temporary history is parsed once per revision and checked afresh on deletion in a worker',
    () async {
      final pdf = await fixture.file('upload/manual.pdf');
      final owner = Object();
      final appIsolate = Isolate.current.controlPort;
      var captures = 0;
      String? reference;
      AttachmentFileLock.registerTransientOwner(
        owner,
        capture: () {
          captures++;
          return _workerReader(appIsolate, reference);
        },
        active: () => false,
      );
      addTearDown(() => AttachmentFileLock.unregisterTransientOwner(owner));
      final session = StorageUploadSession(
        readVersion: BusinessRepository(
          fixture.database,
        ).readStorageChangeVersion,
      )..reset(await StorageUsageService.readUploadFiles());
      final results = await Future.wait([session.inspect(), session.inspect()]);
      expect(identical(await session.inspect(), results.first), isTrue);
      expect(results.last.files.single.canDelete, isTrue);
      expect(captures, 1);
      reference = pdf.path;
      // Destructive actions read live owners under the lock even if the page
      // still has an older, deletable row.
      expect(
        await StorageUsageService.deleteUploadFiles([pdf.path], images: false),
        0,
      );
      expect(await pdf.exists(), isTrue);
      AttachmentFileLock.notifyTransientChanged();
      expect((await session.inspect()).files.single.isInUse, isTrue);
      expect(captures, 3);
    },
  );

  for (final broken in [false, true]) {
    test(
      'writes during inspection supersede both labels and errors, broken=$broken',
      () async {
        final pdf = await fixture.file('upload/manual.pdf');
        final part = FilePart(uri: pdf.uri.toString(), name: 'Manual');
        await fixture.message([const FilePart(uri: 'old.txt', name: 'Old')]);
        Future<void> setFilePayload(String payload) =>
            fixture.database.customStatement(
              "UPDATE message_part_rows SET payload = ? WHERE kind = 'file'",
              [payload],
            );
        if (broken) await setFilePayload('broken');
        final business = BusinessRepository(fixture.database);
        final checked = Completer<void>(), release = Completer<void>();
        var reads = 0;
        final session = StorageUploadSession(
          readVersion: () async {
            if (++reads == 2) {
              checked.complete();
              await release.future;
            }
            return business.readStorageChangeVersion();
          },
        )..reset(await StorageUsageService.readUploadFiles());
        final pending = session.inspect();
        try {
          await checked.future;
          await setFilePayload(part.encodePayload());
          expect(identical(session.inspect(), pending), isTrue);
        } finally {
          release.complete();
        }
        expect((await pending).files.single.isInUse, isNull);
        expect((await session.inspect()).files.single.isInUse, isTrue);
      },
    );
  }

  test(
    'inventory is independent of history and both categories share one checked snapshot',
    () async {
      final photo = await fixture.file('images/photo.png');
      final pdf = await fixture.file('upload/manual.pdf');
      await fixture.message([TextPart('[Manual](${pdf.uri})')]);
      final report = await StorageUsageService.computeReport(
        includeUploadFiles: true,
      );
      final files = report.uploads;
      expect(files.images.single.path, photo.path);
      expect(files.files.single.path, pdf.path);
      expect(files.files.single.bytes, await pdf.length());
      expect(files.files.single.modifiedAt, (await pdf.stat()).modified);
      expect(files.files.single.isInUse, isNull);
      expect(files.files.single.canDelete, isFalse);

      final session = StorageUploadSession(
        readVersion: BusinessRepository(
          fixture.database,
        ).readStorageChangeVersion,
      )..reset(files);
      final results = await Future.wait([session.inspect(), session.inspect()]);
      expect(identical(results.first, results.last), isTrue);
      expect(results.first.files.single.isInUse, isTrue);
      expect(results.first.images.single.canDelete, isTrue);
      await session.refreshDirectory();
      expect(identical(await session.inspect(), results.first), isTrue);

      const update =
          "UPDATE message_part_rows SET payload = ? WHERE kind = 'text'";
      await fixture.database.customStatement(update, [
        '![Image](${photo.uri})',
      ]);
      final changed = await session.inspect();
      expect(changed.images.single.isInUse, isTrue);
      expect(changed.files.single.canDelete, isTrue);

      final other = sqlite3.open(
        '${fixture.root.path}/kelivo.db',
        mode: OpenMode.readWrite,
      );
      try {
        other.execute(update, ['[Manual](${pdf.uri})']);
      } finally {
        other.close();
      }
      final external = await session.inspect();
      expect(external.images.single.canDelete, isTrue);
      expect(external.files.single.isInUse, isTrue);
      session.reset(files);
      expect(identical(await session.inspect(), external), isFalse);
    },
  );

  test(
    'empty categories skip the reference database and failures can be retried',
    () async {
      final pdf = await fixture.file('upload/manual.pdf');
      final part = FilePart(uri: pdf.uri.toString(), name: 'manual.pdf');
      await fixture.message([part]);
      const update =
          "UPDATE message_part_rows SET payload = ? WHERE kind = 'file'";
      await fixture.database.customStatement(update, ['broken']);
      expect(
        await StorageUsageService.listUploadEntries(images: true),
        isEmpty,
      );

      final session = StorageUploadSession(
        readVersion: BusinessRepository(
          fixture.database,
        ).readStorageChangeVersion,
      )..reset(await StorageUsageService.readUploadFiles());
      await expectLater(session.inspect(), throwsFormatException);
      expect(session.directory.files.single.canDelete, isFalse);
      expect(session.directory.files.single.name, 'manual.pdf');
      await fixture.database.customStatement(update, [part.encodePayload()]);
      expect((await session.inspect()).files.single.isInUse, isTrue);
    },
  );
}

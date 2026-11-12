import 'dart:convert';
import 'dart:io';

import 'package:Kelivo/core/database/chat_database_repository.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/models/conversation.dart';
import 'package:Kelivo/core/models/message_part.dart';
import 'package:Kelivo/shared/markdown/markdown_image_sources.dart';
import 'package:Kelivo/core/services/backup/restore_business_lease.dart';
import 'package:Kelivo/core/services/storage/windows_data_directory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../support/recovery_fault_durability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, source, target;
  late WindowsDataDirectory storage;
  late FaultDurability io;

  Future<void> write(
    String relative,
    String text, {
    Directory? inDirectory,
  }) async {
    final file = File(p.join((inDirectory ?? source).path, relative));
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<void> restart() async {
    await storage.close();
    storage = WindowsDataDirectory(supportDirectory: source, durability: io);
    await storage.initialize();
  }

  String preference(Directory directory) {
    final db = sqlite3.open(p.join(directory.path, 'kelivo.db'));
    try {
      return db.select('SELECT value FROM preference_rows').single['value']
          as String;
    } finally {
      db.close();
    }
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo-directory-test-');
    root = Directory(await root.resolveSymbolicLinks());
    source = await Directory(p.join(root.path, 'AppData')).create();
    target = await Directory(p.join(root.path, 'Other drive 中文')).create();
    final db = sqlite3.open(p.join(source.path, 'kelivo.db'));
    db.execute(
      'CREATE TABLE preference_rows (key TEXT PRIMARY KEY, value TEXT)',
    );
    db.execute('INSERT INTO preference_rows VALUES (?, ?)', [
      'avatar',
      jsonEncode(p.join(source.path, 'avatars', 'me.png')),
    ]);
    db.close();
    await write('avatars/me.png', 'avatar');
    await write('upload/attachment.txt', 'attachment');
    await write('sessions/one/outputs/result.txt', 'result');
    await write('skills/example/SKILL.md', 'skill');
    await write('snapshots/retained.zip', 'snapshot');
    await write(
      'browser/state.json',
      jsonEncode({
        'version': 1,
        'url': File(
          p.join(source.path, 'sessions/one/outputs/result.txt'),
        ).uri.toString(),
      }),
    );
    await write('shared_preferences.json', '{"window_width_v1":1000}');
    io = FaultDurability();
    storage = WindowsDataDirectory(supportDirectory: source, durability: io);
    await storage.initialize();
  });

  tearDown(() async {
    await storage.close();
    await root.delete(recursive: true);
  });

  test(
    'ordinary launches keep the default directory until a user schedules a move',
    () async {
      final originalDatabase = await File(
        p.join(source.path, 'kelivo.db'),
      ).readAsBytes();
      await write(
        'existing.txt',
        'an unrelated directory',
        inDirectory: target,
      );
      for (var launch = 0; launch < 3; launch++) {
        await restart();
        expect((await storage.directory).path, source.path);
        expect((await storage.state).active, isNull);
        expect((await storage.state).pending, isNull);
        expect((await storage.state).previous, isNull);
      }
      expect(
        await File(p.join(source.path, 'kelivo.db')).readAsBytes(),
        originalDatabase,
      );
      expect(
        await File(
          p.join(source.path, WindowsDataDirectory.identityName),
        ).exists(),
        isFalse,
      );
      expect(
        await File(p.join(target.path, 'existing.txt')).readAsString(),
        'an unrelated directory',
      );
      expect(await File(p.join(target.path, 'kelivo.db')).exists(), isFalse);
    },
  );

  test('scheduling keeps live paths unchanged until a cold restart', () async {
    await storage.schedule(target);
    expect((await storage.directory).path, source.path);
    expect(await File(p.join(target.path, 'kelivo.db')).exists(), isFalse);
    expect((await storage.state).pending!.path, target.path);
    await restart();
    expect((await storage.directory).path, target.path);
    expect((await storage.state).pending, isNull);
    expect((await storage.state).previous!.path, source.path);
    expect(
      jsonDecode(preference(target)),
      p.join(target.path, 'avatars/me.png'),
    );
    expect(
      jsonDecode(preference(source)),
      p.join(source.path, 'avatars/me.png'),
    );
    for (final path in [
      'avatars/me.png',
      'upload/attachment.txt',
      'sessions/one/outputs/result.txt',
      'skills/example/SKILL.md',
      'snapshots/retained.zip',
    ]) {
      expect(
        await File(p.join(target.path, path)).readAsString(),
        await File(p.join(source.path, path)).readAsString(),
      );
    }
    expect(
      await File(p.join(target.path, 'shared_preferences.json')).exists(),
      isFalse,
    );
    final browser = jsonDecode(
      await File(p.join(target.path, 'browser/state.json')).readAsString(),
    );
    expect(
      browser['url'],
      File(
        p.join(target.path, 'sessions/one/outputs/result.txt'),
      ).uri.toString(),
    );
  });

  test(
    'cleanup requires successful admission and keeps bootstrap settings',
    () async {
      await storage.schedule(target);
      await restart();
      await expectLater(storage.cleanPrevious(), throwsStateError);
      await storage.confirmStartup();
      await storage.cleanPrevious();
      expect(await File(p.join(source.path, 'kelivo.db')).exists(), isFalse);
      expect(await Directory(p.join(source.path, 'avatars')).exists(), isFalse);
      expect(
        await File(p.join(source.path, 'shared_preferences.json')).exists(),
        isTrue,
      );
      expect(
        await Directory(
          p.join(source.path, WindowsDataDirectory.controlName),
        ).exists(),
        isTrue,
      );
      expect(
        await File(p.join(target.path, 'upload/attachment.txt')).readAsString(),
        'attachment',
      );
      await restart();
      expect((await storage.directory).path, target.path);
      expect((await storage.state).previous, isNull);
    },
  );

  test(
    'can move back to the default folder after cleaning the old copy',
    () async {
      await storage.schedule(target);
      await restart();
      await storage.confirmStartup();
      await storage.cleanPrevious();
      await storage.schedule(source);
      await restart();
      expect((await storage.directory).path, source.path);
      expect(
        jsonDecode(preference(source)),
        p.join(source.path, 'avatars/me.png'),
      );
      await storage.confirmStartup();
      await storage.cleanPrevious();
      expect(await File(p.join(target.path, 'kelivo.db')).exists(), isFalse);
    },
  );

  test(
    'cancel before restart performs no copy and leaves source intact',
    () async {
      await storage.schedule(target);
      await storage.cancel();
      await restart();
      expect((await storage.directory).path, source.path);
      expect((await storage.state).pending, isNull);
      expect(await target.list().isEmpty, isTrue);
    },
  );

  test(
    'copy interruption is resumable and does not publish a partial copy',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (file.path == p.join(target.path, 'upload/attachment.txt')) {
          throw const FileSystemException('disk full');
        }
      };
      await expectLater(restart(), throwsA(isA<FileSystemException>()));
      expect((await storage.directory).path, source.path);
      expect((await storage.state).pending, isNotNull);
      io.onSync = null;
      await restart();
      expect((await storage.directory).path, target.path);
      expect(
        await File(p.join(target.path, 'upload/attachment.txt')).readAsString(),
        'attachment',
      );
    },
  );

  test(
    'cancel retains a partial destination and permits a different move',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (file.path == p.join(target.path, 'kelivo.db')) {
          throw StateError('stop');
        }
      };
      await expectLater(restart(), throwsStateError);
      io.onSync = null;
      await write('user-file.txt', 'keep this', inDirectory: target);
      await storage.cancel();
      await restart();
      expect((await storage.directory).path, source.path);
      expect((await storage.state).pending, isNull);
      expect(await File(p.join(target.path, 'kelivo.db')).exists(), isTrue);
      expect(
        await File(p.join(target.path, 'user-file.txt')).readAsString(),
        'keep this',
      );
      final another = await Directory(p.join(root.path, 'another')).create();
      await storage.schedule(another);
      await restart();
      expect((await storage.directory).path, another.path);
    },
  );

  test(
    'late publication error resolves to the published destination',
    () async {
      await storage.schedule(target);
      io.afterRename = (path) async {
        if (p.basename(path) == 'state-000000000002.json') {
          throw StateError('power loss after rename');
        }
      };
      await expectLater(restart(), throwsStateError);
      io.afterRename = null;
      await restart();
      expect((await storage.directory).path, target.path);
      expect((await storage.state).pending, isNull);
      expect((await storage.state).previous!.path, source.path);
    },
  );

  test(
    'missing configured directory does not create it or fall back',
    () async {
      await storage.schedule(target);
      await restart();
      final moved = await target.rename('${target.path}-offline');
      await expectLater(restart(), throwsStateError);
      expect(await target.exists(), isFalse);
      await moved.rename(target.path);
      await restart();
      expect((await storage.directory).path, target.path);
    },
  );

  test('empty replacement at selected path fails identity check', () async {
    await storage.schedule(target);
    await restart();
    await target.rename('${target.path}-removed');
    await target.create();
    await expectLater(restart(), throwsStateError);
    expect(await target.list().isEmpty, isTrue);
  });

  test('rejects nonempty, overlapping and network destinations', () async {
    await write('keep.txt', 'unrelated', inDirectory: target);
    await expectLater(storage.schedule(target), throwsStateError);
    await expectLater(storage.schedule(source), throwsStateError);
    await expectLater(storage.schedule(root), throwsStateError);
    final child = await Directory(p.join(source.path, 'nested')).create();
    await expectLater(storage.schedule(child), throwsStateError);
    await expectLater(
      storage.schedule(Directory(r'\\server\share')),
      throwsStateError,
    );
    expect(
      await File(p.join(target.path, 'keep.txt')).readAsString(),
      'unrelated',
    );
    expect((await storage.state).pending, isNull);
  });

  test('destination changed after scheduling is never overwritten', () async {
    await storage.schedule(target);
    await write('mine.txt', 'keep', inDirectory: target);
    await expectLater(restart(), throwsStateError);
    await storage.cancel();
    expect(await File(p.join(target.path, 'mine.txt')).readAsString(), 'keep');
    expect((await storage.directory).path, source.path);
  });

  test(
    'changed source prevents old-copy cleanup before any deletion',
    () async {
      await storage.schedule(target);
      await restart();
      await storage.confirmStartup();
      await write('upload/attachment.txt', 'updated after move');
      await expectLater(storage.cleanPrevious(), throwsStateError);
      expect(
        await File(p.join(source.path, 'avatars/me.png')).exists(),
        isTrue,
      );
      expect(
        await File(p.join(source.path, 'upload/attachment.txt')).readAsString(),
        'updated after move',
      );
      expect((await storage.state).previous, isNotNull);
    },
  );

  test('a new WAL in retained source prevents cleanup', () async {
    await storage.schedule(target);
    await restart();
    await storage.confirmStartup();
    await write('kelivo.db-wal', 'new writes from another program');
    await expectLater(storage.cleanPrevious(), throwsStateError);
    expect(await File(p.join(source.path, 'kelivo.db-wal')).exists(), isTrue);
    expect(await File(p.join(source.path, 'kelivo.db')).exists(), isTrue);
  });

  test('another business process owning the source prevents copying', () async {
    await storage.schedule(target);
    final lease = await RestoreBusinessLease.acquire(appDataDirectory: source);
    try {
      await expectLater(
        restart(),
        throwsA(isA<RestoreBusinessLeaseUnavailable>()),
      );
    } finally {
      await lease.close();
    }
    expect((await storage.directory).path, source.path);
    expect(await File(p.join(target.path, 'kelivo.db')).exists(), isFalse);
  });

  test(
    'corrupt latest locator fails instead of reverting to earlier data',
    () async {
      await storage.schedule(target);
      await restart();
      await File(
        p.join(
          source.path,
          WindowsDataDirectory.controlName,
          'state-000000000002.json',
        ),
      ).writeAsString('{');
      await expectLater(restart(), throwsFormatException);
      expect(await File(p.join(target.path, 'kelivo.db')).exists(), isTrue);
    },
  );

  test(
    'moved production schema can reopen through the normal repository',
    () async {
      await File(p.join(source.path, 'kelivo.db')).delete();
      final repository = ChatDatabaseRepository.open(
        file: File(p.join(source.path, 'kelivo.db')),
      );
      await repository.ensureReady();
      final oldImage = p.join(source.path, 'avatars/me.png');
      await repository.putMigrationBatch(
        conversations: [
          Conversation(
            id: 'chat',
            title: 'Retained chat',
            extras: {'workspace.cwd': p.join(source.path, 'sessions/one')},
          ),
        ],
        messages: [
          (
            message: ChatMessage(
              id: 'message',
              conversationId: 'chat',
              role: 'assistant',
              parts: [
                TextPart('![image]($oldImage)'),
                ImagePart(uri: oldImage, assetId: 'asset'),
                ReasoningPart('Signed reasoning mentioning $oldImage'),
                AssistantRoundEndPart(
                  reasoningDetails: [
                    {
                      'type': 'reasoning.text',
                      'text': oldImage,
                      'signature': 'signature',
                    },
                  ],
                ),
              ],
            ),
            messageOrder: 0,
          ),
        ],
        toolEventsByMessageId: const {},
        geminiSignaturesByMessageId: const {},
      );
      await repository.registerAsset(
        id: 'asset',
        contentHash: 'image-content',
        path: oldImage,
        byteSize: 6,
        thumbnailPath: oldImage,
      );
      await repository.close();
      await storage.schedule(target);
      await restart();
      final moved = ChatDatabaseRepository.open(
        file: File(p.join(target.path, 'kelivo.db')),
      );
      try {
        await moved.ensureReady();
        final message = (await moved.getMessage('message'))!;
        final newImage = p.join(target.path, 'avatars/me.png');
        expect(message.parts.whereType<ImagePart>().single.uri, newImage);
        expect(markdownImageSources(message.content), [newImage]);
        expect(
          message.parts.whereType<ReasoningPart>().single.text,
          'Signed reasoning mentioning $oldImage',
        );
        expect(
          message.parts
              .whereType<AssistantRoundEndPart>()
              .single
              .reasoningDetails!
              .single['text'],
          oldImage,
        );
        final db = sqlite3.open(p.join(target.path, 'kelivo.db'));
        try {
          final asset = db.select(
            'SELECT path, thumbnail_path FROM asset_rows WHERE id = ?',
            ['asset'],
          ).single;
          expect(asset['path'], newImage);
          expect(asset['thumbnail_path'], newImage);
          final conversation = jsonDecode(
            db
                    .select('SELECT extras_json FROM conversation_rows')
                    .single['extras_json']
                as String,
          );
          expect(
            conversation['workspace.cwd'],
            p.join(target.path, 'sessions/one'),
          );
        } finally {
          db.close();
        }
      } finally {
        await moved.close();
      }
      await storage.confirmStartup();
      expect((await storage.state).confirmed, isTrue);
    },
  );

  test(
    'retry after path rewriting recopies the original database family',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (p.basename(file.path).startsWith('state-000000000002.json.')) {
          throw StateError('interrupted before activation');
        }
      };
      await expectLater(restart(), throwsStateError);
      expect(
        jsonDecode(preference(source)),
        p.join(source.path, 'avatars/me.png'),
      );
      expect(
        jsonDecode(preference(target)),
        p.join(target.path, 'avatars/me.png'),
      );
      expect((await storage.directory).path, source.path);
      io.onSync = null;
      await restart();
      expect((await storage.directory).path, target.path);
      expect(
        jsonDecode(preference(target)),
        p.join(target.path, 'avatars/me.png'),
      );
    },
  );

  test(
    'identity publication interrupted before scheduling can be retried',
    () async {
      io.afterRename = (path) async {
        if (p.basename(path) == WindowsDataDirectory.identityName) {
          throw StateError('identity durable, intent not written');
        }
      };
      await expectLater(storage.schedule(target), throwsStateError);
      io.afterRename = null;
      await storage.schedule(target);
      await restart();
      expect((await storage.directory).path, target.path);
    },
  );

  test(
    'a directory substituted with a link cannot redirect a resumed copy',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (file.path == p.join(target.path, 'upload/attachment.txt')) {
          throw StateError('pause');
        }
      };
      await expectLater(restart(), throwsStateError);
      io.onSync = null;
      final external = await Directory(p.join(root.path, 'outside')).create();
      await File(
        p.join(external.path, 'attachment.txt'),
      ).writeAsString('external');
      await Directory(p.join(target.path, 'upload')).delete(recursive: true);
      await Link(p.join(target.path, 'upload')).create(external.path);
      await expectLater(restart(), throwsStateError);
      expect(
        await File(p.join(external.path, 'attachment.txt')).readAsString(),
        'external',
      );
    },
    skip: Platform.isWindows ? 'Requires Windows symlink privileges' : false,
  );

  test('copies committed WAL contents without modifying the source', () async {
    final writer = sqlite3.open(p.join(source.path, 'kelivo.db'));
    writer.execute('PRAGMA journal_mode=WAL');
    writer.execute('PRAGMA wal_autocheckpoint=0');
    writer.execute('CREATE TABLE wal_rows (value TEXT)');
    writer.execute("INSERT INTO wal_rows VALUES ('committed in WAL')");
    try {
      expect(
        await File(p.join(source.path, 'kelivo.db-wal')).length(),
        greaterThan(0),
      );
      await storage.schedule(target);
      await restart();
      final moved = sqlite3.open(p.join(target.path, 'kelivo.db'));
      try {
        expect(
          moved.select('SELECT value FROM wal_rows').single['value'],
          'committed in WAL',
        );
      } finally {
        moved.close();
      }
      expect(
        writer.select('SELECT value FROM wal_rows').single['value'],
        'committed in WAL',
      );
    } finally {
      writer.close();
    }
  });

  test(
    'a launch without the bootstrap lease cannot cancel another move',
    () async {
      await storage.schedule(target);
      final competing = WindowsDataDirectory(supportDirectory: source);
      await expectLater(
        competing.initialize(),
        throwsA(isA<RestoreBusinessLeaseUnavailable>()),
      );
      await expectLater(competing.cancel(), throwsStateError);
      expect(competing.ownsControlLease, isFalse);
      await restart();
      expect((await storage.directory).path, target.path);
    },
  );

  test(
    'malformed cleanup inventory leaves every original file intact',
    () async {
      await storage.schedule(target);
      await restart();
      await storage.confirmStartup();
      final id = (await storage.state).active!.id;
      final file = File(
        p.join(
          source.path,
          WindowsDataDirectory.controlName,
          'manifest-$id.json',
        ),
      );
      final manifest =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      manifest['kelivo.db']['kind'] = 'unknown';
      await file.writeAsString(jsonEncode(manifest));
      await expectLater(storage.cleanPrevious(), throwsFormatException);
      expect(await File(p.join(source.path, 'kelivo.db')).exists(), isTrue);
      expect(
        await File(p.join(source.path, 'upload/attachment.txt')).readAsString(),
        'attachment',
      );
    },
  );

  test(
    'read-only source assets migrate and can be explicitly cleaned',
    () async {
      final readOnly = File(p.join(source.path, 'readonly.txt'));
      await readOnly.writeAsString('read-only asset');
      Future<void> setReadOnly(bool enabled) async {
        if (!await readOnly.exists()) return;
        final result = Platform.isWindows
            ? await Process.run('attrib', [
                enabled ? '+R' : '-R',
                readOnly.path,
              ])
            : await Process.run('chmod', [
                enabled ? '444' : '644',
                readOnly.path,
              ]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }

      addTearDown(() => setReadOnly(false));
      await setReadOnly(true);
      await storage.schedule(target);
      await restart();
      expect(await readOnly.readAsString(), 'read-only asset');
      expect((await readOnly.stat()).mode & 0x80, 0);
      final copied = File(p.join(target.path, 'readonly.txt'));
      expect(await copied.readAsString(), 'read-only asset');
      await copied.writeAsString('editable after moving');
      await storage.confirmStartup();
      await storage.cleanPrevious();
      expect(await readOnly.exists(), isFalse);
      expect(await copied.readAsString(), 'editable after moving');
    },
  );

  test(
    'failed streaming copy leaves a known partial file that can be retried',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (file.path == p.join(target.path, 'avatars/me.png')) {
          await File(p.join(source.path, 'upload/attachment.txt')).delete();
        }
      };
      await expectLater(restart(), throwsA(isA<FileSystemException>()));
      final partial = File(p.join(target.path, 'upload/attachment.txt'));
      expect(await partial.exists(), isTrue);
      expect(await partial.length(), 0);
      expect(await Directory(p.join(target.path, 'upload')).list().length, 1);
      await write('upload/attachment.txt', 'attachment');
      io.onSync = null;
      await restart();
      expect((await storage.directory).path, target.path);
      expect(await partial.readAsString(), 'attachment');
    },
  );

  test(
    'an unavailable partial destination cannot prevent cancellation',
    () async {
      await storage.schedule(target);
      io.onSync = (file) async {
        if (file.path == p.join(target.path, 'kelivo.db')) {
          throw StateError('stop');
        }
      };
      await expectLater(restart(), throwsStateError);
      io.onSync = null;
      final offline = await target.rename('${target.path}-offline');
      await storage.cancel();
      await restart();
      expect((await storage.directory).path, source.path);
      expect((await storage.state).pending, isNull);
      expect(await File(p.join(offline.path, 'kelivo.db')).exists(), isTrue);
    },
  );
}

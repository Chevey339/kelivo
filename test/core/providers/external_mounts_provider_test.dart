import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/extension_entity_store.dart';
import 'package:Kelivo/core/models/workspace_directory_access.dart';
import 'package:Kelivo/core/providers/external_mounts_provider.dart';
import 'package:Kelivo/core/services/sandbox/workspace_channel.dart';
import '../services/sandbox/sandbox_channel_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ExtensionEntityStore store;
  late SandboxChannelHarness harness;
  late ExternalMountsProvider provider;
  late Map<String, String> sources;
  late List<Map<dynamic, dynamic>> native;
  late List<String> released;
  var failNextMount = false;

  WorkspaceDirectory directory(String token) => WorkspaceDirectory(
    path: sources[token]!,
    access: WorkspaceDirectoryAccess(platform: 'android', token: token),
  );

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    db = AppDatabase(NativeDatabase.memory());
    store = ExtensionEntityStore(db);
    sources = {'a': '/storage/A', 'b': '/storage/B'};
    native = [];
    released = [];
    failNextMount = false;
    harness = SandboxChannelHarness();
    harness.handler = (call) {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      switch (call.method) {
        case 'resolveDirectory':
          final token = args['token'] as String;
          if (!sources.containsKey(token)) {
            throw PlatformException(code: 'external_folder_unavailable');
          }
          return {'path': sources[token], 'token': token};
        case 'setExternalMounts':
          if (failNextMount) {
            failNextMount = false;
            throw PlatformException(code: 'mount_failed');
          }
          native = [for (final item in args['mounts'] as List) item as Map];
          return null;
        case 'releaseDirectory':
          released.add(args['token'] as String);
          return null;
      }
      return null;
    };
    harness.install();
    provider = ExternalMountsProvider(store: store, channel: harness.channel);
    await provider.loaded;
  });

  tearDown(() async {
    provider.dispose();
    harness.dispose();
    await db.close();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'mounts are independent, persistent, named and individually writable',
    () async {
      await provider.add(directory('a'), name: 'Notes', readOnly: true);
      await provider.add(directory('b'), name: 'Output', readOnly: false);
      expect(native.map((m) => m['guest']), [
        '/mounts/Notes',
        '/mounts/Output',
      ]);
      expect(native.first['readOnly'], true);
      expect(native.last['readOnly'], isNot(true));
      expect(
        await store.listByKind(ExtensionEntityStore.kindWorkspace),
        isEmpty,
      );
      provider.dispose();
      provider = ExternalMountsProvider(store: store, channel: harness.channel);
      await provider.loaded;
      expect(provider.entries.map((m) => m.name), ['Notes', 'Output']);
      expect(provider.activeMounts.first.readOnly, true);
    },
  );

  test(
    'rename and toggle replace native snapshot; unmount releases only its grant',
    () async {
      await provider.add(directory('a'), name: 'Notes', readOnly: false);
      await provider.add(directory('b'), name: 'Output', readOnly: false);
      final id = provider.entries.first.id;
      await provider.update(id, name: 'Reference', readOnly: true);
      expect(native.first['guest'], '/mounts/Reference');
      expect(native.first['readOnly'], true);
      expect(released, isEmpty);
      await provider.remove(id);
      expect(native.single['guest'], '/mounts/Output');
      expect(released, ['a']);
      expect(sources['a'], '/storage/A');
    },
  );

  test('revoked access removes live binding and can be reselected', () async {
    await provider.add(directory('a'), name: 'Notes', readOnly: true);
    final id = provider.entries.single.id;
    sources.remove('a');
    expect(await provider.resolveMounts(), isEmpty);
    expect(native, isEmpty);
    expect(provider.entries, hasLength(1));
    expect(provider.errorFor(id), isNotNull);
    await provider.update(
      id,
      name: 'Notes',
      readOnly: true,
      directory: directory('b'),
    );
    expect(native.single['host'], '/storage/B');
    expect(provider.errorFor(id), isNull);
    expect(released, ['a']);
  });

  test(
    'failed runtime update rolls back the registry and persisted permission',
    () async {
      await provider.add(directory('a'), name: 'Notes', readOnly: true);
      failNextMount = true;
      await expectLater(
        provider.update(
          provider.entries.single.id,
          name: 'Changed',
          readOnly: false,
        ),
        throwsA(isA<WorkspaceChannelException>()),
      );
      expect(provider.entries.single.name, 'Notes');
      expect(provider.entries.single.readOnly, true);
      expect(native.single['readOnly'], true);
      final stored = await store.get(ExternalMountsProvider.kind, 'global');
      expect((stored!.payload['mounts'] as List).single['name'], 'Notes');
      expect(released, isEmpty);
    },
  );

  test('moved folders stay manageable when saved mounts now overlap', () async {
    sources['c'] = '/storage/C';
    await provider.add(directory('a'), name: 'A', readOnly: false);
    await provider.add(directory('b'), name: 'B', readOnly: true);
    await provider.add(directory('c'), name: 'C', readOnly: false);
    final a = provider.entries[0].id;
    final b = provider.entries[1].id;
    final c = provider.entries[2].id;
    provider.dispose();
    sources['b'] = '/storage/A/B';
    sources['c'] = '/storage/A/C';
    provider = ExternalMountsProvider(store: store, channel: harness.channel);
    await provider.loaded;
    expect(provider.entries, hasLength(3));
    expect(native, isEmpty);
    for (final id in [a, b, c]) {
      expect(provider.errorFor(id), contains('external_mount_overlap'));
    }
    // Removing one conflict must work even while another remains.
    await provider.remove(b);
    expect(provider.entries, hasLength(2));
    expect(native, isEmpty);
    sources['new'] = '/storage/New';
    await provider.update(
      c,
      name: 'C',
      readOnly: false,
      directory: directory('new'),
    );
    expect(native.map((m) => m['host']), ['/storage/A', '/storage/New']);
    expect(provider.errorFor(a), isNull);
    expect(provider.errorFor(c), isNull);
  });

  test('application writes check symlinks and parents of new files', () async {
    final root = await Directory.systemTemp.createTemp('kelivo-mount-guard-');
    addTearDown(() => root.delete(recursive: true));
    final locked = Directory('${root.path}/locked')..createSync();
    final writable = Directory('${root.path}/writable')..createSync();
    sources['a'] = locked.path;
    sources['b'] = writable.path;
    await provider.add(directory('a'), name: 'Locked', readOnly: true);
    await provider.add(directory('b'), name: 'Writable', readOnly: false);
    Link('${writable.path}/alias').createSync(locked.path);
    await expectLater(
      provider.requireWritableHostPaths(['${writable.path}/alias/sub/new.txt']),
      throwsA(isA<WorkspaceChannelException>()),
    );
    await provider.requireWritableHostPaths(['${writable.path}/new.txt']);
    await provider.update(
      provider.entries.first.id,
      name: 'Locked',
      readOnly: false,
    );
    await provider.requireWritableHostPaths([
      '${writable.path}/alias/sub/new.txt',
    ]);
  });

  test(
    'rejects duplicate names, traversal, overlapping sources and mount limit',
    () async {
      await provider.add(directory('a'), name: 'Notes', readOnly: true);
      for (final name in ['notes', '../bad', 'a/b', 'a:b', '.', ' bad']) {
        await expectLater(
          provider.add(directory('b'), name: name, readOnly: false),
          throwsA(isA<WorkspaceChannelException>()),
        );
      }
      sources['child'] = '/storage/A/child';
      await expectLater(
        provider.add(directory('child'), name: 'Alias', readOnly: false),
        throwsA(isA<WorkspaceChannelException>()),
      );
      expect(provider.entries, hasLength(1));
      for (var i = 1; i < 10; i++) {
        sources['$i'] = '/storage/folder$i';
        await provider.add(directory('$i'), name: 'Folder$i', readOnly: false);
      }
      await expectLater(
        provider.add(directory('b'), name: 'Overflow', readOnly: false),
        throwsA(isA<WorkspaceChannelException>()),
      );
      expect(native, hasLength(10));
    },
  );
}

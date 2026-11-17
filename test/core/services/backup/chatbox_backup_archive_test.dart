import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/services/backup/chatbox_backup_archive.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kelivo_chatbox_zip_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('detects ZIP local-file, empty, and spanned signatures', () {
    expect(ChatboxBackupArchive.looksLikeZip([0x50, 0x4b, 0x03, 0x04]), isTrue);
    expect(ChatboxBackupArchive.looksLikeZip([0x50, 0x4b, 0x05, 0x06]), isTrue);
    expect(ChatboxBackupArchive.looksLikeZip([0x50, 0x4b, 0x07, 0x08]), isTrue);
    expect(ChatboxBackupArchive.looksLikeZip(utf8.encode('{"a":1}')), isFalse);
  });

  test(
    'synthesizes the legacy session map from a formatVersion=2 ZIP',
    () async {
      final png = _pngBytes();
      final zip = _encodeChatboxZipV2(
        settings: _settings(),
        session: _session(imageStorageKey: 'picture:test'),
        resources: [
          _resource(
            id: 'resource-000001',
            storageKey: 'picture:test',
            bytes: png,
          ),
        ],
      );

      final result = await ChatboxBackupArchive.readZipV2(
        bytes: zip,
        stagingDir: Directory('${root.path}/staging'),
        resourceDestDir: '${root.path}/dest',
      );

      expect(result.root['__exported_at'], '2026-07-18T00:00:00.000Z');
      expect(result.root['settings'], isA<Map>());
      expect(result.root['chat-sessions-list'], isA<List>());
      expect(
        ((result.root['chat-sessions-list'] as List).first as Map)['id'],
        'assistant-1',
      );
      final session = result.root['session:assistant-1'] as Map;
      final image =
          ((session['messages'] as List)[1] as Map)['contentParts'] as List;
      expect(
        (image[1] as Map)['url'],
        '${root.path}/dest/resource-000001-${sha256.convert(png)}.png',
      );
      expect(result.stagedResourceFiles, hasLength(1));
      expect(await result.stagedResourceFiles.single.readAsBytes(), png);
    },
  );

  test('settings-only ZIP synthesizes an empty session list', () async {
    final result = await ChatboxBackupArchive.readZipV2(
      bytes: _encodeChatboxZipV2(settings: _settings()),
      stagingDir: Directory('${root.path}/staging'),
      resourceDestDir: '${root.path}/dest',
    );
    expect(result.root['chat-sessions-list'], isEmpty);
    expect(result.root.containsKey('session:assistant-1'), isFalse);
    expect((result.root['settings'] as Map)['providers'], isA<Map>());
  });

  test('rejects a ZIP that is not a Chatbox backup', () async {
    final archive = Archive()..add(ArchiveFile.string('readme.txt', 'nope'));
    await expectLater(
      ChatboxBackupArchive.readZipV2(
        bytes: ZipEncoder().encodeBytes(archive),
        stagingDir: Directory('${root.path}/staging'),
        resourceDestDir: '${root.path}/dest',
      ),
      throwsA(
        isA<ChatboxImportException>().having(
          (e) => e.message,
          'message',
          contains('manifest.json'),
        ),
      ),
    );
  });

  test('rejects an unknown formatVersion without guessing', () async {
    await expectLater(
      ChatboxBackupArchive.readZipV2(
        bytes: _encodeChatboxZipV2(settings: _settings(), formatVersion: 3),
        stagingDir: Directory('${root.path}/staging'),
        resourceDestDir: '${root.path}/dest',
      ),
      throwsA(
        isA<ChatboxUnsupportedBackupVersionException>().having(
          (e) => e.version,
          'version',
          3,
        ),
      ),
    );
  });

  test('rejects unsafe ZIP paths', () async {
    final archive = Archive()
      ..add(
        ArchiveFile.string('../manifest.json', '{"format":"chatbox-backup"}'),
      );
    await expectLater(
      ChatboxBackupArchive.readZipV2(
        bytes: ZipEncoder().encodeBytes(archive),
        stagingDir: Directory('${root.path}/staging'),
        resourceDestDir: '${root.path}/dest',
      ),
      throwsA(
        isA<ChatboxImportException>().having(
          (e) => e.message,
          'message',
          contains('Unsafe ZIP entry path'),
        ),
      ),
    );
  });

  test('resource dest names include content checksums', () async {
    final pngA = _pngBytes();
    final pngB = Uint8List.fromList([...pngA, 1, 2, 3]);
    final first = await ChatboxBackupArchive.readZipV2(
      bytes: _encodeChatboxZipV2(
        settings: _settings(),
        session: _session(imageStorageKey: 'picture:a'),
        resources: [
          _resource(
            id: 'resource-000001',
            storageKey: 'picture:a',
            bytes: pngA,
          ),
        ],
      ),
      stagingDir: Directory('${root.path}/staging-a'),
      resourceDestDir: '${root.path}/dest',
    );
    final second = await ChatboxBackupArchive.readZipV2(
      bytes: _encodeChatboxZipV2(
        settings: _settings(),
        session: _session(imageStorageKey: 'picture:b'),
        resources: [
          _resource(
            id: 'resource-000001',
            storageKey: 'picture:b',
            bytes: pngB,
          ),
        ],
      ),
      stagingDir: Directory('${root.path}/staging-b'),
      resourceDestDir: '${root.path}/dest',
    );
    final urlA =
        ((((first.root['session:assistant-1'] as Map)['messages'] as List)[1]
                    as Map)['contentParts']
                as List)[1]
            as Map;
    final urlB =
        ((((second.root['session:assistant-1'] as Map)['messages'] as List)[1]
                    as Map)['contentParts']
                as List)[1]
            as Map;
    expect(urlA['url'], isNot(urlB['url']));
    expect(urlA['url'], contains('resource-000001-'));
    expect(urlB['url'], contains('resource-000001-'));
  });

  test('inlines utf8 tool-result blobs into tool-call parts', () async {
    const resultText = 'full tool output from chatbox blob';
    final zip = _encodeChatboxZipV2(
      settings: _settings(),
      session: {
        'id': 'assistant-1',
        'name': 'Chatbox assistant',
        'messages': [
          {
            'id': 'tool-1',
            'role': 'tool',
            'name': 'search',
            'contentParts': [
              {
                'type': 'tool-call',
                'state': 'result',
                'toolName': 'search',
                'args': {'q': 'hi'},
                'resultStorageKey': 'tool-result:1',
              },
            ],
          },
        ],
      },
      resources: [
        {
          'id': 'resource-000002',
          'storageKey': 'tool-result:1',
          'path': 'sessions/assistant-1/resources/resource-000002.txt',
          'bytes': utf8.encode(resultText),
          'kind': 'tool-result',
          'encoding': 'utf8',
          'mimeType': 'text/plain',
        },
      ],
    );

    final result = await ChatboxBackupArchive.readZipV2(
      bytes: zip,
      stagingDir: Directory('${root.path}/staging'),
      resourceDestDir: '${root.path}/dest',
    );

    final part =
        ((((result.root['session:assistant-1'] as Map)['messages'] as List)
                            .first
                        as Map)['contentParts']
                    as List)
                .first
            as Map;
    expect(part['result'], resultText);
    expect(part.containsKey('resultStorageKey'), isFalse);
    expect(result.stagedResourceFiles, isEmpty);
  });

  test('treats extreme compression ratios as unsafe', () {
    expect(
      ChatboxBackupArchive.isUnsafeCompressionRatio(2 * 1024 * 1024, 200),
      isTrue,
    );
    expect(ChatboxBackupArchive.isUnsafeCompressionRatio(1000, 900), isFalse);
    expect(ChatboxBackupArchive.isUnsafeCompressionRatio(1000, 0), isFalse);
  });

  test(
    'file-backed ZIP budget check does not require loading entry bytes',
    () async {
      final png = _pngBytes();
      final zipFile = File('${root.path}/from-disk.zip');
      await zipFile.writeAsBytes(
        _encodeChatboxZipV2(
          settings: _settings(),
          session: _session(imageStorageKey: 'picture:test'),
          resources: [
            _resource(
              id: 'resource-000001',
              storageKey: 'picture:test',
              bytes: png,
            ),
          ],
        ),
        flush: true,
      );

      final result = await ChatboxBackupArchive.readZipV2(
        file: zipFile,
        stagingDir: Directory('${root.path}/staging-disk'),
        resourceDestDir: '${root.path}/dest-disk',
      );

      expect(result.root['session:assistant-1'], isA<Map>());
      expect(result.stagedResourceFiles, hasLength(1));
      expect(await result.stagedResourceFiles.single.readAsBytes(), png);
    },
  );

  test('aborts raw DEFLATE as soon as the byte bound is exceeded', () {
    final compressed = ZLibCodec(raw: true).encode(Uint8List(64 * 1024));
    expect(
      () => ChatboxBackupArchive.inflateDeflateBounded(
        compressed,
        maxBytes: 4096,
      ),
      throwsA(
        isA<ChatboxImportException>().having(
          (e) => e.message,
          'message',
          contains('too large'),
        ),
      ),
    );
  });

  test('publish replaces a truncated dest with the staged file', () async {
    final png = _pngBytes();
    final result = await ChatboxBackupArchive.readZipV2(
      bytes: _encodeChatboxZipV2(
        settings: _settings(),
        session: _session(imageStorageKey: 'picture:test'),
        resources: [
          _resource(
            id: 'resource-000001',
            storageKey: 'picture:test',
            bytes: png,
          ),
        ],
      ),
      stagingDir: Directory('${root.path}/staging'),
      resourceDestDir: '${root.path}/dest',
    );
    final dest = File(
      '${result.resourceDestDir}/${result.stagedResourceFiles.single.uri.pathSegments.last}',
    );
    await dest.create(recursive: true);
    await dest.writeAsBytes(const [1, 2, 3], flush: true);

    await ChatboxBackupArchive.publishStagedResources(result);

    expect(await dest.readAsBytes(), png);
  });

  test('publish leaves a dest that already matches the staged file', () async {
    final png = _pngBytes();
    final result = await ChatboxBackupArchive.readZipV2(
      bytes: _encodeChatboxZipV2(
        settings: _settings(),
        session: _session(imageStorageKey: 'picture:test'),
        resources: [
          _resource(
            id: 'resource-000001',
            storageKey: 'picture:test',
            bytes: png,
          ),
        ],
      ),
      stagingDir: Directory('${root.path}/staging'),
      resourceDestDir: '${root.path}/dest',
    );
    final dest = File(
      '${result.resourceDestDir}/${result.stagedResourceFiles.single.uri.pathSegments.last}',
    );
    await dest.create(recursive: true);
    await dest.writeAsBytes(png, flush: true);

    await ChatboxBackupArchive.publishStagedResources(result);

    expect(await dest.readAsBytes(), png);
  });

  test('rejects a checksum mismatch', () async {
    final settings = utf8.encode(jsonEncode(_settings()));
    final manifest = utf8.encode(
      jsonEncode({
        'format': 'chatbox-backup',
        'formatVersion': 2,
        'exportedAt': '2026-07-18T00:00:00.000Z',
        'application': {
          'name': 'Chatbox',
          'version': '1.22.0',
          'platform': 'test',
        },
        'exportItems': ['setting'],
        'data': {
          'settings': {
            'path': 'settings.json',
            'size': settings.length,
            'checksum': {'algorithm': 'sha256', 'value': '0' * 64},
          },
        },
        'sessions': <dynamic>[],
        'resources': <dynamic>[],
        'warnings': <dynamic>[],
        'stats': {
          'sessionCount': 0,
          'resourceCount': 0,
          'deduplicatedResourceCount': 0,
          'warningCount': 0,
        },
      }),
    );
    final archive = Archive()
      ..add(ArchiveFile.bytes('settings.json', settings))
      ..add(ArchiveFile.bytes('manifest.json', manifest));

    await expectLater(
      ChatboxBackupArchive.readZipV2(
        bytes: ZipEncoder().encodeBytes(archive),
        stagingDir: Directory('${root.path}/staging'),
        resourceDestDir: '${root.path}/dest',
      ),
      throwsA(
        isA<ChatboxImportException>().having(
          (e) => e.message,
          'message',
          contains('checksum mismatch'),
        ),
      ),
    );
  });
}

Uint8List _pngBytes() => Uint8List.fromList(
  base64.decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
  ),
);

Map<String, dynamic> _settings() => {
  'providers': {
    'openai': {
      'apiKey': 'chatbox-secret',
      'apiHost': 'https://api.example.test',
      'models': [
        {'modelId': 'gpt-test'},
      ],
    },
  },
};

Map<String, dynamic> _session({required String imageStorageKey}) => {
  'id': 'assistant-1',
  'name': 'Chatbox assistant',
  'messages': [
    {'id': 'system-1', 'role': 'system', 'content': 'Imported system prompt'},
    {
      'id': 'message-1',
      'role': 'user',
      'contentParts': [
        {'type': 'text', 'text': 'Hello'},
        {'type': 'image', 'storageKey': imageStorageKey},
      ],
    },
  ],
};

Map<String, dynamic> _resource({
  required String id,
  required String storageKey,
  required List<int> bytes,
}) {
  return {
    'id': id,
    'storageKey': storageKey,
    'path': 'sessions/assistant-1/resources/$id.png',
    'bytes': bytes,
  };
}

Uint8List _encodeChatboxZipV2({
  Map<String, dynamic>? settings,
  Map<String, dynamic>? session,
  List<Map<String, dynamic>> resources = const [],
  int formatVersion = 2,
}) {
  final files = <String, List<int>>{};
  Map<String, dynamic>? settingsDesc;
  if (settings != null) {
    final bytes = utf8.encode(jsonEncode(settings));
    files['settings.json'] = bytes;
    settingsDesc = _descriptor('settings.json', bytes);
  }

  final sessionEntries = <Map<String, dynamic>>[];
  if (session != null) {
    final bytes = utf8.encode(jsonEncode(session));
    const path = 'sessions/assistant-1/session.json';
    files[path] = bytes;
    sessionEntries.add({
      ..._descriptor(path, bytes),
      'id': session['id'],
      'meta': {
        'id': session['id'],
        'name': session['name'],
        'starred': false,
        'sortOrder': 1,
        'createdAt': 1,
      },
      'resourceIds': [for (final resource in resources) resource['id']],
    });
  }

  final resourceEntries = <Map<String, dynamic>>[];
  for (final resource in resources) {
    final path = resource['path'] as String;
    final bytes = resource['bytes'] as List<int>;
    files[path] = bytes;
    resourceEntries.add({
      ..._descriptor(path, bytes),
      'id': resource['id'],
      'originalStorageKeys': [resource['storageKey']],
      'sessionIds': ['assistant-1'],
      'scope': 'session',
      'encoding': resource['encoding'] ?? 'data-url-base64',
      'mimeType': resource['mimeType'] ?? 'image/png',
      'kind': resource['kind'] ?? 'image',
    });
  }

  final manifest = <String, dynamic>{
    'format': 'chatbox-backup',
    'formatVersion': formatVersion,
    'exportedAt': '2026-07-18T00:00:00.000Z',
    'application': {'name': 'Chatbox', 'version': '1.22.0', 'platform': 'test'},
    'exportItems': [
      if (settings != null) 'setting',
      if (session != null) 'conversations',
    ],
    'data': {if (settingsDesc != null) 'settings': settingsDesc},
    'sessions': sessionEntries,
    'resources': resourceEntries,
    'warnings': <dynamic>[],
    'stats': {
      'sessionCount': sessionEntries.length,
      'resourceCount': resourceEntries.length,
      'deduplicatedResourceCount': 0,
      'warningCount': 0,
    },
  };
  files['manifest.json'] = utf8.encode(jsonEncode(manifest));
  final archive = Archive();
  for (final entry in files.entries) {
    archive.add(ArchiveFile.bytes(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

Map<String, dynamic> _descriptor(String path, List<int> bytes) => {
  'path': path,
  'size': bytes.length,
  'checksum': {
    'algorithm': 'sha256',
    'value': sha256.convert(bytes).toString(),
  },
};

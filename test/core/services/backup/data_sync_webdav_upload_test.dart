import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:Kelivo/core/models/backup.dart';
import 'package:Kelivo/core/services/backup/backup_cancel_token.dart';
import 'package:Kelivo/core/services/backup/data_sync.dart';

void main() {
  late Directory temporary;
  late File archive;
  const payload = <int>[80, 75, 3, 4, 1, 2, 3, 4];
  const config = WebDavConfig(
    url: 'https://dav.example.test/root',
    path: 'device/backups',
    username: 'test-user',
    password: 'test-password',
    userAgent: 'Kelivo backup test',
  );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('kelivo_webdav_upload_');
    archive = File('${temporary.path}/kelivo_backup_test.zip');
    await archive.writeAsBytes(payload);
  });

  tearDown(() async {
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test(
    'prepared archive creates collections and streams the authenticated PUT',
    () async {
      final requests = <String>[];
      List<int>? uploaded;
      await http.runWithClient(
        () => DataSync.uploadWebDavBackupFile(config, archive),
        () => MockClient.streaming((request, body) async {
          requests.add('${request.method} ${request.url.path}');
          expect(
            request.headers['Authorization'],
            'Basic ${base64Encode(utf8.encode('test-user:test-password'))}',
          );
          expect(request.headers['User-Agent'], 'Kelivo backup test');
          final bytes = await body.toBytes();
          if (request.method == 'PROPFIND') {
            expect(request.headers['Depth'], '0');
            return http.StreamedResponse(const Stream.empty(), 404);
          }
          if (request.method == 'MKCOL') {
            return http.StreamedResponse(const Stream.empty(), 201);
          }
          expect(request.method, 'PUT');
          expect(request.headers['content-type'], 'application/zip');
          expect(request.contentLength, payload.length);
          uploaded = bytes;
          return http.StreamedResponse(const Stream.empty(), 201);
        }),
      );
      expect(requests, [
        'PROPFIND /root/device/',
        'MKCOL /root/device/',
        'PROPFIND /root/device/backups/',
        'MKCOL /root/device/backups/',
        'PUT /root/device/backups/kelivo_backup_test.zip',
      ]);
      expect(uploaded, payload);
      expect(await archive.exists(), isFalse);
    },
  );

  test(
    'authentication failure stops before upload and removes the temporary archive',
    () async {
      final methods = <String>[];
      await expectLater(
        http.runWithClient(
          () => DataSync.uploadWebDavBackupFile(config, archive),
          () => MockClient((request) async {
            methods.add(request.method);
            return http.Response('', 401);
          }),
        ),
        throwsA(
          isA<Exception>().having(
            (error) => '$error',
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
      expect(methods, ['PROPFIND']);
      expect(await archive.exists(), isFalse);
    },
  );

  test('encrypted prepared archive keeps its binary content type', () async {
    archive = await archive.rename('${temporary.path}/backup.kbackup');
    var uploaded = false;
    await http.runWithClient(
      () => DataSync.uploadWebDavBackupFile(config, archive),
      () => MockClient.streaming((request, body) async {
        if (request.method == 'PUT') {
          uploaded = true;
          expect(request.headers['content-type'], 'application/octet-stream');
          expect(request.url.path, endsWith('/backup.kbackup'));
          expect(await body.toBytes(), payload);
        } else {
          expect(request.method, 'PROPFIND');
          await body.drain<void>();
        }
        return http.StreamedResponse(const Stream.empty(), 200);
      }),
    );
    expect(uploaded, isTrue);
    expect(await archive.exists(), isFalse);
  });

  test('cancelled preparation never starts a remote request', () async {
    final token = BackupCancelToken()..cancel();
    addTearDown(token.dispose);
    var requests = 0;
    await expectLater(
      http.runWithClient(
        () => DataSync.uploadWebDavBackupFile(
          config,
          archive,
          cancelToken: token,
        ),
        () => MockClient((_) async {
          requests++;
          return http.Response('', 201);
        }),
      ),
      throwsA(isA<BackupCancelledException>()),
    );
    expect(requests, 0);
    expect(await archive.exists(), isFalse);
  });
}

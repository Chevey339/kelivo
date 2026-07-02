import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Cuplivo/core/models/backup.dart';
import 'package:Cuplivo/core/services/backup/s3_client.dart';

S3Config _config(HttpServer server) {
  return S3Config(
    endpoint: 'http://${server.address.address}:${server.port}',
    region: 'us-east-1',
    bucket: 'backup-bucket',
    accessKeyId: 'test-access-key',
    secretAccessKey: 'test-secret-key',
    prefix: 'kelivo_backups',
    pathStyle: true,
  );
}

String _listResultXml() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Contents>
    <Key>kelivo_backups/kelivo_backup_2026-04-22T10-11-12.123456.zip</Key>
    <LastModified>2026-04-22T10:11:12.123Z</LastModified>
    <Size>128</Size>
  </Contents>
</ListBucketResult>''';
}

String _legacyListResultXml() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Contents>
    <Key>kelivo_backups/kelivo_backup_2026-04-20T09-00-00.123456.zip</Key>
    <LastModified>2026-04-20T09:00:00.123Z</LastModified>
    <Size>64</Size>
  </Contents>
</ListBucketResult>''';
}

String _backup3ListResultXml() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Contents>
    <Key>kelivo_backups/backup_3.zip</Key>
    <LastModified>2026-04-22T12:00:00.000Z</LastModified>
    <Size>333</Size>
  </Contents>
</ListBucketResult>''';
}

String _emptyListResultXml() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
</ListBucketResult>''';
}

String _pagedListResultXml({required bool firstPage}) {
  if (firstPage) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>true</IsTruncated>
  <Contents>
    <Key>kelivo_backups/page_1.zip</Key>
    <LastModified>2026-04-22T11:00:00.000Z</LastModified>
    <Size>111</Size>
  </Contents>
  <NextContinuationToken>page-two</NextContinuationToken>
</ListBucketResult>''';
  }
  return '''<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>false</IsTruncated>
  <Contents>
    <Key>kelivo_backups/page_2.zip</Key>
    <LastModified>2026-04-22T12:00:00.000Z</LastModified>
    <Size>222</Size>
  </Contents>
</ListBucketResult>''';
}

String _noSuchKeyXml() {
  return '''<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchKey</Code>
  <Message>The specified key does not exist.</Message>
</Error>''';
}

String _manifestJson() {
  return '''{
  "version": 1,
  "items": [
    {
      "key": "kelivo_backups/kelivo_backup_2026-04-22T10-11-12.123456.zip",
      "displayName": "kelivo_backup_2026-04-22T10-11-12.123456.zip",
      "size": 128,
      "lastModified": "2026-04-22T10:11:12.123Z"
    }
  ]
}''';
}

String _manifestWithGhostsJson() {
  return '''{
  "version": 1,
  "items": [
    {
      "key": "kelivo_backups/backup_1.zip",
      "displayName": "backup_1.zip",
      "size": 111,
      "lastModified": "2026-04-20T12:00:00.000Z"
    },
    {
      "key": "kelivo_backups/backup_2.zip",
      "displayName": "backup_2.zip",
      "size": 222,
      "lastModified": "2026-04-21T12:00:00.000Z"
    },
    {
      "key": "kelivo_backups/backup_3.zip",
      "displayName": "backup_3.zip",
      "size": 999,
      "lastModified": "2026-04-23T12:00:00.000Z"
    }
  ]
}''';
}

void main() {
  group('S3 bucket list fallback', () {
    test('test() succeeds when manifest key is missing', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final seenPaths = <String>[];
      server.listen((request) async {
        seenPaths.add(request.uri.path);
        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType(
          'application',
          'xml',
          charset: 'utf-8',
        );
        request.response.write(_noSuchKeyXml());
        await request.response.close();
      });

      await const S3BackupClient().test(_config(server));

      expect(seenPaths, [
        '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
      ]);
    });

    test(
      'listObjects returns manifest items when bucket listing is unavailable',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        final seenPaths = <String>[];
        server.listen((request) async {
          seenPaths.add(request.uri.path);
          if (request.uri.path ==
              '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(_manifestJson());
          } else if (request.uri.path == '/backup-bucket' ||
              request.uri.path == '/backup-bucket/') {
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_noSuchKeyXml());
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(items, hasLength(1));
        expect(
          seenPaths,
          contains(
            '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
          ),
        );
      },
    );

    test(
      'listObjects treats successful bucket listing as authoritative',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          if (request.uri.path ==
              '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(_manifestJson());
          } else if (request.uri.path == '/backup-bucket') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_legacyListResultXml());
          } else if (request.method == 'PUT' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            await request.drain<void>();
            request.response.statusCode = HttpStatus.ok;
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(items, hasLength(1));
        expect(items.map((e) => e.displayName).toList(), [
          'kelivo_backup_2026-04-20T09-00-00.123456.zip',
        ]);
      },
    );

    test(
      'listObjects prunes manifest-only items when bucket listing succeeds',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        String? manifestBody;
        server.listen((request) async {
          if (request.method == 'GET' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(_manifestWithGhostsJson());
          } else if (request.method == 'GET' &&
              request.uri.path == '/backup-bucket') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_backup3ListResultXml());
          } else if (request.method == 'PUT' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            manifestBody = await utf8.decoder.bind(request).join();
            request.response.statusCode = HttpStatus.ok;
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(items.map((e) => e.href.pathSegments.join('/')).toList(), [
          'kelivo_backups/backup_3.zip',
        ]);
        expect(items.single.size, 333);
        final manifest = jsonDecode(manifestBody!) as Map<String, dynamic>;
        final manifestItems = manifest['items'] as List<dynamic>;
        expect(manifestItems, hasLength(1));
        expect(
          manifestItems.single,
          containsPair('key', 'kelivo_backups/backup_3.zip'),
        );
        expect(manifestItems.single, containsPair('size', 333));
      },
    );

    test(
      'listObjects clears manifest items when bucket listing is empty',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        String? manifestBody;
        server.listen((request) async {
          if (request.method == 'GET' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(_manifestWithGhostsJson());
          } else if (request.method == 'GET' &&
              request.uri.path == '/backup-bucket') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_emptyListResultXml());
          } else if (request.method == 'PUT' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            manifestBody = await utf8.decoder.bind(request).join();
            request.response.statusCode = HttpStatus.ok;
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(items, isEmpty);
        final manifest = jsonDecode(manifestBody!) as Map<String, dynamic>;
        expect(manifest['items'], isEmpty);
      },
    );

    test('listObjects reads all ListBucket pages', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final continuationTokens = <String?>[];
      server.listen((request) async {
        if (request.uri.path ==
            '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_noSuchKeyXml());
        } else if (request.uri.path == '/backup-bucket') {
          final token = request.uri.queryParameters['continuation-token'];
          continuationTokens.add(token);
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_pagedListResultXml(firstPage: token == null));
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final items = await const S3BackupClient().listObjects(_config(server));

      expect(continuationTokens, [null, 'page-two']);
      expect(items.map((e) => e.displayName).toList(), [
        'page_2.zip',
        'page_1.zip',
      ]);
    });

    test(
      'listObjects surfaces manifest sync write failures after bucket listing',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        server.listen((request) async {
          if (request.method == 'GET' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType.json;
            request.response.write(_manifestWithGhostsJson());
          } else if (request.method == 'GET' &&
              request.uri.path == '/backup-bucket') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_backup3ListResultXml());
          } else if (request.method == 'PUT' &&
              request.uri.path ==
                  '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            await request.drain<void>();
            request.response.statusCode = HttpStatus.forbidden;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write('''<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>AccessDenied</Code>
  <Message>Access Denied</Message>
</Error>''');
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        await expectLater(
          () => const S3BackupClient().listObjects(_config(server)),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('S3 manifest write failed'),
            ),
          ),
        );
      },
    );

    test('uploadFile writes manifest object after upload', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final seenPaths = <String>[];
      String? manifestBody;
      server.listen((request) async {
        seenPaths.add(request.uri.path);
        if (request.method == 'GET' &&
            request.uri.path ==
                '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_noSuchKeyXml());
        } else if (request.method == 'PUT' &&
            request.uri.path == '/backup-bucket/kelivo_backups/demo.zip') {
          await request.drain<void>();
          request.response.statusCode = HttpStatus.ok;
        } else if (request.method == 'PUT' &&
            request.uri.path ==
                '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
          manifestBody = await utf8.decoder.bind(request).join();
          request.response.statusCode = HttpStatus.ok;
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final tmpDir = await Directory.systemTemp.createTemp(
        'kelivo_s3_manifest_upload_',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });
      final file = File('${tmpDir.path}/demo.zip');
      await file.writeAsBytes([1, 2, 3]);

      await const S3BackupClient().uploadFile(
        _config(server),
        key: 'kelivo_backups/demo.zip',
        file: file,
      );

      expect(
        seenPaths,
        contains('/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json'),
      );
      expect(manifestBody, contains('"key":"kelivo_backups/demo.zip"'));
    });

    test(
      'downloadToFile writes object response directly to destination',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        final seenPaths = <String>[];
        final payload = List<int>.generate(128 * 1024, (i) => i % 251);
        server.listen((request) async {
          seenPaths.add(request.uri.path);
          if (request.method == 'GET' &&
              request.uri.path == '/backup-bucket/kelivo_backups/demo.zip') {
            request.response.statusCode = HttpStatus.ok;
            for (var offset = 0; offset < payload.length; offset += 4096) {
              final end = (offset + 4096).clamp(0, payload.length).toInt();
              request.response.add(payload.sublist(offset, end));
              await request.response.flush();
            }
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final tmpDir = await Directory.systemTemp.createTemp(
          'kelivo_s3_download_',
        );
        addTearDown(() async {
          if (await tmpDir.exists()) {
            await tmpDir.delete(recursive: true);
          }
        });

        final destination = File('${tmpDir.path}/demo.zip');
        await const S3BackupClient().downloadToFile(
          _config(server),
          key: 'kelivo_backups/demo.zip',
          destination: destination,
        );

        expect(seenPaths, contains('/backup-bucket/kelivo_backups/demo.zip'));
        expect(await destination.readAsBytes(), payload);
      },
    );

    test(
      'listObjects uses primary bucket URL when provider accepts it',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        var requestCount = 0;
        final seenPaths = <String>[];
        server.listen((request) async {
          requestCount += 1;
          seenPaths.add(request.uri.path);
          if (request.uri.path ==
              '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_noSuchKeyXml());
          } else {
            expect(request.uri.path, '/backup-bucket');
            expect(request.uri.queryParameters['list-type'], '2');
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_listResultXml());
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(requestCount, 2);
        expect(seenPaths, [
          '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
          '/backup-bucket',
        ]);
        expect(items, hasLength(1));
        expect(
          items.single.displayName,
          'kelivo_backup_2026-04-22T10-11-12.123456.zip',
        );
      },
    );

    test(
      'listObjects retries with trailing slash when primary URL returns NoSuchKey',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        final paths = <String>[];
        server.listen((request) async {
          paths.add(request.uri.path);
          if (request.uri.path ==
              '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_noSuchKeyXml());
          } else if (request.uri.path == '/backup-bucket') {
            request.response.statusCode = HttpStatus.notFound;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_noSuchKeyXml());
          } else if (request.uri.path == '/backup-bucket/') {
            request.response.statusCode = HttpStatus.ok;
            request.response.headers.contentType = ContentType(
              'application',
              'xml',
              charset: 'utf-8',
            );
            request.response.write(_listResultXml());
          } else {
            request.response.statusCode = HttpStatus.notFound;
          }
          await request.response.close();
        });

        final items = await const S3BackupClient().listObjects(_config(server));

        expect(paths, [
          '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
          '/backup-bucket',
          '/backup-bucket/',
        ]);
        expect(items, hasLength(1));
      },
    );

    test(
      'test() does not fall back to ListBucket when manifest key is missing',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() async {
          await server.close(force: true);
        });

        final paths = <String>[];
        server.listen((request) async {
          paths.add(request.uri.path);
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_noSuchKeyXml());
          await request.response.close();
        });

        await const S3BackupClient().test(_config(server));

        expect(paths, [
          '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
        ]);
      },
    );

    test('listObjects preserves non-NoSuchKey failures', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      var requestCount = 0;
      server.listen((request) async {
        requestCount += 1;
        if (request.uri.path ==
            '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_noSuchKeyXml());
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write('''<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>AccessDenied</Code>
  <Message>Access Denied</Message>
</Error>''');
        }
        await request.response.close();
      });

      await expectLater(
        () => const S3BackupClient().listObjects(_config(server)),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('AccessDenied'),
          ),
        ),
      );
      expect(requestCount, 2);
    });

    test('endpoint that already includes bucket is not duplicated', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        if (request.method == 'GET' &&
            request.uri.path ==
                '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json') {
          request.response.statusCode = HttpStatus.notFound;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_noSuchKeyXml());
        } else if (request.method == 'PUT') {
          await request.drain<void>();
          request.response.statusCode = HttpStatus.ok;
        } else if (request.method == 'GET') {
          request.response.statusCode = HttpStatus.ok;
          request.response.headers.contentType = ContentType(
            'application',
            'xml',
            charset: 'utf-8',
          );
          request.response.write(_listResultXml());
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final cfg = S3Config(
        endpoint:
            'http://${server.address.address}:${server.port}/backup-bucket',
        region: 'us-east-1',
        bucket: 'backup-bucket',
        accessKeyId: 'test-access-key',
        secretAccessKey: 'test-secret-key',
        prefix: 'kelivo_backups',
        pathStyle: true,
      );

      final tmpDir = await Directory.systemTemp.createTemp(
        'kelivo_s3_endpoint_dedupe_',
      );
      addTearDown(() async {
        if (await tmpDir.exists()) {
          await tmpDir.delete(recursive: true);
        }
      });
      final file = File('${tmpDir.path}/demo.zip');
      await file.writeAsBytes([1, 2, 3]);

      await const S3BackupClient().uploadFile(
        cfg,
        key: 'kelivo_backups/demo.zip',
        file: file,
      );
      await const S3BackupClient().test(cfg);
      await const S3BackupClient().listObjects(cfg);

      expect(
        paths,
        containsAll([
          '/backup-bucket/kelivo_backups/.kelivo_backups_manifest.json',
          '/backup-bucket/kelivo_backups/demo.zip',
          '/backup-bucket',
        ]),
      );
      expect(paths, isNot(contains('/backup-bucket/backup-bucket')));
      expect(
        paths,
        isNot(contains('/backup-bucket/backup-bucket/kelivo_backups/demo.zip')),
      );
    });
  });
}

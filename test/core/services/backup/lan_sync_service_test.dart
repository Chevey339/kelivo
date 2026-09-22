import 'dart:io';

import 'package:Kelivo/core/services/backup/lan_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LAN sync transfer', () {
    test('serves and downloads an archive with the one-time link', () async {
      final root = await Directory.systemTemp.createTemp('kelivo_lan_sync_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
      final expected = List<int>.generate(8192, (index) => index % 251);
      await archive.writeAsBytes(expected, flush: true);

      final session = await LanSyncShareSession.start(
        archive,
        advertisedAddresses: [InternetAddress.loopbackIPv4],
        bindAddress: InternetAddress.loopbackIPv4,
        allowLoopback: true,
        enableBroadcast: false,
      );
      addTearDown(session.close);

      final destination = Directory(
        '${root.path}${Platform.pathSeparator}received',
      );
      final downloaded = await LanSyncClient.download(
        session.primaryUrl.toString(),
        destinationDirectory: destination,
        allowLoopback: true,
      );

      expect(await downloaded.readAsBytes(), expected);
      expect(session.completedTransfers, 1);
    });

    test('does not reveal a share when the token is wrong', () async {
      final root = await Directory.systemTemp.createTemp('kelivo_lan_token_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
      await archive.writeAsBytes([1, 2, 3], flush: true);
      final session = await LanSyncShareSession.start(
        archive,
        advertisedAddresses: [InternetAddress.loopbackIPv4],
        bindAddress: InternetAddress.loopbackIPv4,
        allowLoopback: true,
        enableBroadcast: false,
      );
      addTearDown(session.close);

      final invalid = session.primaryUrl.replace(
        queryParameters: {'token': 'wrong'},
      );
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final response = await (await client.getUrl(invalid)).close();

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('client rejects non-local and malformed links', () async {
      await expectLater(
        LanSyncClient.download(
          'https://192.168.1.2:1234${LanSyncShareSession.route}?token=x',
        ),
        throwsA(
          isA<LanSyncException>().having(
            (error) => error.code,
            'code',
            'invalidLink',
          ),
        ),
      );
      await expectLater(
        LanSyncClient.download(
          'http://8.8.8.8:1234${LanSyncShareSession.route}?token=x',
        ),
        throwsA(
          isA<LanSyncException>().having(
            (error) => error.code,
            'code',
            'nonLocalAddress',
          ),
        ),
      );
    });

    test(
      'client never follows a redirect outside the validated host',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'kelivo_lan_redirect_',
        );
        addTearDown(() async {
          if (await root.exists()) await root.delete(recursive: true);
        });
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            'http://8.8.8.8${LanSyncShareSession.route}?token=x',
          );
          await request.response.close();
        });

        await expectLater(
          LanSyncClient.download(
            'http://127.0.0.1:${server.port}'
            '${LanSyncShareSession.route}?token=x',
            allowLoopback: true,
            destinationDirectory: root,
          ),
          throwsA(
            isA<LanSyncException>().having(
              (error) => error.code,
              'code',
              'connectionRejected',
            ),
          ),
        );
      },
    );

    test(
      'discovers a share and exchanges the six-digit pairing code',
      () async {
        final root = await Directory.systemTemp.createTemp('kelivo_lan_pair_');
        addTearDown(() async {
          if (await root.exists()) await root.delete(recursive: true);
        });
        final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
        final expected = List<int>.generate(2048, (index) => index % 239);
        await archive.writeAsBytes(expected, flush: true);
        final discoveryPort = await _availableUdpPort();
        final session = await LanSyncShareSession.start(
          archive,
          advertisedAddresses: [InternetAddress.loopbackIPv4],
          bindAddress: InternetAddress.loopbackIPv4,
          allowLoopback: true,
          discoveryPortNumber: discoveryPort,
          broadcastTargets: [InternetAddress.loopbackIPv4],
        );
        addTearDown(session.close);

        final link = await LanSyncDiscovery.findByPairingCode(
          session.pairingCode,
          timeout: const Duration(seconds: 3),
          port: discoveryPort,
          bindAddress: InternetAddress.loopbackIPv4,
          allowLoopback: true,
        );
        final parsed = Uri.parse(link);
        expect(parsed.queryParameters['token'], session.token);
        expect(link, session.primaryUrl.toString());

        final downloaded = await LanSyncClient.download(
          link,
          destinationDirectory: Directory(
            '${root.path}${Platform.pathSeparator}paired',
          ),
          allowLoopback: true,
        );
        expect(await downloaded.readAsBytes(), expected);
      },
    );

    test('wrong pairing code is not matched', () async {
      final root = await Directory.systemTemp.createTemp('kelivo_lan_wrong_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
      await archive.writeAsBytes([1, 2, 3], flush: true);
      final discoveryPort = await _availableUdpPort();
      final session = await LanSyncShareSession.start(
        archive,
        advertisedAddresses: [InternetAddress.loopbackIPv4],
        bindAddress: InternetAddress.loopbackIPv4,
        allowLoopback: true,
        discoveryPortNumber: discoveryPort,
        broadcastTargets: [InternetAddress.loopbackIPv4],
      );
      addTearDown(session.close);
      final wrongCode = session.pairingCode == '000000' ? '000001' : '000000';

      await expectLater(
        LanSyncDiscovery.findByPairingCode(
          wrongCode,
          timeout: const Duration(milliseconds: 1800),
          port: discoveryPort,
          bindAddress: InternetAddress.loopbackIPv4,
          allowLoopback: true,
        ),
        throwsA(
          isA<LanSyncException>().having(
            (error) => error.code,
            'code',
            'pairingNotFound',
          ),
        ),
      );
    });

    test('broadcast announcement contains neither code nor token', () async {
      final root = await Directory.systemTemp.createTemp(
        'kelivo_lan_announce_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
      await archive.writeAsBytes([1], flush: true);
      final discoveryPort = await _availableUdpPort();
      final receiver = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      addTearDown(receiver.close);
      final announcement = receiver
          .where((event) => event == RawSocketEvent.read)
          .map((_) => receiver.receive())
          .where((datagram) => datagram != null)
          .cast<Datagram>()
          .first;
      final session = await LanSyncShareSession.start(
        archive,
        advertisedAddresses: [InternetAddress.loopbackIPv4],
        bindAddress: InternetAddress.loopbackIPv4,
        allowLoopback: true,
        discoveryPortNumber: discoveryPort,
        broadcastTargets: [InternetAddress.loopbackIPv4],
      );
      addTearDown(session.close);

      final text = String.fromCharCodes((await announcement).data);
      expect(text, isNot(contains(session.pairingCode)));
      expect(text, isNot(contains(session.token)));
      expect(text, contains(LanSyncShareSession.discoveryService));
    });

    test('pairing endpoint rate-limits repeated incorrect codes', () async {
      final root = await Directory.systemTemp.createTemp('kelivo_lan_limit_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final archive = File('${root.path}${Platform.pathSeparator}backup.zip');
      await archive.writeAsBytes([1], flush: true);
      final session = await LanSyncShareSession.start(
        archive,
        advertisedAddresses: [InternetAddress.loopbackIPv4],
        bindAddress: InternetAddress.loopbackIPv4,
        allowLoopback: true,
        enableBroadcast: false,
      );
      addTearDown(session.close);
      final pairUri = Uri(
        scheme: 'http',
        host: InternetAddress.loopbackIPv4.address,
        port: session.primaryUrl.port,
        path: LanSyncShareSession.pairRoute,
      );
      final wrongCode = session.pairingCode == '999999' ? '000000' : '999999';

      for (var attempt = 0; attempt < 5; attempt++) {
        expect(
          await _postPair(pairUri, session.sessionId, wrongCode),
          HttpStatus.forbidden,
        );
      }
      expect(
        await _postPair(pairUri, session.sessionId, session.pairingCode),
        HttpStatus.tooManyRequests,
      );
    });
  });
}

Future<int> _availableUdpPort() async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  socket.close();
  return port;
}

Future<int> _postPair(Uri uri, String session, String code) async {
  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write('{"session":"$session","code":"$code"}');
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

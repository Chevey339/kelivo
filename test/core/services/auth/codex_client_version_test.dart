import 'dart:async';
import 'dart:convert';

import 'package:Kelivo/core/services/auth/codex_client_version.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response release(String version) =>
    http.Response(jsonEncode({'version': version}), 200);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'shares the lookup and reuses the cached release after restart',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      http.Client createClient() => MockClient((request) {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.host, 'registry.npmjs.org');
        expect(request.url.path, '/@openai/codex/latest');
        expect(request.followRedirects, false);
        expect(request.headers['authorization'], isNull);
        started.complete();
        return response.future;
      });
      final version = CodexClientVersion(clientFactory: createClient);
      final pending = version.refresh();
      await started.future;
      final joined = version.refresh(force: true);
      expect(await version.current(), defaultCodexClientVersion);
      response.complete(release('0.170.0'));
      await Future.wait([pending, joined]);
      expect(version.snapshot.version, '0.170.0');
      expect(calls, 1);

      final restarted = CodexClientVersion(clientFactory: createClient);
      await restarted.refresh();
      expect(restarted.snapshot.version, '0.170.0');
      expect(calls, 1);
    },
  );

  test('checks stale cache and lets manual sync bypass fresh cache', () async {
    SharedPreferences.setMockInitialValues({
      'codex_client_version_v1': jsonEncode({
        'version': '0.170.0',
        'checkedAt': DateTime.now()
            .subtract(const Duration(hours: 7))
            .millisecondsSinceEpoch,
      }),
    });
    var latest = '0.171.0';
    final version = CodexClientVersion(
      clientFactory: () => MockClient((_) async => release(latest)),
    );
    expect(await version.current(), '0.170.0');
    await version.refresh();
    expect(version.snapshot.version, latest);
    latest = '0.172.0';
    await version.refresh(force: true);
    expect(version.snapshot.version, latest);
  });

  test(
    'failed lookups and prereleases do not replace a stable release',
    () async {
      http.Response? response;
      final version = CodexClientVersion(
        clientFactory: () => MockClient((_) async {
          return response ?? (throw http.ClientException('Offline'));
        }),
      );
      await version.refresh();
      expect(version.snapshot.version, defaultCodexClientVersion);
      response = release('0.170.0');
      await version.refresh(force: true);
      expect(version.snapshot.version, '0.170.0');
      for (final invalid in [
        http.Response('{}', 503),
        http.Response('not json', 200),
        release('0.171.0-alpha.1'),
        release('0.171.0\n'),
      ]) {
        response = invalid;
        await version.refresh(force: true);
        expect(version.snapshot.version, '0.170.0');
      }
      expect(await CodexClientVersion().current(), '0.170.0');
    },
  );

  test(
    'tracks a rolled-back dist-tag without going below the bundled floor',
    () async {
      var latest = '0.171.0';
      final version = CodexClientVersion(
        clientFactory: () => MockClient((_) async => release(latest)),
      );
      await version.refresh();
      expect(version.snapshot.version, '0.171.0');
      latest = '0.170.0';
      await version.refresh(force: true);
      expect(await CodexClientVersion().current(), '0.170.0');
      latest = '0.160.0';
      await version.refresh(force: true);
      expect(version.snapshot.version, defaultCodexClientVersion);
    },
  );
}

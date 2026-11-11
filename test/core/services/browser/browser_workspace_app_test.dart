import 'dart:io';

import 'package:Kelivo/core/services/browser/browser_workspace_app.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chromium storage requires the native connection allowlist version', () {
    for (final version in [
      null,
      '',
      '151.0.1.0',
      'Chrome/134.0.1.0',
      'invalid',
    ]) {
      expect(BrowserWorkspaceApp.supportsConnectionAllowlist(version), false);
    }
    for (final version in ['152.0.0.0', 'Chrome/152.0.1.0', 'Edg/159.0.1.0']) {
      expect(BrowserWorkspaceApp.supportsConnectionAllowlist(version), true);
    }
    expect(BrowserWorkspaceApp.headers['Connection-Allowlist'], '()');
  });
  test(
    'storage callers require native main-frame origin, exact host and port',
    () {
      final app = BrowserWorkspaceApp('notes.app.html');
      for (final scheme in ['kelivo', 'https']) {
        expect(
          app.acceptsCaller(
            '$scheme://ws-test.kelivo.invalid',
            true,
            'ws-test.kelivo.invalid',
            android: scheme == 'https',
          ),
          true,
        );
      }
      for (final origin in [
        null,
        'null',
        'file:///',
        'https://other.kelivo.invalid',
        'https://ws-test.kelivo.invalid:444',
        'https://ws-test.kelivo.invalid.evil.test',
        'https://user@ws-test.kelivo.invalid',
        'https://ws-test.kelivo.invalid/?x',
      ]) {
        expect(
          app.acceptsCaller(
            origin,
            true,
            'ws-test.kelivo.invalid',
            android: true,
          ),
          false,
          reason: origin,
        );
      }
      expect(
        app.acceptsCaller(
          'kelivo://ws-test.kelivo.invalid',
          false,
          'ws-test.kelivo.invalid',
          android: false,
        ),
        false,
      );
      expect(
        app.acceptsCaller(
          'https://ws-test.kelivo.invalid',
          true,
          'ws-test.kelivo.invalid',
          android: false,
        ),
        false,
      );
      expect(
        app.acceptsCaller(
          'kelivo://ws-test.kelivo.invalid',
          true,
          'ws-test.kelivo.invalid',
          android: true,
        ),
        false,
      );
      expect(
        BrowserWorkspaceApp.isDataPath('NOTES.APP.HTML.DATA./state.json'),
        true,
      );
    },
  );

  test(
    'application origins and all resource paths enforce the data boundary',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'workspace-app-policy-',
      );
      addTearDown(() => root.delete(recursive: true));
      for (final name in [
        'a.app.html',
        'b.app.html',
        'ordinary.html',
        'secret.json',
      ]) {
        await File('${root.path}/$name').writeAsString('fixture');
      }
      await Directory('${root.path}/a.app.html.data').create();
      await File(
        '${root.path}/a.app.html.data/state.json',
      ).writeAsString('private');
      final resources = BrowserWorkspaceResources()
        ..rootForSession = (_) async => root;
      final a = await resources.scope(
        'chat',
        pageUrl: 'kelivo://workspace/a.app.html',
      );
      final b = await resources.scope(
        'chat',
        pageUrl: 'kelivo://workspace/b.app.html',
      );
      final normal = await resources.scope('chat');
      expect({a.host, b.host, normal.host}.length, 3);
      expect(a.host.split('.').length, 2);
      expect(b.host.split('.').length, 2);
      expect(normal.host.endsWith('.kelivo.invalid'), true);
      expect(BrowserWorkspaceResources.isInternalHost(a.host), true);
      expect(BrowserWorkspaceResources.isInternalHost(normal.host), true);
      expect(
        BrowserWorkspaceResources.isInternalHost('${a.host}.example.com'),
        false,
      );
      expect(
        await a.read(
          a.internalUrl('kelivo://workspace/a.app.html', android: false),
        ),
        isNotNull,
      );
      for (final scope in [a, b, normal]) {
        expect(
          await scope.read(
            Uri.parse('kelivo://workspace/a.app.html.data/state.json'),
          ),
          isNull,
        );
      }
      expect(await a.read(Uri.parse('kelivo://workspace/secret.json')), isNull);
      expect(await a.read(Uri.parse('kelivo://workspace/b.app.html')), isNull);
      if (!Platform.isWindows) {
        await Link(
          '${root.path}/alias.json',
        ).create('${root.path}/a.app.html.data/state.json');
        expect(
          await normal.read(Uri.parse('kelivo://workspace/alias.json')),
          isNull,
        );
      }
      resources.rootForSession = (_) async => null;
      expect(await a.read(Uri.parse('kelivo://workspace/a.app.html')), isNull);
    },
  );
}

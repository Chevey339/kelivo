import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/core/services/browser/browser_workspace_resources.dart';
import 'package:Kelivo/core/services/browser/browser_service.dart';
import 'package:Kelivo/core/services/browser/browser_tools_service.dart';

void main() {
  late Directory root;
  late BrowserWorkspaceResources resources;
  late BrowserWorkspaceScope scope;
  late Map<String, Directory> bindings;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('browser-workspace-');
    final workspace = await Directory('${root.path}/workspace').create();
    bindings = {'chat-a': workspace, 'chat-b': workspace};
    resources = BrowserWorkspaceResources()
      ..rootForSession = (id) async => bindings[id];
    scope = await resources.scope('chat-a');
    await File(
      '${workspace.path}/index.html',
    ).writeAsString('<script src="./app.js"></script>');
    await File(
      '${workspace.path}/app.js',
    ).writeAsString('window.loaded = true;');
    await File('${workspace.path}/data.json').writeAsString('{"value":42}');
  });
  tearDown(() async {
    scope.close();
    await root.delete(recursive: true);
  });

  test(
    'replaced screenshot leaf never truncates the replacement or its symlink target',
    () async {
      for (final symlink in [false, if (!Platform.isWindows) true]) {
        final outside = File('${root.path}/outside.txt');
        await outside.writeAsString('keep me');
        final leaf = '${bindings['chat-a']!.path}/race-$symlink.png';
        var checks = 0;
        await expectLater(
          scope.saveScreenshot(
            'race-$symlink.png',
            Uint8List.fromList([1, 2, 3]),
            checkAccess: () {
              if (++checks == 6) {
                if (symlink) {
                  Link(leaf).createSync(outside.path);
                } else {
                  File(leaf).writeAsStringSync('replacement');
                }
              }
            },
          ),
          throwsStateError,
        );
        expect(await outside.readAsString(), 'keep me');
        if (!symlink) expect(await File(leaf).readAsString(), 'replacement');
        expect(
          Directory(
            bindings['chat-a']!.path,
          ).listSync().where((e) => e.path.contains('.kelivo-screenshot-')),
          isEmpty,
        );
      }
    },
  );

  test(
    'screenshot saves within binding, creates parents and refuses overwrite',
    () async {
      final png = Uint8List.fromList([137, 80, 78, 71]);
      expect(
        await scope.saveScreenshot('screens/shot.png', png, checkAccess: () {}),
        'kelivo://workspace/screens/shot.png',
      );
      final file = File('${bindings['chat-a']!.path}/screens/shot.png');
      expect(await file.readAsBytes(), png);
      await expectLater(
        scope.saveScreenshot(
          'screens/shot.png',
          Uint8List(1),
          checkAccess: () {},
        ),
        throwsStateError,
      );
      expect(await file.readAsBytes(), png);
    },
  );

  test(
    'screenshot rejects parent symlink escapes, closed and rebound scopes',
    () async {
      final png = Uint8List.fromList([137, 80, 78, 71]);
      if (!Platform.isWindows) {
        await Link('${bindings['chat-a']!.path}/escape').create(root.path);
        await expectLater(
          scope.saveScreenshot(
            'escape/nested/shot.png',
            png,
            checkAccess: () {},
          ),
          throwsStateError,
        );
        expect(await Directory('${root.path}/nested').exists(), false);
      }
      bindings['chat-a'] = await Directory('${root.path}/other').create();
      await expectLater(
        scope.saveScreenshot('rebound.png', png, checkAccess: () {}),
        throwsStateError,
      );
      scope.close();
      await expectLater(
        scope.saveScreenshot('closed.png', png, checkAccess: () {}),
        throwsStateError,
      );
    },
  );

  test('takeover during screenshot write removes partial output', () async {
    var checks = 0;
    await expectLater(
      scope.saveScreenshot(
        'cancelled.png',
        Uint8List.fromList([1, 2, 3]),
        checkAccess: () {
          if (++checks == 6) throw StateError('browser_human_control');
        },
      ),
      throwsStateError,
    );
    expect(
      await File('${bindings['chat-a']!.path}/cancelled.png').exists(),
      false,
    );
  });

  test(
    'public entry and relative assets resolve on both platform transports',
    () async {
      for (final android in [false, true]) {
        final url = scope.internalUrl(
          'kelivo://workspace/index.html',
          android: android,
        );
        expect(url.scheme, android ? 'https' : 'kelivo');
        expect((await scope.read(url))!.mime, 'text/html');
        expect(
          String.fromCharCodes(
            (await scope.read(url.resolve('app.js')))!.bytes,
          ),
          'window.loaded = true;',
        );
        expect(
          (await scope.read(url.resolve('data.json')))!.mime,
          'application/json',
        );
        expect(
          scope.publicUrl(url.toString()),
          'kelivo://workspace/index.html',
        );
        expect(
          scope.publicUrl(url.resolve('app.js?v=2#x').toString()),
          'kelivo://workspace/app.js?v=2#x',
        );
      }
      expect(
        (await scope.read(
          scope.internalUrl('kelivo://workspace/', android: false),
        ))!.mime,
        'text/html',
      );
      expect(
        BrowserService.normalizeAddress('kelivo://workspace/index.html'),
        'kelivo://workspace/index.html',
      );
      expect(
        BrowserToolsService.validateArguments({
          'action': 'open',
          'url': 'kelivo://workspace/index.html',
        })['url'],
        'kelivo://workspace/index.html',
      );
    },
  );

  test(
    'origins are stable within a binding and isolated between conversations',
    () async {
      final again = await resources.scope('chat-a');
      final other = await resources.scope('chat-b');
      expect(again.host, scope.host);
      expect(other.host, isNot(scope.host));
      expect(
        await scope.read(
          other.internalUrl('kelivo://workspace/index.html', android: false),
        ),
        isNull,
      );
      again.close();
      other.close();
      await expectLater(resources.scope('missing'), throwsStateError);
    },
  );

  test(
    'revoking or changing the binding immediately stops resource reads',
    () async {
      final url = scope.internalUrl(
        'kelivo://workspace/index.html',
        android: false,
      );
      bindings.remove('chat-a');
      expect(await scope.read(url), isNull);
      bindings['chat-a'] = await Directory('${root.path}/new-root').create();
      expect(await scope.read(url), isNull);
      expect((await resources.scope('chat-a')).host, isNot(scope.host));
    },
  );

  test('rejects malformed authorities, traversal, disk and network paths', () {
    for (final url in [
      'file:///etc/passwd',
      'kelivo://other/index.html',
      'kelivo://workspace:80/index.html',
      'kelivo://user@workspace/index.html',
      'kelivo://workspace/../secret.html',
      'kelivo://workspace/%2e%2e/secret.html',
      'kelivo://workspace/a%2fb.html',
      'kelivo://workspace/a%5cb.html',
      'kelivo://workspace/C:%5csecret.html',
      'kelivo://workspace/a%00.html',
    ]) {
      expect(
        BrowserWorkspaceResources.isWorkspaceUrl(url),
        isFalse,
        reason: url,
      );
      expect(
        () => BrowserToolsService.validateArguments({
          'action': 'open',
          'url': url,
        }),
        throwsFormatException,
        reason: url,
      );
    }
  });

  test(
    'follows safe symlinks but refuses escapes and missing/large resources',
    () async {
      final path = bindings['chat-a']!.path;
      await File('${root.path}/secret.html').writeAsString('outside');
      if (!Platform.isWindows) {
        await Link('$path/escape.html').create('${root.path}/secret.html');
        await Link('$path/safe.html').create('$path/index.html');
        expect(
          await scope.read(Uri.parse('kelivo://workspace/escape.html')),
          isNull,
        );
        expect(
          await scope.read(Uri.parse('kelivo://workspace/safe.html')),
          isNotNull,
        );
      }
      expect(
        await scope.read(Uri.parse('kelivo://workspace/missing.html')),
        isNull,
      );
      final large = await File('$path/large.js').open(mode: FileMode.write);
      await large.truncate(BrowserWorkspaceScope.maxResourceBytes + 1);
      await large.close();
      expect(
        await scope.read(Uri.parse('kelivo://workspace/large.js')),
        isNull,
      );
      scope.close();
      expect(
        await scope.read(Uri.parse('kelivo://workspace/index.html')),
        isNull,
      );
    },
  );
}

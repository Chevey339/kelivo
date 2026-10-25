import 'dart:io';

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

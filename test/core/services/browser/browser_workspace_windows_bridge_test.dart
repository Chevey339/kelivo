import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Exercise the actual Windows Dart adapter on the host test runner.
// ignore: depend_on_referenced_packages
import 'package:flutter_inappwebview_windows/flutter_inappwebview_windows.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Windows storage bounds decoding and encoding, then releases slots',
    () async {
      const channelName =
          'com.pichillilorenzo/flutter_inappwebview_storage-test';
      const codec = StandardMethodCodec();
      final controller = WindowsInAppWebViewController(
        const WindowsInAppWebViewControllerCreationParams(id: 'storage-test'),
      );
      addTearDown(controller.dispose);
      final release = Completer<void>(), entered = Completer<void>();
      var calls = 0;
      var replyAllowed = true;
      final content = 'x' * 100000;
      controller.addJavaScriptHandler(
        handlerName: 'kelivoWorkspaceStorage',
        callback: (args) async {
          expect(
            (args.single as Map)['origin'],
            'kelivo://ws-fixture.kelivo.invalid',
          );
          expect((args.single as Map)['isMainFrame'], true);
          expect(
            (args.single as Map)['message']['origin'],
            'https://forged.example',
          );
          if ((args.single as Map)['validateReply'] == true) {
            return replyAllowed;
          }
          if (++calls == 8) entered.complete();
          await release.future;
          return {
            'result': {'content': content},
          };
        },
      );
      Future<Object?> invoke(
        String arguments, {
        String? origin = 'kelivo://ws-fixture.kelivo.invalid',
        bool mainFrame = true,
      }) {
        final result = Completer<Object?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channelName,
              codec.encodeMethodCall(
                MethodCall('onCallJsHandler', {
                  'handlerName': 'kelivoWorkspaceStorage',
                  'args': arguments,
                  'sourceOrigin': origin,
                  'isMainFrame': mainFrame,
                }),
              ),
              (data) {
                try {
                  result.complete(codec.decodeEnvelope(data!));
                } catch (error, stack) {
                  result.completeError(error, stack);
                }
              },
            );
        return result.future;
      }

      final arguments = jsonEncode([
        {
          'origin': 'https://forged.example',
          'isMainFrame': true,
          'content': content,
          'validateReply': true,
        },
      ]);
      final pending = List.generate(8, (_) => invoke(arguments));
      await entered.future;
      // The ninth request is rejected before attempting to decode even malformed
      // JSON. Neither large parsing workers nor waiting callbacks can grow freely.
      await expectLater(
        invoke('['),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'storage_busy',
          ),
        ),
      );
      release.complete();
      for (final result in await Future.wait(pending)) {
        expect(
          (jsonDecode(result as String) as Map)['result']['content'],
          content,
        );
      }
      expect(await invoke(arguments), isA<String>());
      replyAllowed = false;
      await expectLater(
        invoke(arguments),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'storage_document_changed',
          ),
        ),
      );
      replyAllowed = true;
      for (final invalid in ['null', '{}', '[1]', '[]', '[{},{}]']) {
        await expectLater(
          invoke(invalid),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'storage_invalid_request',
            ),
          ),
        );
      }
      await expectLater(
        invoke(arguments, origin: null),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'storage_access_denied',
          ),
        ),
      );
      await expectLater(
        invoke(arguments, mainFrame: false),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'storage_access_denied',
          ),
        ),
      );
      controller.removeJavaScriptHandler(handlerName: 'kelivoWorkspaceStorage');
      await expectLater(
        invoke(arguments),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'storage_access_denied',
          ),
        ),
      );
    },
  );
}

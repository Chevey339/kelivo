import 'dart:async';

import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_document.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import '../../support/genui_web_platform.dart';

void main() {
  late FakeGenUiWebPlatform platform;
  final document = UiWebDocument.parse(
    '{"version":1,"title":"Preview","summary":"Local"}\n<button>Example</button>',
    closed: true,
    generation: UiGenerationStatus.complete,
  );
  setUp(() {
    platform = FakeGenUiWebPlatform();
    WebViewPlatform.instance = platform;
  });

  test(
    'installs required decisions before load, never installs a bridge',
    () async {
      final controller = UiWebController();
      await controller.start(document);
      expect(platform.events, [
        'permission',
        'navigationPolicy',
        'httpAuth',
        'navigationDelegate',
        'background:0',
        'alert',
        'confirm',
        'prompt',
        'javascript:unrestricted',
        'load',
      ]);
      final native = platform.controllers.single;
      expect(
        native.documents.single,
        UiWebSandbox.wrap(document.html, title: document.title),
      );
      expect(native.scripts, isEmpty);
      final permission = FakeGenUiPermission();
      native.permission!(permission);
      await Future<void>.value();
      expect(permission.denials, 1);
      expect(permission.grants, 0);
      expect(controller.phase, UiWebNativePhase.ready);
      await controller.close();
      expect(native.scripts, [UiWebSandbox.removeGeneratedDocument]);
      expect(native.documents.last, UiWebSandbox.emptyDocument);
      expect(controller.closeError, isNull);
      expect(controller.nativeController, isNull);
      controller.dispose();
    },
  );

  test('macOS loads without the unsupported UIView background API', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    platform.failAt = 'background:0';
    final controller = UiWebController();
    await controller.start(document);
    expect(controller.phase, UiWebNativePhase.ready);
    expect(platform.events, [
      'permission',
      'navigationPolicy',
      'httpAuth',
      'navigationDelegate',
      'alert',
      'confirm',
      'prompt',
      'javascript:unrestricted',
      'load',
    ]);
    final permission = FakeGenUiPermission();
    platform.controllers.single.permission!(permission);
    await Future<void>.value();
    expect(permission.denials, 1);
    expect(permission.grants, 0);
    await controller.close();
    expect(controller.closeError, isNull);
    controller.dispose();
  });

  for (final step in [
    'permission',
    'navigationPolicy',
    'httpAuth',
    'navigationDelegate',
    'background:0',
    'alert',
    'confirm',
    'prompt',
    'javascript:unrestricted',
  ]) {
    test('a required $step installation failure never loads content', () async {
      platform.failAt = step;
      final controller = UiWebController();
      await expectLater(controller.start(document), throwsStateError);
      expect(platform.controllers.single.documents, isEmpty);
      expect(controller.phase, UiWebNativePhase.failed);
      await controller.close();
      expect(controller.closeError, isNull);
      controller.dispose();
    });
  }

  test('submitting HTML does not expose an unfinished native page', () async {
    platform.finishInitial = false;
    final controller = UiWebController();
    await controller.start(document);
    expect(controller.phase, UiWebNativePhase.initializing);
    platform.controllers.single.navigation!.finished!('about:blank');
    expect(controller.phase, UiWebNativePhase.ready);
    await controller.close();
    platform.controllers.single.navigation!.finished!('about:blank');
    expect(controller.phase, UiWebNativePhase.closed);
    controller.dispose();
  });

  test(
    'navigation allows only local frames after the host load has started',
    () async {
      final controller = UiWebController();
      await controller.start(document);
      final navigation = platform.controllers.single.navigation!;
      for (final url in [
        'https://example.test',
        'http://127.0.0.1/a',
        'file:///private',
        'mailto:example@example.test',
        'data:text/html,example',
        'about:blank#next',
        'about:config',
      ]) {
        for (final main in [false, true]) {
          expect(
            await navigation.request!(
              NavigationRequest(url: url, isMainFrame: main),
            ),
            NavigationDecision.prevent,
          );
        }
      }
      expect(
        await navigation.request!(
          const NavigationRequest(url: 'about:blank', isMainFrame: true),
        ),
        NavigationDecision.prevent,
      );
      for (final url in ['about:blank', 'about:srcdoc']) {
        expect(
          await navigation.request!(
            NavigationRequest(url: url, isMainFrame: false),
          ),
          NavigationDecision.navigate,
        );
      }
      await controller.close();
      controller.dispose();
    },
  );

  for (final waiting in ['initialization', 'cleanup', 'blank-load']) {
    test(
      'the entire close sequence has a deadline while waiting for $waiting',
      () {
        fakeAsync((time) {
          final wait = Completer<void>();
          if (waiting == 'initialization') platform.permissionWait = wait;
          if (waiting == 'cleanup') platform.cleanupWait = wait;
          if (waiting == 'blank-load') platform.emptyWait = wait;
          final controller = UiWebController();
          unawaited(controller.start(document));
          time.flushMicrotasks();
          var done = false;
          final closing = controller.close();
          expect(identical(closing, controller.close()), isTrue);
          unawaited(
            closing.then((_) {
              done = true;
            }),
          );
          time.flushMicrotasks();
          expect(done, isFalse);
          time.elapse(const Duration(seconds: 6));
          expect(done, isTrue);
          expect(controller.closeError, isA<TimeoutException>());
          expect(controller.phase, UiWebNativePhase.closed);
          wait.complete();
          time.flushMicrotasks();
          if (waiting == 'initialization') {
            expect(platform.controllers.single.documents, isEmpty);
          }
          // Late completion cannot report ready or erase the failed teardown.
          expect(controller.phase, UiWebNativePhase.closed);
          expect(controller.closeError, isA<TimeoutException>());
          controller.dispose();
        });
      },
    );
  }

  test(
    'an old about:blank completion cannot confirm the new empty document',
    () {
      fakeAsync((time) {
        final wait = Completer<void>();
        platform.emptyWait = wait;
        final controller = UiWebController();
        unawaited(controller.start(document));
        time.flushMicrotasks();
        var done = false;
        unawaited(
          controller.close().then((_) {
            done = true;
          }),
        );
        time.flushMicrotasks();
        final native = platform.controllers.single;
        native.navigation!.finished?.call('about:blank');
        time.flushMicrotasks();
        expect(done, isFalse);
        wait.complete();
        time.flushMicrotasks();
        expect(done, isTrue);
        expect(controller.closeError, isNull);
        controller.dispose();
      });
    },
  );

  test('not-ready documents never construct a native controller', () async {
    final controller = UiWebController();
    final streaming = UiWebDocument.parse(
      document.source,
      closed: false,
      generation: UiGenerationStatus.generating,
    );
    await expectLater(controller.start(streaming), throwsStateError);
    expect(platform.controllers, isEmpty);
    await controller.close();
    controller.dispose();
  });
  testWidgets(
    'unsupported platforms never construct a native controller',
    (tester) async {
      final controller = UiWebController();
      await expectLater(controller.start(document), throwsUnsupportedError);
      expect(platform.controllers, isEmpty);
      await controller.close();
      controller.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  test(
    'a missing finish callback does not reject a verified empty document',
    () async {
      platform.finishEmpty = false;
      final controller = UiWebController();
      await controller.start(document);
      await controller.close();
      expect(controller.closeError, isNull);
      expect(platform.controllers.single.title, UiWebSandbox.closedTitle);
      controller.dispose();
    },
  );
}

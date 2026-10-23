import 'dart:async';

import 'package:Kelivo/features/browser/widgets/browser_window_chrome.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('app.browser_window');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  Future<void> shortcut(String key) {
    final done = Completer<void>();
    binding.channelBuffers.push(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall('shortcut', key)),
      (_) => done.complete(),
    );
    return done.future;
  }

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call);
      return Future<Object?>.value();
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  void chromeTestWidgets(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  chromeTestWidgets(
    'modal cover disables commands without changing window spacing',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final received = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: BrowserWindowChrome(
            onShortcut: received.add,
            child: const SizedBox.expand(),
          ),
        ),
      );
      expect(calls.map((call) => (call.method, call.arguments)), [
        ('setBrowserChrome', true),
        ('setBrowserShortcuts', true),
      ]);
      for (final key in ['f', 'l', 't', 'w', 'r', 'x']) {
        await shortcut(key);
      }
      expect(received, ['f', 'l', 't', 'w', 'r']);
      calls.clear();
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Covered')),
        ),
      );
      // Route state changes synchronously, even before the host rebuilds and
      // its native disable message is sent.
      await shortcut('t');
      expect(received, ['f', 'l', 't', 'w', 'r']);
      await tester.pumpAndSettle();
      expect(calls.map((call) => (call.method, call.arguments)), [
        ('setBrowserShortcuts', false),
      ]);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(calls.last.method, 'setBrowserShortcuts');
      expect(calls.last.arguments, true);
      await shortcut('f');
      expect(received.last, 'f');
      expect(received.length, 6);
      calls.clear();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(calls.map((call) => (call.method, call.arguments)), [
        ('setBrowserChrome', false),
        ('setBrowserShortcuts', false),
      ]);
    },
  );

  chromeTestWidgets('stacked browser routes return channel ownership on pop', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    final first = <String>[];
    final second = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: BrowserWindowChrome(
          onShortcut: first.add,
          child: const SizedBox.expand(),
        ),
      ),
    );
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => BrowserWindowChrome(
            onShortcut: second.add,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await shortcut('t');
    expect(second, ['t']);
    expect(first, isEmpty);
    calls.clear();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await shortcut('w');
    expect(first, ['w']);
    expect(second, ['t']);
    expect(calls.where((call) => call.method == 'setBrowserChrome'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  chromeTestWidgets(
    'non-macOS host leaves native window and shortcuts untouched',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.pumpWidget(
        BrowserWindowChrome(onShortcut: (_) {}, child: const SizedBox.shrink()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      expect(calls, isEmpty);
    },
  );
}

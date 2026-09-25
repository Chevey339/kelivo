import 'dart:ui' as ui;

import 'package:Kelivo/desktop/windows_paste_fix.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/windows_key_events.dart';

const _probe = ui.KeyData(
  timeStamp: Duration.zero,
  type: ui.KeyEventType.down,
  physical: 0,
  logical: 0,
  character: null,
  synthesized: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void windowsTest(
    String description,
    Future<void> Function(WidgetTester) body,
  ) {
    testWidgets(description, (tester) async {
      try {
        await body(tester);
      } finally {
        WindowsPasteFix.instance.uninstall();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  Future<TextEditingController> mountInput(WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': 'history'}
          : null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TextField(controller: controller)),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    return controller;
  }

  windowsTest(
    'Win+V reaches normal TextField paste exactly once per selection',
    (tester) async {
      final controller = await mountInput(tester);
      await sendWindowsClipboardHistoryPaste(tester);
      await tester.pump();
      expect(controller.text, isEmpty, reason: 'Reproduce the engine sequence');

      WindowsPasteFix.instance.install();
      for (var i = 1; i <= 2; i++) {
        await sendWindowsClipboardHistoryPaste(tester);
        await tester.pump();
        expect(controller.text, List.filled(i, 'history').join());
        expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
      }
    },
  );

  windowsTest('normal Ctrl+V and ordinary input still work', (tester) async {
    final controller = await mountInput(tester);
    WindowsPasteFix.instance.install();
    for (final (logical, physical, type) in [
      (
        LogicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.controlLeft,
        ui.KeyEventType.down,
      ),
      (LogicalKeyboardKey.keyV, PhysicalKeyboardKey.keyV, ui.KeyEventType.down),
      (LogicalKeyboardKey.keyV, PhysicalKeyboardKey.keyV, ui.KeyEventType.up),
      (
        LogicalKeyboardKey.controlLeft,
        PhysicalKeyboardKey.controlLeft,
        ui.KeyEventType.up,
      ),
    ]) {
      await sendWindowsKeyData(
        tester,
        windowsKeyData(logical, type, physical: physical.usbHidUsage),
      );
    }
    await tester.pump();
    expect(controller.text, 'history');
    await tester.enterText(find.byType(TextField), '普通输入');
    expect(controller.text, '普通输入');
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
  });

  windowsTest('zero probe reaches transit detection before any raw event', (
    tester,
  ) async {
    await tester.pump();
    WindowsPasteFix.instance.install();
    tester.platformDispatcher.onKeyData!(_probe);
    await sendWindowsRawKey(tester, {
      'type': 'keydown',
      'keymap': 'windows',
      'keyCode': 0x41,
      'scanCode': 0x1e,
      'characterCodePoint': 0,
      'modifiers': 0,
    });
    // A raw event without KeyData must not switch the framework to raw mode.
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    await sendWindowsClipboardHistoryPaste(tester);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  windowsTest('zero probes do not interrupt an active paste', (tester) async {
    final controller = await mountInput(tester);
    WindowsPasteFix.instance.install();
    for (final data in windowsClipboardHistoryEvents()) {
      tester.platformDispatcher.onKeyData!(_probe);
      await sendWindowsKeyData(tester, data);
    }
    await tester.pump();
    expect(controller.text, 'history');
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
  });

  for (var length = 1; length <= 5; length++) {
    windowsTest(
      'interruption after event $length releases all introduced keys',
      (tester) async {
        await tester.pump();
        WindowsPasteFix.instance.install();
        for (final data in windowsClipboardHistoryEvents().take(length)) {
          await sendWindowsKeyData(tester, data);
        }
        await sendWindowsKeyData(
          tester,
          windowsKeyData(
            LogicalKeyboardKey.keyA,
            ui.KeyEventType.down,
            physical: PhysicalKeyboardKey.keyA.usbHidUsage,
          ),
        );
        expect(HardwareKeyboard.instance.logicalKeysPressed, {
          LogicalKeyboardKey.keyA,
        });
        await sendWindowsKeyData(
          tester,
          windowsKeyData(
            LogicalKeyboardKey.keyA,
            ui.KeyEventType.up,
            physical: PhysicalKeyboardKey.keyA.usbHidUsage,
          ),
        );
        await sendWindowsClipboardHistoryPaste(tester);
        expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
      },
    );
  }

  for (final reset in ['timeout', 'view focus', 'app lifecycle']) {
    windowsTest('$reset releases Ctrl and V without another raw message', (
      tester,
    ) async {
      await tester.pump();
      WindowsPasteFix.instance.install();
      for (final data in windowsClipboardHistoryEvents().take(3)) {
        await sendWindowsKeyData(tester, data);
      }
      expect(HardwareKeyboard.instance.logicalKeysPressed, {
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyV,
      });
      switch (reset) {
        case 'timeout':
          await tester.pump(const Duration(seconds: 1));
        case 'view focus':
          tester.binding.handleViewFocusChanged(
            ui.ViewFocusEvent(
              viewId: tester.view.viewId,
              state: ui.ViewFocusState.unfocused,
              direction: ui.ViewFocusDirection.undefined,
            ),
          );
        case 'app lifecycle':
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
      }
      expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
      await sendWindowsClipboardHistoryPaste(tester);
      expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    });
  }

  windowsTest('already held Ctrl belongs to the user', (tester) async {
    await tester.pump();
    WindowsPasteFix.instance.install();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await sendWindowsClipboardHistoryPaste(tester);
    expect(HardwareKeyboard.instance.logicalKeysPressed, {
      LogicalKeyboardKey.controlLeft,
    });
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
  });

  windowsTest('a real key up releases the introduced key only once', (
    tester,
  ) async {
    await tester.pump();
    WindowsPasteFix.instance.install();
    final events = <KeyEvent>[];
    HardwareKeyboard.instance.addHandler((event) {
      events.add(event);
      return false;
    });
    await sendWindowsKeyData(tester, windowsClipboardHistoryEvents().first);
    await sendWindowsKeyData(
      tester,
      windowsKeyData(
        LogicalKeyboardKey.controlLeft,
        ui.KeyEventType.up,
        physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
      ),
    );
    expect(events.whereType<KeyUpEvent>(), hasLength(1));
    expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
  });

  windowsTest('unrelated KeyData and callback result pass through unchanged', (
    tester,
  ) async {
    await tester.pump();
    final dispatcher = tester.platformDispatcher;
    final original = dispatcher.onKeyData;
    final received = <ui.KeyData>[];
    dispatcher.onKeyData = (data) {
      received.add(data);
      return false;
    };
    try {
      WindowsPasteFix.instance.install();
      for (final physical in [
        windowsUnmappedPhysicalKey,
        PhysicalKeyboardKey.keyA.usbHidUsage,
      ]) {
        final data = ui.KeyData(
          timeStamp: const Duration(milliseconds: 42),
          type: ui.KeyEventType.down,
          physical: physical,
          logical: LogicalKeyboardKey.keyA.keyId,
          character: 'a',
          synthesized: false,
        );
        expect(dispatcher.onKeyData!(data), isFalse);
        expect(received.last, same(data));
      }
    } finally {
      WindowsPasteFix.instance.uninstall();
      dispatcher.onKeyData = original;
    }
  });

  windowsTest(
    'real Ctrl down during a paste takes ownership until its key up',
    (tester) async {
      await tester.pump();
      WindowsPasteFix.instance.install();
      await sendWindowsKeyData(tester, windowsClipboardHistoryEvents().first);
      await sendWindowsKeyData(
        tester,
        windowsKeyData(
          LogicalKeyboardKey.controlLeft,
          ui.KeyEventType.down,
          physical: PhysicalKeyboardKey.controlLeft.usbHidUsage,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(HardwareKeyboard.instance.logicalKeysPressed, {
        LogicalKeyboardKey.controlLeft,
      });
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    },
  );

  windowsTest('installation waits for Flutter callback and is idempotent', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final dispatcher = tester.platformDispatcher;
    final original = dispatcher.onKeyData;
    dispatcher.onKeyData = null;
    WindowsPasteFix.instance.install();
    expect(dispatcher.onKeyData, isNull);
    dispatcher.onKeyData = original;
    tester.binding.scheduleFrame();
    await tester.pump();
    final installed = dispatcher.onKeyData;
    expect(installed, isNot(same(original)));
    WindowsPasteFix.instance.install();
    expect(dispatcher.onKeyData, same(installed));
    await sendWindowsClipboardHistoryPaste(tester);
    WindowsPasteFix.instance.uninstall();
    expect(dispatcher.onKeyData, same(original));
  });

  windowsTest('other platforms retain their original keyboard callback', (
    tester,
  ) async {
    await tester.pump();
    final original = tester.platformDispatcher.onKeyData;
    for (final platform in TargetPlatform.values) {
      if (platform == TargetPlatform.windows) continue;
      debugDefaultTargetPlatformOverride = platform;
      WindowsPasteFix.instance.install();
      expect(tester.platformDispatcher.onKeyData, same(original));
    }
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });
}

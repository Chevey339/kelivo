// Exercises Android's captured keydata + raw-event sequence, including the
// engine's synthesized Shift up. No TextEditingValue selection is injected.
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:Kelivo/shared/text_input/android_ime_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late AndroidImeSelection selection;
  setUp(() {
    selection = AndroidImeSelection();
  });
  tearDown(() {
    selection.dispose();
  });

  void data(
    int code,
    LogicalKeyboardKey key,
    ui.KeyEventType type, {
    bool synthesized = false,
    PhysicalKeyboardKey? physicalKey,
  }) {
    binding.keyEventManager.handleKeyData(
      ui.KeyData(
        timeStamp: Duration.zero,
        type: type,
        physical:
            physicalKey?.usbHidUsage ?? LogicalKeyboardKey.androidPlane + code,
        logical: key.keyId,
        character: null,
        synthesized: synthesized,
      ),
    );
  }

  Future<void> raw(
    int code,
    bool down, {
    int meta = 0,
    int device = -1,
    int scanCode = 0,
    int flags = 0,
  }) async {
    await binding.keyEventManager.handleRawKeyMessage(<String, dynamic>{
      'type': down ? 'keydown' : 'keyup',
      'keymap': 'android',
      'keyCode': code,
      'scanCode': scanCode,
      'metaState': meta,
      'deviceId': device,
      'source': 0x101,
      'flags': flags,
      'repeatCount': 0,
    });
  }

  Future<void> arrow(
    LogicalKeyboardKey key, {
    bool extend = true,
    int device = -1,
    bool gboard = false,
  }) async {
    final code = <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.arrowUp: 19,
      LogicalKeyboardKey.arrowDown: 20,
      LogicalKeyboardKey.arrowLeft: 21,
      LogicalKeyboardKey.arrowRight: 22,
    }[key]!;
    // Captured from Gboard 18.6.3 on Android 11: unlike iFlytek, its
    // virtual-keyboard packets carry Linux scan codes and soft-key flags.
    final scanCode = gboard
        ? <LogicalKeyboardKey, int>{
            LogicalKeyboardKey.arrowUp: 103,
            LogicalKeyboardKey.arrowDown: 108,
            LogicalKeyboardKey.arrowLeft: 105,
            LogicalKeyboardKey.arrowRight: 106,
          }[key]!
        : 0;
    final physicalKey = gboard
        ? <LogicalKeyboardKey, PhysicalKeyboardKey>{
            LogicalKeyboardKey.arrowUp: PhysicalKeyboardKey.arrowUp,
            LogicalKeyboardKey.arrowDown: PhysicalKeyboardKey.arrowDown,
            LogicalKeyboardKey.arrowLeft: PhysicalKeyboardKey.arrowLeft,
            LogicalKeyboardKey.arrowRight: PhysicalKeyboardKey.arrowRight,
          }[key]
        : null;
    final flags = gboard ? 6 : 0;
    if (extend) {
      data(
        59,
        LogicalKeyboardKey.shiftLeft,
        ui.KeyEventType.down,
        physicalKey: gboard ? PhysicalKeyboardKey.shiftLeft : null,
      );
      data(
        59,
        LogicalKeyboardKey.shiftLeft,
        ui.KeyEventType.up,
        synthesized: true,
        physicalKey: gboard ? PhysicalKeyboardKey.shiftLeft : null,
      );
      await raw(
        59,
        true,
        device: device,
        scanCode: gboard ? 42 : 0,
        flags: flags,
      );
    }
    data(code, key, ui.KeyEventType.down, physicalKey: physicalKey);
    await raw(
      code,
      true,
      meta: extend ? 1 : 0,
      device: device,
      scanCode: scanCode,
      flags: flags,
    );
    data(code, key, ui.KeyEventType.up, physicalKey: physicalKey);
    await raw(
      code,
      false,
      meta: extend ? 1 : 0,
      device: device,
      scanCode: scanCode,
      flags: flags,
    );
    if (extend) {
      await raw(
        59,
        false,
        device: device,
        scanCode: gboard ? 42 : 0,
        flags: flags,
      );
    }
  }

  Future<TextEditingController> field(
    WidgetTester tester,
    String text, {
    double width = 220,
    bool selectable = true,
  }) async {
    selection.install();
    final controller = TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: const TextSelection.collapsed(offset: 0),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 8,
                enableInteractiveSelection: selectable,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('IME Shift arrows extend by grapheme in both directions', (
    tester,
  ) async {
    final controller = await field(tester, '👩‍💻中文abc');
    await arrow(LogicalKeyboardKey.arrowRight);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await arrow(LogicalKeyboardKey.arrowRight);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );
    await arrow(LogicalKeyboardKey.arrowLeft);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.copyEnabled, isTrue);
    expect(state.cutEnabled, isTrue);
    expect(HardwareKeyboard.instance.isShiftPressed, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('vertical selection follows wrapped visual lines', (
    tester,
  ) async {
    final controller = await field(tester, 'abcdefghij ' * 12, width: 180);
    await arrow(LogicalKeyboardKey.arrowDown);
    final first = controller.selection;
    expect(first.baseOffset, 0);
    expect(first.extentOffset, greaterThan(0));
    expect(first.extentOffset, lessThan(controller.text.length));
    await arrow(LogicalKeyboardKey.arrowUp);
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Gboard Shift arrows with scan codes preserve the range', (
    tester,
  ) async {
    final controller = await field(tester, '👩‍💻中文abc');
    await arrow(LogicalKeyboardKey.arrowRight, gboard: true);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    await arrow(LogicalKeyboardKey.arrowRight, gboard: true);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 6),
    );
    await arrow(LogicalKeyboardKey.arrowLeft, gboard: true);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    expect(state.copyEnabled, isTrue);
    expect(state.cutEnabled, isTrue);
    await arrow(LogicalKeyboardKey.arrowRight, extend: false, gboard: true);
    expect(controller.selection.isCollapsed, isTrue);
    expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Gboard vertical selection follows wrapped visual lines', (
    tester,
  ) async {
    final controller = await field(tester, 'abcdefghij ' * 12, width: 180);
    await arrow(LogicalKeyboardKey.arrowDown, gboard: true);
    expect(controller.selection.baseOffset, 0);
    expect(
      controller.selection.extentOffset,
      inExclusiveRange(0, controller.text.length),
    );
    await arrow(LogicalKeyboardKey.arrowUp, gboard: true);
    expect(controller.selection, const TextSelection.collapsed(offset: 0));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('ordinary arrows remain ordinary after selection mode ends', (
    tester,
  ) async {
    final controller = await field(tester, 'abcdef');
    await arrow(LogicalKeyboardKey.arrowRight);
    expect(
      controller.selection,
      const TextSelection(baseOffset: 0, extentOffset: 1),
    );
    await arrow(LogicalKeyboardKey.arrowRight, extend: false);
    expect(controller.selection.isCollapsed, isTrue);
    expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('does not reinterpret physical devices with missing modifiers', (
    tester,
  ) async {
    final controller = await field(tester, 'abcdef');
    await arrow(LogicalKeyboardKey.arrowRight, device: 7);
    expect(controller.selection.isCollapsed, isTrue);
    await arrow(LogicalKeyboardKey.arrowRight, device: 7, gboard: true);
    expect(controller.selection.isCollapsed, isTrue);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

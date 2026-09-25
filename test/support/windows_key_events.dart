import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const windowsUnmappedPhysicalKey = 0x1600000000;

ui.KeyData windowsKeyData(
  LogicalKeyboardKey logical,
  ui.KeyEventType type, {
  int physical = windowsUnmappedPhysicalKey,
  bool synthesized = false,
}) => ui.KeyData(
  timeStamp: Duration.zero,
  type: type,
  physical: physical,
  logical: logical.keyId,
  character: null,
  synthesized: synthesized,
);

// Captured Win+V sequence from flutter/flutter#143997. Keep its raw message
// boundaries: synthesized events do not have a matching raw key message.
List<ui.KeyData> windowsClipboardHistoryEvents() => [
  windowsKeyData(LogicalKeyboardKey.controlLeft, ui.KeyEventType.down),
  windowsKeyData(
    LogicalKeyboardKey.controlLeft,
    ui.KeyEventType.up,
    synthesized: true,
  ),
  windowsKeyData(LogicalKeyboardKey.keyV, ui.KeyEventType.down),
  windowsKeyData(LogicalKeyboardKey.keyV, ui.KeyEventType.up),
  windowsKeyData(
    LogicalKeyboardKey.controlLeft,
    ui.KeyEventType.down,
    synthesized: true,
  ),
  windowsKeyData(
    LogicalKeyboardKey.controlLeft,
    ui.KeyEventType.up,
    synthesized: true,
  ),
];

Future<void> sendWindowsKeyData(WidgetTester tester, ui.KeyData data) async {
  tester.platformDispatcher.onKeyData!(data);
  if (data.synthesized || data.physical == 0) return;
  final raw = KeyEventSimulator.getKeyData(
    LogicalKeyboardKey(data.logical),
    platform: 'windows',
    isDown: data.type != ui.KeyEventType.up,
    character: '',
  );
  if (data.physical == windowsUnmappedPhysicalKey) {
    raw['scanCode'] = 0;
    raw['modifiers'] = 0;
  }
  await sendWindowsRawKey(tester, raw);
}

Future<void> sendWindowsRawKey(
  WidgetTester tester,
  Map<String, dynamic> raw,
) async {
  final completed = Completer<void>();
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.keyEvent.name,
    const JSONMessageCodec().encodeMessage(raw),
    (_) => completed.complete(),
  );
  await completed.future;
}

Future<void> sendWindowsClipboardHistoryPaste(WidgetTester tester) async {
  for (final data in windowsClipboardHistoryEvents()) {
    await sendWindowsKeyData(tester, data);
  }
}

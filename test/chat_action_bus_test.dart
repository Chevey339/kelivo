import 'dart:async';

import 'package:Kelivo/desktop/hotkeys/chat_action_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatActionBus broadcasts cancelTransientUi to listeners', () async {
    final received = <ChatAction>[];
    final completer = Completer<void>();

    final sub = ChatActionBus.instance.stream.listen((action) {
      received.add(action);
      if (action == ChatAction.cancelTransientUi && !completer.isCompleted) {
        completer.complete();
      }
    });

    ChatActionBus.instance.fire(ChatAction.cancelTransientUi);
    await completer.future.timeout(const Duration(seconds: 1));
    await sub.cancel();

    expect(received, contains(ChatAction.cancelTransientUi));
  });
}

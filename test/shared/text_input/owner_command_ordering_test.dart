import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mirror_harness.dart';

Future<void> deliverOwnerCommand(MirrorHarness h, String name) async {
  final reply = Completer<void>();
  await h.tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    h.bridge.channel.name,
    MirrorHarness.codec.encodeMethodCall(
      MethodCall('command', {'session': h.bridge.session, 'command': name}),
    ),
    (data) {
      try {
        MirrorHarness.codec.decodeEnvelope(data!);
        reply.complete();
      } catch (error, stack) {
        reply.completeError(error, stack);
      }
    },
  );
  return reply.future;
}

void main() {
  testWidgets('reference TextField submits the value visible at Dart delivery', (
    tester,
  ) async {
    final source = 'alpha beta\n' * 300;
    final controller = TextEditingController.fromValue(
      TextEditingValue(
        text: source.replaceRange(100, 100, 'A'),
        selection: const TextSelection.collapsed(offset: 101),
      ),
    );
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.send,
            onSubmitted: (value) {
              sent.add(value);
              controller.clear();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    // The platform action message contains an action and client ID, not a
    // text snapshot. A delayed action is delivered after this local app write.
    controller.value = controller.value.replaced(controller.selection, 'B');
    final atDartDelivery = controller.text;
    await tester.testTextInput.receiveAction(TextInputAction.send);
    final remaining = controller.text;
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    expect(sent, hasLength(1));
    expect(sent.single == atDartDelivery, isTrue);
    expect(remaining, isEmpty);
  });

  testWidgets('owner Send matches TextField for an optimistic app edit', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha beta\n' * 300;
    await h.mount(source, 100);
    await h.replace(100, 100, 'A');
    final acceptedSendValue = h.native;
    final submissions = <String>[];
    h.bridge.onCommand = (command, snapshot) {
      expect(command, 'submit');
      submissions.add(snapshot.text);
      h.text.value = const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    };

    // The native action is in flight. The app has already made B visible
    // before Dart receives the action. Like TextField, Send includes B in the
    // submitted value even though its native apply RPC has not completed.
    h.holdAppCommands = true;
    h.text.value = h.text.value.replaced(h.text.selection, 'B');
    final atDartDelivery = h.text.text;
    await tester.idle();
    expect(h.native, acceptedSendValue);
    expect(h.heldAppCommands, hasLength(1));
    await deliverOwnerCommand(h, 'submit');
    await h.releaseAllAppCommands();
    final finalValue = await h.bridge.flush();
    await h.dispose();

    expect(submissions, hasLength(1));
    expect(submissions.single == atDartDelivery, isTrue);
    expect(finalValue.text, isEmpty);
  });

  testWidgets('Send2 includes the earlier unconfirmed Send1 consumption', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha beta\n' * 300;
    await h.mount(source, 100);
    await h.replace(100, 100, 'A');
    final firstSend = h.native.text;
    final submissions = <String>[];
    h.bridge.onCommand = (_, snapshot) {
      submissions.add(snapshot.text);
      h.text.value = const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    };
    h.holdAppCommands = true;
    await deliverOwnerCommand(h, 'submit');
    await tester.idle();
    expect(h.heldAppCommands, hasLength(1));
    await h.replace(101, 101, 'B');
    expect(h.native.text.length, source.length + 2);
    await deliverOwnerCommand(h, 'submit');
    await h.releaseAllAppCommands();
    final finalValue = await h.bridge.flush();
    await h.dispose();

    expect(submissions, hasLength(2));
    expect(submissions.first == firstSend, isTrue);
    expect(submissions.last, 'B');
    expect(finalValue.text, isEmpty);
  });
}

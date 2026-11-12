import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mirror_harness.dart';

Future<void> deliverCommand(MirrorHarness h, {int? request}) async {
  const codec = StandardMethodCodec();
  final reply = Completer<void>();
  await h.tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    h.bridge.channel.name,
    codec.encodeMethodCall(
      MethodCall('command', {
        'session': h.bridge.session,
        'command': 'paste',
        'request': request,
      }),
    ),
    (data) {
      try {
        codec.decodeEnvelope(data!);
        reply.complete();
      } catch (error, stack) {
        reply.completeError(error, stack);
      }
    },
  );
  return reply.future;
}

void main() {
  testWidgets('close waits for accepted image registration after detaching', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount('alpha beta\n' * 300, 100);
    final persisted = Completer<void>();
    var registered = false;
    h.bridge.onContent = (content) async {
      expect(content.mimeType, 'image/png');
      expect(content.data, Uint8List.fromList([1, 2, 3]));
      await persisted.future;
      registered = true;
    };
    final delivery = h.dispatch(
      MirrorHarness.codec.encodeMethodCall(
        MethodCall('content', {
          'session': h.bridge.session,
          'mimeType': 'image/png',
          'uri': 'content://fixture/image',
          'data': Uint8List.fromList([1, 2, 3]),
        }),
      ),
    );
    await tester.idle();
    var closed = false;
    final close = h.bridge.close().then((_) => closed = true);
    await tester.idle();
    expect(h.bridge.client, isNull);
    expect(closed, isFalse);
    persisted.complete();
    await delivery;
    await close;
    expect(registered, isTrue);
    await h.dispose();
  });
  testWidgets(
    'app command waits for ordered owner delivery, not its RPC reply',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount('alpha beta\n' * 300, 100);
      TextEditingValue? received;
      h.bridge.onCommand = (_, snapshot) => received = snapshot;
      var delivered = false;
      final command = h.bridge
          .performCommand('paste')
          .then((_) => delivered = true);
      await tester.idle();
      final call = h.commands.lastWhere((c) => c.method == 'command');
      final request = (call.arguments as Map)['request'] as int;
      expect(delivered, isFalse);
      await h.replace(100, 100, 'X');
      final expected = h.text.value;
      var flushed = false;
      final flush = h.bridge.flush().then((_) => flushed = true);
      await tester.idle();
      expect(flushed, isFalse);
      await deliverCommand(h, request: request);
      await command;
      await flush;
      expect(received, expected);
      await h.dispose();
    },
  );

  testWidgets('close retains an accepted asynchronous owner paste', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha beta\n' * 300;
    await h.mount(source, 100);
    final clipboard = Completer<String>();
    var pendingPaste = false;
    h.bridge.onCommand = (_, snapshot) async {
      pendingPaste = true;
      final paste = await clipboard.future;
      h.text.value = h.text.value.replaced(h.text.selection, paste);
      pendingPaste = false;
    };
    final delivery = deliverCommand(h);
    await tester.idle();
    expect(pendingPaste, isTrue);
    var closed = false;
    final close = h.bridge.close().then((v) {
      closed = true;
      return v;
    });
    await tester.idle();
    expect(closed, isFalse);
    clipboard.complete('APP');
    await delivery;
    final finalValue = await close;
    expect(finalValue.text, source.replaceRange(100, 100, 'APP'));
    expect(finalValue, h.text.value);
    expect(pendingPaste, isFalse);
    await h.dispose();
  });

  testWidgets('owner failure settles its command and a concurrent flush', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount('alpha beta\n' * 300, 100);
    h.bridge.onCommand = (_, _) => throw StateError('owner failed');
    final command = h.bridge.performCommand('paste');
    final commandError = expectLater(command, throwsStateError);
    await tester.idle();
    final request =
        (h.commands.lastWhere((c) => c.method == 'command').arguments
                as Map)['request']
            as int;
    final flushError = expectLater(h.bridge.flush(), throwsStateError);
    await expectLater(
      deliverCommand(h, request: request),
      throwsA(isA<PlatformException>()),
    );
    await commandError;
    await flushError;
    await h.dispose();
  });

  testWidgets('an owner cannot deadlock by awaiting its own input barrier', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount('alpha beta\n' * 300, 100);
    h.bridge.onCommand = (_, snapshot) async {
      expect(snapshot, h.text.value);
      expect(h.bridge.flush, throwsStateError);
      expect(h.bridge.close, throwsStateError);
    };
    await deliverCommand(h);
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });
}

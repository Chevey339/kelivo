import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';
import 'package:re_editor/re_editor.dart';

import 'mirror_harness.dart';

void main() {
  testWidgets('native CRLF paste preserves offsets and paragraph mode', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha\nbeta\ngamma\n' * 200;
    await h.mount(source, 100);
    await h.replace(100, 100, 'X\r\nY');
    await tester.pumpAndSettle();
    final actual = h.text.value;
    final retainedLineRenderer = tester
        .state<LongMessageEditorState>(find.byType(LongMessageEditor))
        .usesLineEditor;
    await h.dispose();
    expect(actual.text, source.replaceRange(100, 100, 'X\r\nY'));
    expect(actual.selection, const TextSelection.collapsed(offset: 104));
    expect(retainedLineRenderer, isFalse);
  });

  testWidgets('app CRLF paste survives native input after fallback', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha\nbeta\ngamma\n' * 200;
    await h.mount(source, 100);
    h.text.value = h.text.value.replaced(h.text.selection, 'X\r\nY');
    await tester.pumpAndSettle();
    expect(h.text.selection.extentOffset, 104);
    expect(
      tester
          .state<LongMessageEditorState>(find.byType(LongMessageEditor))
          .usesLineEditor,
      isFalse,
    );
    // The old native document is now closed; type through the new TextField
    // connection rather than injecting a late event into a retired session.
    await tester.showKeyboard(find.byType(TextField));
    tester.testTextInput.updateEditingValue(
      h.text.value.replaced(h.text.selection, 'Z'),
    );
    await tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, 'X\r\nYZ'));
    expect(h.text.selection.extentOffset, 105);
    expect(await h.bridge.flush(), h.text.value);
    await h.dispose();
  });

  testWidgets('next native arrow preserves touched wrap affinity', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount(
      'aaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ' * 200,
      100,
    );
    final layout = (h.bridge.client! as CodeNavigationInputClient)
        .captureNavigationLayout()!;
    TextSelection? expected;
    var trigger = 0;
    for (var offset = 1; offset < 250; offset++) {
      layout.invalidate();
      final upstream = layout.resolve(
        h.text.value.copyWith(
          selection: TextSelection.collapsed(
            offset: offset,
            affinity: TextAffinity.upstream,
          ),
        ),
        true,
        false,
      );
      layout.invalidate();
      final downstream = layout.resolve(
        h.text.value.copyWith(
          selection: TextSelection.collapsed(offset: offset),
        ),
        true,
        false,
      );
      if (upstream.extentOffset != downstream.extentOffset) {
        trigger = offset;
        expected = upstream;
        break;
      }
    }
    layout.dispose();
    expect(expected, isNotNull);
    final touched = TextSelection.collapsed(
      offset: trigger,
      affinity: TextAffinity.upstream,
    );
    h.text.selection = touched;
    await tester.pump();
    expect(h.bridge.nativeValue!.selection, touched);
    const codec = StandardMethodCodec();
    ByteData? reply;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'kelivo/native_message_input',
      codec.encodeMethodCall(
        MethodCall('navigate', {
          'session': h.bridge.session,
          'revision': h.bridge.revision,
          'base': trigger,
          'extent': trigger,
          'up': true,
          'extend': false,
        }),
      ),
      (bytes) => reply = bytes,
    );
    final target = codec.decodeEnvelope(reply!) as Map;
    await h.dispose();
    expect(target['extent'], expected!.extentOffset);
    expect(target['affinity'], expected.affinity.name);
  });

  for (final action in ['flush', 'close']) {
    testWidgets('native navigation failure settles pending $action', (
      tester,
    ) async {
      final h = MirrorHarness(tester);
      await h.mount('original text\n' * 400, 100);
      final nativeBarrier = Completer<Object?>();
      var barrierRequested = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        h.bridge.channel,
        (call) async {
          if (call.method == 'flush') {
            barrierRequested = true;
            return nativeBarrier.future;
          }
          if (call.method == 'close') {
            return {'revision': h.nativeRevision};
          }
          return null;
        },
      );
      var completed = false;
      Object? observedError;
      final pending = (action == 'flush' ? h.bridge.flush() : h.bridge.close())
          .then<void>(
            (_) => completed = true,
            onError: (Object error, StackTrace stack) {
              observedError = error;
              completed = true;
            },
          );
      await tester.pump();
      expect(barrierRequested, isTrue);
      await h.dispatch(
        MirrorHarness.codec.encodeMethodCall(
          MethodCall('failure', {
            'session': h.bridge.session,
            'error': 'No retained navigation layout',
          }),
        ),
      );
      await tester.pump();
      final settledOnFailure = completed;
      final errorOnFailure = observedError;
      // Release the intentionally blocked native RPC after observing the
      // result so this focused regression never hangs the test process.
      nativeBarrier.complete({'revision': h.nativeRevision});
      await tester.pump();
      await pending;
      h.bridge.failures.clear();
      await h.dispose();
      expect(settledOnFailure, isTrue);
      expect(errorOnFailure, isA<StateError>());
    });
  }
}

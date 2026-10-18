import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'mirror_harness.dart';

void main() {
  for (final returnToLines in [false, true]) {
    testWidgets(
      'old clipboard reply cannot overwrite later edits, return=$returnToLines',
      (tester) async {
        final h = MirrorHarness(tester);
        final source = 'alpha beta gamma\n' * 200;
        await h.mount(source, 100);
        final clipboardReply = Completer<Object?>();
        var clipboardRequested = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') {
              clipboardRequested = true;
              return clipboardReply.future;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final origin = tester.getTopLeft(find.byType(CodeEditor));
        await tester.longPressAt(origin + const Offset(30, 12));
        await tester.pump();
        expect(find.text('Paste'), findsOneWidget);
        await tester.tap(find.text('Paste'));
        await tester.pump();
        expect(clipboardRequested, isTrue);
        final paragraphText = source.replaceRange(200, 200, 'A\r\nB');
        h.text.value = TextEditingValue(
          text: paragraphText,
          selection: const TextSelection.collapsed(offset: 204),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.showKeyboard(find.byType(TextField));
        final afterParagraphInput = h.text.value.replaced(
          h.text.selection,
          'Y',
        );
        tester.testTextInput.updateEditingValue(afterParagraphInput);
        await tester.pump();
        if (returnToLines) {
          h.text.value = h.text.value.copyWith(
            text: h.text.text.replaceAll('\r', ''),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CodeEditor), findsOneWidget);
        }
        final expected = h.text.value;
        clipboardReply.complete({'text': 'PASTE'});
        await tester.pumpAndSettle();
        final afterClipboard = h.text.value;
        await h.dispose();
        expect(
          afterClipboard,
          expected,
          reason:
              'A retired line controller must not erase newer paragraph input',
        );
      },
    );
  }

  testWidgets('touch during mode handoff must not edit a closing bridge', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount('alpha beta gamma\n' * 200, 100);
    final flushReply = Completer<Object?>();
    var waitingForFlush = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      h.bridge.channel,
      (call) async {
        if (call.method == 'flush') {
          waitingForFlush = true;
          return flushReply.future;
        }
        if (call.method == 'close') {
          return {'revision': h.nativeRevision};
        }
        return null;
      },
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    await tester.pump();
    expect(waitingForFlush, isTrue);
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.readOnly, isTrue);
    expect(h.bridge.client, isNull);
    final before = h.text.selection;
    final origin = tester.getTopLeft(find.byType(CodeEditor));
    await tester.tapAt(origin + const Offset(30, 12));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    final error = tester.takeException();
    final after = h.text.selection;
    flushReply.complete({'revision': h.nativeRevision});
    await tester.pumpAndSettle();
    await h.dispose();
    expect(
      after,
      before,
      reason: 'Selection is frozen until the handoff completes',
    );
    expect(error, isNull);
  });
}

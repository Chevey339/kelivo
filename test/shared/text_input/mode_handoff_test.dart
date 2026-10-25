import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'mirror_harness.dart';

void main() {
  testWidgets('handoff does not steal focus acquired by another input', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final other = FocusNode();
    await h.mount(
      'alpha beta gamma\n' * 200,
      100,
      otherInput: TextField(focusNode: other),
    );
    final barrier = Completer<Object?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      h.bridge.channel,
      (call) async {
        if (call.method == 'flush') return barrier.future;
        if (call.method == 'close') return {'revision': h.nativeRevision};
        return null;
      },
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    await tester.pump();
    other.requestFocus();
    await tester.pump();
    expect(other.hasPrimaryFocus, isTrue);
    barrier.complete({'revision': h.nativeRevision});
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(other.hasPrimaryFocus, isTrue);
    await h.dispose();
    other.dispose();
  });

  testWidgets('accessibility handoff drains and reopens the current model', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha\nbeta\ngamma\n' * 200;
    await h.mount(source, 100);
    final oldSession = h.bridge.session;
    h.bridge.paused = true;
    await h.replace(100, 100, 'X');
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(h.text.text, source.replaceRange(100, 100, 'X'));
    expect(
      tester.testTextInput.hasAnyClients,
      isTrue,
      reason: 'Paragraph editor must open its input connection automatically',
    );
    tester.testTextInput.updateEditingValue(
      h.text.value.replaced(h.text.selection, 'Y'),
    );
    await tester.pump();
    expect((await h.bridge.flush()).text, source.replaceRange(100, 100, 'XY'));
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(h.bridge.session, isNot(oldSession));
    expect(h.native.text, source.replaceRange(100, 100, 'XY'));
    await h.replace(102, 102, 'Z');
    await tester.pump();
    expect(h.text.text, source.replaceRange(100, 100, 'XYZ'));
    await h.dispose();
  });

  testWidgets('paragraph fallback opens with every accepted old native edit', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = 'alpha\nbeta\ngamma\n' * 200;
    await h.mount(source, 100);
    h.bridge.paused = true;
    await h.replace(100, 100, 'X');
    tester.testTextInput.log.clear();
    h.text.value = TextEditingValue(
      text: source.replaceRange(200, 200, 'A\r\nB'),
      selection: const TextSelection.collapsed(offset: 204),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(
      tester.testTextInput.hasAnyClients,
      isTrue,
      reason: 'Paragraph editor must open its input connection automatically',
    );
    await tester.pump();
    final opened = tester.testTextInput.log
        .where((call) => call.method == 'TextInput.setEditingState')
        .map(
          (call) => TextEditingValue.fromJSON(
            Map<String, dynamic>.from(call.arguments as Map),
          ),
        )
        .first;
    final expected = source
        .replaceRange(200, 200, 'A\r\nB')
        .replaceRange(100, 100, 'X');
    // Capture the native paragraph editor's initial state before manually
    // releasing the old channel for cleanup. A new IME edit could use this base.
    h.bridge.resume();
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      opened.replaced(opened.selection, 'Y'),
    );
    await tester.pump();
    final actual = h.text.text;
    final saved = await h.bridge.flush();
    await h.dispose();
    expect(
      opened.text,
      expected,
      reason:
          'The new native connection must not start from an undrained model',
    );
    expect(actual, expected.replaceRange(205, 205, 'Y'));
    expect(saved.text, actual);
  });
}

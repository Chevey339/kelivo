import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

import 'mirror_harness.dart';

void main() {
  testWidgets(
    'native arrows resolve visual rows without changing the document',
    (tester) async {
      final h = MirrorHarness(tester);
      final source = '中文 abcdefghijklmnopqrstuvwxyz ' * 400;
      await h.mount(source, 100);
      final client = h.bridge.client! as CodeNavigationInputClient;
      final before = h.text.value;
      final down = client.resolveVerticalNavigation(
        before.selection,
        false,
        false,
      );
      expect(down.isCollapsed, isTrue);
      expect(down.extentOffset, greaterThan(100));
      expect(down.extentOffset, lessThan(200));
      expect(
        h.text.value,
        before,
        reason: 'Resolution cannot be a second writer',
      );
      final extended = client.resolveVerticalNavigation(
        before.selection,
        false,
        true,
      );
      expect(extended.baseOffset, 100);
      expect(extended.extentOffset, down.extentOffset);
      final up = client.resolveVerticalNavigation(down, true, false);
      expect(up.extentOffset, 100);
      await h.dispose();
    },
  );

  testWidgets('navigation respects explicit newlines and document boundaries', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    final source = ('abcdefghij\n' * 400);
    await h.mount(source, 5);
    final client = h.bridge.client! as CodeNavigationInputClient;
    for (final selected in [
      const TextSelection(baseOffset: 2, extentOffset: 5),
      const TextSelection(baseOffset: 5, extentOffset: 2),
    ]) {
      expect(
        client.resolveVerticalNavigation(selected, true, false),
        const TextSelection.collapsed(offset: 2),
      );
      expect(
        client.resolveVerticalNavigation(selected, false, false),
        const TextSelection.collapsed(offset: 5),
      );
    }
    expect(
      client.resolveVerticalNavigation(h.text.selection, false, false),
      const TextSelection.collapsed(offset: 16),
    );
    expect(
      client.resolveVerticalNavigation(
        const TextSelection.collapsed(offset: 0),
        true,
        false,
      ),
      const TextSelection.collapsed(offset: 0),
    );
    await h.dispose();
  });
  testWidgets(
    'vertical navigation remembers x across short rows and resets on a new caret',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount('aaaaaaaaaaaaaaa\naa\naaaaaaaaaaaaaaa\n' * 100, 9);
      final client = h.bridge.client! as CodeNavigationInputClient;
      Future<TextSelection> move(bool up, bool extend) async {
        final next = client.resolveVerticalNavigation(
          h.text.selection,
          up,
          extend,
        );
        await h.send(h.native.copyWith(selection: next), []);
        await tester.pump();
        return next;
      }

      expect((await move(false, false)).extentOffset, 18);
      expect((await move(false, false)).extentOffset, 28);
      expect((await move(true, false)).extentOffset, 18);
      expect((await move(true, false)).extentOffset, 9);
      h.text.selection = const TextSelection.collapsed(offset: 8);
      await tester.pump();
      expect(
        await move(false, true),
        const TextSelection(baseOffset: 8, extentOffset: 18),
      );
      expect(
        await move(false, true),
        const TextSelection(baseOffset: 8, extentOffset: 27),
      );
      await h.dispose();
    },
  );
  testWidgets(
    'changing visual affinity at a wrap boundary resets vertical memory',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(
        ('aaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ' * 200),
        0,
      );
      final client = h.bridge.client! as CodeNavigationInputClient;
      TextSelection? boundary;
      for (var offset = 1; offset < 250; offset++) {
        final next = client.resolveVerticalNavigation(
          TextSelection.collapsed(offset: offset),
          true,
          false,
        );
        if (next.affinity == TextAffinity.upstream && next.extentOffset > 0) {
          boundary = next;
          break;
        }
      }
      expect(
        boundary,
        isNotNull,
        reason: 'fixture must reach a visual wrap end',
      );
      await h.send(h.native.copyWith(selection: boundary), []);
      await tester.pump();
      final touch = boundary!.copyWith(affinity: TextAffinity.downstream);
      h.text.selection = touch;
      await tester.pump();
      final afterTouch = client.resolveVerticalNavigation(
        h.text.selection,
        false,
        false,
      );
      // A different caret definitely discards old column memory. Returning to the
      // touched visual position must give the same result as the affinity change.
      h.text.selection = TextSelection.collapsed(
        offset: touch.extentOffset + 1,
      );
      await tester.pump();
      h.text.selection = touch;
      await tester.pump();
      final fresh = client.resolveVerticalNavigation(
        h.text.selection,
        false,
        false,
      );
      expect(afterTouch, fresh);
      await h.dispose();
    },
  );

  testWidgets(
    'a completed document cannot navigate a reopened document of the same client',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount('long text\n' * 400, 100);
      final oldSession = h.bridge.session;
      final active = h.bridge.client!;
      await h.bridge.close();
      h.bridge.bindDocument(h.text);
      h.bridge.attach(active, const TextInputConfiguration());
      h.bridge.setEditingState(h.text.value);
      await tester.pump();
      const codec = StandardMethodCodec();
      ByteData? reply;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'kelivo/native_message_input',
        codec.encodeMethodCall(
          MethodCall('navigate', {
            'session': oldSession,
            'revision': 0,
            'base': 100,
            'extent': 100,
            'up': false,
            'extend': false,
          }),
        ),
        (value) => reply = value,
      );
      expect(
        () => codec.decodeEnvelope(reply!),
        throwsA(isA<PlatformException>()),
      );
      expect(h.text.selection.extentOffset, 100);
      await h.dispose();
    },
  );
}

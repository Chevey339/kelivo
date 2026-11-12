import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mirror_harness.dart';

void main() {
  final source = List.generate(400, (i) => 'line $i 中文 abcdefghijk').join('\n');
  testWidgets(
    'the latest touch wins when it returns to the acknowledged caret',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      h.holdAppCommands = true;
      h.text.selection = const TextSelection.collapsed(offset: 200);
      await tester.pump();
      h.text.selection = const TextSelection.collapsed(offset: 100);
      await tester.pump();
      expect(h.heldAppCommands, hasLength(1));
      await h.releaseNextAppCommand();
      expect(
        h.text.selection.extentOffset,
        100,
        reason: 'The first acknowledgement must not erase the later touch',
      );
      expect(h.heldAppCommands, hasLength(1));
      await h.releaseAllAppCommands();
      expect(h.native.selection, const TextSelection.collapsed(offset: 100));
      expect(h.text.selection, h.native.selection);
      expect(h.text.text, source);
      expect(h.bridge.failures, isEmpty);
      await h.dispose();
    },
  );

  testWidgets(
    'equal touch offsets in different revisions stay distinct across retry',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      h.holdAppCommands = true;
      h.text.selection = const TextSelection.collapsed(offset: 200);
      await tester.pump();
      expect(h.heldAppCommands.single['revision'], 0);
      await h.replace(0, 0, 'X');
      await tester.pump();
      expect(h.text.selection.extentOffset, 201);
      h.text.selection = const TextSelection.collapsed(offset: 200);
      await tester.pump();
      await h.releaseNextAppCommand(); // stale revision is rejected
      expect(h.heldAppCommands.single['revision'], 1);
      expect(h.heldAppCommands.single['selection'], [201, 201]);
      await h
          .releaseNextAppCommand(); // first touch at its transformed coordinate
      expect(h.text.selection.extentOffset, 200);
      expect(h.heldAppCommands.single['selection'], [200, 200]);
      await h.releaseAllAppCommands();
      expect(h.native.selection, const TextSelection.collapsed(offset: 200));
      expect(h.text.selection, h.native.selection);
      expect(h.text.text, 'X$source');
      expect(h.bridge.failures, isEmpty);
      await h.dispose();
    },
  );
}

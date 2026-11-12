import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'mirror_harness.dart';

void main() {
  testWidgets(
    'native navigation and app acknowledgement retain the visual wrap side',
    (tester) async {
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
        final next = layout.resolve(
          h.text.value.copyWith(
            selection: TextSelection.collapsed(offset: offset),
          ),
          true,
          false,
        );
        if (next.affinity == TextAffinity.upstream && next.extentOffset > 0) {
          trigger = offset;
          expected = next;
          break;
        }
      }
      layout.dispose();
      expect(expected, isNotNull);
      h.text.selection = TextSelection.collapsed(offset: trigger);
      await tester.pump();
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
      expect(target['affinity'], 'upstream');
      expect(target['extent'], expected!.extentOffset);
      final event = h.event(h.native.copyWith(selection: expected), []);
      event['affinity'] = target['affinity'];
      await h.dispatch(codec.encodeMethodCall(MethodCall('event', event)));
      await tester.pump();
      expect(h.text.selection, expected);
      // A touch can change only affinity at the same UTF-16 offset. The native
      // app acknowledgement carries numeric offsets, so retain the local side.
      h.text.selection = expected.copyWith(affinity: TextAffinity.downstream);
      await tester.pump();
      h.text.selection = expected;
      await tester.pump();
      expect(h.text.selection, expected);
      expect(h.bridge.value!.selection, expected);
      await h.dispose();
    },
  );
}

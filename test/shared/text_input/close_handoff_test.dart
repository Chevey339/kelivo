import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'mirror_harness.dart';

void main() {
  final source = 'original text\n' * 400;
  testWidgets(
    'closing drains queued delivery after the input client detaches',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      h.bridge.paused = true;
      await h.replace(100, 100, 'X');
      h.bridge.detach(h.bridge.client!);
      expect(h.text.text, source);
      final closed = await h.bridge.close();
      expect(closed.text, source.replaceRange(100, 100, 'X'));
      expect(h.text.text, closed.text);
      expect(h.bridge.queued, isEmpty);
      expect(h.bridge.failures, isEmpty);
      await h.dispose();
    },
  );

  testWidgets('navigation and accepted edits drain after renderer disposal', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount('中文 abcdefghijklmnopqrstuvwxyz ' * 400, 100);
    final expected = (h.bridge.client! as CodeNavigationInputClient)
        .resolveVerticalNavigation(h.text.selection, false, false)
        .extentOffset;
    final session = h.bridge.session;
    await tester.pumpWidget(const SizedBox());
    expect(h.bridge.client, isNull);
    const codec = StandardMethodCodec();
    ByteData? response;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'kelivo/native_message_input',
      codec.encodeMethodCall(
        MethodCall('navigate', {
          'session': session,
          'revision': 0,
          'base': 100,
          'extent': 100,
          'up': false,
          'extend': false,
        }),
      ),
      (data) => response = data,
    );
    final target = codec.decodeEnvelope(response!) as Map;
    expect(target['extent'], expected);
    await h.replace(expected, expected, 'X');
    final saved = await h.bridge.close();
    expect(saved.text, h.native.text);
    expect(h.text.text, saved.text);
    expect(saved.selection.extentOffset, expected + 1);
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });

  testWidgets('app changes while blurred join the document queue', (
    tester,
  ) async {
    final h = MirrorHarness(tester);
    await h.mount(source, 100);
    h.bridge.detach(h.bridge.client!);
    h.text.value = h.text.value.replaced(h.text.selection, 'APP');
    await tester.pump();
    final saved = await h.bridge.flush();
    expect(saved.text, source.replaceRange(100, 100, 'APP'));
    expect(h.native.text, saved.text);
    await h.replace(103, 103, 'X');
    expect(
      (await h.bridge.close()).text,
      source.replaceRange(100, 100, 'APPX'),
    );
    expect(h.bridge.failures, isEmpty);
    await h.dispose();
  });
  testWidgets(
    'save already in progress completes before close releases the document',
    (tester) async {
      final h = MirrorHarness(tester);
      await h.mount(source, 100);
      h.holdAppCommands = true;
      h.text.value = h.text.value.replaced(h.text.selection, 'APP');
      await tester.pump();
      final saving = h.bridge.flush();
      final closing = h.bridge.close();
      final duringClose = h.bridge.flush();
      await h.releaseAllAppCommands();
      final saved = await saving;
      expect((await closing).text, saved.text);
      expect((await duringClose).text, saved.text);
      expect(saved.text, source.replaceRange(100, 100, 'APP'));
      final methods = h.commands.map((call) => call.method).toList();
      expect(methods.where((method) => method == 'close').length, 1);
      expect(
        methods.skip(methods.indexOf('close') + 1),
        isNot(contains('flush')),
      );
      await h.dispose();
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/shared/widgets/long_message_editor.dart';

import 'mirror_harness.dart';

void main() {
  for (final interaction in ['content', 'action']) {
    testWidgets('accepted queued $interaction survives native mode handoff', (
      tester,
    ) async {
      final h = MirrorHarness(tester);
      await h.mount('alpha beta gamma\n' * 200, 100);
      final inserted = <KeyboardInsertedContent>[];
      final submissions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LongMessageEditor(
              controller: h.text,
              autofocus: true,
              decoration: const InputDecoration(),
              inputConnectionFactory: h.bridge.openConnection,
              textInputAction: TextInputAction.send,
              onSubmitted: submissions.add,
              contentInsertionConfiguration: ContentInsertionConfiguration(
                allowedMimeTypes: const ['image/png'],
                onContentInserted: inserted.add,
              ),
              onInputModeExit: () async {
                await h.bridge.close();
                h.bridge.bindDocument(h.text);
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(h.bridge.client, isNotNull);
      final acceptedSession = h.bridge.session;
      final pixels = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      // MirrorConnection.insertContent reads and accepts these bytes before it
      // queues the event behind navigation. The old session remains routable
      // until its close barrier completes, even after the renderer detaches.
      final contentMessage = MirrorHarness.codec.encodeMethodCall(
        MethodCall(interaction, {
          'session': acceptedSession,
          'type': interaction,
          'action': 4,
          'mimeType': 'image/png',
          'uri': 'content://ime.test/accepted.png',
          'data': pixels,
        }),
      );
      final flushReply = Completer<Object?>();
      var barrierPending = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        h.bridge.channel,
        (call) async {
          if (call.method == 'flush') {
            barrierPending = true;
            return flushReply.future;
          }
          if (call.method == 'close') {
            return {'revision': h.nativeRevision};
          }
          return null;
        },
      );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      await tester.pump();
      expect(barrierPending, isTrue);
      expect(h.bridge.client, isNull);
      await h.dispatch(contentMessage);
      flushReply.complete({'revision': h.nativeRevision});
      await tester.pumpAndSettle();
      await h.dispose();
      if (interaction == 'content') {
        expect(inserted, hasLength(1));
        expect(inserted.single.mimeType, 'image/png');
        expect(inserted.single.data, pixels);
      } else {
        expect(submissions, ['alpha beta gamma\n' * 200]);
      }
    });
  }
}

import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/audio_clip_player.dart';

import '../../support/fake_audioplayers_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = FakeAudioplayersPlatform();
  final playback = AudioClipPlayback.instance;

  setUpAll(() {
    AudioplayersPlatformInterface.instance = platform;
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
  });

  setUp(() {
    platform.calls.clear();
    platform.sourceGates.clear();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Widget clips(String? firstPath) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Column(
        children: [
          if (firstPath != null)
            AudioClipPlayer(
              key: const ValueKey('first'),
              path: firstPath,
              builder: (_, button, time) =>
                  Row(children: [button, if (time != null) Text(time)]),
            ),
          AudioClipPlayer(
            key: const ValueKey('second'),
            path: '/tmp/widget-b.wav',
            builder: (_, button, time) =>
                Row(children: [button, if (time != null) Text(time)]),
          ),
        ],
      ),
    ),
  );

  for (final replacement in <String?>[null, '/tmp/widget-new.wav']) {
    testWidgets(
      '${replacement == null ? 'removing' : 'replacing'} the playing card does not notify a sibling during tree updates',
      (tester) async {
        await tester.pumpWidget(clips('/tmp/widget-a.wav'));
        expect(find.byType(AudioClipPlayer), findsNWidgets(2));
        await tester.runAsync(() async {
          await tester.tap(
            find.descendant(
              of: find.byKey(const ValueKey('first')),
              matching: find.byTooltip('Play audio'),
            ),
          );
          await settle();
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(playback.status.value?.path, '/tmp/widget-a.wav');
        expect(playback.status.value?.playing, isTrue);
        expect(platform.resumed, ['/tmp/widget-a.wav']);
        expect(find.byTooltip('Pause'), findsOneWidget);

        await tester.pumpWidget(clips(replacement));
        expect(tester.takeException(), isNull);
        await tester.runAsync(settle);
        await tester.pumpAndSettle();
        expect(playback.status.value, isNull);
        expect(find.byTooltip('Pause'), findsNothing);
        expect(platform.calls, contains('stop:/tmp/widget-a.wav'));
      },
    );
  }

  test('a clip removed while its source prepares never starts', () async {
    final owner = Object();
    final gate = platform.sourceGates['/tmp/a.wav'] = Completer<void>();

    final start = playback.toggle(owner: owner, path: '/tmp/a.wav');
    await settle();
    await playback.stopFor(owner);
    gate.complete();
    await start;

    expect(platform.resumed, isEmpty);
    expect(playback.status.value, isNull);
  });

  test('a later clip wins over an earlier start that resolves late', () async {
    final first = Object();
    final second = Object();
    final gate = platform.sourceGates['/tmp/a.wav'] = Completer<void>();

    final startFirst = playback.toggle(owner: first, path: '/tmp/a.wav');
    await settle();
    await playback.toggle(owner: second, path: '/tmp/b.wav');
    gate.complete();
    await startFirst;

    expect(platform.resumed, ['/tmp/b.wav']);
    expect(playback.status.value?.path, '/tmp/b.wav');
    await playback.stopFor(second);
  });

  test('a deferred owner stop never clears a newly started clip', () async {
    final first = Object();
    final second = Object();
    await playback.toggle(owner: first, path: '/tmp/a.wav');
    final stopped = playback.stopFor(first);
    final started = playback.toggle(owner: second, path: '/tmp/b.wav');
    await Future.wait([stopped, started]);
    expect(playback.status.value?.owner, same(second));
    expect(playback.status.value?.path, '/tmp/b.wav');
    expect(playback.status.value?.playing, isTrue);
    await playback.stopFor(second);
  });

  test('the replaced clip finishing late does not touch the next', () async {
    final first = Object();
    final second = Object();
    await playback.toggle(owner: first, path: '/tmp/a.wav');
    final gate = platform.sourceGates['/tmp/b.wav'] = Completer<void>();

    final startSecond = playback.toggle(owner: second, path: '/tmp/b.wav');
    await settle();
    // Even after the old player was told to stop, its events stay its own.
    platform.completePlayback('/tmp/a.wav');
    platform.failPlayback('/tmp/a.wav', StateError('late'));
    await settle();
    gate.complete();
    await startSecond;

    expect(platform.resumed, ['/tmp/a.wav', '/tmp/b.wav']);
    expect(playback.status.value?.owner, same(second));
    expect(playback.status.value?.playing, isTrue);
    await playback.stopFor(second);
  });

  test('a new path on the same owner never plays the old source', () async {
    final owner = Object();
    final gate = platform.sourceGates['/tmp/old.wav'] = Completer<void>();

    final startOld = playback.toggle(owner: owner, path: '/tmp/old.wav');
    await settle();
    // What AudioClipPlayer does when its path changes, then a tap.
    await playback.stopFor(owner);
    await playback.toggle(owner: owner, path: '/tmp/new.wav');
    gate.complete();
    await startOld;

    expect(platform.resumed, ['/tmp/new.wav']);
    await playback.stopFor(owner);
  });

  for (final event in ['completion', 'error']) {
    test('a $event while the clip is starting resets it', () async {
      final owner = Object();
      final gate = platform.sourceGates['/tmp/a.wav'] = Completer<void>();

      final start = playback.toggle(owner: owner, path: '/tmp/a.wav');
      await settle();
      if (event == 'error') {
        platform.failPlayback('/tmp/a.wav', StateError('decode failed'));
      } else {
        platform.completePlayback('/tmp/a.wav');
      }
      await settle();
      gate.complete();
      if (event == 'error') {
        // Surfaced to the caller, which reports that the clip can't play.
        await expectLater(start, throwsStateError);
      } else {
        await start;
      }

      expect(playback.status.value, isNull);
      expect(platform.resumed, isEmpty);
    });
  }

  test('native playback errors reset the status instead of escaping', () async {
    final owner = Object();
    await playback.toggle(owner: owner, path: '/tmp/a.wav');
    expect(playback.status.value?.playing, isTrue);

    platform.failPlayback('/tmp/a.wav', StateError('decode failed'));
    await settle();

    expect(playback.status.value, isNull);
  });

  test('pausing while loading keeps the clip from starting', () async {
    final owner = Object();
    final gate = platform.sourceGates['/tmp/a.wav'] = Completer<void>();

    final start = playback.toggle(owner: owner, path: '/tmp/a.wav');
    await settle();
    await playback.toggle(owner: owner, path: '/tmp/a.wav');
    gate.complete();
    await start;
    expect(platform.resumed, isEmpty);
    expect(playback.status.value?.playing, isFalse);

    await playback.toggle(owner: owner, path: '/tmp/a.wav');
    expect(platform.resumed, ['/tmp/a.wav']);
    await playback.stopFor(owner);
  });
}

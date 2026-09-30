import 'dart:async';

// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

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

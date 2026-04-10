import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/voice_message_playback_provider.dart';

void main() {
  group('VoiceMessagePlaybackProvider', () {
    test('marks playback active and clears on completion', () async {
      final completion = StreamController<void>.broadcast();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration>.broadcast();
      final playedPaths = <String>[];
      var stopCount = 0;
      final provider = VoiceMessagePlaybackProvider(
        play: (path) async {
          playedPaths.add(path);
        },
        stop: () async {
          stopCount++;
        },
        disposePlayer: () async {},
        completionStream: completion.stream,
        positionStream: position.stream,
        durationStream: duration.stream,
      );
      addTearDown(() async {
        await completion.close();
        await position.close();
        await duration.close();
        provider.dispose();
      });

      await provider.play(
        playbackId: 'msg-1:file-1',
        path: '/tmp/voice_1.wav',
        fallbackDuration: const Duration(seconds: 12),
      );

      expect(provider.isPlayingItem('msg-1:file-1'), isTrue);
      expect(provider.currentPlaybackId, 'msg-1:file-1');
      expect(provider.currentDuration, const Duration(seconds: 12));
      expect(playedPaths, ['/tmp/voice_1.wav']);
      expect(stopCount, 1);

      duration.add(const Duration(seconds: 15));
      position.add(const Duration(seconds: 4));
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentDuration, const Duration(seconds: 15));
      expect(provider.currentPosition, const Duration(seconds: 4));
      expect(provider.progressFor('msg-1:file-1'), closeTo(4 / 15, 0.0001));
      expect(
        provider.remainingFor('msg-1:file-1'),
        const Duration(seconds: 11),
      );

      completion.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentPlaybackId, isNull);
      expect(provider.currentPosition, Duration.zero);
      expect(provider.currentDuration, Duration.zero);
    });

    test('toggle stops current playback when tapping same bubble', () async {
      final completion = StreamController<void>.broadcast();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration>.broadcast();
      var beforePlayCount = 0;
      var stopCount = 0;
      final provider = VoiceMessagePlaybackProvider(
        play: (_) async {},
        stop: () async {
          stopCount++;
        },
        disposePlayer: () async {},
        completionStream: completion.stream,
        positionStream: position.stream,
        durationStream: duration.stream,
      );
      addTearDown(() async {
        await completion.close();
        await position.close();
        await duration.close();
        provider.dispose();
      });

      await provider.toggle(
        playbackId: 'msg-1:file-1',
        path: '/tmp/voice_1.wav',
        fallbackDuration: const Duration(seconds: 9),
        beforePlay: () async {
          beforePlayCount++;
        },
      );
      await provider.toggle(
        playbackId: 'msg-1:file-1',
        path: '/tmp/voice_1.wav',
        fallbackDuration: const Duration(seconds: 9),
        beforePlay: () async {
          beforePlayCount++;
        },
      );

      expect(beforePlayCount, 1);
      expect(stopCount, 2);
      expect(provider.currentPlaybackId, isNull);
      expect(provider.currentPosition, Duration.zero);
      expect(provider.currentDuration, Duration.zero);
    });

    test('toggle switches playback target and reruns beforePlay', () async {
      final completion = StreamController<void>.broadcast();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration>.broadcast();
      final playedPaths = <String>[];
      var beforePlayCount = 0;
      final provider = VoiceMessagePlaybackProvider(
        play: (path) async {
          playedPaths.add(path);
        },
        stop: () async {},
        disposePlayer: () async {},
        completionStream: completion.stream,
        positionStream: position.stream,
        durationStream: duration.stream,
      );
      addTearDown(() async {
        await completion.close();
        await position.close();
        await duration.close();
        provider.dispose();
      });

      await provider.toggle(
        playbackId: 'msg-1:file-1',
        path: '/tmp/voice_1.wav',
        fallbackDuration: const Duration(seconds: 8),
        beforePlay: () async {
          beforePlayCount++;
        },
      );
      await provider.toggle(
        playbackId: 'msg-2:file-2',
        path: '/tmp/voice_2.wav',
        fallbackDuration: const Duration(seconds: 3),
        beforePlay: () async {
          beforePlayCount++;
        },
      );

      expect(beforePlayCount, 2);
      expect(playedPaths, ['/tmp/voice_1.wav', '/tmp/voice_2.wav']);
      expect(provider.currentPlaybackId, 'msg-2:file-2');
      expect(provider.currentDuration, const Duration(seconds: 3));
    });

    test('clears playback state when play fails', () async {
      final completion = StreamController<void>.broadcast();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration>.broadcast();
      final provider = VoiceMessagePlaybackProvider(
        play: (_) async {
          throw StateError('boom');
        },
        stop: () async {},
        disposePlayer: () async {},
        completionStream: completion.stream,
        positionStream: position.stream,
        durationStream: duration.stream,
      );
      addTearDown(() async {
        await completion.close();
        await position.close();
        await duration.close();
        provider.dispose();
      });

      await expectLater(
        provider.play(
          playbackId: 'msg-1:file-1',
          path: '/tmp/voice_1.wav',
          fallbackDuration: const Duration(seconds: 5),
        ),
        throwsA(isA<StateError>()),
      );

      expect(provider.currentPlaybackId, isNull);
      expect(provider.currentPosition, Duration.zero);
      expect(provider.currentDuration, Duration.zero);
    });

    test('clamps position to duration when progress overshoots', () async {
      final completion = StreamController<void>.broadcast();
      final position = StreamController<Duration>.broadcast();
      final duration = StreamController<Duration>.broadcast();
      final provider = VoiceMessagePlaybackProvider(
        play: (_) async {},
        stop: () async {},
        disposePlayer: () async {},
        completionStream: completion.stream,
        positionStream: position.stream,
        durationStream: duration.stream,
      );
      addTearDown(() async {
        await completion.close();
        await position.close();
        await duration.close();
        provider.dispose();
      });

      await provider.play(
        playbackId: 'msg-1:file-1',
        path: '/tmp/voice_1.wav',
        fallbackDuration: const Duration(seconds: 4),
      );

      position.add(const Duration(seconds: 7));
      await Future<void>.delayed(Duration.zero);

      expect(provider.currentPosition, const Duration(seconds: 4));
      expect(provider.remainingFor('msg-1:file-1'), Duration.zero);
      expect(provider.progressFor('msg-1:file-1'), 1.0);
    });
  });
}

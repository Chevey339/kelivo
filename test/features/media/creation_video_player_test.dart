import 'dart:async';
import 'dart:io';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/features/media/widgets/creation_video_player.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _UnavailableCodec extends VideoPlayerPlatform {
  final events = StreamController<VideoEvent>();
  final released = <int>[];
  bool? pluginHandlesLifecycle;

  @override
  Future<void> init() async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<int> createWithOptions(VideoCreationOptions options) async {
    pluginHandlesLifecycle =
        options.videoPlayerOptions?.allowBackgroundPlayback == false;
    events.addError(
      PlatformException(code: 'VideoError', message: 'Unsupported format'),
    );
    return 12;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> dispose(int playerId) async {
    released.add(playerId);
    await events.close();
  }
}

void main() {
  testWidgets(
    'unsupported playback exposes the system player and releases the native player once',
    (tester) async {
      final previous = VideoPlayerPlatform.instance;
      final platform = _UnavailableCodec();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = previous);
      final item = GenerationItemRow(
        id: 'video',
        batchId: 'batch',
        ordinal: 0,
        mode: MediaMode.video,
        path: '/tmp/unsupported.mp4',
        mime: 'video/mp4',
        byteSize: 100,
        favorite: false,
        status: GenerationItemStatus.ready,
        createdAt: DateTime(2026),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CreationVideoPlayer(item: item, cover: const SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (
        var i = 0;
        !Platform.isLinux && platform.released.isEmpty && i < 100;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(find.byTooltip('Open in system player'), findsOneWidget);
      if (!Platform.isLinux) expect(platform.pluginHandlesLifecycle, isFalse);
      expect(platform.released, Platform.isLinux ? isEmpty : [12]);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(platform.released, Platform.isLinux ? isEmpty : [12]);
    },
  );
}

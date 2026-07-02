import 'package:Cuplivo/core/providers/tts_provider.dart';
import 'package:Cuplivo/core/services/tts/tts_playback_models.dart';
import 'package:Cuplivo/l10n/app_localizations.dart';
import 'package:Cuplivo/shared/widgets/app_overlays.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart' as lucide;
import 'package:provider/provider.dart';

class _FakeTtsProvider extends ChangeNotifier implements TtsProvider {
  _FakeTtsProvider({TtsPlaybackState? state})
    : _state =
          state ??
          const TtsPlaybackState(
            status: TtsPlaybackStatus.paused,
            position: Duration(seconds: 20),
            duration: Duration(minutes: 2),
            speed: 1.2,
            currentChunkIndex: 1,
            totalChunks: 3,
          );

  int rewindCount = 0;
  int playPauseCount = 0;
  int forwardCount = 0;
  int speedCount = 0;
  int stopCount = 0;
  final TtsPlaybackState _state;

  @override
  TtsPlaybackState get playbackState => _state;

  @override
  Future<void> seekBackward() async {
    rewindCount++;
  }

  @override
  Future<void> togglePause() async {
    playPauseCount++;
  }

  @override
  Future<void> seekForward() async {
    forwardCount++;
  }

  @override
  Future<void> cyclePlaybackSpeed() async {
    speedCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('AppOverlays gives the active TTS floating player an Overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(325, 750);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tts = _FakeTtsProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<TtsProvider>.value(
        value: tts,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return AppOverlays(child: child ?? const SizedBox.shrink());
          },
          home: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('继续播放'), findsOneWidget);
    expect(find.byTooltip('关闭播放器'), findsOneWidget);
    expect(find.byTooltip('展开播放控制'), findsOneWidget);
    expect(find.byTooltip('后退 15 秒'), findsNothing);
    expect(find.byTooltip('前进 15 秒'), findsNothing);
    expect(find.byTooltip('播放倍速'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(lucide.LucideIcons.grip), findsNothing);
    expect(
      find.byKey(const ValueKey('ttsCircularProgressButton')),
      findsOneWidget,
    );

    expect(find.bySemanticsLabel('语音播放器'), findsOneWidget);
    final player = find.byKey(const ValueKey('ttsFloatingPlayerSurface'));
    final beforeDrag = tester.getTopLeft(player);
    await tester.drag(player, const Offset(-18, 24));
    await tester.pump();
    final afterDrag = tester.getTopLeft(player);

    expect(afterDrag.dx, beforeDrag.dx);
    expect(afterDrag.dy, greaterThan(beforeDrag.dy));

    await tester.tap(find.byTooltip('展开播放控制'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('收起播放控制'), findsOneWidget);
    expect(find.byTooltip('后退 15 秒'), findsOneWidget);
    expect(find.byTooltip('前进 15 秒'), findsOneWidget);
    expect(find.byTooltip('播放倍速'), findsOneWidget);
    final expandedWidth = tester.getSize(player).width;

    await tester.tap(find.byTooltip('后退 15 秒'));
    await tester.tap(find.byTooltip('继续播放'));
    await tester.tap(find.byTooltip('前进 15 秒'));
    await tester.tap(find.byTooltip('播放倍速'));

    await tester.tap(find.byTooltip('收起播放控制'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.takeException(), isNull);
    final midCollapseWidth = tester.getSize(player).width;
    expect(midCollapseWidth, lessThan(expandedWidth));
    expect(midCollapseWidth, greaterThan(120));
    await tester.pump(const Duration(milliseconds: 170));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final collapsedWidth = tester.getSize(player).width;
    expect(collapsedWidth, lessThan(midCollapseWidth));

    expect(find.byTooltip('展开播放控制'), findsOneWidget);
    expect(find.byTooltip('后退 15 秒'), findsNothing);
    expect(find.byTooltip('前进 15 秒'), findsNothing);
    expect(find.byTooltip('播放倍速'), findsNothing);

    await tester.tap(find.byTooltip('关闭播放器'));

    expect(tts.rewindCount, 1);
    expect(tts.playPauseCount, 1);
    expect(tts.forwardCount, 1);
    expect(tts.speedCount, 1);
    expect(tts.stopCount, 1);
  });

  testWidgets('ended TTS player stays visible and exposes replay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(325, 750);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final tts = _FakeTtsProvider(
      state: const TtsPlaybackState(
        status: TtsPlaybackStatus.ended,
        position: Duration(minutes: 2),
        duration: Duration(minutes: 2),
        speed: 1.0,
        currentChunkIndex: 3,
        totalChunks: 3,
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<TtsProvider>.value(
        value: tts,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            return AppOverlays(child: child ?? const SizedBox.shrink());
          },
          home: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('语音播放器'), findsOneWidget);
    expect(find.byTooltip('重新播放'), findsOneWidget);

    await tester.tap(find.byTooltip('重新播放'));

    expect(tts.playPauseCount, 1);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../utils/safe_resize_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/foundation.dart'
    show ValueListenable, compute, Uint8List;
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/media_creation.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/animations/status_animation.dart';
import '../../../shared/responsive/screen_type_helper.dart';
import '../../../shared/widgets/thinking_sheen.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../models/creation_waiting_games.dart';
import '../providers/media_creation_controller.dart';
import 'creation_game_painter.dart';
import '../../../shared/widgets/sliding_segmented_tabs.dart';

int creationFakeProgress(Duration elapsed) {
  final fraction = elapsed.inMilliseconds.clamp(0, 1 << 32) / 45000;
  if (fraction >= 1) {
    return math.min(
      99,
      (90 + 10 * (1 - math.exp(-1.5 * (fraction - 1)))).floor(),
    );
  }
  const knots = [(0.0, 3), (.1, 25), (.55, 58), (.85, 88), (1.0, 90)];
  for (var index = 1; index < knots.length; index++) {
    final (after, finish) = knots[index];
    if (fraction <= after) {
      final (before, start) = knots[index - 1];
      return (start + (finish - start) * (fraction - before) / (after - before))
          .floor();
    }
  }
  return 90;
}

class CreationWaitingCard extends StatefulWidget {
  const CreationWaitingCard({
    super.key,
    required this.batch,
    this.progress,
    this.preview,
    this.queueAhead = 0,
    this.showStatusLabel = true,
    this.ordinal = 0,
    this.gameSeed,
    this.result,
    this.onGameHoldingChanged,
  });

  final GenerationBatchRow batch;
  final double? progress;
  final String? preview;
  final int queueAhead;
  final bool showStatusLabel;
  final int ordinal;
  final String? gameSeed;
  final Widget? result;
  final ValueChanged<bool>? onGameHoldingChanged;

  @override
  State<CreationWaitingCard> createState() => _CreationWaitingCardState();
}

enum _GamePhase { waiting, playing, paused, ended, fading, completing }

class _CreationWaitingCardState extends State<CreationWaitingCard>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _revealResult = false;
  bool _tickerMode = true;
  bool _inViewport = true;
  bool get _visible => _tickerMode && _inViewport;
  final _visibilityKey = UniqueKey();
  final _focus = FocusNode(debugLabel: 'Creation waiting game');
  final _paint = ValueNotifier<int>(0);
  Ticker? _ticker;
  Duration? _lastTick;
  Timer? _banner;
  CreationGame? _game;
  _GamePhase _phase = _GamePhase.waiting;
  CreationWaitGame _gamePreference = CreationWaitGame.random;
  Size _boardSize = Size.zero;
  Offset? _dragAnchor;
  bool _draggingPaddle = false;
  bool _registered = false;
  bool _foreground = true;
  Uint8List? _preview;
  int _previewRevision = 0;

  void _decodePreview() {
    final value = widget.preview;
    if (value == null) return;
    final revision = ++_previewRevision;
    unawaited(
      compute(_previewBytes, value).then((bytes) {
        if (mounted && revision == _previewRevision && bytes != null) {
          setState(() => _preview = bytes);
        }
      }),
    );
  }

  void _releasePreview() {
    _previewRevision++;
    if (_preview != null && mounted) setState(() => _preview = null);
  }

  @override
  void initState() {
    super.initState();
    _decodePreview();
    _focus.addListener(_focusChanged);
    _syncRegistration();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _pause(rebuild: false, releaseFocus: true);
    _syncTimer();
    _syncTicker();
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerMode = TickerMode.valuesOf(context).enabled;
    if (widget.result != null && MediaQuery.disableAnimationsOf(context)) {
      _previewRevision++;
      _preview = null;
    }
    if (!_tickerMode) _pause(rebuild: false, releaseFocus: true);
    _syncTimer();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant CreationWaitingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.batch.id != oldWidget.batch.id ||
        (!oldWidget.batch.status.isActive && widget.batch.status.isActive)) {
      _previewRevision++;
      _preview = null;
    }
    if (widget.result != null && MediaQuery.disableAnimationsOf(context)) {
      _previewRevision++;
      _preview = null;
    }
    if (oldWidget.result == null && widget.result != null) _revealResult = true;
    if (widget.result == null) _revealResult = false;
    if (oldWidget.result == null &&
        widget.result != null &&
        (_phase == _GamePhase.playing || _phase == _GamePhase.paused)) {
      _phase = _GamePhase.completing;
      _WaitingGameCards.release(this);
      _scheduleReset(const Duration(milliseconds: 1500));
    } else if ((!widget.batch.status.isActive || widget.result != null) &&
        _phase != _GamePhase.completing) {
      _reset(rebuild: false);
    }
    if (_phase != _GamePhase.completing &&
        oldWidget.preview != widget.preview) {
      _decodePreview();
    }
    _syncRegistration();
    _syncTimer();
    _syncTicker();
  }

  void _syncTimer() {
    final needsTick =
        widget.result == null &&
        _foreground &&
        _visible &&
        widget.batch.startedAt != null &&
        widget.batch.status == GenerationStatus.running &&
        (widget.progress == null ||
            DateTime.now().difference(widget.batch.startedAt!).inSeconds < 50);
    if (needsTick) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (!mounted) return;
        setState(() {});
        if (widget.progress != null &&
            DateTime.now().difference(widget.batch.startedAt!).inSeconds >=
                50) {
          _syncTimer();
        }
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _syncRegistration() {
    final needed =
        (widget.result == null && widget.batch.status.isActive) ||
        _phase == _GamePhase.completing;
    if (needed == _registered) return;
    _registered = needed;
    final binding = WidgetsBinding.instance;
    if (needed) {
      _foreground =
          binding.lifecycleState == null ||
          binding.lifecycleState == AppLifecycleState.resumed;
      binding.addObserver(this);
      _WaitingGameCards.add(this);
    } else {
      binding.removeObserver(this);
      _WaitingGameCards.remove(this);
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _pause();
  }

  void _visibilityChanged(VisibilityInfo info) {
    final visible = info.visibleFraction > 0;
    if (!mounted || visible == _inViewport) return;
    setState(() {
      _inViewport = visible;
      if (!visible) _pause(rebuild: false, releaseFocus: true);
    });
    _syncTimer();
    _syncTicker();
  }

  bool get _canInteract =>
      mounted &&
      _foreground &&
      _visible &&
      ModalRoute.of(context)?.isCurrent != false;

  bool get _canStart =>
      _canInteract &&
      _phase == _GamePhase.waiting &&
      widget.result == null &&
      widget.batch.status.isActive &&
      _gamePreference != CreationWaitGame.off &&
      !_boardSize.isEmpty;

  CreationWaitGame get _nextGame =>
      waitingGameFor(_gamePreference, widget.gameSeed ?? widget.batch.id);

  bool _reportedHolding = false;
  void _reportHolding(bool holding) {
    if (_reportedHolding == holding) return;
    _reportedHolding = holding;
    final callback = widget.onGameHoldingChanged;
    if (callback == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_reportedHolding == holding) callback(holding);
      });
    } else {
      callback(holding);
    }
  }

  void _activate() {
    if (_phase == _GamePhase.paused && _canInteract) {
      setState(() => _phase = _GamePhase.playing);
    } else if (_canStart) {
      _WaitingGameCards.claim(this);
      final width = _boardSize.width;
      final height = _boardSize.height;
      final game = _nextGame == CreationWaitGame.snake
          ? CreationSnakeGame(width, height)
          : CreationBrickGame(width, height);
      setState(() {
        _game = game;
        _phase = _GamePhase.playing;
      });
    } else {
      return;
    }
    _reportHolding(true);
    _focus.requestFocus();
    _syncTicker();
  }

  void _pause({bool rebuild = true, bool releaseFocus = false}) {
    if (releaseFocus && _focus.hasFocus) _focus.unfocus();
    if (_phase != _GamePhase.playing) return;
    if (rebuild) {
      setState(() => _phase = _GamePhase.paused);
    } else {
      _phase = _GamePhase.paused;
    }
    _dragAnchor = null;
    _draggingPaddle = false;
    _syncTicker();
  }

  void _reset({bool rebuild = true}) {
    if (_phase == _GamePhase.waiting) return;
    _banner?.cancel();
    _banner = null;
    void reset() {
      _game = null;
      _phase = _GamePhase.waiting;
      _dragAnchor = null;
      _draggingPaddle = false;
    }

    if (rebuild) {
      setState(reset);
    } else {
      reset();
    }
    _reportHolding(false);
    _WaitingGameCards.release(this);
    _syncRegistration();
    _syncTicker();
  }

  void _scheduleReset(Duration duration) {
    _banner?.cancel();
    _banner = Timer(duration, () {
      if (mounted) _reset();
    });
  }

  void _syncTicker() {
    final playing = _phase == _GamePhase.playing && _visible && _foreground;
    if (playing) {
      final ticker = _ticker ??= createTicker(_tick);
      if (!ticker.isActive) {
        _lastTick = null;
        ticker.start();
      }
    } else {
      _ticker?.stop();
      _lastTick = null;
    }
  }

  void _tick(Duration elapsed) {
    final before = _lastTick;
    _lastTick = elapsed;
    final game = _game;
    if (before == null || game == null || _phase != _GamePhase.playing) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final left =
        pressed.contains(LogicalKeyboardKey.arrowLeft) ||
        pressed.contains(LogicalKeyboardKey.keyA);
    final right =
        pressed.contains(LogicalKeyboardKey.arrowRight) ||
        pressed.contains(LogicalKeyboardKey.keyD);
    final score = game.score;
    game.advance(
      (elapsed - before).inMicroseconds / Duration.microsecondsPerSecond,
      horizontal: (right ? 1 : 0) - (left ? 1 : 0),
    );
    _paint.value++;
    if (game.over) {
      setState(() => _phase = _GamePhase.ended);
      _reportHolding(false);
      _WaitingGameCards.release(this);
      _syncTicker();
      _banner = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (MediaQuery.disableAnimationsOf(context)) {
          _reset();
        } else {
          setState(() => _phase = _GamePhase.fading);
          _scheduleReset(const Duration(milliseconds: 500));
        }
      });
    } else if (score != game.score) {
      setState(() {});
    }
  }

  static final _directions = {
    LogicalKeyboardKey.arrowUp: SnakeDirection.up,
    LogicalKeyboardKey.keyW: SnakeDirection.up,
    LogicalKeyboardKey.arrowDown: SnakeDirection.down,
    LogicalKeyboardKey.keyS: SnakeDirection.down,
    LogicalKeyboardKey.arrowLeft: SnakeDirection.left,
    LogicalKeyboardKey.keyA: SnakeDirection.left,
    LogicalKeyboardKey.arrowRight: SnakeDirection.right,
    LogicalKeyboardKey.keyD: SnakeDirection.right,
  };

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (!_canInteract) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape && _game != null) {
        _reset();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.space &&
          !HardwareKeyboard.instance.isControlPressed &&
          !HardwareKeyboard.instance.isMetaPressed &&
          !HardwareKeyboard.instance.isAltPressed &&
          (_canStart ||
              _phase == _GamePhase.paused ||
              _phase == _GamePhase.playing)) {
        _phase == _GamePhase.playing ? _pause() : _activate();
        return KeyEventResult.handled;
      }
    }
    final direction = _directions[key];
    if (_phase != _GamePhase.playing || direction == null) {
      return KeyEventResult.ignored;
    }
    if (_game case final CreationSnakeGame snake when event is KeyDownEvent) {
      snake.steer(direction);
    }
    return KeyEventResult.handled;
  }

  math.Point<double> _brickPosition(Offset point, CreationBrickGame brick) {
    final scale = math.min(
      _boardSize.width / brick.width,
      _boardSize.height / brick.height,
    );
    return math.Point(
      (point.dx - (_boardSize.width - brick.width * scale) / 2) / scale,
      (point.dy - (_boardSize.height - brick.height * scale) / 2) / scale,
    );
  }

  void _beginDrag(Offset point) {
    _dragAnchor = point;
    if (_game case final CreationBrickGame brick) {
      final local = _brickPosition(point, brick);
      _draggingPaddle = brick.touchesPaddle(local);
      if (_draggingPaddle) brick.aim(local.x);
    }
  }

  void _moveDrag(Offset point) {
    if (_phase != _GamePhase.playing) return;
    switch (_game) {
      case final CreationSnakeGame snake:
        final delta = point - (_dragAnchor ?? point);
        if (delta.distance <= 12) return;
        snake.steer(
          delta.dx.abs() > delta.dy.abs()
              ? delta.dx < 0
                    ? SnakeDirection.left
                    : SnakeDirection.right
              : delta.dy < 0
              ? SnakeDirection.up
              : SnakeDirection.down,
        );
        _dragAnchor = point;
      case final CreationBrickGame brick:
        if (_draggingPaddle) brick.aim(_brickPosition(point, brick).x);
      case null:
        break;
    }
  }

  @override
  void dispose() {
    _WaitingGameCards.remove(this);
    _banner?.cancel();
    _timer?.cancel();
    _ticker?.dispose();
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _paint.dispose();
    VisibilityDetectorController.instance.forget(_visibilityKey);
    if (_registered) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.result case final result? when _phase != _GamePhase.completing) {
      if (!_revealResult || MediaQuery.disableAnimationsOf(context)) {
        return result;
      }
      const duration = Duration(milliseconds: 700);
      final revealed = result
          .animate(onComplete: (_) => _releasePreview())
          .fadeIn(duration: duration, curve: handoffCurve)
          .blurXY(begin: 18, end: 0, duration: duration, curve: handoffCurve)
          .scale(
            begin: const Offset(1.04, 1.04),
            end: const Offset(1, 1),
            duration: duration,
            curve: handoffCurve,
          );
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_preview case final bytes?)
              Positioned.fill(
                key: const ValueKey('last-preview'),
                child: _BlurredPreview(bytes),
              ),
            KeyedSubtree(key: const ValueKey('result'), child: revealed),
          ],
        ),
      );
    }
    _gamePreference = context
        .select<MediaCreationController?, CreationWaitGame>(
          (controller) => controller?.waitGame ?? CreationWaitGame.random,
        );
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final started = widget.batch.startedAt;
    final elapsed = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    final percent = widget.result != null
        ? 1.0
        : (widget.progress ?? creationFakeProgress(elapsed) / 100).clamp(
            0.0,
            1.0,
          );
    final label = switch (widget.batch.status) {
      GenerationStatus.queued => l10n.creationQueuePosition(widget.queueAhead),
      GenerationStatus.downloading => l10n.creationDownloading,
      _ => creationWaitingText(l10n, widget.batch.mode, elapsed),
    };
    final animated =
        _foreground && _visible && !MediaQuery.disableAnimationsOf(context);
    final radius = BorderRadius.circular(
      ResponsiveHelper.isDesktop(context) ? 16 : 14,
    );
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _visibilityChanged,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            cs.onSurface.withValues(alpha: .06),
            context.appColors.surfaceCard,
          ),
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_preview case final bytes?) _BlurredPreview(bytes),
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final narrow = bounds.maxWidth <= 260;
                    return Padding(
                      padding: widget.showStatusLabel
                          ? EdgeInsets.fromLTRB(
                              narrow ? 8 : 10,
                              narrow ? 34 : 40,
                              narrow ? 8 : 10,
                              narrow ? 8 : 10,
                            )
                          : const EdgeInsets.all(12),
                      child: _board(context, percent, animated),
                    );
                  },
                ),
              ),
              if (widget.showStatusLabel)
                LayoutBuilder(
                  builder: (context, bounds) {
                    final narrow = bounds.maxWidth <= 260;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        narrow ? 12 : 16,
                        narrow ? 11 : 14,
                        12,
                        0,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ThinkingSheen(
                          enabled: animated,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: narrow ? 12 : 13,
                              color: _preview == null
                                  ? cs.onSurfaceVariant
                                  : Colors.white.withValues(alpha: .92),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (started != null &&
                  widget.batch.status != GenerationStatus.queued)
                PositionedDirectional(
                  end: 12,
                  bottom: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        height: 26,
                        constraints: const BoxConstraints(minWidth: 50),
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceCard.withValues(
                            alpha: .8,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: cs.onSurface.withValues(alpha: .11),
                            width: .5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.progress != null) ...[
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primary,
                                ),
                                child: const SizedBox.square(dimension: 6),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              NumberFormat.percentPattern(
                                l10n.localeName,
                              ).format(percent),
                              style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: AppFontWeights.semibold,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_bannerText(l10n) case final text?)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _preview != null
                            ? Colors.black.withValues(alpha: .12)
                            : Color.alphaBlend(
                                cs.onSurface.withValues(alpha: .06),
                                context.appColors.surfaceCard,
                              ).withValues(alpha: .28),
                      ),
                      child: Center(
                        child: Text(
                          text,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            color: _preview != null
                                ? Colors.white
                                : cs.onSurfaceVariant,
                            fontWeight: AppFontWeights.semibold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String? _bannerText(AppLocalizations l10n) {
    final score = _game?.score ?? 0;
    return switch (_phase) {
      _GamePhase.paused => l10n.creationGamePaused(score),
      _GamePhase.ended => l10n.creationGameEnded(score),
      _GamePhase.completing => l10n.creationGameCompleted(score),
      _ => null,
    };
  }

  Widget _board(BuildContext context, double percent, bool animated) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final game = _game;
    final showGame = game != null && _phase != _GamePhase.fading;
    final snake =
        game is CreationSnakeGame ||
        game == null && _nextGame == CreationWaitGame.snake;
    final label = game != null
        ? snake
              ? l10n.creationGameSnakeControls
              : l10n.creationGameBrickControls
        : widget.batch.mode == MediaMode.image
        ? l10n.creationGameDuringImage(
            snake ? l10n.creationGameSnake : l10n.creationGameBrick,
          )
        : l10n.creationGameDuringVideo(
            snake ? l10n.creationGameSnake : l10n.creationGameBrick,
          );
    final foreground = _preview == null ? colors.onSurface : Colors.white;
    return LayoutBuilder(
      builder: (context, constraints) {
        _boardSize = constraints.biggest;
        final board = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedOpacity(
                opacity: showGame ? 0 : 1,
                duration: animated
                    ? const Duration(milliseconds: 500)
                    : Duration.zero,
                child: CreationDotField(
                  progress: percent,
                  paused: !animated || showGame,
                  color: _preview == null
                      ? null
                      : Colors.white.withValues(alpha: .92),
                ),
              ),
              AnimatedOpacity(
                opacity: showGame ? 1 : 0,
                duration: animated
                    ? const Duration(milliseconds: 500)
                    : Duration.zero,
                child: game == null
                    ? null
                    : RepaintBoundary(
                        child: CustomPaint(
                          painter: CreationGamePainter(
                            game: game,
                            primary: _preview == null
                                ? colors.primary
                                : Colors.white,
                            foreground: foreground,
                            reducedMotion: !animated,
                            repaint: _paint,
                          ),
                        ),
                      ),
              ),
              if (game != null)
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: l10n.creationGameScore(game.score),
                  child: const SizedBox.shrink(),
                ),
            ],
          ),
        );
        if (game == null && _gamePreference == CreationWaitGame.off) {
          return board;
        }
        return TapRegion(
          onTapOutside:
              _phase == _GamePhase.playing || _phase == _GamePhase.paused
              ? (_) => _pause(releaseFocus: true)
              : null,
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _key,
            child: MouseRegion(
              onEnter: (_) => _WaitingGameCards.hover(this),
              onHover: (_) => _WaitingGameCards.hover(this),
              cursor: SystemMouseCursors.click,
              child: Semantics(
                label: label,
                button: game == null,
                onTap:
                    _phase == _GamePhase.waiting || _phase == _GamePhase.paused
                    ? _activate
                    : null,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  gestures: {
                    TapGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          TapGestureRecognizer
                        >(
                          TapGestureRecognizer.new,
                          (recognizer) => recognizer
                            ..gestureSettings = const DeviceGestureSettings(
                              touchSlop: 12,
                            )
                            ..onTap = _activate,
                        ),
                    LongPressGestureRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          LongPressGestureRecognizer
                        >(
                          () => LongPressGestureRecognizer(
                            duration: const Duration(milliseconds: 500),
                          ),
                          (recognizer) {
                            recognizer.gestureSettings =
                                const DeviceGestureSettings(touchSlop: 12);
                            recognizer.onLongPressStart = (details) {
                              _activate();
                              _beginDrag(details.localPosition);
                            };
                            recognizer.onLongPressMoveUpdate = (details) =>
                                _moveDrag(details.localPosition);
                          },
                        ),
                    if (_phase == _GamePhase.playing)
                      PanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            PanGestureRecognizer
                          >(PanGestureRecognizer.new, (recognizer) {
                            recognizer
                              ..dragStartBehavior = DragStartBehavior.down
                              ..gestureSettings = const DeviceGestureSettings(
                                touchSlop: 6,
                              );
                            recognizer.onStart = (details) {
                              _beginDrag(details.localPosition);
                            };
                            recognizer.onUpdate = (details) =>
                                _moveDrag(details.localPosition);
                          }),
                  },
                  child: board,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WaitingGameCards {
  static final _cards = <_CreationWaitingCardState>{};
  static _CreationWaitingCardState? _active, _hovered;

  static void add(_CreationWaitingCardState card) {
    if (_cards.isEmpty) FocusManager.instance.addLateKeyEventHandler(_space);
    _cards.add(card);
  }

  static void remove(_CreationWaitingCardState card) {
    if (!_cards.remove(card)) return;
    release(card);
    if (_hovered == card) _hovered = null;
    if (_cards.isEmpty) FocusManager.instance.removeLateKeyEventHandler(_space);
  }

  static void claim(_CreationWaitingCardState card) {
    final previous = _active;
    _active = card;
    if (previous != null && previous != card && previous.mounted) {
      previous._reset();
    }
  }

  static void release(_CreationWaitingCardState card) {
    if (_active == card) _active = null;
  }

  static void hover(_CreationWaitingCardState card) => _hovered = card;

  static KeyEventResult _space(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isAltPressed) {
      return KeyEventResult.ignored;
    }
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext?.findAncestorStateOfType<EditableTextState>() != null ||
        focusContext
                ?.findAncestorWidgetOfExactType<FocusableActionDetector>() !=
            null) {
      return KeyEventResult.ignored;
    }
    final hovered = _hovered;
    if (hovered != null &&
        (hovered._canStart ||
            hovered._phase == _GamePhase.paused && hovered._canInteract)) {
      hovered._activate();
      return KeyEventResult.handled;
    }
    _CreationWaitingCardState? last;
    for (final card in _cards) {
      if (!card._canStart) continue;
      final previous = last;
      if (previous == null ||
          card.widget.batch.createdAt.isAfter(
            previous.widget.batch.createdAt,
          ) ||
          (card.widget.batch.createdAt == previous.widget.batch.createdAt &&
              card.widget.ordinal < previous.widget.ordinal)) {
        last = card;
      }
    }
    if (last == null) return KeyEventResult.ignored;
    last._activate();
    return KeyEventResult.handled;
  }
}

Uint8List? _previewBytes(String value) {
  try {
    return base64Decode(value);
  } on FormatException {
    return null;
  }
}

String creationWaitingText(
  AppLocalizations l10n,
  MediaMode mode,
  Duration elapsed,
) {
  final seconds = elapsed.inSeconds;
  final video = mode == MediaMode.video;
  if (seconds < 10) {
    return video ? l10n.creationWaitingVideo : l10n.creationWaitingImage;
  }
  if (seconds < 20) {
    return video ? l10n.creationWaitingVideoMotion : l10n.creationWaitingSketch;
  }
  if (seconds < 25) {
    return video ? l10n.creationWaitingVideoFrames : l10n.creationWaitingDraft;
  }
  if (seconds < 30) {
    return video
        ? l10n.creationWaitingVideoRendering
        : l10n.creationWaitingScene;
  }
  if (seconds < 35) {
    return video
        ? l10n.creationWaitingVideoComposite
        : l10n.creationWaitingDetails;
  }
  if (seconds < 40) return l10n.creationWaitingNearlyDone;
  if (seconds < 50) {
    return video ? l10n.creationWaitingVideoFinish : l10n.creationWaitingFinish;
  }
  return l10n.creationWaitingLong;
}

class _BlurredPreview extends StatefulWidget {
  const _BlurredPreview(this.bytes);
  final Uint8List bytes;

  @override
  State<_BlurredPreview> createState() => _BlurredPreviewState();
}

class _BlurredPreviewState extends State<_BlurredPreview> {
  static SafeResizeImage _image(Uint8List bytes) => SafeResizeImage.wrap(
    MemoryImage(bytes),
    width: 320,
    height: 320,
    maxSourcePixels: maxCreationSourcePixels,
    maxEdge: 640,
    maxPixels: 320 * 320,
    fit: SafeResizeFit.cover,
  );
  late SafeResizeImage _provider = _image(widget.bytes);

  @override
  void didUpdateWidget(_BlurredPreview previous) {
    super.didUpdateWidget(previous);
    if (!identical(previous.bytes, widget.bytes)) {
      unawaited(_provider.evict());
      _provider = _image(widget.bytes);
    }
  }

  @override
  void dispose() {
    unawaited(_provider.evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: .7,
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Transform.scale(
        scale: 1.25,
        child: Image(
          image: _provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

class CreationDotField extends StatelessWidget {
  const CreationDotField({
    super.key,
    required this.progress,
    this.thumbnail = false,
    this.paused = false,
    this.color,
  });

  final double progress;
  final bool thumbnail, paused;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: StatusAnimation.elapsed(
        paused: paused || thumbnail || reduced,
        builder: (context, animation) => CustomPaint(
          painter: _Dots(
            color: color ?? cs.primary,
            progress: progress,
            spacing: thumbnail ? 6 : 40 / 3,
            animation: animation,
            reduced: reduced || thumbnail,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  _Dots({
    required this.color,
    required this.progress,
    required this.spacing,
    required this.animation,
    required this.reduced,
  }) : super(repaint: animation);

  final Color color;
  final double progress, spacing;
  final ValueListenable<double> animation;
  final bool reduced;

  static double _smooth(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double _sweep(double seconds, double from, double to) {
    if (reduced) return (from + to) / 2;
    final phase = animation.value / seconds;
    final wave = (1 - math.cos(phase * math.pi)) / 2;
    return from + (to - from) * wave;
  }

  double _blob(double spread, double distance) {
    final inner = spread * .14;
    final edge = _smooth((distance - inner) / (spread - inner));
    final center = _smooth((distance - inner) / (spread * .32));
    return (1 - edge) * (1 - center * .12);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final columns = (size.width / spacing).floor();
    final rows = (size.height / spacing).floor();
    final left = (size.width - (columns - 1) * spacing) / 2;
    final top = (size.height - (rows - 1) * spacing) / 2;
    final maturity = math.pow((progress / .82).clamp(0.0, 1.0), 1.28);
    final first = Offset(_sweep(3.46, .18, .82), _sweep(4.87, .18, .82));
    final second = Offset(_sweep(4.31, .82, .18), _sweep(4.42, .82, .18));
    final expansion = maturity * (.72 - .08 * _smooth((maturity - .5) / .5));
    final spread1 = _sweep(3.6, .35, .60) * .5 + expansion;
    final spread2 = _sweep(2.4, .43, .70) * .5 + expansion;
    final radius =
        math.min(spacing * .48, (2 + 5 * _smooth(progress / .7)) / 2) *
        (reduced ? 1 : _sweep(2.25, .105, .234) / .234);
    final opacity = _sweep(2.1, .58, .82);
    final breath = reduced
        ? .47
        : .38 + .18 * (1 - math.cos(animation.value / 1.75 * math.pi * 2)) / 2;
    final faint = Paint()
      ..color = color.withValues(alpha: color.a * .2 * breath);
    final glow = Paint();
    for (var x = 0; x < columns; x++) {
      for (var y = 0; y < rows; y++) {
        if ((x == 0 || x == columns - 1) && (y == 0 || y == rows - 1)) {
          continue;
        }
        final center = Offset(left + x * spacing, top + y * spacing);
        canvas.drawCircle(center, 1.1, faint);
        final relative = Offset(
          columns == 1 ? .5 : x / (columns - 1),
          rows == 1 ? .5 : y / (rows - 1),
        );
        final light = math.max(
          _blob(spread1, (relative - first).distance),
          _blob(spread2, (relative - second).distance),
        );
        final dotRadius = radius * math.pow(light, 1.15);
        if (dotRadius <= .2) continue;
        final glowStrength = maturity * math.pow(light, .85 + maturity * 1.1);
        glow.color = color.withValues(
          alpha:
              color.a * (opacity + (1 - opacity) * glowStrength * .64) * breath,
        );
        canvas.drawCircle(center, dotRadius, glow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dots old) =>
      old.color != color ||
      old.progress != progress ||
      old.spacing != spacing ||
      old.reduced != reduced ||
      old.animation != animation;
}

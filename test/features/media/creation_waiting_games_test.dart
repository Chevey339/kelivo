import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/models/media_creation.dart';
import 'package:Kelivo/features/media/models/creation_waiting_games.dart';
import 'package:Kelivo/features/media/widgets/creation_waiting_card.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/utils/safe_resize_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

GenerationBatchRow _batch(String id, {DateTime? createdAt}) =>
    GenerationBatchRow(
      id: id,
      providerId: 'provider',
      modelId: 'model',
      mode: MediaMode.image,
      prompt: 'A landscape',
      paramsJson: '{}',
      referencesJson: '[]',
      status: GenerationStatus.running,
      source: GenerationSource.workbench,
      createdAt: createdAt ?? DateTime(2026),
    );

void _step(CreationSnakeGame game) =>
    game.advance((game.stepMilliseconds + 1) / 1000);

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: Center(child: child)),
);

Widget _card(
  GenerationBatchRow batch,
  int ordinal, {
  Widget? result,
  String? preview,
}) => SizedBox(
  width: 250,
  height: 225,
  child: CreationWaitingCard(
    key: ValueKey((batch.id, ordinal)),
    batch: batch,
    ordinal: ordinal,
    result: result,
    preview: preview,
  ),
);

void main() {
  test(
    'game choices are stable for a given generation and honor overrides',
    () {
      final seeded = {
        for (var i = 0; i < 10; i++)
          waitingGameFor(CreationWaitGame.random, 'batch-$i'),
      };
      expect(seeded, {CreationWaitGame.snake, CreationWaitGame.brick});
      expect(
        List.generate(
          8,
          (_) => waitingGameFor(CreationWaitGame.random, 'batch'),
        ),
        everyElement(waitingGameFor(CreationWaitGame.random, 'batch')),
      );
      for (final value in [
        CreationWaitGame.snake,
        CreationWaitGame.brick,
        CreationWaitGame.off,
      ]) {
        expect(waitingGameFor(value, 'message'), value);
      }
    },
  );

  test('Snake wraps, grows on food and speeds up', () {
    final game = CreationSnakeGame(125, 160, random: math.Random(4));
    expect((game.columns, game.rows), (8, 10));
    final head = game.body.first;
    game.steer(SnakeDirection.left);
    game.advance(.189);
    expect(game.body.first, head);
    game.advance(.002);
    expect(game.body.first, head + 1);
    for (var i = 0; i < 3; i++) {
      _step(game);
    }
    expect(game.body.first, head ~/ game.columns * game.columns);
    expect(game.score, 1);
    expect(game.body, hasLength(5));
    expect(game.stepMilliseconds, 183);
    expect(game.body, isNot(contains(game.food)));
  });

  test(
    'Snake allows a vacated tail cell, rejects excess turns and detects collision',
    () {
      final game = CreationSnakeGame(125, 160, random: math.Random(4));
      game.steer(SnakeDirection.up);
      game.steer(SnakeDirection.down);
      _step(game);
      expect(game.direction, SnakeDirection.up);
      game.steer(SnakeDirection.left);
      _step(game);
      final tail = game.body.last;
      game.steer(SnakeDirection.down);
      _step(game);
      expect(game.body.first, tail);
      expect(game.over, isFalse);

      final longer = CreationSnakeGame(125, 160, random: math.Random(4));
      for (var i = 0; i < 4; i++) {
        _step(longer);
      }
      longer.steer(SnakeDirection.up);
      _step(longer);
      longer.steer(SnakeDirection.left);
      _step(longer);
      longer.steer(SnakeDirection.down);
      _step(longer);
      expect(longer.over, isTrue);
    },
  );

  test(
    'Brick Breaker caps the timestep and scores wall and paddle bounces',
    () {
      final game = CreationBrickGame(250, 250);
      game.ball = const math.Point(13, 150);
      game.velocity = const math.Point(-115, 10);
      game.advance(1);
      expect(game.ball.x, game.radius);
      expect(game.ball.y, closeTo(150.35, .001));
      expect(game.velocity.x, 115);
      expect(game.score, 1);

      game.ball = math.Point(125, game.paddleTop - game.radius - 1);
      game.velocity = const math.Point(0, 155);
      game.advance(.02);
      expect(game.velocity.y, -160);
      expect(game.score, 2);
      game.advance(.02, horizontal: 1);
      expect(game.paddle, greaterThan(75));
    },
  );

  test(
    'Brick Breaker scores a hit, refills after exit, and ends after a miss',
    () {
      final game = CreationBrickGame(250, 250);
      final brick = game.bricks.first;
      game.remaining = {brick};
      game.ball = math.Point(
        brick.x,
        brick.y + game.radius + game.cell * .43 + 1,
      );
      game.velocity = const math.Point(0, -155);
      game.advance(.02);
      expect(game.remaining, isEmpty);
      expect(game.velocity.y, 155);
      expect(game.score, 1);
      game.ball = const math.Point(125, 175);
      game.advance(.02);
      expect(game.remaining.length, game.bricks.length);
      game.ball = const math.Point(20, 262);
      game.advance(.02);
      expect(game.over, isTrue);
    },
  );

  group('Waiting card interaction', () {
    late Duration visibilityInterval;
    setUp(() {
      final visibility = VisibilityDetectorController.instance;
      visibilityInterval = visibility.updateInterval;
      visibility.updateInterval = Duration.zero;
    });
    tearDown(() {
      VisibilityDetectorController.instance.updateInterval = visibilityInterval;
    });

    testWidgets(
      'streamed preview cache entries are released on replacement and exit',
      (tester) async {
        final batch = _batch('preview');
        final cache = PaintingBinding.instance.imageCache;
        final previews = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is SafeResizeImage &&
              (widget.image as SafeResizeImage).imageProvider is MemoryImage,
        );
        Future<Object> showPreview(int size, {Object? previous}) async {
          final encoded = base64Encode(
            img.encodePng(img.Image(width: size, height: size)),
          );
          await tester.pumpWidget(_host(_card(batch, 0, preview: encoded)));
          // The waiting card decodes base64 on a worker isolate.
          for (var attempt = 0; attempt < 200; attempt++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
            if (previews.evaluate().isEmpty) continue;
            final provider = tester.widget<Image>(previews.first).image;
            final key = await provider.obtainKey(ImageConfiguration.empty);
            if (key != previous && cache.statusForKey(key).tracked) return key;
          }
          throw StateError('Preview did not reach the image cache');
        }

        final first = await showPreview(2);
        final second = await showPreview(3, previous: first);
        expect(cache.statusForKey(first).untracked, isTrue);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(cache.statusForKey(second).untracked, isTrue);
      },
    );

    testWidgets(
      'Space targets the newest batch or hovered card after an outside pause',
      (tester) async {
        final older = _batch('old');
        final newer = _batch('new', createdAt: DateTime(2026, 2));
        await tester.pumpWidget(
          _host(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [_card(older, 0), _card(newer, 0), _card(newer, 1)],
            ),
          ),
        );
        await tester.pump();
        final cards = find.byType(CreationWaitingCard);
        final active = find.bySemanticsLabel('Score 0');

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(
          find.descendant(of: cards.at(1), matching: active),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(find.text('Paused · 0'), findsOneWidget);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(5, 5));
        await mouse.moveTo(tester.getCenter(cards.at(0)));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();
        expect(find.text('Paused · 0'), findsNothing);
        expect(active, findsOneWidget);
        expect(
          find.descendant(of: cards.at(0), matching: active),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(active, findsNothing);
        await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('touch hold starts after 500 ms and moving 13 px cancels it', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_card(_batch('hold'), 0)));
      final center = tester.getCenter(find.byType(CreationWaitingCard));
      final active = find.bySemanticsLabel('Score 0');

      final moved = await tester.startGesture(center);
      await moved.moveBy(const Offset(13, 0));
      await tester.pump(const Duration(milliseconds: 500));
      await moved.up();
      await tester.pump();
      expect(active, findsNothing);

      final still = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 499));
      expect(active, findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(active, findsOneWidget);
      await still.up();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('only the card being played holds its result for 1.5 seconds', (
      tester,
    ) async {
      final batch = _batch('into-result');
      Widget pair({bool ready = false}) => _host(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _card(batch, 0, result: ready ? const Text('First artwork') : null),
            _card(
              batch,
              1,
              result: ready ? const Text('Second artwork') : null,
            ),
          ],
        ),
      );
      await tester.pumpWidget(pair());
      await tester.pump();
      await tester.tap(find.byType(CreationWaitingCard).first);
      await tester.pump();
      await tester.pumpWidget(pair(ready: true));
      expect(find.text('Creation ready · 0'), findsOneWidget);
      expect(find.text('First artwork'), findsNothing);
      expect(find.text('Second artwork'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(find.text('First artwork'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('First artwork'), findsOneWidget);
      expect(find.text('Creation ready · 0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

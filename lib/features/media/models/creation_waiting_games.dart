import 'dart:math' as math;

import '../../../core/models/media_creation.dart';

CreationWaitGame waitingGameFor(CreationWaitGame preference, String seed) {
  if (preference != CreationWaitGame.random) return preference;
  var hash = 0x811c9dc5;
  for (final unit in seed.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.isEven ? CreationWaitGame.snake : CreationWaitGame.brick;
}

enum SnakeDirection {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const SnakeDirection(this.x, this.y);
  final int x, y;
}

sealed class CreationGame {
  int score = 0;
  bool over = false;

  void advance(double seconds, {int horizontal = 0});
}

final class CreationSnakeGame extends CreationGame {
  CreationSnakeGame(double width, double height, {math.Random? random})
    : columns = math.max(8, (width / 21).floor()),
      rows = math.max(10, (height / 21).floor()),
      _random = random ?? math.Random() {
    final head = (rows ~/ 2) * columns + columns ~/ 2;
    body = [head, head - 1, head - 2, head - 3];
    previousBody = body;
    food = (rows ~/ 2) * columns + (columns ~/ 2 + 4) % columns;
  }

  final int columns, rows;
  final math.Random _random;
  late List<int> body, previousBody;
  int? food;
  SnakeDirection direction = SnakeDirection.right;
  SnakeDirection? _turn;
  double _seconds = 0;

  int get stepMilliseconds => math.max(95, 190 - score * 7);
  double get interpolation => (_seconds * 1000 / stepMilliseconds).clamp(0, 1);

  void steer(SnakeDirection next) {
    if (_turn != null ||
        next == direction ||
        next.x == -direction.x && next.y == -direction.y) {
      return;
    }
    _turn = next;
  }

  @override
  void advance(double seconds, {int horizontal = 0}) {
    _seconds += seconds;
    while (!over && _seconds * 1000 >= stepMilliseconds) {
      _seconds -= stepMilliseconds / 1000;
      _step();
    }
  }

  void _step() {
    direction = _turn ?? direction;
    _turn = null;
    final head = body.first;
    final x = (head % columns + direction.x) % columns;
    final y = (head ~/ columns + direction.y) % rows;
    final next = y * columns + x;
    final isFood = next == food;
    final collision = body.indexOf(next);
    if (collision >= 0 && (isFood || collision < body.length - 1)) {
      over = true;
      return;
    }
    previousBody = body;
    body = [next, ...body];
    if (!isFood) {
      body.removeLast();
      return;
    }
    score++;
    final occupied = body.toSet();
    final choices = [
      for (var i = 0; i < columns * rows; i++)
        if (!occupied.contains(i)) i,
    ];
    food = choices.isEmpty ? null : choices[_random.nextInt(choices.length)];
    over = choices.isEmpty;
  }
}

final class CreationBrickGame extends CreationGame {
  CreationBrickGame(this.width, this.height) {
    final columns = math.max(8, (width / 21).floor());
    cell = math.min(width / columns, height / 15);
    for (var row = 0; row < 5; row++) {
      for (var column = 0; column < columns; column++) {
        bricks.add(
          math.Point(
            (width - columns * cell) / 2 + (column + .5) * cell,
            (row + .8) * cell,
          ),
        );
      }
    }
    remaining = bricks.toSet();
    paddleWidth = math.min(100, width);
    paddleHeight = math.min(24, height / 5);
    paddle = target = (width - paddleWidth) / 2;
    ball = math.Point(width / 2, height * .53);
  }

  final double width, height;
  late final double cell, paddleWidth, paddleHeight;
  late double paddle, target;
  late math.Point<double> ball;
  math.Point<double> velocity = const math.Point(115, -155);
  final bricks = <math.Point<double>>[];
  late Set<math.Point<double>> remaining;
  double _bounceSpeed = 155;

  double get radius => math.min(12, math.min(width, height) / 6);
  double get paddleTop => height - paddleHeight;

  bool touchesPaddle(math.Point<double> point) =>
      point.y >= paddleTop - 10 &&
      point.x >= paddle - 10 &&
      point.x <= paddle + paddleWidth + 10;

  void aim(double x) {
    target = (x - paddleWidth / 2).clamp(0, width - paddleWidth);
  }

  @override
  void advance(double seconds, {int horizontal = 0}) {
    if (over) return;
    final dt = seconds.clamp(0.0, .035);
    if (horizontal != 0) aim(target + paddleWidth / 2 + horizontal * 360 * dt);
    final easing = 1 - math.pow(.89, dt * 60);
    paddle += (target - paddle) * easing;
    final previous = ball;
    final r = radius;
    var x = previous.x + velocity.x * dt;
    var y = previous.y + velocity.y * dt;
    var dx = velocity.x;
    var dy = velocity.y;

    if (x <= r && dx < 0 || x >= width - r && dx > 0) {
      x = x.clamp(r, width - r);
      dx = -dx;
      score++;
    }
    if (y <= r && dy < 0) {
      y = r;
      dy = -dy;
      score++;
    }
    if (dy > 0 &&
        previous.y + r <= paddleTop &&
        y + r >= paddleTop &&
        x + r >= paddle &&
        x - r <= paddle + paddleWidth) {
      y = paddleTop - r;
      final offset = (x - paddle - paddleWidth / 2) / (paddleWidth / 2);
      dx = offset.clamp(-.9, .9) * 165;
      _bounceSpeed = math.min(225, _bounceSpeed + 5);
      dy = -_bounceSpeed;
      score++;
    }
    final point = math.Point(x, y);
    final hit = remaining
        .where(
          (brick) =>
              brick.squaredDistanceTo(point) <= math.pow(r + cell * .43, 2),
        )
        .firstOrNull;
    if (hit != null) {
      remaining.remove(hit);
      score++;
      if ((previous.x - hit.x).abs() > (previous.y - hit.y).abs()) {
        dx = -dx;
      } else {
        dy = -dy;
      }
    }
    ball = point;
    velocity = math.Point(dx, dy);
    if (remaining.isEmpty && y - r > cell * 5.5) {
      remaining = bricks.toSet();
    }
    over = y - r > height;
  }
}

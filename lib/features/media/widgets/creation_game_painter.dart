import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../models/creation_waiting_games.dart';

class CreationGamePainter extends CustomPainter {
  CreationGamePainter({
    required this.game,
    required this.primary,
    required this.foreground,
    required this.reducedMotion,
    required super.repaint,
  });

  final CreationGame game;
  final Color primary, foreground;
  final bool reducedMotion;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (game) {
      case final CreationSnakeGame snake:
        _snake(canvas, size, snake);
      case final CreationBrickGame brick:
        _brick(canvas, size, brick);
    }
    canvas.restore();
  }

  void _snake(Canvas canvas, Size size, CreationSnakeGame snake) {
    final cell = math.min(size.width / snake.columns, size.height / snake.rows);
    final left = (size.width - snake.columns * cell) / 2;
    final top = (size.height - snake.rows * cell) / 2;
    final paint = Paint();
    Offset center(int index) => Offset(
      left + (index % snake.columns + .5) * cell,
      top + (index ~/ snake.columns + .5) * cell,
    );

    paint.color = foreground.withValues(alpha: .12);
    for (var i = 0; i < snake.columns * snake.rows; i++) {
      canvas.drawCircle(center(i), math.max(.8, .065 * cell), paint);
    }
    final active = !snake.over;
    final color = active ? primary : foreground.withValues(alpha: .26);
    if (snake.food case final food?) {
      canvas.drawCircle(center(food), cell * .34, paint..color = color);
    }

    final t = reducedMotion || !active ? 1.0 : snake.interpolation;
    final eased = t * t * (3 - 2 * t);
    Offset position(int i) {
      final now = center(snake.body[i]);
      final before = center(
        snake.previousBody[math.min(i, snake.previousBody.length - 1)],
      );
      if ((now - before).distance > cell * 1.5) return now;
      return Offset.lerp(before, now, eased)!;
    }

    for (var i = snake.body.length - 1; i >= 0; i--) {
      final radius = i == 0
          ? .43
          : lerpDouble(.35, .265, i / snake.body.length)!;
      paint.color = active
          ? color.withValues(alpha: math.max(.5, 1 - i * .055))
          : color;
      canvas.drawCircle(position(i), cell * radius, paint);
    }
    final head = position(0);
    final look = Offset(
      snake.direction.x.toDouble(),
      snake.direction.y.toDouble(),
    );
    final across = Offset(-look.dy, look.dx);
    final eyeRadius = math.max(1.1, cell * .055);
    for (final side in [-1, 1]) {
      final eye = head + look * (cell * .12) + across * (cell * .155 * side);
      paint.color = Colors.white;
      if (active) {
        canvas.drawCircle(eye, eyeRadius, paint);
      } else {
        paint.strokeWidth = 1;
        canvas.drawLine(
          eye - Offset(eyeRadius, eyeRadius),
          eye + Offset(eyeRadius, eyeRadius),
          paint,
        );
        canvas.drawLine(
          eye - Offset(eyeRadius, -eyeRadius),
          eye + Offset(eyeRadius, -eyeRadius),
          paint,
        );
      }
    }
  }

  void _brick(Canvas canvas, Size size, CreationBrickGame brick) {
    final scale = math.min(
      size.width / brick.width,
      size.height / brick.height,
    );
    canvas.translate(
      (size.width - brick.width * scale) / 2,
      (size.height - brick.height * scale) / 2,
    );
    canvas.scale(scale);
    const spacing = 40 / 3;
    final columns = math.max(1, (brick.width / spacing).floor());
    final rows = math.max(1, (brick.height / spacing).floor());
    final x = (brick.width - (columns - 1) * spacing) / 2;
    final y = (brick.height - (rows - 1) * spacing) / 2;
    final paint = Paint()..color = primary.withValues(alpha: .12);
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        canvas.drawCircle(
          Offset(x + col * spacing, y + row * spacing),
          1.1,
          paint,
        );
      }
    }
    paint.color = brick.over ? foreground.withValues(alpha: .26) : primary;
    final radius = brick.cell * .43;
    for (final point in brick.remaining) {
      canvas.drawCircle(Offset(point.x, point.y), radius, paint);
    }
    canvas.drawCircle(Offset(brick.ball.x, brick.ball.y), radius, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          brick.paddle,
          brick.paddleTop,
          brick.paddleWidth,
          brick.paddleHeight,
        ),
        Radius.circular(brick.paddleHeight / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CreationGamePainter oldDelegate) =>
      oldDelegate.game != game ||
      oldDelegate.primary != primary ||
      oldDelegate.foreground != foreground ||
      oldDelegate.reducedMotion != reducedMotion;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Build a max-height constraint for large text inputs to avoid UI overflow.
///
/// This keeps editors readable while respecting keyboard/viewInsets and
/// surrounding UI (buttons, headers, etc.) via [reservedHeight].
BoxConstraints buildInputMaxHeightConstraints({
  required BuildContext context,
  double reservedHeight = 0,
  double softCapFraction = 0.45,
  double minHeight = 80,
  double extraBottomPadding = 0,
  bool enabled = true,
}) {
  if (!enabled) return const BoxConstraints();
  final maxHeight = computeInputMaxHeight(
    context: context,
    reservedHeight: reservedHeight,
    softCapFraction: softCapFraction,
    minHeight: minHeight,
    extraBottomPadding: extraBottomPadding,
  );
  if (!maxHeight.isFinite || maxHeight <= 0) {
    // TODO: Consider returning a safe minHeight constraint instead of unconstrained BoxConstraints().
    return const BoxConstraints();
  }
  final safeMinHeight = math.max(0.0, minHeight);
  return BoxConstraints(minHeight: safeMinHeight, maxHeight: maxHeight);
}

/// Compute a max height for text inputs based on visible screen area.
///
/// This expects a valid [MediaQuery]. If absent, it falls back to [minHeight]
/// to avoid exceptions and keep layout safe.
double computeInputMaxHeight({
  required BuildContext context,
  double reservedHeight = 0,
  double softCapFraction = 0.45,
  double minHeight = 80,
  double extraBottomPadding = 0,
}) {
  final minCap = math.max(0.0, minHeight);
  final mq = MediaQuery.maybeOf(context);
  if (mq == null) {
    return minCap;
  }
  final size = mq.size;
  final viewInsets = mq.viewInsets;
  final visibleHeight = math.max(0.0, size.height - viewInsets.bottom - extraBottomPadding);
  final cappedFraction = softCapFraction.clamp(0.1, 0.95).toDouble();
  final softCap = visibleHeight * cappedFraction;
  final available = visibleHeight - reservedHeight;

  if (available > 0) {
    final capped = math.min(softCap, available);
    return math.max(minCap, capped);
  }
  // TODO: Revisit fallback behavior when reservedHeight exceeds visible height to avoid unusably small inputs.
  return minCap;
}

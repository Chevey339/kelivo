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
  final safeMinHeight = math.max(0.0, minHeight);
  final safeMaxHeight = maxHeight.isFinite ? math.max(0.0, maxHeight) : safeMinHeight;
  final effectiveMinHeight = math.min(safeMinHeight, safeMaxHeight);
  return BoxConstraints(minHeight: effectiveMinHeight, maxHeight: safeMaxHeight);
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
  final safeExtraBottomPadding = math.max(0.0, extraBottomPadding);
  final visibleHeight = math.max(0.0, size.height - viewInsets.bottom - safeExtraBottomPadding);
  if (visibleHeight <= 0) {
    return 0;
  }
  final cappedFraction = softCapFraction.clamp(0.1, 0.95).toDouble();
  final softCap = visibleHeight * cappedFraction;
  final safeReservedHeight = reservedHeight.isFinite ? math.max(0.0, reservedHeight) : 0.0;
  final clampedReserved = math.min(safeReservedHeight, visibleHeight);
  final available = visibleHeight - clampedReserved;
  final capped = available > 0 ? math.min(softCap, available) : 0.0;
  final candidate = math.max(minCap, capped);
  return candidate.clamp(0.0, visibleHeight);
}

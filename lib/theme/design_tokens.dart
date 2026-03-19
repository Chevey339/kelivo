import 'package:flutter/material.dart';

class AppColors {
  static const Color textMuted = Colors.black54;
}

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppRadii {
  static const double capsule = 28;
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
}

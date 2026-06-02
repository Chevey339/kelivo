import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

class AppFontWeights {
  const AppFontWeights._();

  static FontWeight get regular => normalize(FontWeight.w400);
  static FontWeight get medium => normalize(FontWeight.w500);
  static FontWeight get semibold => normalize(FontWeight.w600);
  static FontWeight get emphasis => normalize(FontWeight.w700);
  static FontWeight get strong => normalize(FontWeight.w700);
  static FontWeight get heavy => normalize(FontWeight.w800);
  static FontWeight get black => normalize(FontWeight.w900);

  static FontWeight normalize(FontWeight weight, {TargetPlatform? platform}) {
    final effectivePlatform = platform ?? defaultTargetPlatform;
    if (effectivePlatform != TargetPlatform.android) {
      return weight;
    }
    if (weight == FontWeight.w500) {
      return FontWeight.w400;
    }
    if (weight.value >= FontWeight.w600.value) {
      return FontWeight.w500;
    }
    return weight;
  }
}

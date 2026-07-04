import 'package:Cuplivo/theme/theme_factory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getPlatformFontFallback', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('uses Android system font stack on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(getPlatformFontFallback(), kAndroidFontFamilyFallback);
    });

    test('keeps CJK fallback on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(getPlatformFontFallback(), kDefaultFontFamilyFallback);
    });

    test('keeps Windows fallback on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;

      expect(getPlatformFontFallback(), kWindowsFontFamilyFallback);
    });
  });
}

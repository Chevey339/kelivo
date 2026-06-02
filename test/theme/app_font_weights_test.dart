import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFontWeights', () {
    test(
      'normalizes medium to regular and heavier weights to medium on Android',
      () {
        expect(
          AppFontWeights.normalize(
            FontWeight.w400,
            platform: TargetPlatform.android,
          ),
          FontWeight.w400,
        );
        expect(
          AppFontWeights.normalize(
            FontWeight.w500,
            platform: TargetPlatform.android,
          ),
          FontWeight.w400,
        );
        expect(
          AppFontWeights.normalize(
            FontWeight.w600,
            platform: TargetPlatform.android,
          ),
          FontWeight.w500,
        );
        expect(
          AppFontWeights.normalize(
            FontWeight.bold,
            platform: TargetPlatform.android,
          ),
          FontWeight.w500,
        );
        expect(
          AppFontWeights.normalize(
            FontWeight.w700,
            platform: TargetPlatform.android,
          ),
          FontWeight.w500,
        );
        expect(
          AppFontWeights.normalize(
            FontWeight.w800,
            platform: TargetPlatform.android,
          ),
          FontWeight.w500,
        );
      },
    );

    test('keeps medium and heavier weights unchanged off Android', () {
      expect(
        AppFontWeights.normalize(FontWeight.w500, platform: TargetPlatform.iOS),
        FontWeight.w500,
      );
      expect(
        AppFontWeights.normalize(FontWeight.w600, platform: TargetPlatform.iOS),
        FontWeight.w600,
      );
      expect(
        AppFontWeights.normalize(FontWeight.w700, platform: TargetPlatform.iOS),
        FontWeight.w700,
      );
      expect(
        AppFontWeights.normalize(
          FontWeight.w800,
          platform: TargetPlatform.macOS,
        ),
        FontWeight.w800,
      );
    });
  });
}

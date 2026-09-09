import 'package:Kelivo/core/models/mobile_background_settings.dart';
import 'package:Kelivo/features/settings/widgets/background_status_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom sizes stay bounded and circular artwork is centered', (
    tester,
  ) async {
    for (final appearance in [
      const BackgroundOverlayAppearance(),
      BackgroundOverlayAppearance.circle,
      const BackgroundOverlayAppearance(
        width: 48,
        height: 48,
        iconSize: 120,
        progressSize: 140,
      ),
      const BackgroundOverlayAppearance(width: 400, height: 180),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: BackgroundStatusPreview(
                  title: 'A very long conversation title with several words',
                  detail:
                      'A long tool name and task detail can occupy two lines',
                  appearance: appearance,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final frame = tester.getRect(
        find.byKey(const ValueKey('overlayPreviewFrame')),
      );
      final icon = tester.getRect(
        find.byKey(const ValueKey('overlayPreviewIcon')),
      );
      expect(frame.width, lessThanOrEqualTo(280));
      expect(frame.contains(icon.center), isTrue);
      expect(icon.left, greaterThanOrEqualTo(frame.left));
      expect(icon.right, lessThanOrEqualTo(frame.right));
      if (appearance.isIconOnly) expect(icon.center, frame.center);
    }
  });
}

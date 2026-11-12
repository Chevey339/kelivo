import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/genui_review_exercise.dart';

void main() {
  testWidgets(
    'all component states and dialogs remain usable in narrow and large RTL layouts',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cases = await exerciseGenUiReview(tester);
      expect(cases, hasLength(28));
    },
  );
}

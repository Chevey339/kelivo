import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';

void main() {
  testWidgets('showAppDialog keeps horizontal insets on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAppDialog<void>(
                context,
                child: const SizedBox(
                  key: Key('dialog-content'),
                  width: double.infinity,
                  height: 120,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final content = find.byKey(const Key('dialog-content'));
    expect(tester.getTopLeft(content).dx, 24);
    expect(tester.getSize(content).width, 393 - 48);
  });
}

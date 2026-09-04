import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/shared/widgets/form_sheet.dart';

void main() {
  Widget buildHost({
    required Widget sheet,
    EdgeInsets viewInsets = EdgeInsets.zero,
    Size size = const Size(400, 800),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, viewInsets: viewInsets),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(child: sheet),
        ),
      ),
    );
  }

  FormSheet shortSheet() {
    return FormSheet(
      title: 'Add book',
      actions: FormSheetActions(
        cancelLabel: 'Cancel',
        confirmLabel: 'Save',
        onCancel: () {},
        onConfirm: () {},
      ),
      children: const [SizedBox(height: 48, child: Text('Name field'))],
    );
  }

  testWidgets('sheet height equals content height for short content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHost(sheet: shortSheet()));
    await tester.pumpAndSettle();

    final height = tester.getSize(find.byType(FormSheet)).height;
    expect(height, lessThan(800 * 0.9));
    expect(height, lessThan(400));
    expect(height, greaterThan(120));
  });

  testWidgets('sheet grows when viewInsets.bottom is set', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildHost(sheet: shortSheet()));
    await tester.pumpAndSettle();
    final closed = tester.getSize(find.byType(FormSheet)).height;

    await tester.pumpWidget(
      buildHost(
        sheet: shortSheet(),
        viewInsets: const EdgeInsets.only(bottom: 240),
      ),
    );
    await tester.pumpAndSettle();
    final open = tester.getSize(find.byType(FormSheet)).height;

    expect(open - closed, closeTo(240, 1));
  });

  testWidgets('actions are equal width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormSheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Save',
            onCancel: () {},
            onConfirm: () {},
          ),
        ),
      ),
    );

    final cancel = tester.getSize(find.text('Cancel'));
    final save = tester.getSize(find.text('Save'));
    // Labels sit in equal Expanded buttons; compare the button boxes.
    final cancelBtn = tester.getSize(
      find
          .ancestor(of: find.text('Cancel'), matching: find.byType(Expanded))
          .first,
    );
    final saveBtn = tester.getSize(
      find
          .ancestor(of: find.text('Save'), matching: find.byType(Expanded))
          .first,
    );
    expect(cancelBtn.width, saveBtn.width);
    expect(cancel.width, lessThan(cancelBtn.width));
    expect(save.width, lessThan(saveBtn.width));
  });

  testWidgets('omitting actions sizes to content', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildHost(
        sheet: const FormSheet(
          title: 'Skills',
          children: [SizedBox(height: 48, child: Text('Row'))],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Skills'), findsOneWidget);
    expect(tester.getSize(find.byType(FormSheet)).height, lessThan(400));
  });

  testWidgets('confirm is disabled when onConfirm is null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FormSheetActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Save',
            onCancel: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();

    final confirm = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.text('Save'),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(confirm.onTap, isNull);
  });
}

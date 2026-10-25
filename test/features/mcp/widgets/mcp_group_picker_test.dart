import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_group_picker.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../../../support/mcp_presentation_harness.dart';

Future<void> openPickerFromEditor(
  WidgetTester tester,
  McpPresentationHarness harness, {
  required bool desktop,
  required ValueChanged<({String? groupId})?> onSelected,
}) async {
  await tester.pumpWidget(
    harness.app(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Editor'),
                      TextFormField(initialValue: 'Unsaved draft'),
                      TextButton(
                        onPressed: () async => onSelected(
                          await showMcpGroupPicker(context, desktop: desktop),
                        ),
                        child: const Text('Choose group'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('Open editor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose group'));
  await tester.pumpAndSettle();
}

Future<void> submitNewGroup(WidgetTester tester) async {
  await tester.tap(find.text('New group…'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'New group');
  await tester.pump();
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
}

void main() {
  for (final desktop in [false, true]) {
    testWidgets('group creation failure can be retried desktop=$desktop', (
      tester,
    ) async {
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final write = Completer<String>();
      harness.mcp.groupCreation = write.future;
      ({String? groupId})? result;
      await openPickerFromEditor(
        tester,
        harness,
        desktop: desktop,
        onSelected: (value) => result = value,
      );
      await submitNewGroup(tester);
      await tester.tap(find.text('Other (Ungrouped)'));
      await tester.tap(find.text('New group…'));
      await tester.pumpAndSettle();
      expect(find.text('Select group'), findsOneWidget);
      expect(harness.mcp.groupCreationStarted, 1);

      write.completeError(StateError('Group write failed'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        AppSnackBarManager().activeToasts.single.notification.message,
        contains('Group write failed'),
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      harness.mcp.groupCreation = Future.value('created-group');
      await submitNewGroup(tester);
      expect(result?.groupId, 'created-group');
      expect(find.text('Select group'), findsNothing);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('late group save cannot pop the editor desktop=$desktop', (
      tester,
    ) async {
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final write = Completer<String>();
      harness.mcp.groupCreation = write.future;
      ({String? groupId})? result;
      await openPickerFromEditor(
        tester,
        harness,
        desktop: desktop,
        onSelected: (value) => result = value,
      );
      await submitNewGroup(tester);
      final pickerContext = tester.element(
        find.byKey(const ValueKey('mcp-group-option-other')),
      );
      Navigator.of(pickerContext).pop();
      await tester.pump(const Duration(milliseconds: 16));
      // Complete while the dismissed picker is still in its reverse animation.
      expect(pickerContext.mounted, isTrue);
      write.complete('created-group');
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Unsaved draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

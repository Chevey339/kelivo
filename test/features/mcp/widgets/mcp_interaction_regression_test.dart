import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/desktop/widgets/desktop_form_dialog.dart';
import 'package:Kelivo/desktop/setting/mcp_pane.dart';
import 'package:Kelivo/features/mcp/pages/mcp_page.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_icon_picker.dart';
import 'package:Kelivo/features/mcp/widgets/mcp_text_dialog.dart';
import 'package:Kelivo/features/provider/widgets/provider_icon_picker.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/utils/brand_assets.dart';

import '../../../support/mcp_presentation_harness.dart';

Future<void> settleWrites(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<TestGesture> lift(WidgetTester tester, Finder row) async {
  final gesture = await tester.startGesture(tester.getCenter(row));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(const Offset(0, 14));
  await tester.pump(const Duration(milliseconds: 300));
  return gesture;
}

void main() {
  for (final failWrite in [false, true]) {
    testWidgets(
      'drop keeps its new position while saving; failure=$failWrite',
      (tester) async {
        tester.view.physicalSize = const Size(430, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(McpPresentationHarness.create))!;
        final write = Completer<void>();
        harness.mcp.reorderWait = write.future;
        await tester.pumpWidget(harness.app(const McpPage()));
        await tester.pumpAndSettle();
        final gesture = await lift(tester, find.text('GitHub'));
        await gesture.moveTo(
          tester.getBottomLeft(find.byKey(const ValueKey('mcp-server-2'))) +
              const Offset(120, 35),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump();
        // Storage is intentionally blocked: inspect the frames that the earlier
        // final-order-only drag tests missed.
        expect(harness.mcp.items.first.id, 'server-0');
        for (var frame = 0; frame < 40; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(find.text('GitHub')).dy,
            greaterThan(tester.getTopLeft(find.text('Filesystem')).dy),
            reason: 'drop frame $frame',
          );
        }
        if (failWrite) {
          write.completeError(StateError('Delayed write failed'));
        } else {
          write.complete();
        }
        await settleWrites(tester);
        expect(harness.mcp.items.first.id, failWrite ? 'server-0' : 'server-1');
        expect(
          tester.getTopLeft(find.text('GitHub')).dy,
          failWrite
              ? lessThan(tester.getTopLeft(find.text('Filesystem')).dy)
              : greaterThan(tester.getTopLeft(find.text('Filesystem')).dy),
        );
        if (failWrite) {
          expect(
            AppSnackBarManager().activeToasts.single.notification.message,
            contains('Delayed write failed'),
          );
          await tester.pump(const Duration(seconds: 4));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'group drag hides children, survives cancellation, and reorders both ways',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      final first = (await tester.runAsync(
        () => harness.mcp.createGroup('First'),
      ))!;
      final second = (await tester.runAsync(
        () => harness.mcp.createGroup('Second'),
      ))!;
      await tester.runAsync(
        () => harness.mcp.moveServersToGroup({'server-0'}, first),
      );
      await tester.runAsync(
        () => harness.mcp.moveServersToGroup({'server-1', 'server-2'}, second),
      );
      await tester.pumpWidget(harness.app(const McpPage()));
      await tester.pumpAndSettle();
      final cancelled = await lift(tester, find.text('First'));
      expect(find.text('GitHub'), findsNothing);
      expect(find.text('Brave Search'), findsNothing);
      await cancelled.cancel();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Brave Search'), findsOneWidget);
      expect(harness.mcp.groups.map((g) => g.id), [first, second]);

      for (final down in [true, false]) {
        final write = Completer<void>();
        harness.mcp.reorderWait = write.future;
        harness.mcp.reorderStarted = 0;
        final gesture = await lift(tester, find.text('First'));
        final target = tester.getRect(
          find.byKey(ValueKey('mcp-group-$second')),
        );
        await gesture.moveTo(
          Offset(
            target.center.dx,
            down ? target.bottom + 30 : target.center.dy,
          ),
        );
        await tester.pump(const Duration(milliseconds: 350));
        await gesture.up();
        for (
          var frame = 0;
          frame < 60 && harness.mcp.reorderStarted == 0;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(harness.mcp.reorderStarted, 1);
        expect(harness.mcp.groupReorderTarget, down ? 1 : 0);
        for (var frame = 0; frame < 50; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            tester.getTopLeft(find.text('First')).dy,
            down
                ? greaterThan(tester.getTopLeft(find.text('Second')).dy)
                : lessThan(tester.getTopLeft(find.text('Second')).dy),
            reason: 'down=$down, post-drop frame=$frame',
          );
        }
        write.complete();
        await settleWrites(tester);
        expect(
          harness.mcp.groups.map((g) => g.id),
          down ? [second, first] : [first, second],
        );
        expect(harness.mcp.presentationFor('server-0').groupId, first);
        expect(find.text('GitHub'), findsOneWidget);
      }
      // Folding interpolates the row's height instead of removing its slot.
      final key = find.byKey(const ValueKey('mcp-server-0'));
      final height = tester.getSize(key).height;
      await tester.tap(find.text('First'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));
      expect(tester.getSize(key).height, inExclusiveRange(0, height));
      await settleWrites(tester);
      expect(tester.getSize(key).height, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final moving in [false, true]) {
    testWidgets(
      'fast desktop group drag restores children without mounting a proxy moving=$moving',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final harness = (await tester.runAsync(McpPresentationHarness.create))!;
        final first = (await tester.runAsync(
          () => harness.mcp.createGroup('First'),
        ))!;
        await tester.runAsync(() => harness.mcp.createGroup('Second'));
        await tester.runAsync(
          () => harness.mcp.moveServersToGroup({'server-0'}, first),
        );
        await tester.pumpWidget(
          harness.app(const Scaffold(body: DesktopMcpPane())),
        );
        await tester.pumpAndSettle();
        final handle = find.descendant(
          of: find.byKey(ValueKey('mcp-group-$first')),
          matching: find.byType(ReorderableDragStartListener),
        );
        final start = tester.getCenter(handle);
        final gesture = await tester.startGesture(start);
        // Deliberately no pump: this is what a quick native mouse drag does.
        await gesture.moveBy(const Offset(0, 12));
        if (moving) await gesture.moveTo(start + const Offset(0, 180));
        await gesture.up();
        await settleWrites(tester);
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.text('Brave Search'), findsOneWidget);
        await tester.tap(find.text('First'));
        await settleWrites(tester);
        expect(find.text('GitHub'), findsNothing);
        await tester.tap(find.text('First'));
        await settleWrites(tester);
        expect(find.text('GitHub'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  for (final scale in [1.0, 1.3]) {
    testWidgets('selection title is centered at scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      await tester.pumpWidget(
        harness.app(
          const McpPage(),
          locale: const Locale('zh'),
          textScale: scale,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('mcp-selection-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining('1'),
      );
      expect(tester.getCenter(title).dx, closeTo(195, .5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('short text form is compact and clears the mobile keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final harness = (await tester.runAsync(McpPresentationHarness.create))!;
    String? result;
    await tester.pumpWidget(
      harness.app(
        Scaffold(
          body: Builder(
            builder: (ctx) => IosTextButton(
              label: 'Rename',
              onPressed: () async {
                result = await showDialog<String>(
                  context: ctx,
                  builder: (_) => McpTextDialog(
                    title: 'Rename group',
                    hint: 'Name',
                    submitLabel: 'Save',
                    initialValue: 'Development',
                    valid: (v) => v.isNotEmpty,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    final surface = find.descendant(
      of: find.byType(DesktopFormDialog),
      matching: find.byType(Material),
    );
    expect(tester.getSize(surface).height, lessThan(220));
    expect(tester.getSize(surface).width, lessThan(350));
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pumpAndSettle();
    expect(tester.getRect(surface).bottom, lessThan(844 - 310));
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result, 'New name');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'MCP uses provider icon grid with selection and short keyboard viewport',
    (tester) async {
      tester.view.physicalSize = const Size(700, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = (await tester.runAsync(McpPresentationHarness.create))!;
      await tester.pumpWidget(
        harness.app(
          Scaffold(
            body: Builder(
              builder: (ctx) => IosTextButton(
                label: 'Icon',
                onPressed: () =>
                    showMcpIconPicker(ctx, desktop: false, onSelected: (_) {}),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Built-in Icon'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderIconPicker), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      final input = find.byType(TextField);
      await tester.ensureVisible(input);
      await tester.enterText(input, BrandAssets.selectableIcons.first.id);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Keyboard selection uses the same provider grid, no separate MCP list.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    },
  );
}

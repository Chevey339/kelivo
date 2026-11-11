import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_budgets.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_content.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_diagnostic_source.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/app_text_selection_toolbar.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

Widget _app(Widget child) => MaterialApp(
  builder: (_, child) => AppSnackBarOverlay(child: child!),
  locale: const Locale('en'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  for (final surface in [
    'valid dialog',
    'invalid dialog',
    'standalone source',
    'standalone diagnostics',
  ]) {
    testWidgets(
      '$surface guards native selection copy as well as its source button',
      (tester) async {
        final source =
            '${UiCatalog.header}\nroot = Text(text="${'界' * 24000}")';
        final controller = UiSurfaceController(
          owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
        );
        controller.updateSource(
          surface == 'invalid dialog' ? 'invalid\n$source' : source,
          closed: true,
          generation: UiGenerationStatus.complete,
        );
        expect(
          controller.phase,
          surface == 'invalid dialog'
              ? SurfacePhase.invalid
              : SurfacePhase.complete,
        );
        final copied = <String>[];
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
          controller.dispose();
        });
        await tester.pumpWidget(
          _app(
            surface == 'standalone source'
                ? GenUiSource(source: source)
                : surface == 'standalone diagnostics'
                ? GenUiDiagnosticSource(source: source, errorLines: const {2})
                : AppSelectionArea(child: GenUiSurface(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        if (surface.endsWith('dialog')) {
          await tester.tap(find.byTooltip('View source').first);
          await tester.pumpAndSettle();
        }
        // Diagnostic lines join the parent region instead of using EditableText's
        // independent clipboard action. There is exactly one area in the dialog.
        final areaFinder = find.byType(SelectionArea).last;
        final area = tester.widget<SelectionArea>(areaFinder);
        final areaContext = tester.element(areaFinder);
        final region = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion).last,
        );
        region.selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        final menu =
            area.contextMenuBuilder!(areaContext, region)
                as AppTextSelectionToolbar;
        menu.buttonItems
            .singleWhere((item) => item.type == ContextMenuButtonType.copy)
            .onPressed!();
        await tester.pumpAndSettle();
        expect(copied, isEmpty);
        expect(
          find.text(
            'Text exceeds the 64 KiB copy limit. Select a smaller section.',
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        area.focusNode!.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(copied, isEmpty);
        expect(
          find.text(
            'Text exceeds the 64 KiB copy limit. Select a smaller section.',
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
  testWidgets('explicit budget permits an inclusive 64 KiB plain selection', (
    tester,
  ) async {
    final value = 'x' * UiBudgets.copyBytes;
    String? copied;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.pumpWidget(
      _app(
        AppSelectionArea(
          copyByteLimit: UiBudgets.copyBytes,
          child: Text(value),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pumpAndSettle();
    final area = tester.widget<SelectionArea>(find.byType(SelectionArea));
    final menu =
        area.contextMenuBuilder!(
              tester.element(find.byType(SelectionArea)),
              region,
            )
            as AppTextSelectionToolbar;
    menu.buttonItems
        .singleWhere((item) => item.type == ContextMenuButtonType.copy)
        .onPressed!();
    await tester.pumpAndSettle();
    expect(copied, value);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}

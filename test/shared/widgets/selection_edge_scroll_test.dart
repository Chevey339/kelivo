import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/selection_scroll_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markstream/markstream.dart';

import '../../support/markdown_render_helpers.dart';

void main() => registerSelectionEdgeScrollTests();

void registerSelectionEdgeScrollTests({bool native = false}) {
  for (final cancel in [false, true]) {
    for (final toTop in [false, true]) {
      testWidgets(
        'touch selection handle scrolls at the ${toTop ? 'top' : 'bottom'} edge and stops on ${cancel ? 'cancel' : 'release'}',
        (tester) async {
          if (!native) {
            tester.view.physicalSize = const Size(400, 600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
          }
          final scroll = ScrollController(initialScrollOffset: 800);
          final selection = MarkstreamSelectionController();
          final source = List.generate(
            160,
            (i) => 'anchor$i selectable words continue here.',
          ).join('\n\n');
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: SingleChildScrollView(
                    key: const ValueKey('viewport'),
                    controller: scroll,
                    child: MarkstreamSelectionScope(
                      controller: selection,
                      child: AppSelectionArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: MarkstreamView(source: source),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final viewport = tester.getRect(
            find.byKey(const ValueKey('viewport')),
          );
          final paragraph = markdownParagraphs(tester).firstWhere((p) {
            final point = p.localToGlobal(Offset.zero);
            return point.dy > viewport.top + 90 &&
                point.dy < viewport.bottom - 90;
          });
          final glyph = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: 1),
              )
              .first
              .toRect();
          await tester.longPressAt(paragraph.localToGlobal(glyph.center));
          await tester.pumpAndSettle();
          expect(paragraph.selections, isNotEmpty);
          final original = selection.selectedPlainText;
          final region = tester.state<SelectableRegionState>(
            find.byType(SelectableRegion),
          );
          final regionBox = region.context.findRenderObject()! as RenderBox;
          final handle =
              regionBox.localToGlobal(
                region.selectionEndpoints[toTop ? 0 : 1].point,
              ) +
              const Offset(0, 8);
          final gesture = await tester.startGesture(handle);
          final target = Offset(
            handle.dx,
            toTop ? viewport.top + 4 : viewport.bottom - 4,
          );
          for (var i = 1; i <= 12; i++) {
            await gesture.moveTo(Offset.lerp(handle, target, i / 12)!);
            await tester.pump(const Duration(milliseconds: 16));
          }
          for (var i = 0; i < 45; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(scroll.offset, toTop ? lessThan(740) : greaterThan(860));
          expect(
            selection.selectedPlainText.length,
            greaterThan(original.length),
          );
          expect(
            selection.selectedPlainText,
            toTop ? endsWith(original) : startsWith(original),
          );
          // Moving away from the edge must stop the page while the handle is
          // still held; returning to the edge should resume selection scrolling.
          await gesture.moveTo(Offset(handle.dx, viewport.center.dy));
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final inside = scroll.offset;
          for (var i = 0; i < 15; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(scroll.offset, inside);
          await gesture.moveTo(target);
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(scroll.offset, toTop ? lessThan(inside) : greaterThan(inside));
          if (cancel) {
            await gesture.cancel();
          } else {
            await gesture.up();
          }
          for (var i = 0; i < 5; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          final stopped = scroll.offset;
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(scroll.offset, stopped);
          if (!cancel && !toTop) {
            region.selectAll(SelectionChangedCause.keyboard);
            await tester.pumpAndSettle();
            expect(selection.selectedPlainText, source);
            final container = tester.widget<SelectionContainer>(
              find
                  .descendant(
                    of: find.byType(SelectionScrollContainer),
                    matching: find.byType(SelectionContainer),
                  )
                  .first,
            );
            final delegate = container.delegate!;
            final transform = delegate.getTransformTo(null);
            expect(delegate.value.selectionRects, isNotEmpty);
            for (final rect in delegate.value.selectionRects) {
              final global = MatrixUtils.transformRect(transform, rect);
              expect(global.top, greaterThanOrEqualTo(viewport.top - .01));
              expect(global.bottom, lessThanOrEqualTo(viewport.bottom + .01));
            }
            expect(
              MatrixUtils.transformPoint(
                transform,
                delegate.value.startSelectionPoint!.localPosition,
              ).dy,
              lessThan(viewport.top),
            );
            expect(
              MatrixUtils.transformPoint(
                transform,
                delegate.value.endSelectionPoint!.localPosition,
              ).dy,
              greaterThan(viewport.bottom),
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          scroll.dispose();
          selection.dispose();
        },
        variant: native
            ? const DefaultTestVariant()
            : TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}

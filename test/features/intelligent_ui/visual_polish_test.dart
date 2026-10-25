import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_layout.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_theme.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/ios_form_text_field.dart';
import 'package:Kelivo/theme/theme_factory.dart';

Widget _app(Widget child, {EdgeInsets padding = EdgeInsets.zero}) =>
    MaterialApp(
      theme: buildLightTheme(null),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: child!,
      ),
      home: Scaffold(body: GenUiThemeScope(child: child)),
    );

void main() {
  for (final prefix in [false, true]) {
    testWidgets(
      'compact single-line editor centers its content with prefix=$prefix',
      (tester) async {
        final controller = TextEditingController(text: 'Sample');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: IosFormTextField(
                  label: '',
                  inlineLabel: false,
                  controller: controller,
                  compact: true,
                  outerPadding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 14.5, height: 1.3),
                  prefix: prefix
                      ? const SizedBox(width: 28, child: Text('⌕'))
                      : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byType(IosFormTextField);
        expect(tester.getSize(field).height, 44);
        expect(
          tester.getCenter(find.byType(EditableText)).dy,
          closeTo(tester.getCenter(field).dy, .5),
        );
      },
    );
  }

  testWidgets('labelled divider uses both edges of its available width', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Center(
          child: SizedBox(width: 340, child: GenUiDivider(label: 'Group')),
        ),
      ),
    );
    final rule = find.descendant(
      of: find.byType(GenUiDivider),
      matching: find.byType(ColoredBox),
    );
    final bounds = tester.getRect(find.byType(GenUiDivider));
    expect(tester.getRect(rule.first).left, bounds.left);
    expect(tester.getRect(rule.last).right, bounds.right);
    expect(tester.getRect(find.text('Group')).center.dx, bounds.center.dx);
  });

  testWidgets(
    'iOS horizontal thumb clears the last row and vertical gestures reach the message',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c =
          UiSurfaceController(
            owner: const UiSurfaceOwner(
              revisionId: 'polish',
              surfaceKey: '0:0',
            ),
          )..updateSource(
            '''ui 1 catalog "kelivo.native/1"
root = DataTable(data=[{"id":1,"a":"A long first value","b":100,"c":200},{"id":2,"a":"Second value","b":120,"c":180}],rowKey="id",columns=[{"key":"a","label":"Category"},{"key":"b","label":"North (thousands)"},{"key":"c","label":"South (thousands)"}])
''',
            closed: true,
            generation: UiGenerationStatus.complete,
          );
      addTearDown(c.dispose);
      final outer = ScrollController();
      addTearDown(outer.dispose);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                GenUiSurface(controller: c),
                const SizedBox(height: 1400),
              ],
            ),
          ),
          padding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey('genui-table-viewport-root'));
      final paint = find.descendant(
        of: viewport,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter is ScrollbarPainter,
        ),
      );
      expect(paint, findsOneWidget);
      final painter =
          tester.widget<CustomPaint>(paint).foregroundPainter!
              as ScrollbarPainter;
      final rect = tester.getRect(paint);
      final thumbYs = <double>[
        for (double y = 0; y < rect.height; y++)
          if (painter.hitTestOnlyThumbInteractive(
            Offset(12, y),
            PointerDeviceKind.mouse,
          ))
            rect.top + y,
      ];
      expect(thumbYs, isNotEmpty);
      expect(
        thumbYs.first,
        greaterThanOrEqualTo(tester.getRect(find.byType(Table)).bottom),
      );
      await tester.drag(viewport, const Offset(-130, 0));
      await tester.pumpAndSettle();
      final horizontal = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: viewport,
          matching: find.byType(SingleChildScrollView),
        ),
      );
      expect(horizontal.controller!.offset, greaterThan(0));
      await tester.drag(viewport, const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(outer.offset, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/widgets/genui_surface.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';

// Explicit print-only benchmark, excluded from the default *_test.dart glob.
// Reports debug widget observations, not device build/raster acceptance.
void main() {
  testWidgets('1000 rows and eight columns, local sort/filter/page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final rows = [
      for (var i = 0; i < 1000; i++)
        {
          'id': i,
          for (var c = 0; c < 7; c++)
            'c$c': i % 17 == 0 ? null : (i * (c + 1)) % 1000,
        },
    ];
    final columns = [
      {'key': 'id', 'label': 'ID'},
      for (var c = 0; c < 7; c++) {'key': 'c$c', 'label': 'Column $c'},
    ];
    final c = UiSurfaceController(
      owner: const UiSurfaceOwner(revisionId: 'table-bench', surfaceKey: '0:0'),
    );
    addTearDown(c.dispose);
    c.updateSource(
      '${UiCatalog.header}\nroot = DataTable(data=${jsonEncode(rows)},rowKey="id",columns=${jsonEncode(columns)})\n',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(null),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(child: GenUiSurface(controller: c)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final table = c.nodes['root']!.tableData!, samples = <int>[];
    for (var i = 0; i < 45; i++) {
      final watch = Stopwatch()..start();
      c.setView('root', {
        'sortKey': table.columns[i % 8].viewKey,
        'descending': i.isOdd,
        'filter': i % 3 == 0 ? '1' : '',
        'page': i % 10,
        'pageSize': 20,
      }, token: c.token);
      await tester.pump();
      watch.stop();
      if (i >= 5) samples.add(watch.elapsedMicroseconds);
    }
    samples.sort();
    // ignore: avoid_print
    print(
      'GENUI_TABLE rows=1000 columns=8 phase=${c.phase.name} sortFilterPageToPaint medianUs=${samples[samples.length ~/ 2]} p95Us=${samples[(samples.length * .95).floor()]} maxUs=${samples.last}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../catalog/ui_catalog.dart';
import '../../runtime/ui_surface_controller.dart';
import '../../runtime/ui_surface_state.dart';
import '../genui_surface.dart';

// Illustrative data from the supplied visual reference, not current offers.
final genUiTableGallerySources = <String, String>{
  'table': _tableSource(),
  'table-empty':
      'root = DataTable(data=[],rowKey="id",columns=[{"key":"name","label":"Model"},{"key":"price","label":"Price"}])',
  'table-invalid':
      'root = Column(children=[note,table])\nnote = Text(text="Only the invalid table is replaced")\ntable = DataTable(data=[{"id":"same","name":"A"},{"id":"same","name":"B"}],rowKey="id",columns=[{"key":"name","label":"Model"}])',
};

String _tableSource() {
  const rows = [
    ['ThinkPad X1 Carbon G12', 12999, 1.09, 15.5, '14″ 2.8K OLED', 4.6],
    ['MacBook Air 13 M4', 8999, 1.24, 18, '13.6″ Liquid', 4.8],
    ['MacBook Pro 14 M4 Pro', 16999, 1.6, 22, '14.2″ XDR', 4.9],
    ['Dell XPS 13 9350', 10999, 1.19, 17, '13.4″ 2.8K OLED', 4.4],
    ['Huawei MateBook X Pro', 11999, 0.98, 13, '14.2″ 3.1K OLED', 4.5],
    ['Lenovo Xiaoxin Pro 14', 5999, 1.45, 12, '14″ 2.8K 120Hz', 4.3],
    ['ASUS Zenbook 14', 7499, 1.2, 14, '14″ 3K OLED', 4.2],
    ['ROG Zephyrus 14', 13999, 1.5, 10, '14″ 3K 120Hz', 4.6],
    ['Xiaomi Book Pro 14', 6999, 1.4, 11.5, '14″ 2.8K', 4.1],
    ['Honor MagicBook Art 14', 7999, 1.03, 14.5, '14.6″ 3.1K OLED', 4.4],
    ['Surface Laptop 7', 9888, 1.34, 20, '13.8″ PixelSense', 4.3],
    ['HP EliteBook 840 G11', 9299, 1.36, null, '14″ WUXGA', 4.0],
    ['Samsung Galaxy Book4 Pro', 10999, 1.23, 16, '14″ 3K AMOLED', 4.2],
    ['Acer Swift Go 14', 5299, 1.32, 12.5, '14″ 2.8K OLED', 3.9],
  ];
  final data = [
    for (var i = 0; i < rows.length; i++)
      {
        'id': 'L${i + 1}',
        'model': rows[i][0],
        'price': rows[i][1],
        'kg': rows[i][2],
        'hours': rows[i][3],
        'screen': rows[i][4],
        'score': rows[i][5],
      },
  ];
  return 'root = Column(children=[note,table])\n'
      'note = Callout(title="Compare example laptops",text="Sort with a column header. Filter visible text. Missing values stay last in either direction. These are illustrative reference values.",tone="tip")\n'
      'table = DataTable(data=${jsonEncode(data)},rowKey="id",columns=[{"key":"model","label":"Model"},{"key":"price","label":"Price"},{"key":"kg","label":"kg","digits":2},{"key":"hours","label":"Hours","digits":1},{"key":"screen","label":"Screen"},{"key":"score","label":"Score","digits":1}])';
}

class GenUiTableGallery extends StatefulWidget {
  const GenUiTableGallery({
    super.key,
    this.kind = 'table',
    this.filtered = false,
    this.exporting = false,
  });
  final String kind;
  final bool filtered, exporting;
  @override
  State<GenUiTableGallery> createState() => _GenUiTableGalleryState();
}

class _GenUiTableGalleryState extends State<GenUiTableGallery> {
  late final UiSurfaceController _surface;
  @override
  void initState() {
    super.initState();
    _surface = UiSurfaceController(
      owner: UiSurfaceOwner(
        revisionId: 'table-gallery',
        surfaceKey: widget.kind,
      ),
    );
    _surface.updateSource(
      '${UiCatalog.header}\n${genUiTableGallerySources[widget.kind]}\n',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    if (widget.filtered) {
      _surface.setView('table', {
        'filter': 'Pro',
        'sortKey': _surface.nodes['table']!.tableData!.columns[1].viewKey,
        'descending': true,
      }, token: _surface.token);
    }
  }

  @override
  void dispose() {
    _surface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenUiSurface(
    controller: _surface,
    title: 'Laptop comparison',
    exporting: widget.exporting,
  );
}

import 'package:flutter/material.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../genui_layout.dart';
import '../genui_surface.dart';

/// Native-only development fixtures, without provider requests or installed
/// application data. The static Canvas previews live in the web-safe graph.
class GenUiChartGallery extends StatefulWidget {
  const GenUiChartGallery({super.key, this.kind, this.dataView = false});
  final String? kind;
  final bool dataView;
  @override
  State<GenUiChartGallery> createState() => _GenUiChartGalleryState();
}

class _GenUiChartGalleryState extends State<GenUiChartGallery> {
  final _surfaces = <String, UiSurfaceController>{};
  @override
  void initState() {
    super.initState();
    for (final entry in genUiChartGallerySources.entries) {
      final c = UiSurfaceController(
        owner: UiSurfaceOwner(
          revisionId: 'chart-gallery',
          surfaceKey: entry.key,
        ),
      );
      c.updateSource(
        '${UiCatalog.header}\n${entry.value}\n',
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      if (widget.dataView && c.nodes['root']?.chartData != null) {
        c.setView('root', {'dataView': true}, token: c.token);
      }
      _surfaces[entry.key] = c;
    }
  }

  @override
  void dispose() {
    for (final c in _surfaces.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenUiColumn(
    children: [
      for (final entry in _surfaces.entries)
        if (widget.kind == null || widget.kind == entry.key)
          GenUiSurface(controller: entry.value, title: 'Native ${entry.key}'),
    ],
  );
}

const genUiChartGallerySources = <String, String>{
  'line':
      r'''root = Chart(kind="line",title="Monthly channels",x="month",y=["Online","Stores","Partners"],unit="k",xLabel="Month",yLabel="Revenue",data=[{"month":"Jan","Online":120,"Stores":220,"Partners":150},{"month":"Feb","Online":135,"Stores":180,"Partners":240},{"month":"Mar","Online":100,"Stores":null,"Partners":205},{"month":"Apr","Online":140,"Stores":235,"Partners":150},{"month":"May","Online":90,"Stores":290,"Partners":190},{"month":"Jun","Online":235,"Stores":335,"Partners":330}])''',
  'area':
      r'''root = Chart(kind="area",title="Positive and negative change",x="x",y=["A","B"],unit="u",data=[{"x":0,"A":2,"B":1},{"x":1,"A":-2,"B":3},{"x":2,"A":null,"B":1},{"x":3,"A":-1,"B":null},{"x":4,"A":3,"B":-2},{"x":5,"A":1,"B":-1}])''',
  'bar':
      r'''root = Chart(kind="bar",title="Irregular numeric positions",x="day",y=["North","South","East","West"],xLabel="Day",unit="u",data=[{"day":0,"North":3,"South":-2,"East":1,"West":0},{"day":2,"North":-1,"South":2,"East":null,"West":3},{"day":10,"North":2,"South":4,"East":-1,"West":1}])''',
  'scatter':
      r'''root = Chart(kind="scatter",title="Measured samples",x="x",y=["A","B","C","D"],xLabel="Input",yLabel="Output",data=[{"x":0,"A":1,"B":3,"C":2,"D":4},{"x":0.5,"A":2,"B":2,"C":4,"D":1},{"x":2,"A":3,"B":1,"C":null,"D":2},{"x":4,"A":1,"B":4,"C":3,"D":2}])''',
  'pie':
      r'''root = Chart(kind="pie",donut=true,title="Channel share",x="channel",y=["amount"],unit="k",data=[{"channel":"Online","amount":280},{"channel":"Stores","amount":356},{"channel":"Partners","amount":364}])''',
  'gaps': r'''$a: number = 1
$k: number = 1
let points = @sample(x => $k * @sqrt(x * x - $a), -4, 4, 81)
root = Column(children=[parameters,curve])
parameters = Row(children=[aInput,kInput])
aInput = Slider(label="a",bind=$a,min=0,max=4,step=0.1)
kInput = Slider(label="k",bind=$k,min=-2,max=2,step=0.1)
curve = Chart(kind="line",title="k × √(x² − a)",data=points,x="x",y=["y"],xLabel="x",yLabel="y")''',
  'empty':
      r'''root = Chart(kind="line",title="Empty range",data=[],x="x",y=["y"])''',
  'invalid': r'''root = Column(children=[title,bad])
title = Text(text="A node error does not hide its sibling")
bad = Chart(kind="pie",title="Negative pie data",data=[{"x":"A","y":-2}],x="x",y=["y"])''',
};

import 'package:flutter/widgets.dart';
import '../../runtime/ui_interaction_controller.dart';
import '../../runtime/ui_surface_controller.dart';
import '../../runtime/ui_surface_state.dart';
import '../../host/ui_snapshot_export.dart';
import '../genui_expansion.dart';
import '../genui_surface.dart';

const genUiExpansionGallerySource = r'''ui 1 catalog "kelivo.native/1"
$name: string = "Example"
$n: number = 3
$enabled: boolean = true
root = Column(children=[nameField,amount,enabledField,total,ask])
nameField = TextField(label="Label",bind=$name)
amount = NumberField(label="Quantity",bind=$n,min=0,max=100,unit="items")
enabledField = Switch(label="Apply discount",bind=$enabled)
total = Metric(label="Local total",value=$n*12*($enabled ? 0.9 : 1),unit="USD")
ask = Button(label="Explain",action=Ask(text="Explain",context={"quantity":$n}))
''';

class GenUiExpansionGallery extends StatefulWidget {
  const GenUiExpansionGallery({super.key, this.exporting = false});
  final bool exporting;
  @override
  State<GenUiExpansionGallery> createState() => _GenUiExpansionGalleryState();
}

class _GenUiExpansionGalleryState extends State<GenUiExpansionGallery> {
  late final _controller =
      UiSurfaceController(
        owner: const UiSurfaceOwner(
          revisionId: 'expansion-gallery',
          surfaceKey: '0:0',
        ),
      )..updateSource(
        genUiExpansionGallerySource,
        closed: true,
        generation: UiGenerationStatus.complete,
      );
  late final _interactions = UiInteractionController(_controller);
  @override
  void dispose() {
    _interactions.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exporting) {
      return GenUiSurface(controller: _controller, exporting: true);
    }
    return GenUiExpansion(
      surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
        controller: _controller,
        interactions: _interactions,
        title: 'Expansion and snapshot',
        onExpand: expand,
        expandFocusNode: focus,
        expanded: expanded,
        onExport: () => exportUiSnapshot(
          context,
          _controller,
          originalFence: '```kelivo-ui\n$genUiExpansionGallerySource```',
        ),
      ),
    );
  }
}

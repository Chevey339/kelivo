import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:Kelivo/features/intelligent_ui/catalog/ui_catalog.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_form_validation.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_interaction_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../genui_content.dart';
import '../genui_layout.dart';
import '../genui_surface.dart';

/// Shared by the native development entry and C08 pixel/interaction fixtures.
/// This entry never sends requests or registers a production feature switch.
class GenUiInputGallery extends StatefulWidget {
  const GenUiInputGallery({
    super.key,
    this.validation = false,
    this.showIntent = true,
    this.readOnly = false,
    this.enabled = true,
  });
  final bool validation, showIntent, readOnly, enabled;
  @override
  State<GenUiInputGallery> createState() => _GenUiInputGalleryState();
}

class _GenUiInputGalleryState extends State<GenUiInputGallery> {
  late final UiSurfaceController _surface;
  late final UiInteractionController _interactions;
  UiAskIntent? _intent;
  @override
  void initState() {
    super.initState();
    _surface = UiSurfaceController(
      readOnly: widget.readOnly,
      owner: const UiSurfaceOwner(
        revisionId: 'input-gallery',
        surfaceKey: '0:0',
      ),
    );
    _surface.updateSource(
      '${UiCatalog.header}\n${genUiInputGallerySource.replaceFirst(r"$active: boolean = true", "\$active: boolean = ${widget.enabled}")}',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    _interactions = UiInteractionController(_surface);
    assert(
      _surface.phase == SurfacePhase.complete,
      _surface.parsed.program.diagnostics.toString(),
    );
    if (widget.validation) {
      _interactions.editText(
        'amountField',
        const UiFieldDraft('-'),
        token: _surface.token,
        finish: true,
      );
      _interactions.activate('ask', token: _surface.token);
    }
  }

  @override
  void dispose() {
    _interactions.dispose();
    _surface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenUiColumn(
    children: [
      GenUiSurface(
        controller: _surface,
        interactions: _interactions,
        title: 'Native inputs and local actions',
        onAsk: (intent) async {
          if (widget.showIntent) setState(() => _intent = intent);
        },
      ),
      if (widget.showIntent)
        GenUiCallout(
          title: 'Observed Ask intent',
          text: _intent == null
              ? 'Fill the required fields and choose Explain to inspect the frozen context.'
              : const JsonEncoder.withIndent(
                  '  ',
                ).convert({'text': _intent!.text, 'context': _intent!.context}),
          tone: 'info',
        ),
    ],
  );
}

const genUiInputGallerySource = r'''$name: string = ""
$active: boolean = true
$note: string = "A local form with native controls."
$amount: number? = 3
$slope: number = 2
$enabled: boolean = true
$agree: boolean = false
$plan: string? = null
$period: number = 20
root = Form(title="Parameters",enabled=$active,children=[nameField,noteField,enabledField,amountField,slopeField,planField,periodField,agreeField,actions])
nameField = TextField(label="Name",bind=$name,placeholder="Required name",required=true,maxLength=30)
noteField = TextField(label="Notes",bind=$note,multiline=true,maxLength=200)
enabledField = Switch(label="Include distance",bind=$enabled)
amountField = NumberField(label="Distance",bind=$amount,min=0,max=10,step=1,unit="km",required=true,visible=$enabled)
slopeField = Slider(label="Slope",bind=$slope,min=-5,max=5,step=0.1,digits=1)
planField = Select(label="Plan",bind=$plan,placeholder="Choose a plan",options=[{"value":"basic","label":"Basic"},{"value":"plus","label":"Plus"}],required=true)
periodField = RadioGroup(label="Period",bind=$period,options=[{"value":10,"label":"10 years"},{"value":20,"label":"20 years"},{"value":30,"label":"30 years"}])
agreeField = Checkbox(label="I confirm these parameters",bind=$agree,required=true)
actions = Row(distribution="fit",children=[ask,reset])
ask = Button(label="Explain parameters",form=root,variant="primary",action=Ask(text="Explain these parameters.",context={"name":$name,"notes":$note,"distance":$enabled ? $amount : null,"slope":$slope,"plan":$plan,"period":$period}))
reset = Button(label="Reset",action=Reset())''';

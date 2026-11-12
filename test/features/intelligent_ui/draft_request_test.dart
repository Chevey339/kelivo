import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_draft_request.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import 'package:Kelivo/features/intelligent_ui/models/ui_context_attachment.dart';
import 'package:Kelivo/utils/unicode_sanitizer.dart';

void main() {
  UiSurfaceController controller(String body) {
    final surface = UiSurfaceController(
      owner: const UiSurfaceOwner(revisionId: 'r', surfaceKey: '0:0'),
    );
    surface.updateSource(
      'ui 1 catalog "kelivo.native/1"\n$body',
      closed: true,
      generation: UiGenerationStatus.complete,
    );
    addTearDown(surface.dispose);
    return surface;
  }

  UiDraftRequest repair(UiSurfaceController surface) => UiDraftRequest.repair(
    conversationId: 'c',
    controller: surface,
    introduction: 'Please repair',
    omitted: '[omitted]',
  );
  test(
    'repair includes parser and runtime diagnostics with separate source excerpts',
    () {
      final surface = controller(
        'root = Column(children=[bad,result])\n'
        'bad = Text(text="Bad property", extra=true)\n${'\n' * 12}'
        'result = Metric(label="Runtime", value=1/0)\n',
      );
      expect(surface.phase, SurfacePhase.completeWithErrors);
      final draft = repair(surface);
      expect(draft.attachment, isNull);
      expect(draft.text, contains('unknownProperty'));
      expect(draft.text, contains('divisionByZero'));
      expect(draft.text, contains('extra=true'));
      expect(draft.text, contains('value=1/0'));
      expect(draft.text.split('divisionByZero').length, 2);
    },
  );
  test('domain gaps include their code and the sampling declaration', () {
    final surface = controller(
      'let data = @sample(x => @sqrt(x), -1, 1, 3)\n'
      'root = Chart(kind="line", data=data, x="x", y=["y"])\n',
    );
    expect(surface.phase, SurfacePhase.completeWithErrors);
    expect(surface.nodes['root']!.gaps, isNotEmpty);
    final draft = repair(surface);
    expect(draft.text, contains('domain'));
    expect(draft.text, contains('@sample'));
    expect(draft.text, contains('@sqrt(x)'));
  });
  for (final expression in ['1/0', '@sample(x => @sqrt(x), -1, 1, 3)']) {
    test('repair includes unconsumed evaluated value: $expression', () {
      final surface = controller(
        'let unused = $expression\nroot = Text(text="Good")\n',
      );
      expect(surface.phase, SurfacePhase.completeWithErrors);
      final draft = repair(surface);
      expect(
        draft.text,
        contains(expression == '1/0' ? 'divisionByZero' : 'domain'),
      );
      expect(draft.text, contains('let unused = $expression'));
    });
  }
  test(
    'repair omits oversized source records intact and stays within 4 KiB',
    () {
      final surface = controller(
        'root = Text(text="${'界' * 4000}", extra=true)\n',
      );
      final draft = repair(surface);
      expect(utf8.encode(draft.text).length, lessThanOrEqualTo(4096));
      expect(draft.text, contains('[omitted]'));
      expect(draft.text, isNot(contains('界')));
    },
  );
  test('frozen Unicode is already exactly what the provider can send', () {
    final text = UiContextText(
      title: 'Broken\ud800',
      body: 'Value: \ud800\u0ce1 ![x](data:image/png;base64,YQ==)',
    );
    expect(UnicodeSanitizer.sanitize(text.exactText), text.exactText);
    expect(UiContextText.parseSentPart(text.exactText), text);
  });
}

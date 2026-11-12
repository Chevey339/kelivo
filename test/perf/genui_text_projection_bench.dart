import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_controller.dart';
import 'package:Kelivo/features/intelligent_ui/runtime/ui_surface_state.dart';
import '../support/genui_projection_fixture.dart';

// Print-only benchmark: run explicitly; never a default-suite timing assertion.
void main() {
  for (final blocks in [16, 64, 255]) {
    test('bounded projection of $blocks repeated 108 KiB Markdown fields', () {
      final controller = UiSurfaceController(
        owner: const UiSurfaceOwner(
          revisionId: 'projection-bench',
          surfaceKey: '0:0',
        ),
      );
      controller.updateSource(
        genUiRepeatedMarkdownFixture(blocks),
        closed: true,
        generation: UiGenerationStatus.complete,
      );
      final read = controller.captureRead(), samples = <int>[];
      var text = '';
      for (var i = 0; i < 25; i++) {
        final watch = Stopwatch()..start();
        text = testUiProjection.context(read).body;
        watch.stop();
        if (i >= 5) samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      // ignore: avoid_print
      print(
        'GENUI_PROJECTION blocks=$blocks phase=${controller.phase.name} '
        'outputCharacters=${text.length} medianUs=${samples[samples.length ~/ 2]} '
        'p95Us=${samples[(samples.length * .95).floor()]}',
      );
      controller.dispose();
    });
  }
}

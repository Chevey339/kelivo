import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/support/genui_review_exercise.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native all-component visual and interaction review',
    (tester) async {
      if (Platform.isAndroid) {
        await binding.convertFlutterSurfaceToImage();
      }
      final cases = await exerciseGenUiReview(
        tester,
        openWeb: true,
        capture: (name) async {
          // Let the test binding's pointer indicator decay before capture.
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await binding.takeScreenshot(name);
        },
      );
      final result = {
        'platform': Platform.operatingSystem,
        'cases': cases,
        'input':
            'Automated pointer and keyboard events in the native application; visual captures require inspection.',
      };
      binding.reportData = {...?binding.reportData, ...result};
      // ignore: avoid_print
      print('GENUI_NATIVE_REVIEW ${jsonEncode(result)}');
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

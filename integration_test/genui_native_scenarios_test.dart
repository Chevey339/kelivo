import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:Kelivo/features/intelligent_ui/host/ui_web_controller.dart';
import '../test/support/genui_scenario_exercise.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native six-scene production flow',
    (tester) async {
      for (var n = 0; n < 100 && tester.view.physicalSize.isEmpty; n++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.view.physicalSize.isEmpty, isFalse);
      final before = UiWebController.createdNativeViews;
      final cases = await exerciseGenUiScenarios(tester, checkSemantics: false);
      final result = {
        'platform': Platform.operatingSystem,
        'os': Platform.operatingSystemVersion,
        'scenes': cases,
        'nativeWebViewsCreated': UiWebController.createdNativeViews - before,
        'input':
            'Automated widget interaction; real IME is recorded separately',
        'semantics':
            'OS-driven; deterministic tree assertions run in widget tests',
        'storageRestart':
            'Repository and widgets reopened against the same temporary SQLite file',
        'send':
            'Production composer and repository, isolated local sink without model calls',
      };
      binding.reportData = result;
      // ignore: avoid_print
      print('GENUI_NATIVE_SCENARIOS ${jsonEncode(result)}');
    },
    // Native accessibility is controlled by the OS, as in the application.
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

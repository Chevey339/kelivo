import 'package:flutter/services.dart';
// ignore: depend_on_referenced_packages
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import '../../support/fake_audioplayers_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/genui_scenario_exercise.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => switch (call.method) {
            'getLanguages' => ['en-US'],
            'getEngines' || 'getVoices' => [],
            _ => 1,
          },
        );
    AudioplayersPlatformInterface.instance = FakeAudioplayersPlatform();
    GlobalAudioplayersPlatformInterface.instance =
        FakeGlobalAudioplayersPlatform();
  });
  testWidgets(
    'six composed scenes through production message, composer and storage',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      expect(await exerciseGenUiScenarios(tester), [
        'S1',
        'S2',
        'S3',
        'S4',
        'S5',
        'S6',
      ]);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    }),
  );
}

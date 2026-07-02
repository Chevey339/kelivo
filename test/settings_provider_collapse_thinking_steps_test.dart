import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Cuplivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider collapse thinking steps toggle', () {
    test('defaults to disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.collapseThinkingSteps, isFalse);
    });

    test('loads persisted enabled value', () async {
      SharedPreferences.setMockInitialValues({
        'display_collapse_thinking_steps_v1': true,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.collapseThinkingSteps, isTrue);
    });

    test('persists mode changes to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setCollapseThinkingSteps(true);

      expect(settings.collapseThinkingSteps, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('display_collapse_thinking_steps_v1'), isTrue);
    });
  });
}

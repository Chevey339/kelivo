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

  group('SettingsProvider tool result summary toggle', () {
    test('defaults to disabled', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.showToolResultSummary, isFalse);
    });

    test('loads persisted enabled value', () async {
      SharedPreferences.setMockInitialValues({
        'display_show_tool_result_summary_v1': true,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.showToolResultSummary, isTrue);
    });

    test('persists mode changes to preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setShowToolResultSummary(true);

      expect(settings.showToolResultSummary, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('display_show_tool_result_summary_v1'), isTrue);
    });
  });
}

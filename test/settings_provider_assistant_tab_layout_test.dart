import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

Future<void> _waitForSettingsLoad() async {
  for (var i = 0; i < 25; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider mobile assistant tab layout', () {
    test('defaults to no custom order or hidden tabs', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.mobileAssistantEditTabOrder, isEmpty);
      expect(settings.hiddenMobileAssistantEditTabs, isEmpty);
    });

    test('loads persisted order and hidden tab ids', () async {
      SharedPreferences.setMockInitialValues({
        'mobile_assistant_edit_tab_order_v1': <String>['mcp', 'basic'],
        'mobile_assistant_edit_tab_hidden_v1': <String>['prompts'],
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.mobileAssistantEditTabOrder, ['mcp', 'basic']);
      expect(settings.hiddenMobileAssistantEditTabs, {'prompts'});
    });

    test('persists order and hidden tab changes', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setMobileAssistantEditTabOrder(['memory', 'basic']);
      await settings.setHiddenMobileAssistantEditTabs({'regex', 'custom'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('mobile_assistant_edit_tab_order_v1'), [
        'memory',
        'basic',
      ]);
      expect(prefs.getStringList('mobile_assistant_edit_tab_hidden_v1'), [
        'custom',
        'regex',
      ]);
    });
  });
}

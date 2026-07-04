import 'package:flutter/material.dart';
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

  group('SettingsProvider chat input background opacity', () {
    test('defaults to the current rendered input background opacity', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.chatInputBackgroundOpacityLight, closeTo(0.8236, 0.0001));
      expect(settings.chatInputBackgroundOpacityDark, closeTo(0.7396, 0.0001));
    });

    test('loads persisted input background opacity per brightness', () async {
      SharedPreferences.setMockInitialValues({
        'display_chat_input_background_opacity_light_v1': 0.35,
        'display_chat_input_background_opacity_dark_v1': 0.45,
      });
      final settings = SettingsProvider();

      await _waitForSettingsLoad();

      expect(settings.chatInputBackgroundOpacityLight, 0.35);
      expect(settings.chatInputBackgroundOpacityDark, 0.45);
    });

    test('selects and persists input background opacity with bounds', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await _waitForSettingsLoad();
      await settings.setChatInputBackgroundOpacity(Brightness.light, -0.2);
      await settings.setChatInputBackgroundOpacity(Brightness.dark, 1.2);

      final prefs = await SharedPreferences.getInstance();
      expect(settings.chatInputBackgroundOpacityLight, 0.0);
      expect(settings.chatInputBackgroundOpacityDark, 1.0);
      expect(settings.chatInputBackgroundOpacityFor(Brightness.light), 0.0);
      expect(settings.chatInputBackgroundOpacityFor(Brightness.dark), 1.0);
      expect(
        prefs.getDouble('display_chat_input_background_opacity_light_v1'),
        0.0,
      );
      expect(
        prefs.getDouble('display_chat_input_background_opacity_dark_v1'),
        1.0,
      );
    });
  });
}

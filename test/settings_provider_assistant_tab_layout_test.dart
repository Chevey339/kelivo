import "support/business_test_harness.dart";
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider mobile assistant tab layout', () {
    test('defaults to no custom order or hidden tabs', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.mobileAssistantEditTabOrder, isEmpty);
      expect(settings.hiddenMobileAssistantEditTabs, isEmpty);
    });

    test('loads persisted order and hidden tab ids', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'mobile_assistant_edit_tab_order_v1': <String>['mcp', 'basic'],
          'mobile_assistant_edit_tab_hidden_v1': <String>['prompts'],
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.mobileAssistantEditTabOrder, ['mcp', 'basic']);
      expect(settings.hiddenMobileAssistantEditTabs, {'prompts'});
    });

    test('persists order and hidden tab changes', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setMobileAssistantEditTabOrder(['memory', 'basic']);
      await settings.setHiddenMobileAssistantEditTabs({'regex', 'custom'});

      final prefs = harness.preferences;
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
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.chatInputBackgroundOpacityLight, closeTo(0.8236, 0.0001));
      expect(settings.chatInputBackgroundOpacityDark, closeTo(0.7396, 0.0001));
    });

    test('loads persisted input background opacity per brightness', () async {
      final harness = await createBusinessTestHarness(
        initial: {
          'display_chat_input_background_opacity_light_v1': 0.35,
          'display_chat_input_background_opacity_dark_v1': 0.45,
        },
      );
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;

      expect(settings.chatInputBackgroundOpacityLight, 0.35);
      expect(settings.chatInputBackgroundOpacityDark, 0.45);
    });

    test('selects and persists input background opacity with bounds', () async {
      final harness = await createBusinessTestHarness(initial: {});
      final settings = SettingsProvider(harness.preferences);

      await settings.loaded;
      await settings.setChatInputBackgroundOpacity(Brightness.light, -0.2);
      await settings.setChatInputBackgroundOpacity(Brightness.dark, 1.2);

      final prefs = harness.preferences;
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

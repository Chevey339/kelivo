import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:Kelivo/core/models/tool_schema_override.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/app_exit_flush.dart';

import 'support/business_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(AppExitFlush.debugReset);

  test('tool schema overrides default to empty', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    expect(settings.toolSchemaOverrides, isEmpty);
  });

  test('set, persist raw JSON, and reload', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    const override = ToolSchemaOverride(
      description: 'Custom search',
      paramDescriptions: {'query': 'Look this up'},
    );
    await settings.setToolSchemaOverride('search_web', override);

    expect(settings.toolSchemaOverrides['search_web'], override);
    expect(
      harness.preferences.getString('tool_schema_overrides_v1'),
      jsonEncode({
        'search_web': {
          'description': 'Custom search',
          'paramDescriptions': {'query': 'Look this up'},
        },
      }),
    );

    final reloaded = SettingsProvider(harness.preferences);
    await reloaded.loaded;
    expect(reloaded.toolSchemaOverrides['search_web'], override);
  });

  test('empty override removes the tool and persist key when last', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    await settings.loaded;

    await settings.setToolSchemaOverride(
      'search_web',
      const ToolSchemaOverride(description: 'x'),
    );
    await settings.resetToolSchemaOverride('search_web');

    expect(settings.toolSchemaOverrides, isEmpty);
    expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);

    await settings.setToolSchemaOverride(
      'search_web',
      const ToolSchemaOverride(description: 'x'),
    );
    await settings.resetAllToolSchemaOverrides();
    expect(settings.toolSchemaOverrides, isEmpty);
    expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);
  });

  test('live edits update memory immediately and persist the final value once', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;

    settings.setToolSchemaOverrideLive(
      'search_web',
      const ToolSchemaOverride(description: 'a'),
    );
    settings.setToolSchemaOverrideLive(
      'search_web',
      const ToolSchemaOverride(description: 'ab'),
    );
    settings.setToolSchemaOverrideLive(
      'search_web',
      const ToolSchemaOverride(description: 'abc'),
    );

    expect(settings.toolSchemaOverrides['search_web']?.description, 'abc');
    expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);

    await settings.flushPendingToolSchemaOverridePersist();
    expect(
      harness.preferences.getString('tool_schema_overrides_v1'),
      jsonEncode({
        'search_web': {'description': 'abc'},
      }),
    );
  });

  test('debounced persist writes after the quiet period', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;

    settings.setToolSchemaOverrideLive(
      'search_web',
      const ToolSchemaOverride(description: 'later'),
    );
    expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);

    await Future<void>.delayed(SettingsProvider.toolSchemaOverridePersistDebounce);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      jsonDecode(harness.preferences.getString('tool_schema_overrides_v1')!),
      {
        'search_web': {'description': 'later'},
      },
    );
  });

  test('app-exit flush persists the last live edit', () async {
    final harness = await createBusinessTestHarness(initial: {});
    final settings = SettingsProvider(harness.preferences);
    addTearDown(settings.dispose);
    await settings.loaded;

    settings.setToolSchemaOverrideLive(
      'search_web',
      const ToolSchemaOverride(description: 'keep me'),
    );
    expect(harness.preferences.getString('tool_schema_overrides_v1'), isNull);

    await AppExitFlush.flushAll();
    expect(
      jsonDecode(harness.preferences.getString('tool_schema_overrides_v1')!),
      {
        'search_web': {'description': 'keep me'},
      },
    );
  });
}

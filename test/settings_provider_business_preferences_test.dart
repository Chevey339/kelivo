import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Kelivo/core/database/app_database.dart';
import 'package:Kelivo/core/database/business_preferences.dart';
import 'package:Kelivo/core/database/business_repository.dart';
import 'package:Kelivo/core/database/business_settings_router.dart';
import 'package:Kelivo/core/providers/settings_provider.dart';
import 'package:Kelivo/core/services/search/search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late BusinessRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'display_chat_font_scale_v1': 1.2,
      'flutter_log_enabled_v1': false,
      // A business value in prefs must no longer win over SQLite.
      'theme_mode_v1': 'light',
    });
    database = AppDatabase(NativeDatabase.memory());
    repository = BusinessRepository(database);
    await repository.replaceSnapshot(
      BusinessSettingsRouter.normalizeAndRoute({
        'theme_mode_v1': 'dark',
        'theme_palette_v1': 'ocean',
        'app_launch_count_v1': 4,
        'learning_mode_enabled_v1': true,
        'learning_mode_prompt_v1': 'Learn from the database',
      }),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'loads business values from SQLite and local-only values from prefs',
    () async {
      final preferences = BusinessPreferences(repository);
      final settings = SettingsProvider(preferences);

      await settings.loaded;

      expect(settings.themeMode, ThemeMode.dark);
      expect(settings.themePaletteId, 'ocean');
      expect(settings.appLaunchCount, 4);
      expect(settings.learningModeEnabled, isTrue);
      expect(settings.learningModePrompt, 'Learn from the database');
      expect(settings.chatFontScale, 1.2);
    },
  );

  test(
    'fresh business storage preserves the built-in search service',
    () async {
      final settings = SettingsProvider(BusinessPreferences(repository));

      await settings.loaded;

      expect(settings.searchServices, <SearchServiceOptions>[
        SearchServiceOptions.defaultOption,
      ]);
      expect(settings.searchServiceSelected, 0);
    },
  );

  test('fresh built-in provider reordering survives a cold reload', () async {
    final settings = SettingsProvider(BusinessPreferences(repository));
    await settings.loaded;

    // These built-ins are intentionally not part of the first-run persisted
    // provider-config seed. Their row order must still survive a restart.
    await settings.setProvidersOrder(<String>['Gemini', 'OpenAI']);
    expect(settings.providersOrder.take(2), <String>['Gemini', 'OpenAI']);

    final reloaded = SettingsProvider(BusinessPreferences(repository));
    await reloaded.loaded;

    expect(reloaded.providersOrder.take(2), <String>['Gemini', 'OpenAI']);
  });

  test(
    'migrated order-only provider state survives startup seeding and reload',
    () async {
      const legacyOrder = <String>[
        'Gemini',
        'OpenAI',
        'SiliconFlow',
        'OpenRouter',
        'Atlas Cloud',
        'KelivoIN',
        'Tensdaq',
        'DeepSeek',
        'AIhubmix',
        'Aliyun',
        'Zhipu AI',
        'Claude',
        'Grok',
        'ByteDance',
      ];
      await repository.replaceSnapshot(
        BusinessSettingsRouter.normalizeAndRoute({
          'providers_order_v1': legacyOrder,
        }),
      );

      final settings = SettingsProvider(BusinessPreferences(repository));
      await settings.loaded;
      expect(settings.providersOrder, legacyOrder);

      final reloaded = SettingsProvider(BusinessPreferences(repository));
      await reloaded.loaded;
      expect(reloaded.providersOrder, legacyOrder);
    },
  );

  test(
    'persists representative settings and restores them on cold reload',
    () async {
      final settings = SettingsProvider(BusinessPreferences(repository));
      await settings.loaded;

      await settings.setThemeMode(ThemeMode.light);
      await settings.setThemePalette('forest');
      await settings.incrementAppLaunchCount();
      await settings.setLearningModeEnabled(false);
      await settings.setLearningModePrompt('Updated prompt');
      await settings.setChatFontScale(1.35);

      final reloaded = SettingsProvider(BusinessPreferences(repository));
      await reloaded.loaded;

      expect(reloaded.themeMode, ThemeMode.light);
      expect(reloaded.themePaletteId, 'forest');
      expect(reloaded.appLaunchCount, 5);
      expect(reloaded.learningModeEnabled, isFalse);
      expect(reloaded.learningModePrompt, 'Updated prompt');
      expect(reloaded.chatFontScale, 1.35);

      final localPreferences = await SharedPreferences.getInstance();
      expect(localPreferences.getDouble('display_chat_font_scale_v1'), 1.35);
      expect(localPreferences.getString('theme_mode_v1'), 'light');
    },
  );

  test(
    'copyWith keeps the in-memory snapshot without starting another load',
    () async {
      final preferences = BusinessPreferences(repository);
      final settings = SettingsProvider(preferences);
      await settings.loaded;

      await repository.setPreference('search_enabled_v1', true);
      final copy = settings.copyWith(searchAutoTestOnLaunch: true);
      await copy.loaded;

      expect(copy.searchEnabled, settings.searchEnabled);
      expect(copy.searchAutoTestOnLaunch, isTrue);
    },
  );
}

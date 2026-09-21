import 'package:Kelivo/features/settings/search/settings_search_index.dart';
import 'package:Kelivo/l10n/app_localizations_en.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizationsEn();
  final index = SettingsSearchIndex(en, platform: TargetPlatform.iOS);

  test('exact setting names rank first; all query words must match', () {
    expect(
      index.search(en.displaySettingsPageShowToolCardsTitle).first.id,
      'displaySettingsPageShowToolCardsTitle',
    );
    expect(
      index.search('  font   size ').first.id,
      'displaySettingsPageChatFontSizeTitle',
    );
    expect(index.search('font impossiblequery'), isEmpty);
    expect(index.search(' \n\t '), isEmpty);
    expect(index.search('x' * 20000), isEmpty);
  });

  test('indexes English, simplified and traditional titles in any locale', () {
    final chinese = SettingsSearchIndex(
      AppLocalizationsZh(),
      platform: TargetPlatform.iOS,
    );
    final traditional = SettingsSearchIndex(
      AppLocalizationsZhHant(),
      platform: TargetPlatform.iOS,
    );
    for (final candidate in [index, chinese, traditional]) {
      expect(
        candidate.search('language').map((e) => e.id),
        contains('displaySettingsPageLanguageTitle'),
      );
      expect(
        candidate.search('語言').map((e) => e.id),
        contains('displaySettingsPageLanguageTitle'),
      );
      expect(
        candidate.search('字体').map((e) => e.id),
        contains('displaySettingsPageChatFontSizeTitle'),
      );
      expect(candidate.search('ａｐｉ　ｋｅｙ').first.id, 'providers');
      expect(
        candidate.search('毛玻璃').first.destination,
        SettingsSearchDestination.messageStyle,
      );
    }
  });

  test('platform and runtime availability match the settings surfaces', () {
    Set<String> ids(
      TargetPlatform platform, {
      bool logs = false,
      bool dynamicColor = false,
    }) => SettingsSearchIndex(
      en,
      platform: platform,
      logsEnabled: logs,
      dynamicColorSupported: dynamicColor,
    ).entries.map((entry) => entry.id).toSet();
    final ios = ids(TargetPlatform.iOS);
    final android = ids(TargetPlatform.android, logs: true, dynamicColor: true);
    final desktop = ids(TargetPlatform.macOS);
    for (final platform in TargetPlatform.values) {
      expect(
        ids(platform).contains('linuxHideTitleBarTitle'),
        platform == TargetPlatform.linux,
        reason: 'The title bar setting is Linux-only.',
      );
    }
    expect(ios, contains('scheduledTasks'));
    expect(ios, isNot(contains('hotkeys')));
    expect(ios, isNot(contains('logs')));
    expect(
      android,
      containsAll([
        'scheduledTasks',
        'logs',
        'themeSettingsPageUseDynamicColorTitle',
      ]),
    );
    expect(
      desktop,
      containsAll([
        'scheduledTasks',
        'hotkeys',
        'displaySettingsPageTrayShowTrayTitle',
      ]),
    );
    for (final id in [
      'background',
      'haptics',
      'storage',
      'sponsor',
      'displaySettingsPageKeepSidebarOpenOnAssistantTapTitle',
      'displaySettingsPageKeepAssistantListExpandedOnSidebarCloseTitle',
      'displaySettingsPageMobileCodeBlockWrapTitle',
    ]) {
      expect(desktop, isNot(contains(id)), reason: id);
    }
  });

  test(
    'entries have stable unique ids, paths and localized destination labels',
    () {
      for (final platform in TargetPlatform.values) {
        final candidate = SettingsSearchIndex(en, platform: platform);
        expect(
          candidate.entries.map((e) => e.id).toSet().length,
          candidate.entries.length,
        );
        expect(candidate.suggestions, hasLength(6));
        final item = candidate.entries.firstWhere(
          (e) => e.id == 'displaySettingsPageShowToolCardsTitle',
        );
        expect(item.path, [
          'Settings',
          en.settingsPageDisplay,
          en.displaySettingsPageChatItemDisplayTitle,
        ]);
        expect(item.targetLabel, en.displaySettingsPageShowToolCardsTitle);
      }
    },
  );
}

import 'dart:ui';

/// The languages offered by both app settings layouts.
enum AppLanguage {
  simplifiedChinese('zh_CN', '简体中文', '🇨🇳', Locale('zh', 'CN')),
  traditionalChinese(
    'zh_Hant',
    '繁體中文',
    '🇨🇳',
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ),
  english('en_US', 'English', '🇺🇸', Locale('en', 'US')),
  russian('ru_RU', 'Русский', '🇷🇺', Locale('ru', 'RU')),
  korean('ko_KR', '한국어', '🇰🇷', Locale('ko', 'KR')),
  turkish('tr_TR', 'Türkçe', '🇹🇷', Locale('tr', 'TR'));

  const AppLanguage(this.tag, this.nativeName, this.flag, this.locale);

  final String tag;
  final String nativeName;
  final String flag;
  final Locale locale;

  static AppLanguage? fromTag(String tag) {
    for (final language in values) {
      if (language.tag == tag) return language;
    }
    return null;
  }

  static AppLanguage fromLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      final traditional =
          locale.scriptCode == 'Hant' ||
          (locale.scriptCode != 'Hans' &&
              const {'TW', 'HK', 'MO'}.contains(locale.countryCode));
      return traditional ? traditionalChinese : simplifiedChinese;
    }
    for (final language in values) {
      if (language.locale.languageCode == locale.languageCode) return language;
    }
    return english;
  }
}

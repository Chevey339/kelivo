class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.displayName,
    required this.nativeName,
    required this.flag,
  });

  final String code;
  final String displayName;
  final String nativeName;
  final String flag;
}

const supportedLanguages = [
  LanguageOption(
    code: 'zh-CN',
    displayName: 'Simplified Chinese',
    nativeName: '简体中文',
    flag: '🇨🇳',
  ),
  LanguageOption(
    code: 'en',
    displayName: 'English',
    nativeName: 'English',
    flag: '🇺🇸',
  ),
  LanguageOption(
    code: 'zh-TW',
    displayName: 'Traditional Chinese',
    nativeName: '繁體中文',
    flag: '🇨🇳',
  ),
  LanguageOption(
    code: 'ja',
    displayName: 'Japanese',
    nativeName: '日本語',
    flag: '🇯🇵',
  ),
  LanguageOption(
    code: 'ko',
    displayName: 'Korean',
    nativeName: '한국어',
    flag: '🇰🇷',
  ),
  LanguageOption(
    code: 'fr',
    displayName: 'French',
    nativeName: 'Français',
    flag: '🇫🇷',
  ),
  LanguageOption(
    code: 'de',
    displayName: 'German',
    nativeName: 'Deutsch',
    flag: '🇩🇪',
  ),
  LanguageOption(
    code: 'it',
    displayName: 'Italian',
    nativeName: 'Italiano',
    flag: '🇮🇹',
  ),
  LanguageOption(
    code: 'es',
    displayName: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
  ),
  LanguageOption(
    code: 'ru',
    displayName: 'Russian',
    nativeName: 'Русский',
    flag: '🇷🇺',
  ),
  LanguageOption(
    code: 'tr',
    displayName: 'Turkish',
    nativeName: 'Türkçe',
    flag: '🇹🇷',
  ),
  LanguageOption(
    code: 'bn',
    displayName: 'Bangla',
    nativeName: 'বাংলা',
    flag: '🇧🇩',
  ),
  LanguageOption(
    code: 'ar',
    displayName: 'Arabic',
    nativeName: 'العربية',
    flag: '🇸🇦',
  ),
];

LanguageOption standaloneTranslationLanguage(
  List<LanguageOption> languages, {
  required String? selectedCode,
  required String localeLanguageCode,
}) {
  final byCode = {for (final language in languages) language.code: language};
  final locale = localeLanguageCode.toLowerCase();
  final isChinese = locale.startsWith('zh');
  return byCode[selectedCode] ??
      byCode[isChinese ? 'zh-CN' : locale] ??
      (isChinese ? null : byCode['en']) ??
      languages.first;
}

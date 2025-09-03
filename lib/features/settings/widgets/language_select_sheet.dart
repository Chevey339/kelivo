import 'package:flutter/material.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';

class LanguageOption {
  final String code;
  final String displayName;
  final String displayNameZh;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.displayName,
    required this.displayNameZh,
    required this.flag,
  });
}

const List<LanguageOption> supportedLanguages = [
  LanguageOption(code: 'zh-CN', displayName: 'Simplified Chinese', displayNameZh: '简体中文', flag: '🇨🇳'),
  LanguageOption(code: 'en', displayName: 'English', displayNameZh: 'English', flag: '🇺🇸'),
  LanguageOption(code: 'zh-TW', displayName: 'Traditional Chinese', displayNameZh: '繁體中文', flag: '🇨🇳'),
  LanguageOption(code: 'ja', displayName: 'Japanese', displayNameZh: '日本語', flag: '🇯🇵'),
  LanguageOption(code: 'ko', displayName: 'Korean', displayNameZh: '한국어', flag: '🇰🇷'),
  LanguageOption(code: 'fr', displayName: 'French', displayNameZh: 'Français', flag: '🇫🇷'),
  LanguageOption(code: 'de', displayName: 'German', displayNameZh: 'Deutsch', flag: '🇩🇪'),
  LanguageOption(code: 'it', displayName: 'Italian', displayNameZh: 'Italiano', flag: '🇮🇹'),
  // LanguageOption(code: 'es', displayName: 'Spanish', displayNameZh: 'Español', flag: '🇪🇸'),
  // LanguageOption(code: 'pt', displayName: 'Portuguese', displayNameZh: 'Português', flag: '🇵🇹'),
  // LanguageOption(code: 'ru', displayName: 'Russian', displayNameZh: 'Русский', flag: '🇷🇺'),
  // LanguageOption(code: 'ar', displayName: 'Arabic', displayNameZh: 'العربية', flag: '🇸🇦'),
  // LanguageOption(code: 'hi', displayName: 'Hindi', displayNameZh: 'हिन्दी', flag: '🇮🇳'),
  // LanguageOption(code: 'th', displayName: 'Thai', displayNameZh: 'ไทย', flag: '🇹🇭'),
  // LanguageOption(code: 'vi', displayName: 'Vietnamese', displayNameZh: 'Tiếng Việt', flag: '🇻🇳'),
];

Future<LanguageOption?> showLanguageSelector(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<LanguageOption>(
    context: context,
    isScrollControlled: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _LanguageSelectSheet(),
  );
}

class _LanguageSelectSheet extends StatefulWidget {
  const _LanguageSelectSheet();

  @override
  State<_LanguageSelectSheet> createState() => _LanguageSelectSheetState();
}

class _LanguageSelectSheetState extends State<_LanguageSelectSheet> {
  final DraggableScrollableController _sheetCtrl = DraggableScrollableController();
  static const double _initialSize = 0.8;
  static const double _maxSize = 0.8;

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DraggableScrollableSheet(
          controller: _sheetCtrl,
          expand: false,
          initialChildSize: _initialSize,
          maxChildSize: _maxSize,
          minChildSize: 0.3,
          builder: (c, controller) {
            return Column(
              children: [
                // Header with drag indicator
                Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Text(
                    l10n.selectTranslationLanguage,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                // Language list
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      ...supportedLanguages.map((lang) => _languageOption(context, lang)),
                      const SizedBox(height: 12),
                      // Clear translation button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        child: Material(
                          color: isDark ? Colors.red.withOpacity(0.12) : Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(LanguageOption(
                              code: '__clear__',
                              displayName: l10n.clearTranslation,
                              displayNameZh: l10n.clearTranslation,
                              flag: '',
                            )),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(
                                    Lucide.X,
                                    size: 20,
                                    color: Colors.red.shade600,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.clearTranslation,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _languageOption(BuildContext context, LanguageOption lang) {
    final cs = Theme.of(context).colorScheme;
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pop(lang),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Flag only (remove globe icon)
                Text(
                  lang.flag,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 12),
                // Language name
                Expanded(
                  child: Text(
                    zh ? lang.displayNameZh : lang.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

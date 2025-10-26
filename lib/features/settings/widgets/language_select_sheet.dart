import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';

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

String _displayNameFor(AppLocalizations l10n, String languageCode) {
  switch (languageCode) {
    case 'zh-CN':
      return l10n.languageDisplaySimplifiedChinese;
    case 'en':
      return l10n.languageDisplayEnglish;
    case 'zh-TW':
      return l10n.languageDisplayTraditionalChinese;
    case 'ja':
      return l10n.languageDisplayJapanese;
    case 'ko':
      return l10n.languageDisplayKorean;
    case 'fr':
      return l10n.languageDisplayFrench;
    case 'de':
      return l10n.languageDisplayGerman;
    case 'it':
      return l10n.languageDisplayItalian;
    default:
      return languageCode;
  }
}

Future<LanguageOption?> showLanguageSelector(BuildContext context) async {
  final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<LanguageOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20 )),
      ),
      builder: (ctx) => const _LanguageSelectSheet(),
    );
  }

  // Desktop anchored menu
  final l10n = AppLocalizations.of(context)!;
  LanguageOption? selected;
  final items = [
    ...supportedLanguages.map((lang) => DesktopContextMenuItem(
          icon: null,
          label: '${lang.flag} ${_displayNameFor(l10n, lang.code)}',
          onTap: () => selected = lang,
        )),
    DesktopContextMenuItem(
      icon: Lucide.X,
      label: l10n.languageSelectSheetClearButton,
      onTap: () => selected = const LanguageOption(
        code: '__clear__',
        displayName: 'Clear Translation',
        displayNameZh: '清空翻译',
        flag: '',
      ),
      danger: true,
    ),
  ];
  await showDesktopContextMenuAt(
    context,
    globalPosition: DesktopMenuAnchor.positionOrCenter(context),
    items: items,
  );
  return selected;
}

class _LanguageSelectSheet extends StatefulWidget {
  const _LanguageSelectSheet();

  @override
  State<_LanguageSelectSheet> createState() => _LanguageSelectSheetState();
}

class _LanguageSelectSheetState extends State<_LanguageSelectSheet> {
  // Auto height with a max constraint; no draggable sheet.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with drag indicator (reduced spacing)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                // No title per iOS style; keep content close to handle
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...supportedLanguages.map((lang) => _languageOption(context, lang)),
                      const SizedBox(height: 8),
                      // Clear translation row (iOS style)
                      SizedBox(
                        height: 48,
                        child: IosCardPress(
                          borderRadius: BorderRadius.circular(14),
                          baseColor: cs.surface,
                          duration: const Duration(milliseconds: 260),
                          onTap: () {
                            Haptics.light();
                            Navigator.of(context).pop(const LanguageOption(
                              code: '__clear__',
                              displayName: 'Clear Translation',
                              displayNameZh: '清空翻译',
                              flag: '',
                            ));
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(Lucide.X, size: 20, color: Colors.red.shade600),
                              const SizedBox(width: 10),
                              Text(
                                l10n.languageSelectSheetClearButton,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.red.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _languageOption(BuildContext context, LanguageOption lang) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: cs.surface,
          duration: const Duration(milliseconds: 260),
          onTap: () {
            Haptics.light();
            Navigator.of(context).pop(lang);
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              // Flag only
              Text(lang.flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _getLanguageDisplayName(l10n, lang.code),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLanguageDisplayName(AppLocalizations l10n, String languageCode) {
    switch (languageCode) {
      case 'zh-CN':
        return l10n.languageDisplaySimplifiedChinese;
      case 'en':
        return l10n.languageDisplayEnglish;
      case 'zh-TW':
        return l10n.languageDisplayTraditionalChinese;
      case 'ja':
        return l10n.languageDisplayJapanese;
      case 'ko':
        return l10n.languageDisplayKorean;
      case 'fr':
        return l10n.languageDisplayFrench;
      case 'de':
        return l10n.languageDisplayGerman;
      case 'it':
        return l10n.languageDisplayItalian;
      default:
        return languageCode;
    }
  }
}

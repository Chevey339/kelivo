import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import '../../../core/models/translation_language.dart';
import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../core/services/haptics.dart';
import '../../../desktop/desktop_context_menu.dart';
import '../../../desktop/menu_anchor.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import '../../../shared/widgets/section_card.dart';

String languageDisplayName(AppLocalizations l10n, String languageCode) {
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
    case 'ru':
      return l10n.languageDisplayRussian;
    case 'tr':
      return l10n.languageDisplayTurkish;
    case 'bn':
      return l10n.languageDisplayBangla;
    case 'ar':
      return l10n.languageDisplayArabic;
    case 'fr':
      return l10n.languageDisplayFrench;
    case 'de':
      return l10n.languageDisplayGerman;
    case 'it':
      return l10n.languageDisplayItalian;
    case 'es':
      return l10n.languageDisplaySpanish;
    default:
      return languageCode;
  }
}

const _clearTranslation = LanguageOption(
  code: '__clear__',
  displayName: 'Clear Translation',
  nativeName: '清空翻译',
  flag: '',
);

Future<LanguageOption?> showLanguageSelector(
  BuildContext context, {
  required List<LanguageOption> languages,
}) async {
  final isDesktop =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
  if (!isDesktop) {
    return showModalBottomSheet<LanguageOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.overlaySurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LanguageSelectSheet(languages: languages),
    );
  }

  // Desktop anchored menu
  final l10n = AppLocalizations.of(context)!;
  LanguageOption? selected;
  final items = [
    ...languages.map(
      (lang) => DesktopContextMenuItem(
        icon: null,
        label: '${lang.flag} ${languageDisplayName(l10n, lang.code)}',
        onTap: () => selected = lang,
      ),
    ),
    DesktopContextMenuItem(
      icon: Lucide.X,
      label: l10n.languageSelectSheetClearButton,
      onTap: () => selected = _clearTranslation,
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

class _LanguageSelectSheet extends StatelessWidget {
  const _LanguageSelectSheet({required this.languages});

  final List<LanguageOption> languages;

  // Auto height with a max constraint; no draggable sheet.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final maxHeight = MediaQuery.of(context).size.height * 0.8;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
                      color: cs.onSurface.withValues(alpha: 0.2),
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
                      ...languages.map(
                        (lang) => _languageOption(context, lang),
                      ),
                      const SizedBox(height: 8),
                      // Clear translation row (iOS style)
                      SizedBox(
                        height: 48,
                        child: IosCardPress(
                          borderRadius: BorderRadius.circular(14),
                          baseColor: sheetTileColor(context),
                          duration: const Duration(milliseconds: 260),
                          onTap: () {
                            Haptics.light();
                            Navigator.of(context).pop(_clearTranslation);
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Icon(
                                Lucide.X,
                                size: 20,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.languageSelectSheetClearButton,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: AppFontWeights.medium,
                                  color: Theme.of(context).colorScheme.error,
                                ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        height: 48,
        child: IosCardPress(
          borderRadius: BorderRadius.circular(14),
          baseColor: sheetTileColor(context),
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
                  languageDisplayName(l10n, lang.code),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.medium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

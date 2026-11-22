import 'package:flutter/material.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_text_button.dart';
import '../../../theme/app_font_weights.dart';
import '../widgets/translation_languages_editor.dart';

class TranslationLanguagesPage extends StatelessWidget {
  const TranslationLanguagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    void close() {
      if (ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).maybePop();
      }
    }

    return TranslationLanguagesEditor(
      onSaved: close,
      builder: (context, body, onSave) {
        final toolbar = SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: NavigationToolbar(
              middleSpacing: 8,
              leading: IosIconButton(
                icon: Lucide.ArrowLeft,
                semanticLabel: l10n.settingsPageBackButton,
                size: 22,
                minSize: 44,
                onTap: close,
              ),
              middle: Text(
                l10n.translationLanguageManagerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: AppFontWeights.semibold,
                ),
              ),
              trailing: IosTextButton(
                label: MaterialLocalizations.of(context).saveButtonLabel,
                onPressed: onSave,
              ),
            ),
          ),
        );
        return Material(
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toolbar,
                Expanded(child: body),
              ],
            ),
          ),
        );
      },
    );
  }
}

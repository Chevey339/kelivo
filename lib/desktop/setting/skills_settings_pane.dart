import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:flutter/material.dart';

/// Desktop settings pane wrapping [SkillsPane] with the shared header chrome.
class DesktopSkillsSettingsPane extends StatelessWidget {
  const DesktopSkillsSettingsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.skillsTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFontWeights.regular,
                            color: cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    const SkillsImportPlusButton(
                      key: SkillsKeys.import,
                      size: 18,
                      minSize: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Expanded(child: SkillsPane(showHeader: false)),
            ],
          ),
        ),
      ),
    );
  }
}

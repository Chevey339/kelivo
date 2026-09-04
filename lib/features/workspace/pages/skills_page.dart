import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/pages/skills_page_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/skills_page_mobile_layout.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_import.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skill_labels.dart';
import 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:flutter/material.dart';

export 'package:Kelivo/features/workspace/widgets/skills/skills_pane.dart';

/// Skills library. Use [SkillsPane] to embed the same body in a desktop
/// settings column.
class SkillsPage extends StatelessWidget {
  const SkillsPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return const SkillsPageDesktopLayout();
    }
    return const SkillsPageMobileLayout();
  }
}

/// Mobile: push [SkillsPage]. Desktop: a ~640 × 80% dialog of the pane.
Future<void> openSkillsPage(BuildContext context) {
  if (ResponsiveHelper.isDesktop(context)) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return showAppDialog<void>(
      context,
      maxWidth: 640,
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            AppDialogHeader(
              title: l10n.skillsTitle,
              actions: const [
                SkillsImportPlusButton(
                  key: SkillsKeys.import,
                  size: 18,
                  minSize: 32,
                ),
              ],
            ),
            const Expanded(
              child: SkillsPane(
                showHeader: false,
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const SkillsPage()));
}

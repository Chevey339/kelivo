import 'package:flutter/material.dart';

import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/pages/environment_page_desktop_layout.dart';
import 'package:Kelivo/features/workspace/pages/environment_page_mobile_layout.dart';
import 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';

export 'package:Kelivo/features/workspace/widgets/environment/environment_pane.dart';
export 'package:Kelivo/features/workspace/widgets/environment/environment_status_chip.dart';

/// Environment / sandbox settings. Use [EnvironmentPane] to embed the same
/// body in a desktop settings column.
class EnvironmentPage extends StatelessWidget {
  const EnvironmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context)) {
      return const EnvironmentPageDesktopLayout();
    }
    return const EnvironmentPageMobileLayout();
  }
}

/// Mobile: push [EnvironmentPage]. Desktop: a ~640 × 80% dialog of the pane.
Future<void> openEnvironmentPage(BuildContext context) {
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
            AppDialogHeader(title: l10n.workspaceEnvTitle),
            const Expanded(child: EnvironmentPane()),
          ],
        ),
      ),
    );
  }
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (_) => const EnvironmentPage()),
  );
}

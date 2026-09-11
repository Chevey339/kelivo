import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';

/// Matches Settings' themed navigation bar using the app's own controls.
class ScheduledTasksScaffold extends StatelessWidget {
  const ScheduledTasksScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final IconData? actionIcon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bar = theme.appBarTheme;
    final dark = theme.brightness == Brightness.dark;
    final overlay =
        bar.systemOverlayStyle ??
        (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay.copyWith(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                key: const ValueKey('scheduled-tasks-navigation'),
                height: bar.toolbarHeight ?? kToolbarHeight,
                color: bar.backgroundColor ?? theme.colorScheme.surface,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Center(
                        child: IosIconButton(
                          icon: LucideIcons.arrowLeft,
                          size: 22,
                          minSize: 44,
                          color:
                              bar.foregroundColor ??
                              theme.colorScheme.onSurface,
                          semanticLabel: AppLocalizations.of(
                            context,
                          )!.settingsPageBackButton,
                          onTap: () => Navigator.maybePop(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              bar.titleTextStyle ?? theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    if (actionIcon != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: IosIconButton(
                          key: const ValueKey('scheduled-tasks-action'),
                          icon: actionIcon,
                          size: 22,
                          minSize: 44,
                          color: theme.colorScheme.onSurface,
                          semanticLabel: actionLabel,
                          onTap: onAction,
                          enabled: onAction != null,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

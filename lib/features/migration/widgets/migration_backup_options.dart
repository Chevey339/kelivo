import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_checkbox.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/app_font_weights.dart';
import '../../../theme/app_semantic_colors.dart';
import '../../../theme/theme_factory.dart';

class MigrationBackupOptions extends StatelessWidget {
  const MigrationBackupOptions({
    super.key,
    required this.skipChatsJson,
    required this.skipBackup,
    required this.onSkipChatsJsonChanged,
    required this.onSkipBackupChanged,
  });

  final bool skipChatsJson;
  final bool skipBackup;
  final ValueChanged<bool>? onSkipChatsJsonChanged;
  final ValueChanged<bool>? onSkipBackupChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        _BackupOptionTile(
          key: const Key('migration_skip_chats_json'),
          icon: Lucide.FileText,
          title: l10n.migrationSkipChatsJsonOption,
          description: l10n.migrationSkipChatsJsonDescription,
          selected: skipChatsJson,
          onChanged: skipBackup ? null : onSkipChatsJsonChanged,
        ),
        const SizedBox(height: 8),
        _BackupOptionTile(
          key: const Key('migration_skip_backup'),
          icon: Lucide.HardDrive,
          title: l10n.migrationSkipBackupOption,
          description: l10n.migrationSkipBackupDescription,
          selected: skipBackup,
          onChanged: onSkipBackupChanged,
        ),
      ],
    );
  }
}

class _BackupOptionTile extends StatelessWidget {
  const _BackupOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final enabled = onChanged != null;
    final selectedColor = Color.alphaBlend(
      cs.primary.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.18 : 0.10,
      ),
      context.appColors.surfaceCard,
    );
    final baseColor = selected ? selectedColor : context.appColors.surfaceCard;
    final foreground = enabled
        ? cs.onSurface
        : cs.onSurface.withValues(alpha: 0.42);
    final secondary = enabled
        ? cs.onSurfaceVariant.withValues(alpha: 0.82)
        : cs.onSurfaceVariant.withValues(alpha: 0.38);

    return Semantics(
      container: true,
      button: true,
      checked: selected,
      enabled: enabled,
      child: IosCardPress(
        onTap: enabled ? () => onChanged!(!selected) : null,
        haptics: false,
        baseColor: baseColor,
        borderRadius: BorderRadius.circular(14),
        pressedScale: 0.99,
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? cs.primary.withValues(alpha: 0.14)
                    : cs.onSurface.withValues(alpha: 0.045),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 17,
                color: selected ? cs.primary : secondary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: AppFontWeights.semibold,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: IgnorePointer(
                child: IosCheckbox(
                  value: selected,
                  onChanged: enabled ? onChanged : null,
                  size: 20,
                  hitTestSize: 28,
                  borderWidth: 1.6,
                  activeColor: cs.primary,
                  borderColor: cs.onSurface.withValues(alpha: 0.20),
                  enableHaptics: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(
  name: 'Migration backup options · Light',
  group: 'Migration',
  size: Size(390, 250),
  brightness: Brightness.light,
)
@Preview(
  name: 'Migration backup options · Dark',
  group: 'Migration',
  size: Size(390, 250),
  brightness: Brightness.dark,
)
Widget migrationBackupOptionsPreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildLightTheme(null),
    darkTheme: buildDarkTheme(null),
    themeMode: ThemeMode.system,
    home: const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: _MigrationBackupOptionsPreviewBody(),
        ),
      ),
    ),
  );
}

class _MigrationBackupOptionsPreviewBody extends StatefulWidget {
  const _MigrationBackupOptionsPreviewBody();

  @override
  State<_MigrationBackupOptionsPreviewBody> createState() =>
      _MigrationBackupOptionsPreviewBodyState();
}

class _MigrationBackupOptionsPreviewBodyState
    extends State<_MigrationBackupOptionsPreviewBody> {
  bool _skipChatsJson = true;
  bool _skipBackup = false;

  @override
  Widget build(BuildContext context) {
    return MigrationBackupOptions(
      skipChatsJson: _skipChatsJson,
      skipBackup: _skipBackup,
      onSkipChatsJsonChanged: (value) {
        setState(() => _skipChatsJson = value);
      },
      onSkipBackupChanged: (value) {
        setState(() => _skipBackup = value);
      },
    );
  }
}

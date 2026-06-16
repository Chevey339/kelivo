import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import 'custom_bottom_sheet.dart';
import 'ios_tactile.dart';

class _QQGroupEntry {
  const _QQGroupEntry({required this.name, required this.joinUrl});

  final String name;
  final String joinUrl;
}

List<_QQGroupEntry> _groups(AppLocalizations l10n) => <_QQGroupEntry>[
  _QQGroupEntry(
    name: l10n.aboutPageQQGroupOne,
    joinUrl: 'https://qm.qq.com/q/OQaXetKssC',
  ),
  _QQGroupEntry(
    name: l10n.aboutPageQQGroupTwo,
    joinUrl: 'https://qm.qq.com/q/7t6VEqSXhm',
  ),
];

Future<void> _openJoinUrl(String url) async {
  final uri = Uri.parse(url);
  try {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  } catch (_) {
    await launchUrl(uri);
  }
}

bool get _isDesktopTarget {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return false;
  }
}

/// Shows the "join QQ group" picker: a bottom sheet on mobile, a dialog on
/// desktop. Tapping an entry opens its join link directly.
Future<void> showQQGroupJoinSheet({required BuildContext context}) {
  final l10n = AppLocalizations.of(context)!;
  final groups = _groups(l10n);

  if (_isDesktopTarget) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _QQGroupJoinDialog(
        title: l10n.aboutPageJoinQQGroup,
        closeSemanticLabel: l10n.mcpPageClose,
        groups: groups,
        onSelect: (entry) {
          Navigator.of(dialogContext).maybePop();
          _openJoinUrl(entry.joinUrl);
        },
      ),
    );
  }

  return showCustomBottomSheet<void>(
    context: context,
    title: l10n.aboutPageJoinQQGroup,
    closeSemanticLabel: l10n.mcpPageClose,
    partialHeightFactor: 0.42,
    expandedHeightFactor: 0.42,
    builder: (sheetContext, controller) => ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        for (final entry in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _QQGroupRow(
              entry: entry,
              onTap: () {
                Navigator.of(sheetContext).maybePop();
                _openJoinUrl(entry.joinUrl);
              },
            ),
          ),
      ],
    ),
  );
}

class _QQGroupRow extends StatelessWidget {
  const _QQGroupRow({required this.entry, required this.onTap});

  final _QQGroupEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return IosCardPress(
      borderRadius: BorderRadius.circular(12),
      baseColor: isDark
          ? cs.surfaceContainerHighest.withValues(alpha: 0.50)
          : cs.surfaceContainerHighest.withValues(alpha: 0.45),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/tencent-qq.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              cs.onSurface.withValues(alpha: 0.9),
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: AppFontWeights.semibold,
                color: cs.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
          Icon(
            Lucide.ChevronRight,
            size: 16,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}

class _QQGroupJoinDialog extends StatelessWidget {
  const _QQGroupJoinDialog({
    required this.title,
    required this.closeSemanticLabel,
    required this.groups,
    required this.onSelect,
  });

  final String title;
  final String closeSemanticLabel;
  final List<_QQGroupEntry> groups;
  final ValueChanged<_QQGroupEntry> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 360, maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.emphasis,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IosIconButton(
                      icon: Lucide.X,
                      size: 20,
                      padding: EdgeInsets.zero,
                      color: cs.onSurface.withValues(alpha: 0.62),
                      semanticLabel: closeSemanticLabel,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final entry in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _QQGroupRow(
                    entry: entry,
                    onTap: () => onSelect(entry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

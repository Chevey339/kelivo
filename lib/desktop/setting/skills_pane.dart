import 'package:flutter/material.dart';

import '../../features/skills/pages/skills_management_page.dart';
import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';

/// Desktop settings pane for managing Agent Skills.
///
/// Wraps the shared [SkillManagementContent] (in desktop mode) with a toolbar
/// that exposes import actions. The list, detail dialog and delete flow are
/// handled by [SkillManagementContent]; this pane only provides the toolbar
/// shell and triggers imports via the content's [GlobalKey].
///
/// NOTE(l10n): User-visible strings in this file are intentionally hardcoded
/// in Chinese. They will be moved into ARB files in Task 16 together with
/// other skills strings.
class DesktopSkillsPane extends StatefulWidget {
  const DesktopSkillsPane({super.key});

  @override
  State<DesktopSkillsPane> createState() => _DesktopSkillsPaneState();
}

class _DesktopSkillsPaneState extends State<DesktopSkillsPane> {
  final GlobalKey<SkillManagementContentState> _contentKey =
      GlobalKey<SkillManagementContentState>();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                          l10n.skillsPageTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: AppFontWeights.regular,
                            color: cs.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                    _SmallIconBtn(
                      icon: lucide.Lucide.FileText,
                      tooltip: l10n.skillsImportMd,
                      onTap: () => _contentKey.currentState?.importSkillMd(),
                    ),
                    const SizedBox(width: 6),
                    _SmallIconBtn(
                      icon: lucide.Lucide.Box,
                      tooltip: l10n.skillsImportZip,
                      onTap: () => _contentKey.currentState?.importZip(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SkillManagementContent(
                  key: _contentKey,
                  isDesktop: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05))
        : Colors.transparent;
    final btn = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
    if ((widget.tooltip ?? '').isEmpty) return btn;
    return Tooltip(message: widget.tooltip!, child: btn);
  }
}

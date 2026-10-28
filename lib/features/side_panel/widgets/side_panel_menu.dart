import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../../../desktop/widgets/desktop_pointer_surface.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/surface_ladder.dart';
import '../../browser/widgets/browser_text_field.dart';
import 'side_panel_tab_bar.dart';

class SidePanelMenuEntry {
  const SidePanelMenuEntry({
    required this.title,
    this.subtitle,
    this.group,
    this.leading,
    this.onTap,
    this.onClose,
    this.selected = false,
  });
  final String title;
  final String? subtitle, group;
  final Widget? leading;
  final VoidCallback? onTap, onClose;
  final bool selected;
}

/// Searchable anchored menu with independently actionable close buttons.
Future<void> showSidePanelMenu(
  BuildContext context, {
  required Offset position,
  required List<SidePanelMenuEntry> Function() entries,
  Listenable? listenable,
  String? hint,
}) {
  final l = AppLocalizations.of(context)!;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: l.sidePanelAllTabs,
    // Native WebViews receive clicks through a zero-alpha Flutter barrier.
    barrierColor: const Color(0x01000000),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => _PanelMenu(
      position: position,
      entries: entries,
      listenable: listenable,
      hint: hint,
    ),
  );
}

class _PanelMenu extends StatefulWidget {
  const _PanelMenu({
    required this.position,
    required this.entries,
    this.listenable,
    this.hint,
  });
  final Offset position;
  final List<SidePanelMenuEntry> Function() entries;
  final Listenable? listenable;
  final String? hint;
  @override
  State<_PanelMenu> createState() => _PanelMenuState();
}

class _PanelMenuState extends State<_PanelMenu> {
  final _search = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.listenable?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.listenable?.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(320.0, size.width - 16);
    final height = math.min(440.0, size.height - 24);
    final entries = widget
        .entries()
        .where(
          (entry) => '${entry.title} ${entry.subtitle ?? ''}'
              .toLowerCase()
              .contains(_search.text.toLowerCase()),
        )
        .toList();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Stack(
        children: [
          Positioned(
            left: widget.position.dx.clamp(
              8.0,
              math.max(8, size.width - width - 8),
            ),
            top: widget.position.dy.clamp(
              8.0,
              math.max(8, size.height - height - 8),
            ),
            width: width,
            child: Material(
              color: Color.alphaBlend(
                AppOverlayColors.desktopPopoverSurface(cs),
                cs.surface,
              ),
              elevation: 12,
              shadowColor: cs.shadow.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: height),
                child: DesktopPointerSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: SurfaceLadder.fromScheme(cs).surfaceFill,
                            borderRadius: BorderRadius.circular(
                              AppRadii.capsule,
                            ),
                          ),
                          child: BrowserTextField(
                            controller: _search,
                            autofocus: true,
                            placeholder: l.sidePanelSearchTabs,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(LucideIcons.search, size: 14),
                            ),
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (widget.hint != null)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              widget.hint!,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (index, entry)
                                    in entries.indexed) ...[
                                  if (entry.group != null &&
                                      (index == 0 ||
                                          entries[index - 1].group !=
                                              entry.group))
                                    Builder(
                                      builder: (context) {
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              8,
                                              10,
                                              8,
                                              4,
                                            ),
                                            child: Text(
                                              entry.group!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  IosCardPress(
                                    mouseCursor: SystemMouseCursors.basic,
                                    haptics: false,
                                    focusable: true,
                                    borderRadius: BorderRadius.circular(8),
                                    baseColor: entry.selected
                                        ? SurfaceLadder.fromScheme(
                                            cs,
                                          ).surfaceFill
                                        : Colors.transparent,
                                    padding: EdgeInsets.zero,
                                    onTap: entry.onTap == null
                                        ? null
                                        : () {
                                            Navigator.of(context).pop();
                                            entry.onTap!();
                                          },
                                    child: SizedBox(
                                      height: 32,
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 8),
                                          if (entry.leading != null) ...[
                                            entry.leading!,
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            child: Tooltip(
                                              message: entry.subtitle ?? '',
                                              child: Text(
                                                entry.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: entry.onTap == null
                                                      ? cs.onSurfaceVariant
                                                      : cs.onSurface,
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (entry.onClose != null)
                                            SidePanelIconButton(
                                              icon: LucideIcons.x,
                                              label: l.browserCloseTab,
                                              onTap: entry.onClose,
                                            ),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

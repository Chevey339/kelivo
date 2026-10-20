import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../models/browser_agent_activity.dart';
import 'browser_glass.dart';

export '../models/browser_agent_activity.dart';

/// An action status, not a permission banner. Idle occupies no layout space.
class BrowserAgentStatusChip extends StatelessWidget {
  const BrowserAgentStatusChip({
    super.key,
    required this.activity,
    required this.onPause,
    required this.onResume,
  });

  final BrowserAgentActivity activity;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    if (activity == BrowserAgentActivity.idle) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final paused = activity == BrowserAgentActivity.paused;
    final label = paused ? l.browserAgentPaused : l.browserAgentWorking;
    final action = paused ? l.browserAllowAgent : l.browserPauseAi;
    final colors = Theme.of(context).colorScheme;
    return Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Semantics(
          button: true,
          liveRegion: true,
          label: '$label, $action',
          onTap: paused ? onResume : onPause,
          child: ExcludeSemantics(
            child: BrowserPress(
              draggable: false,
              onTap: paused ? onResume : onPause,
              child: BrowserGlass(
                key: const ValueKey('browserAgentStatusChip'),
                radius: 24,
                elevated: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: math.max(0, constraints.maxWidth),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              paused ? LucideIcons.pause : LucideIcons.bot,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        action,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../l10n/app_localizations.dart';
import '../models/browser_agent_activity.dart';
import 'browser_glass.dart';
import 'browser_surface_controls.dart';

export '../models/browser_agent_activity.dart';

/// An action status, not a permission banner. Idle occupies no layout space.
class BrowserAgentStatusChip extends StatelessWidget {
  const BrowserAgentStatusChip({
    super.key,
    required this.activity,
    this.pauseReason,
    required this.onPause,
    required this.onResume,
  });

  final BrowserAgentActivity activity;
  final BrowserAgentPauseReason? pauseReason;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    if (activity == BrowserAgentActivity.idle) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final paused = activity == BrowserAgentActivity.paused;
    final label = paused
        ? pauseReason == BrowserAgentPauseReason.timeout
              ? l.browserAgentTimedOut
              : l.browserAgentPaused
        : l.browserAgentWorking;
    final action = paused ? l.browserAllowAgent : l.browserTakeOver;
    final colors = Theme.of(context).colorScheme;
    return Align(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Semantics(
          liveRegion: true,
          child: BrowserGlass(
            key: const ValueKey('browserAgentStatusChip'),
            radius: 24,
            elevated: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4),
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
                BrowserSurfaceButton(
                  key: const ValueKey('browserAgentControlAction'),
                  onPressed: paused ? onResume : onPause,
                  radius: 16,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

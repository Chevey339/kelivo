import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/hermes_gateway_provider.dart';
import '../../l10n/app_localizations.dart';

/// Animated indicator showing the current Hermes handoff state in the AppBar.
class HermesHandoffIndicator extends StatelessWidget {
  const HermesHandoffIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HermesGatewayProvider>(
      builder: (context, hp, _) {
        final state = hp.handoffState;
        if (state.status == HermesHandoffStatus.idle) {
          return const SizedBox.shrink();
        }

        final l10n = AppLocalizations.of(context)!;
        final color = _statusColor(context, state.status);
        final icon = _statusIcon(state.status);
        final label = _statusLabel(l10n, state);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Container(
              key: ValueKey(state.status),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.status == HermesHandoffStatus.inProgress)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Icon(icon, size: 12, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(BuildContext context, HermesHandoffStatus status) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case HermesHandoffStatus.inProgress:
        return cs.primary;
      case HermesHandoffStatus.completed:
        return Colors.green;
      case HermesHandoffStatus.failed:
        return cs.error;
      case HermesHandoffStatus.idle:
        return cs.outline;
    }
  }

  IconData _statusIcon(HermesHandoffStatus status) {
    switch (status) {
      case HermesHandoffStatus.inProgress:
        return Icons.swap_horiz;
      case HermesHandoffStatus.completed:
        return Icons.check_circle_outline;
      case HermesHandoffStatus.failed:
        return Icons.error_outline;
      case HermesHandoffStatus.idle:
        return Icons.swap_horiz;
    }
  }

  String _statusLabel(AppLocalizations l10n, HermesHandoffState state) {
    switch (state.status) {
      case HermesHandoffStatus.inProgress:
        if (state.toAgentName != null) {
          return l10n.hermesHandoffInProgress(state.toAgentName!);
        }
        return l10n.hermesHandoffTransferring;
      case HermesHandoffStatus.completed:
        if (state.toAgentName != null) {
          return l10n.hermesHandoffCompleted(state.toAgentName!);
        }
        return l10n.hermesHandoffDone;
      case HermesHandoffStatus.failed:
        return state.reason ?? l10n.hermesHandoffFailed;
      case HermesHandoffStatus.idle:
        return '';
    }
  }
}

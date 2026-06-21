import 'package:flutter/material.dart';
import '../../core/providers/hermes_gateway_provider.dart';
import '../../hermes/hermes_rpc.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../l10n/app_localizations.dart';

/// Bottom sheet for confirming or cancelling a Hermes handoff request.
///
/// Shown automatically when a HandoffRequested stream event fires.
/// Allows the user to pick an agent from the available list and confirm,
/// or cancel the handoff entirely.
class HermesHandoffSheet extends StatefulWidget {
  final HandoffPendingRequest request;
  final HermesGatewayProvider provider;

  const HermesHandoffSheet({
    super.key,
    required this.request,
    required this.provider,
  });

  /// Show the handoff sheet if a pending handoff exists.
  static Future<void> showIfPending(
    BuildContext context,
    HermesGatewayProvider provider,
  ) async {
    final req = provider.pendingHandoff;
    if (req == null) return;

    // Load agents if not yet loaded
    if (provider.agents.isEmpty && !provider.loadingAgents) {
      await provider.loadAgents();
    }

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => HermesHandoffSheet(request: req, provider: provider),
    );
  }

  @override
  State<HermesHandoffSheet> createState() => _HermesHandoffSheetState();
}

class _HermesHandoffSheetState extends State<HermesHandoffSheet> {
  late String _selectedAgentId;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    // Default to the backend-suggested agent
    _selectedAgentId = widget.request.suggestedAgentId;
  }

  Future<void> _confirm() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      await widget.provider.confirmHandoff(_selectedAgentId);
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _cancel() async {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    try {
      await widget.provider.cancelHandoff();
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hp = widget.provider;
    final agents = hp.agents;
    final loading = hp.loadingAgents;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withAlpha(100),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.hermesHandoffTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // From → To agent info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _AgentTransition(
              fromName: widget.request.fromAgentName,
              toName: widget.request.suggestedAgentName,
              l10n: l10n,
            ),
          ),
          const SizedBox(height: 8),
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.hermesHandoffDescription,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          // Agent list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  l10n.hermesHandoffChooseAgent,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '${agents.length} ${l10n.hermesHandoffAgentsAvailable}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: loading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : agents.isEmpty
                ? _NoAgentsState(l10n: l10n)
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: agents.length,
                    itemBuilder: (context, index) {
                      final agent = agents[index];
                      final isSelected = agent.id == _selectedAgentId;
                      final isSuggested =
                          agent.id == widget.request.suggestedAgentId;
                      return _AgentTile(
                        agent: agent,
                        isSelected: isSelected,
                        isSuggested: isSuggested,
                        onTap: () {
                          setState(() => _selectedAgentId = agent.id);
                        },
                        l10n: l10n,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          // Actions
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: l10n.hermesHandoffCancel,
                    icon: Icons.close,
                    onTap: _isConfirming ? null : _cancel,
                    isDestructive: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: l10n.hermesHandoffConfirm,
                    icon: Icons.check,
                    onTap: _isConfirming ? null : _confirm,
                    isPrimary: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTransition extends StatelessWidget {
  final String fromName;
  final String toName;
  final AppLocalizations l10n;

  const _AgentTransition({
    required this.fromName,
    required this.toName,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hermesHandoffFrom,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fromName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(
              Icons.arrow_forward,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.hermesHandoffTo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  toName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final HermesAgent agent;
  final bool isSelected;
  final bool isSuggested;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  const _AgentTile({
    required this.agent,
    required this.isSelected,
    required this.isSuggested,
    required this.onTap,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: IosCardPress(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        baseColor: isSelected
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : isSuggested
            ? Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(100),
                width: 1,
              )
            : null,
        child: Row(
          children: [
            // Agent icon
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              backgroundImage: agent.avatarUrl != null
                  ? NetworkImage(agent.avatarUrl!)
                  : null,
              child: agent.avatarUrl == null
                  ? Text(
                      agent.name.isNotEmpty ? agent.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          agent.name,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (agent.isDefault) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'default',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ),
                      ],
                      if (isSuggested) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.hermesHandoffSuggested,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (agent.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      agent.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (agent.capabilities.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: agent.capabilities.take(3).map((cap) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cap,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _NoAgentsState extends StatelessWidget {
  final AppLocalizations l10n;

  const _NoAgentsState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.hermesHandoffNoAgents,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return IosCardPress(
      onTap: onTap ?? () {},
      padding: const EdgeInsets.symmetric(vertical: 14),
      baseColor: isPrimary
          ? Theme.of(context).colorScheme.primary
          : isDestructive
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 18,
            color: !isEnabled
                ? Theme.of(context).disabledColor
                : isPrimary
                ? Theme.of(context).colorScheme.onPrimary
                : isDestructive
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: !isEnabled
                  ? Theme.of(context).disabledColor
                  : isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/hermes_gateway_provider.dart';
import '../../hermes/hermes_rpc.dart';
import '../../hermes/hermes_usage.dart';
import '../../shared/widgets/ios_tactile.dart';
import '../../l10n/app_localizations.dart';

/// Lists all Hermes backend sessions with search, resume, and delete.
class HermesSessionListPage extends StatefulWidget {
  const HermesSessionListPage({super.key});

  @override
  State<HermesSessionListPage> createState() => _HermesSessionListPageState();
}

class _HermesSessionListPageState extends State<HermesSessionListPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  List<HermesSessionSummary> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final hp = context.read<HermesGatewayProvider>();
    await hp.loadSessions();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });
    final hp = context.read<HermesGatewayProvider>();
    final results = await hp.searchSessions(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hermesSessionListTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSessions,
            tooltip: l10n.hermesSessionListRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.hermesSessionListSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: _onSearch,
              onChanged: (v) => _onSearch(v),
            ),
          ),
          // Session list
          Expanded(
            child: Consumer<HermesGatewayProvider>(
              builder: (context, hp, _) {
                if (_searchQuery.isNotEmpty) {
                  return _buildSessionList(
                    context,
                    hp,
                    _searchResults,
                    l10n,
                    isSearchResult: true,
                  );
                }
                if (hp.loadingSessions) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (hp.sessionsError != null) {
                  return _ErrorState(
                    error: hp.sessionsError!,
                    l10n: l10n,
                    onRetry: _loadSessions,
                  );
                }
                if (hp.sessions.isEmpty) {
                  return _EmptyState(l10n: l10n);
                }
                return _buildSessionList(context, hp, hp.sessions, l10n);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(
    BuildContext context,
    HermesGatewayProvider hp,
    List<HermesSessionSummary> sessions,
    AppLocalizations l10n, {
    bool isSearchResult = false,
  }) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              isSearchResult
                  ? l10n.hermesSessionListNoResults
                  : l10n.hermesSessionListEmpty,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        final isActive = hp.activeSessionId == session.sessionId;
        return _SessionTile(
          session: session,
          isActive: isActive,
          onTap: () => _showSessionDetail(context, hp, session),
          onResume: () => _resumeSession(context, hp, session),
          onDelete: () => _confirmDelete(context, hp, session, l10n),
          onRename: () => _showRenameDialog(context, hp, session, l10n),
          l10n: l10n,
        );
      },
    );
  }

  Future<void> _resumeSession(
    BuildContext context,
    HermesGatewayProvider hp,
    HermesSessionSummary session,
  ) async {
    await hp.resumeSession(session.sessionId);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showSessionDetail(
    BuildContext context,
    HermesGatewayProvider hp,
    HermesSessionSummary session,
  ) async {
    final usage = await hp.fetchSessionUsage(session.sessionId);
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => HermesSessionDetailSheet(
          session: session,
          usage: usage,
          onResume: () => _resumeSession(context, hp, session),
          onDelete: () {
            Navigator.of(context).pop();
            _confirmDelete(context, hp, session, AppLocalizations.of(context)!);
          },
          onRename: () {
            Navigator.of(context).pop();
            _showRenameDialog(
              context,
              hp,
              session,
              AppLocalizations.of(context)!,
            );
          },
        ),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    HermesGatewayProvider hp,
    HermesSessionSummary session,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.hermesSessionDeleteTitle),
        content: Text(
          l10n.hermesSessionDeleteConfirm(session.title ?? session.sessionId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.addBackendCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await hp.deleteSession(session.sessionId);
            },
            child: Text(
              l10n.hermesSessionDelete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    HermesGatewayProvider hp,
    HermesSessionSummary session,
    AppLocalizations l10n,
  ) {
    final controller = TextEditingController(text: session.title ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.hermesSessionRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.hermesSessionRenameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.addBackendCancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await hp.renameSession(session.sessionId, controller.text.trim());
            },
            child: Text(l10n.hermesSessionRenameConfirm),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final HermesSessionSummary session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onRename;
  final AppLocalizations l10n;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onResume,
    required this.onDelete,
    required this.onRename,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosCardPress(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        baseColor: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    session.title ?? l10n.hermesSessionUntitled,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.agentName != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      session.agentName!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(session.lastActiveAt ?? session.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.chat_bubble_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.hermesSessionMessageCount(session.messageCount),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

/// Bottom sheet showing session detail + usage stats.
class HermesSessionDetailSheet extends StatelessWidget {
  final HermesSessionSummary session;
  final HermesUsage? usage;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const HermesSessionDetailSheet({
    super.key,
    required this.session,
    this.usage,
    required this.onResume,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
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
          Text(
            session.title ?? l10n.hermesSessionUntitled,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (session.agentName != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.hermesSessionAgent}: ${session.agentName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Usage stats
          if (usage != null)
            _UsageStats(usage: usage!, l10n: l10n)
          else if (usage == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.hermesSessionUsageUnavailable,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _ActionButton(
                  label: l10n.hermesSessionResume,
                  icon: Icons.play_arrow,
                  onTap: () {
                    Navigator.of(context).pop();
                    onResume();
                  },
                  isPrimary: true,
                ),
                _ActionButton(
                  label: l10n.hermesSessionRename,
                  icon: Icons.edit_outlined,
                  onTap: () {
                    Navigator.of(context).pop();
                    onRename();
                  },
                ),
                _ActionButton(
                  label: l10n.hermesSessionDelete,
                  icon: Icons.delete_outline,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }
}

class _UsageStats extends StatelessWidget {
  final HermesUsage usage;
  final AppLocalizations l10n;

  const _UsageStats({required this.usage, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.hermesSessionUsage,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _UsageStatItem(
                    label: l10n.hermesSessionUsageInputTokens,
                    value: HermesUsage.formatTokens(usage.inputTokens),
                  ),
                ),
                Expanded(
                  child: _UsageStatItem(
                    label: l10n.hermesSessionUsageOutputTokens,
                    value: HermesUsage.formatTokens(usage.outputTokens),
                  ),
                ),
                Expanded(
                  child: _UsageStatItem(
                    label: l10n.hermesSessionUsageTotalTokens,
                    value: HermesUsage.formatTokens(usage.totalTokens),
                  ),
                ),
              ],
            ),
            if (usage.creditsUsed != null ||
                usage.remainingCredits != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (usage.creditsUsed != null)
                    Expanded(
                      child: _UsageStatItem(
                        label: l10n.hermesSessionUsageCreditsUsed,
                        value: usage.formattedCreditsUsed,
                      ),
                    ),
                  if (usage.remainingCredits != null)
                    Expanded(
                      child: _UsageStatItem(
                        label: l10n.hermesSessionUsageCreditsRemaining,
                        value: usage.formattedCredits,
                      ),
                    ),
                  if (usage.costUsd != null)
                    Expanded(
                      child: _UsageStatItem(
                        label: l10n.hermesSessionUsageCost,
                        value: usage.formattedCost,
                      ),
                    ),
                ],
              ),
            ],
            if (usage.model != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.model_training,
                    size: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    usage.model!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${usage.turnCount} ${l10n.hermesSessionUsageTurns}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageStatItem extends StatelessWidget {
  final String label;
  final String value;

  const _UsageStatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDestructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IosCardPress(
        onTap: onTap,
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
              color: isPrimary
                  ? Theme.of(context).colorScheme.onPrimary
                  : isDestructive
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary
                    ? Theme.of(context).colorScheme.onPrimary
                    : isDestructive
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.hermesSessionListEmpty,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.hermesSessionListEmptyHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.l10n,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.hermesSessionListError,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            IosCardPress(
              onTap: onRetry,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              baseColor: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              child: Text(
                l10n.hermesSessionListRetry,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

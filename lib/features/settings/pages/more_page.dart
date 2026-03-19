import 'package:flutter/material.dart';
import '../../../utils/url_launcher_ext.dart';
import '../../../shared/widgets/favicon.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget title(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(color: cs.primary),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        // Page intentionally has no title for now
        title: null,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LeaderBoard section
              title('LLM排行榜'),
              Row(
                children: const [
                  Expanded(
                    child: LeaderBoardItem(
                      url: 'https://lmarena.ai/leaderboard',
                      name: 'LMArena',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: LeaderBoardItem(
                      url: 'https://livebench.ai/#/',
                      name: 'LiveBench',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderBoardItem extends StatelessWidget {
  const LeaderBoardItem({super.key, required this.url, required this.name});

  final String url;
  final String name;

  String _hostOf(String url) {
    try {
      final u = Uri.parse(url);
      return u.host.isNotEmpty ? u.host : url;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.openUrl(url),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Favicon(url: url, size: 20),
                const SizedBox(height: 4),
                Text(name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  _hostOf(url),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.labelSmall?.color?.withValues(
                      alpha: 0.75,
                    ),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

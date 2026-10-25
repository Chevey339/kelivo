import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../../core/services/browser/browser_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/browser_models.dart';
import '../pages/browser_bookmark_editor.dart';
import '../pages/browser_management_page.dart';
import 'browser_controls.dart';
import 'browser_favicon.dart';
import 'browser_surface_controls.dart';

// All mutations come from the shared service, so pages opened by the agent and
// user appear in the same history and bookmark lists.
enum BrowserLibrarySection { bookmarks, history, downloads }

class BrowserLibrary extends StatefulWidget {
  const BrowserLibrary({
    super.key,
    required this.service,
    required this.section,
    required this.onOpen,
    required this.onError,
    this.scrollController,
    this.mobileManagement = false,
  });

  final BrowserService service;
  final BrowserLibrarySection section;
  final ValueChanged<String> onOpen;
  final ValueChanged<Object> onError;
  final ScrollController? scrollController;

  /// Own the mobile page/header; desktop dialogs retain their inline toolbar.
  final bool mobileManagement;

  @override
  State<BrowserLibrary> createState() => _BrowserLibraryState();
}

class _BrowserLibraryState extends State<BrowserLibrary> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  String _query = '';
  bool _searching = false;

  ScrollController get _controller => widget.scrollController ?? _scroll;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      widget.onError(error);
    }
  }

  void _toggleSearch() {
    if (_searching) {
      _searchFocus.unfocus();
      _search.clear();
      setState(() {
        _query = '';
        _searching = false;
      });
    } else {
      if (_controller.hasClients) _controller.jumpTo(0);
      setState(() => _searching = true);
      _searchFocus.requestFocus();
    }
  }

  void _clearHistory(BuildContext context) => _run(() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await confirmBrowserAction(
      context,
      l.browserClearHistoryConfirm,
      l.browserClearHistory,
    );
    if (confirmed) await widget.service.clearHistory();
  });

  @override
  Widget build(
    BuildContext context,
  ) => ListenableProvider<BrowserService>.value(
    value: widget.service,
    child: Selector<BrowserService, List<Object>>(
      // Service collections are immutable snapshots. Provider compares their
      // contents, so page progress and favicon updates don't rebuild this page.
      selector: (_, service) => switch (widget.section) {
        BrowserLibrarySection.bookmarks => service.bookmarks,
        BrowserLibrarySection.history => service.history,
        BrowserLibrarySection.downloads => service.downloads,
      },
      builder: (context, entries, _) {
        if (!widget.mobileManagement) return _content(context);
        final l = AppLocalizations.of(context)!;
        final emptyHistory = entries.isEmpty;
        return BrowserManagementPage(
          title: switch (widget.section) {
            BrowserLibrarySection.bookmarks => l.browserBookmarks,
            BrowserLibrarySection.history => l.browserHistory,
            BrowserLibrarySection.downloads => l.browserDownloads,
          },
          trailingWidth: widget.section == BrowserLibrarySection.history
              ? 96
              : 48,
          trailing: Builder(
            builder: (actionContext) {
              final grouped = widget.section == BrowserLibrarySection.history;
              final search = BrowserSurfaceIconButton(
                key: const ValueKey('browserLibrarySearchAction'),
                surface: !grouped,
                useParentFeedback: grouped,
                label: _searching ? l.browserCancel : l.browserSearchLibrary,
                icon: _searching ? LucideIcons.x : LucideIcons.search,
                size: 48,
                iconSize: 23,
                onPressed: _toggleSearch,
              );
              if (!grouped) return search;
              return BrowserSurfaceIconGroup(
                key: const ValueKey('browserLibraryHistoryActions'),
                children: [
                  search,
                  BrowserSurfaceIconButton(
                    key: const ValueKey('browserLibraryClearHistoryAction'),
                    useParentFeedback: true,
                    label: l.browserClearHistory,
                    icon: LucideIcons.trash2,
                    size: 48,
                    iconSize: 23,
                    foregroundColor: Theme.of(actionContext).colorScheme.error
                        .withValues(alpha: emptyHistory ? .35 : 1),
                    onPressed: emptyHistory
                        ? null
                        : () => _clearHistory(actionContext),
                  ),
                ],
              );
            },
          ),
          child: Builder(builder: _content),
        );
      },
    ),
  );

  Widget _content(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final insets = BrowserManagementPage.contentInsetsOf(context);
    final showSearch = !widget.mobileManagement || _searching;
    return CustomScrollView(
      controller: _controller,
      slivers: [
        if (showSearch)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              18 + insets.left,
              insets.top,
              18 + insets.right,
              14,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: BrowserSurfaceField(
                      controller: _search,
                      focusNode: _searchFocus,
                      autofocus: widget.mobileManagement,
                      hintText: l.browserSearchLibrary,
                      prefixIcon: LucideIcons.search,
                      onChanged: (value) =>
                          setState(() => _query = value.toLowerCase()),
                    ),
                  ),
                  if (!widget.mobileManagement &&
                      widget.section == BrowserLibrarySection.history &&
                      widget.service.history.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    BrowserSurfaceIconButton(
                      label: l.browserClearHistory,
                      icon: LucideIcons.trash2,
                      size: 44,
                      iconSize: 20,
                      foregroundColor: Theme.of(context).colorScheme.error,
                      onPressed: () => _clearHistory(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            12 + insets.left,
            4 + (showSearch ? 0 : insets.top),
            12 + insets.right,
            20 + insets.bottom,
          ),
          sliver: switch (widget.section) {
            BrowserLibrarySection.bookmarks => _bookmarks(context),
            BrowserLibrarySection.history => _history(context),
            BrowserLibrarySection.downloads => _downloads(context),
          },
        ),
      ],
    );
  }

  bool _matches(String title, String url) =>
      '$title $url'.toLowerCase().contains(_query);

  Widget _bookmarks(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = widget.service.bookmarks
        .where((item) => _matches(item.title, item.url))
        .toList();
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: BrowserEmptyState(
          icon: LucideIcons.bookmark,
          title: l.browserNoBookmarks,
        ),
      );
    }
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _SavedPageRow(
          service: widget.service,
          title: item.title,
          url: item.url,
          onOpen: () => widget.onOpen(item.url),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrowserSurfaceIconButton(
                label: l.browserEditBookmark,
                icon: LucideIcons.pencil,
                onPressed: () => _editBookmark(item),
              ),
              BrowserSurfaceIconButton(
                label: l.browserDelete,
                icon: LucideIcons.trash2,
                onPressed: () =>
                    _run(() => widget.service.removeBookmark(item.url)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editBookmark(BrowserBookmark bookmark) async {
    final replacement = await showBrowserBookmarkEditor(
      context,
      bookmark: bookmark,
      favicon: Center(
        child: BrowserFavicon(
          url: bookmark.url,
          service: widget.service,
          size: 32,
        ),
      ),
    );
    if (replacement == null) return;
    await _run(() async {
      // Persist first, so a failed write cannot lose the old bookmark.
      await widget.service.addBookmark(
        url: replacement.url,
        title: replacement.title,
      );
      if (replacement.url != bookmark.url) {
        await widget.service.removeBookmark(bookmark.url);
      }
    });
  }

  Widget _history(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = widget.service.history
        .where((item) => _matches(item.title, item.url))
        .toList();
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: BrowserEmptyState(
          icon: LucideIcons.history,
          title: l.browserNoHistory,
        ),
      );
    }
    final today = DateUtils.dateOnly(DateTime.now());
    String heading(DateTime visitedAt) {
      final day = DateUtils.dateOnly(visitedAt.toLocal());
      if (day == today) return l.browserToday;
      if (day == today.subtract(const Duration(days: 1))) {
        return l.browserYesterday;
      }
      return DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(day);
    }

    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final group = heading(item.visitedAt);
        final showHeading =
            index == 0 || heading(items[index - 1].visitedAt) != group;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeading)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Text(
                  group,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _SavedPageRow(
              service: widget.service,
              title: item.title,
              url: item.url,
              onOpen: () => widget.onOpen(item.url),
              trailing: BrowserSurfaceIconButton(
                label: l.browserDelete,
                icon: LucideIcons.x,
                onPressed: () =>
                    _run(() => widget.service.removeHistory(item.url)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _downloads(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final items = widget.service.downloads
        .where((item) => _matches(item.fileName, item.url))
        .toList();
    if (items.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: BrowserEmptyState(
          icon: LucideIcons.download,
          title: l.browserNoDownloads,
        ),
      );
    }
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final downloading = item.status == BrowserDownloadStatus.downloading;
        final completed = item.status == BrowserDownloadStatus.completed;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BrowserSurfaceGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      completed ? LucideIcons.fileCheck : LucideIcons.fileDown,
                      size: 24,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            switch (item.status) {
                              BrowserDownloadStatus.failed =>
                                l.browserDownloadFailed,
                              BrowserDownloadStatus.cancelled =>
                                l.browserDownloadCancelled,
                              _ => _bytes(item.receivedBytes),
                            },
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (downloading) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              minHeight: 2,
                              value: item.totalBytes > 0
                                  ? item.receivedBytes / item.totalBytes
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (completed && item.path != null)
                      BrowserSurfaceIconButton(
                        label: l.browserOpenDownload,
                        icon: LucideIcons.externalLink,
                        onPressed: () => _run(() async {
                          final result = await OpenFilex.open(item.path!);
                          if (result.type != ResultType.done) {
                            throw StateError(result.message);
                          }
                        }),
                      ),
                    BrowserSurfaceIconButton(
                      label: downloading ? l.browserCancel : l.browserDelete,
                      icon: downloading ? LucideIcons.x : LucideIcons.trash2,
                      onPressed: () => _run(() async {
                        if (downloading) {
                          widget.service.cancelDownload(item.id);
                        } else {
                          await widget.service.removeDownload(item.id);
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _SavedPageRow extends StatelessWidget {
  const _SavedPageRow({
    required this.service,
    required this.title,
    required this.url,
    required this.onOpen,
    required this.trailing,
  });

  final String title;
  final BrowserService service;
  final String url;
  final VoidCallback onOpen;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BrowserSurfaceButton(
          radius: 20,
          onPressed: onOpen,
          semanticLabel: title.isEmpty ? browserDisplayUrl(url) : title,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 13, 4, 13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: .045),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: BrowserFavicon(url: url, service: service, size: 26),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? browserDisplayUrl(url) : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        browserDisplayUrl(url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String browserDisplayUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  return '${uri.host}${uri.path == '/' ? '' : uri.path}';
}

Future<bool> confirmBrowserAction(
  BuildContext context,
  String message,
  String confirmLabel,
) async {
  return await showBrowserDialog<bool>(
        context,
        maxWidth: 400,
        child: Builder(
          builder: (dialogContext) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    BrowserTextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(AppLocalizations.of(context)!.browserCancel),
                    ),
                    BrowserTextButton(
                      destructive: true,
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

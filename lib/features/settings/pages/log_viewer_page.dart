import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../utils/app_directories.dart';
import '../../../core/providers/settings_provider.dart';
import '../logs/request_log_parser.dart';

/// Mobile log viewer - shows list of log files and allows viewing/exporting
class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage>
    with SingleTickerProviderStateMixin {
  static const String _activeRequestLog = 'logs.txt';
  static const String _activeAppLog = 'flutter_logs.txt';

  late final TabController _tab;

  List<File> _requestLogFiles = <File>[];
  List<File> _appLogFiles = <File>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadLogFiles();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _loading = true);
    try {
      final dir = await AppDirectories.getAppDataDirectory();
      final logsDir = Directory('${dir.path}/logs');
      if (await logsDir.exists()) {
        final all = await logsDir
            .list()
            .where((e) => e is File && e.path.toLowerCase().endsWith('.txt'))
            .cast<File>()
            .toList();

        final request = <File>[];
        final app = <File>[];
        for (final f in all) {
          final name = f.path.split('/').last.toLowerCase();
          if (name.startsWith('flutter_logs')) {
            app.add(f);
          } else if (name.startsWith('logs')) {
            request.add(f);
          } else {
            // Keep "other" logs in the simpler viewer.
            app.add(f);
          }
        }

        void sortByMtimeDesc(List<File> files) {
          files.sort((a, b) {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.modified.compareTo(aStat.modified);
          });
        }

        sortByMtimeDesc(request);
        sortByMtimeDesc(app);

        setState(() {
          _requestLogFiles = request;
          _appLogFiles = app;
          _loading = false;
        });
      } else {
        setState(() {
          _requestLogFiles = <File>[];
          _appLogFiles = <File>[];
          _loading = false;
        });
      }
    } catch (_) {
      setState(() {
        _requestLogFiles = <File>[];
        _appLogFiles = <File>[];
        _loading = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showLogSettings(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogSettingsSheet(onChanged: _loadLogFiles),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);

    String appTabLabel() {
      if (locale.languageCode.toLowerCase() == 'zh') {
        return l10n.flutterLogSettingTitle.replaceAll(RegExp(r'(打印|列印)$'), '');
      }
      return l10n.storageSpaceSubLogsFlutter;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.storageSpaceCategoryLogs),
        actions: [
          IconButton(
            icon: Icon(Lucide.RefreshCw, color: cs.onSurface, size: 20),
            onPressed: _loadLogFiles,
          ),
          IconButton(
            icon: Icon(Lucide.Settings, color: cs.onSurface, size: 20),
            tooltip: l10n.logSettingsTitle,
            onPressed: () => _showLogSettings(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: _SegTabBar(
                    controller: _tab,
                    tabs: [l10n.logViewerTitle, appTabLabel()],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _LogFilesList(
                        files: _requestLogFiles,
                        activeFileName: _activeRequestLog,
                        emptyIcon: Lucide.Globe,
                        emptyText: l10n.logViewerEmpty,
                        formatFileSize: _formatFileSize,
                        formatDate: _formatDate,
                        onOpenFile: (file, title) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  _RequestLogFilePage(file: file, title: title),
                            ),
                          );
                        },
                      ),
                      _LogFilesList(
                        files: _appLogFiles,
                        activeFileName: _activeAppLog,
                        emptyIcon: Lucide.Terminal,
                        emptyText: l10n.logViewerEmpty,
                        formatFileSize: _formatFileSize,
                        formatDate: _formatDate,
                        onOpenFile: (file, title) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _PlainLogContentPage(
                                file: file,
                                title: title,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LogFilesList extends StatelessWidget {
  const _LogFilesList({
    required this.files,
    required this.activeFileName,
    required this.emptyIcon,
    required this.emptyText,
    required this.formatFileSize,
    required this.formatDate,
    required this.onOpenFile,
  });

  final List<File> files;
  final String activeFileName;
  final IconData emptyIcon;
  final String emptyText;
  final String Function(int bytes) formatFileSize;
  final String Function(DateTime dt) formatDate;
  final void Function(File file, String title) onOpenFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emptyIcon,
              size: 46,
              color: cs.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 14),
            Text(
              emptyText,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final Color tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color border = cs.outlineVariant.withValues(
      alpha: isDark ? 0.26 : 0.38,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final stat = file.statSync();
        final fileName = file.path.split('/').last;
        final isCurrentLog =
            fileName.toLowerCase() == activeFileName.toLowerCase();

        final title = isCurrentLog ? l10n.logViewerCurrentLog : fileName;
        final subtitle =
            '${formatFileSize(stat.size)} · ${formatDate(stat.modified)}';

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IosCardPress(
            baseColor: tileBg,
            borderRadius: BorderRadius.circular(16),
            onTap: () => onOpenFile(file, title),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _FileIcon(
                    isCurrent: isCurrentLog,
                    icon: isCurrentLog ? Lucide.FileText : Lucide.FileClock,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrentLog
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.92),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.58),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Lucide.ChevronRight,
                    color: cs.onSurface.withValues(alpha: 0.30),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.isCurrent, required this.icon});
  final bool isCurrent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isCurrent
        ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.14)
        : (isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFF2F3F5));
    final Color fg = isCurrent
        ? cs.primary
        : cs.onSurface.withValues(alpha: 0.72);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

/// Page to view plain-text log file content with export option.
class _PlainLogContentPage extends StatefulWidget {
  const _PlainLogContentPage({required this.file, required this.title});
  final File file;
  final String title;

  @override
  State<_PlainLogContentPage> createState() => _PlainLogContentPageState();
}

class _PlainLogContentPageState extends State<_PlainLogContentPage> {
  String _content = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);
    try {
      final content = await widget.file.readAsString();
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _content = 'Error loading file: $e';
        _loading = false;
      });
    }
  }

  Future<void> _exportFile() async {
    try {
      await Share.shareXFiles([
        XFile(widget.file.path),
      ], subject: widget.file.path.split('/').last);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Export failed: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Lucide.Share2, color: cs.onSurface, size: 20),
            tooltip: l10n.logViewerExport,
            onPressed: _exportFile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _content.isEmpty
          ? Center(
              child: Text(
                l10n.logViewerEmpty,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                _content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
    );
  }
}

class _RequestLogFilePage extends StatefulWidget {
  const _RequestLogFilePage({required this.file, required this.title});

  final File file;
  final String title;

  @override
  State<_RequestLogFilePage> createState() => _RequestLogFilePageState();
}

class _RequestLogFilePageState extends State<_RequestLogFilePage> {
  bool _loading = true;
  List<RequestLogEntry> _requests = const <RequestLogEntry>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final content = await widget.file.readAsString();
      final entries = RequestLogParser.parse(content);
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = const <RequestLogEntry>[];
        _loading = false;
      });
    }
  }

  Future<void> _exportFile() async {
    try {
      await Share.shareXFiles([
        XFile(widget.file.path),
      ], subject: widget.file.path.split('/').last);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: 'Export failed: $e',
        type: NotificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final int errorCount = _requests.where((e) => e.hasError).length;
    final int warnCount = _requests.where((e) => e.hasWarning).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Lucide.RefreshCw, color: cs.onSurface, size: 20),
            onPressed: _load,
          ),
          IconButton(
            icon: Icon(Lucide.Share2, color: cs.onSurface, size: 20),
            tooltip: l10n.logViewerExport,
            onPressed: _exportFile,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Lucide.FileQuestion,
                    size: 46,
                    color: cs.onSurface.withValues(alpha: 0.28),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.logViewerEmpty,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              itemCount: _requests.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RequestLogSummaryBar(
                      total: _requests.length,
                      errors: errorCount,
                      warnings: warnCount,
                    ),
                  );
                }
                final e = _requests[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestLogCard(
                    entry: e,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _RequestLogDetailPage(entry: e),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _RequestLogSummaryBar extends StatelessWidget {
  const _RequestLogSummaryBar({
    required this.total,
    required this.errors,
    required this.warnings,
  });

  final int total;
  final int errors;
  final int warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final Color bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color border = cs.outlineVariant.withValues(
      alpha: isDark ? 0.26 : 0.38,
    );

    final Color errorPillBg = Color.alphaBlend(
      cs.error.withValues(alpha: isDark ? 0.18 : 0.12),
      isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
    );
    final Color errorPillFg = cs.error.withValues(alpha: isDark ? 0.92 : 0.88);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.logViewerRequestsCount(total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.90),
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (warnings > 0) ...[
            _CountPill(
              icon: Lucide.BadgeInfo,
              label: '$warnings',
              bg: cs.tertiaryContainer.withValues(alpha: isDark ? 0.50 : 0.55),
              fg: cs.onTertiaryContainer.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 8),
          ],
          if (errors > 0)
            _CountPill(
              icon: Lucide.XCircle,
              label: '$errors',
              bg: errorPillBg,
              fg: errorPillFg,
            ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: fg,
              fontSize: 12,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestLogCard extends StatelessWidget {
  const _RequestLogCard({required this.entry, required this.onTap});

  final RequestLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color border = cs.outlineVariant.withValues(
      alpha: isDark ? 0.26 : 0.38,
    );

    final status = entry.statusCode;
    final bool hasError = entry.hasError;

    final Uri? uri = entry.uri;
    final String title = () {
      if (uri == null) {
        return (entry.rawUrl ?? '').trim();
      }
      final path = (uri.path.isEmpty ? '/' : uri.path);
      if (uri.query.isEmpty) {
        return path;
      }
      return '$path?${uri.query}';
    }();

    final String subtitle = () {
      final parts = <String>[];
      if (uri?.host != null && (uri?.host ?? '').isNotEmpty) {
        parts.add(uri!.host);
      }
      final ts = entry.startedAt;
      if (ts != null) {
        parts.add(_fmtTime(ts));
      }
      final d = entry.duration;
      if (d != null) {
        parts.add(_fmtDuration(d));
      }
      return parts.join(' · ');
    }();

    return IosCardPress(
      baseColor: tileBg,
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MethodPill(method: (entry.method ?? '—').toUpperCase()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface.withValues(alpha: 0.92),
                      letterSpacing: -0.2,
                      height: 1.18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: status, isError: hasError),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.60),
              ),
            ),
            if (hasError && entry.errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InlineErrorPreview(text: entry.errors.first),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineErrorPreview extends StatelessWidget {
  const _InlineErrorPreview({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color base = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF6F7F9);
    final Color bg = Color.alphaBlend(
      cs.error.withValues(alpha: isDark ? 0.12 : 0.07),
      base,
    );
    final Color border = cs.error.withValues(alpha: isDark ? 0.32 : 0.22);
    final Color iconColor = cs.error.withValues(alpha: isDark ? 0.92 : 0.86);
    final Color textColor = cs.onSurface.withValues(alpha: 0.86);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Icon(Lucide.XCircle, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodPill extends StatelessWidget {
  const _MethodPill({required this.method});
  final String method;

  Color _bg(ColorScheme cs, bool isDark) {
    switch (method) {
      case 'GET':
        return const Color(0xFF10B981).withValues(alpha: isDark ? 0.22 : 0.16);
      case 'POST':
        return const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.22 : 0.16);
      case 'PUT':
      case 'PATCH':
        return const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.22 : 0.16);
      case 'DELETE':
        return cs.error.withValues(alpha: isDark ? 0.22 : 0.14);
      default:
        return cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.06);
    }
  }

  Color _fg(ColorScheme cs, bool isDark) {
    switch (method) {
      case 'GET':
        return const Color(0xFF10B981);
      case 'POST':
        return const Color(0xFF3B82F6);
      case 'PUT':
      case 'PATCH':
        return const Color(0xFFF59E0B);
      case 'DELETE':
        return cs.error;
      default:
        return cs.onSurface.withValues(alpha: isDark ? 0.80 : 0.72);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(cs, isDark),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
          color: _fg(cs, isDark),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isError});
  final int? status;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final int code = status ?? 0;
    final bool ok = (code >= 200 && code < 300) && !isError;
    final bool warn = (code >= 300 && code < 400) && !isError;

    final Color bg = () {
      if (isError || code >= 400) {
        final Color base = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white;
        return Color.alphaBlend(
          cs.error.withValues(alpha: isDark ? 0.18 : 0.12),
          base,
        );
      }
      if (ok) {
        return const Color(0xFF10B981).withValues(alpha: isDark ? 0.26 : 0.18);
      }
      if (warn) {
        return cs.tertiaryContainer.withValues(alpha: isDark ? 0.50 : 0.55);
      }
      return cs.onSurface.withValues(alpha: isDark ? 0.12 : 0.06);
    }();

    final Color fg = () {
      if (isError || code >= 400) {
        return cs.error.withValues(alpha: isDark ? 0.92 : 0.88);
      }
      if (ok) {
        return const Color(0xFF10B981);
      }
      if (warn) {
        return cs.onTertiaryContainer.withValues(alpha: 0.92);
      }
      return cs.onSurface.withValues(alpha: isDark ? 0.78 : 0.72);
    }();

    final String text = status == null ? '—' : '$status';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isError || code >= 400) ...[
            Icon(Lucide.XCircle, size: 14, color: fg),
            const SizedBox(width: 6),
          ] else if (ok) ...[
            Icon(Lucide.CheckCircle, size: 14, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtTime(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

String _fmtTimestamp(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  String three(int v) => v.toString().padLeft(3, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}.${three(dt.millisecond)}';
}

String _fmtDuration(Duration d) {
  if (d.inMilliseconds < 1000) {
    return '${d.inMilliseconds}ms';
  }
  if (d.inSeconds < 60) {
    return '${d.inSeconds}s';
  }
  final m = d.inMinutes;
  final s = d.inSeconds - m * 60;
  return '${m}m ${s}s';
}

class _RequestLogDetailPage extends StatelessWidget {
  const _RequestLogDetailPage({required this.entry});

  final RequestLogEntry entry;

  String _prettyJson(String text) {
    final v = text.trim();
    if (v.isEmpty) {
      return '';
    }
    try {
      final obj = jsonDecode(v);
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return text;
    }
  }

  String _prettyJsonObj(Object? obj) {
    if (obj == null) {
      return '';
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj.toString();
    }
  }

  Future<void> _copy(BuildContext context, String text) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!context.mounted) {
        return;
      }
      showAppSnackBar(
        context,
        message: l10n.chatMessageWidgetCopiedToClipboard,
        type: NotificationType.success,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final uri = entry.uri;
    final url = uri?.toString() ?? (entry.rawUrl ?? '');

    final baseItems = <_Kv>[
      _Kv(l10n.logViewerFieldId, '${entry.id}'),
      _Kv(l10n.logViewerFieldMethod, (entry.method ?? '—').toUpperCase()),
      _Kv(
        l10n.logViewerFieldStatus,
        entry.statusCode == null ? '—' : '${entry.statusCode}',
      ),
      _Kv(
        l10n.logViewerFieldStarted,
        entry.startedAt == null ? '—' : _fmtTimestamp(entry.startedAt!),
      ),
      _Kv(
        l10n.logViewerFieldEnded,
        entry.lastEventAt == null ? '—' : _fmtTimestamp(entry.lastEventAt!),
      ),
      _Kv(
        l10n.logViewerFieldDuration,
        entry.duration == null ? '—' : _fmtDuration(entry.duration!),
      ),
    ];

    final query = uri?.queryParameters ?? const <String, String>{};
    final reqHeaders = entry.requestHeaders;
    final resHeaders = entry.responseHeaders;
    final reqHeadersText = _prettyJsonObj(reqHeaders);
    final resHeadersText = _prettyJsonObj(resHeaders);
    final reqBodyText = entry.requestBody == null
        ? ''
        : _prettyJson(entry.requestBody!);
    final resBodyText = entry.responseBody == null
        ? ''
        : _prettyJson(entry.responseBody!);

    final errorLines = entry.errors.isNotEmpty
        ? entry.errors
        : ((entry.statusCode != null && entry.statusCode! >= 400)
              ? <String>['HTTP ${entry.statusCode}']
              : const <String>[]);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Lucide.ArrowLeft, color: cs.onSurface, size: 22),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          '${(entry.method ?? 'REQ').toUpperCase()} · ${entry.statusCode ?? '—'}',
        ),
        actions: [
          IconButton(
            icon: Icon(Lucide.Copy, color: cs.onSurface, size: 20),
            tooltip: MaterialLocalizations.of(context).copyButtonLabel,
            onPressed: url.trim().isEmpty ? null : () => _copy(context, url),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          if (errorLines.isNotEmpty) ...[
            _ErrorHeroCard(errors: errorLines),
            const SizedBox(height: 12),
          ],
          _SectionCard(
            icon: Lucide.BadgeInfo,
            title: l10n.logViewerSectionSummary,
            trailing: url.trim().isEmpty
                ? null
                : IosIconButton(
                    icon: Lucide.Copy,
                    size: 18,
                    padding: const EdgeInsets.all(6),
                    onTap: () => _copy(context, url),
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CodeBlock(text: url, tone: _CodeTone.neutral),
                const SizedBox(height: 12),
                _KvGrid(items: baseItems),
              ],
            ),
          ),
          if (query.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.ListTree,
              title: l10n.logViewerSectionParameters,
              trailing: IosIconButton(
                icon: Lucide.Copy,
                size: 18,
                padding: const EdgeInsets.all(6),
                onTap: () => _copy(context, _prettyJsonObj(query)),
              ),
              child: _CodeBlock(
                text: _prettyJsonObj(query),
                tone: _CodeTone.neutral,
              ),
            ),
          ],
          if (reqHeaders != null && reqHeaders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.Hash,
              title: l10n.logViewerSectionRequestHeaders,
              trailing: IosIconButton(
                icon: Lucide.Copy,
                size: 18,
                padding: const EdgeInsets.all(6),
                onTap: () => _copy(context, reqHeadersText),
              ),
              child: _CodeBlock(text: reqHeadersText, tone: _CodeTone.neutral),
            ),
          ],
          if (reqBodyText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.ArrowUp,
              title: l10n.logViewerSectionRequestBody,
              trailing: IosIconButton(
                icon: Lucide.Copy,
                size: 18,
                padding: const EdgeInsets.all(6),
                onTap: () => _copy(context, reqBodyText),
              ),
              child: _CodeBlock(text: reqBodyText, tone: _CodeTone.neutral),
            ),
          ],
          if (resHeaders != null && resHeaders.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.Hash,
              title: l10n.logViewerSectionResponseHeaders,
              trailing: IosIconButton(
                icon: Lucide.Copy,
                size: 18,
                padding: const EdgeInsets.all(6),
                onTap: () => _copy(context, resHeadersText),
              ),
              child: _CodeBlock(text: resHeadersText, tone: _CodeTone.neutral),
            ),
          ],
          if (resBodyText.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.ArrowDown,
              title: l10n.logViewerSectionResponseBody,
              trailing: IosIconButton(
                icon: Lucide.Copy,
                size: 18,
                padding: const EdgeInsets.all(6),
                onTap: () => _copy(context, resBodyText),
              ),
              child: _CodeBlock(
                text: resBodyText,
                tone: entry.hasError ? _CodeTone.error : _CodeTone.neutral,
              ),
            ),
          ],
          if (entry.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              icon: Lucide.BadgeInfo,
              title: l10n.logViewerSectionWarnings,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in entry.warnings) ...[
                    Text(
                      w,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.78),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorHeroCard extends StatelessWidget {
  const _ErrorHeroCard({required this.errors});
  final List<String> errors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    final Color base = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color bg = Color.alphaBlend(
      cs.error.withValues(alpha: isDark ? 0.14 : 0.08),
      base,
    );
    final Color border = cs.error.withValues(alpha: isDark ? 0.34 : 0.22);
    final Color titleColor = cs.error.withValues(alpha: isDark ? 0.92 : 0.88);
    final Color bodyColor = cs.onSurface.withValues(alpha: 0.86);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Lucide.XCircle, size: 18, color: titleColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.logViewerErrorTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final e in errors.take(3)) ...[
            Text(
              e,
              style: TextStyle(
                color: bodyColor,
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (errors.length > 3)
            Text(
              l10n.logViewerMoreCount(errors.length - 3),
              style: TextStyle(
                color: bodyColor.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color bg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color border = cs.outlineVariant.withValues(
      alpha: isDark ? 0.26 : 0.38,
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.78)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface.withValues(alpha: 0.90),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _CodeTone { neutral, error }

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text, required this.tone});

  final String text;
  final _CodeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final Color neutralBg = isDark
        ? Colors.black.withValues(alpha: 0.16)
        : const Color(0xFFF6F7F9);
    final Color bg = () {
      if (tone == _CodeTone.error) {
        return Color.alphaBlend(
          cs.error.withValues(alpha: isDark ? 0.10 : 0.06),
          neutralBg,
        );
      }
      return neutralBg;
    }();
    final Color border = () {
      if (tone == _CodeTone.error) {
        return cs.error.withValues(alpha: isDark ? 0.32 : 0.22);
      }
      return cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.34);
    }();
    final Color fg = cs.onSurface.withValues(alpha: 0.86);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.4,
          color: fg,
        ),
      ),
    );
  }
}

class _Kv {
  _Kv(this.k, this.v);
  final String k;
  final String v;
}

class _KvGrid extends StatelessWidget {
  const _KvGrid({required this.items});
  final List<_Kv> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        for (final it in items) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  it.k,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  it.v,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.86),
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (it != items.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SegTabBar extends StatelessWidget {
  const _SegTabBar({required this.controller, required this.tabs});
  final TabController controller;
  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    const double outerHeight = 44;
    const double innerPadding = 4;
    const double gap = 6;
    const double minSegWidth = 110;
    final double pillRadius = 18;
    final double innerRadius = ((pillRadius - innerPadding).clamp(
      0.0,
      pillRadius,
    )).toDouble();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double availWidth = constraints.maxWidth;
            final double innerAvailWidth = availWidth - innerPadding * 2;
            final double segWidth = math.max(
              minSegWidth,
              (innerAvailWidth - gap * (tabs.length - 1)) / tabs.length,
            );
            final double rowWidth =
                segWidth * tabs.length + gap * (tabs.length - 1);

            final Color shellBg = isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white;

            List<Widget> children = [];
            for (int index = 0; index < tabs.length; index++) {
              final bool selected = controller.index == index;
              children.add(
                SizedBox(
                  width: segWidth,
                  height: double.infinity,
                  child: _TactileRow(
                    onTap: () => controller.animateTo(index),
                    builder: (pressed) {
                      final Color baseBg = selected
                          ? cs.primary.withValues(alpha: 0.14)
                          : Colors.transparent;

                      final Color baseTextColor = selected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.82);
                      final Color targetTextColor = pressed
                          ? Color.lerp(
                                  baseTextColor,
                                  isDark ? Colors.white : Colors.black,
                                  0.12,
                                ) ??
                                baseTextColor
                          : baseTextColor;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: baseBg,
                          borderRadius: BorderRadius.circular(innerRadius),
                        ),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: targetTextColor),
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            builder: (context, color, _) {
                              return Text(
                                tabs[index],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: color ?? baseTextColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.1,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
              if (index != tabs.length - 1) {
                children.add(const SizedBox(width: gap));
              }
            }

            return Container(
              height: outerHeight,
              decoration: BoxDecoration(
                color: shellBg,
                borderRadius: BorderRadius.circular(pillRadius),
              ),
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.all(innerPadding),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: innerAvailWidth),
                    child: SizedBox(
                      width: rowWidth,
                      child: Row(children: children),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({required this.builder, this.onTap});
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  @override
  State<_TactileRow> createState() => _TactileRowState();
}

class _TactileRowState extends State<_TactileRow> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTapCancel: widget.onTap == null ? null : () => _set(false),
      onTap: widget.onTap,
      child: widget.builder(_pressed),
    );
  }
}

class _LogSettingsSheet extends StatelessWidget {
  const _LogSettingsSheet({required this.onChanged});
  final VoidCallback onChanged;

  static const List<int> _autoDeleteOptions = [0, 3, 7, 14, 30];
  static const List<int> _maxSizeOptions = [0, 50, 100, 200, 500];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    final Color tileBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final Color border = cs.outlineVariant.withValues(
      alpha: isDark ? 0.26 : 0.38,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.logSettingsTitle,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Save output toggle
            Container(
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.logSettingsSaveOutput,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.92),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.logSettingsSaveOutputSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IosSwitch(
                    value: settings.logSaveOutput,
                    onChanged: (v) => settings.setLogSaveOutput(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Auto-delete
            _SettingTile(
              tileBg: tileBg,
              border: border,
              title: l10n.logSettingsAutoDelete,
              subtitle: l10n.logSettingsAutoDeleteSubtitle,
              value: settings.logAutoDeleteDays == 0
                  ? l10n.logSettingsAutoDeleteDisabled
                  : l10n.logSettingsAutoDeleteDays(settings.logAutoDeleteDays),
              options: _autoDeleteOptions
                  .map((d) => d == 0
                      ? l10n.logSettingsAutoDeleteDisabled
                      : l10n.logSettingsAutoDeleteDays(d))
                  .toList(),
              selectedIndex: _autoDeleteOptions.indexOf(settings.logAutoDeleteDays).clamp(0, _autoDeleteOptions.length - 1),
              onSelected: (i) {
                settings.setLogAutoDeleteDays(_autoDeleteOptions[i]);
                onChanged();
              },
            ),
            const SizedBox(height: 12),

            // Max size
            _SettingTile(
              tileBg: tileBg,
              border: border,
              title: l10n.logSettingsMaxSize,
              subtitle: l10n.logSettingsMaxSizeSubtitle,
              value: settings.logMaxSizeMB == 0
                  ? l10n.logSettingsMaxSizeUnlimited
                  : '${settings.logMaxSizeMB} MB',
              options: _maxSizeOptions
                  .map((s) =>
                      s == 0 ? l10n.logSettingsMaxSizeUnlimited : '$s MB')
                  .toList(),
              selectedIndex: _maxSizeOptions.indexOf(settings.logMaxSizeMB).clamp(0, _maxSizeOptions.length - 1),
              onSelected: (i) {
                settings.setLogMaxSizeMB(_maxSizeOptions[i]);
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.tileBg,
    required this.border,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  final Color tileBg;
  final Color border;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final int selectedIndex;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.92),
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(options.length, (i) {
                final bool selected = i == selectedIndex;
                return GestureDetector(
                  onTap: () => onSelected(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? cs.primary.withValues(alpha: isDark ? 0.22 : 0.14)
                          : cs.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: selected
                          ? Border.all(
                              color: cs.primary.withValues(alpha: 0.5),
                            )
                          : null,
                    ),
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

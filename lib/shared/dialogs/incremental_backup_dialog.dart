import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/incremental_backup.dart';
import '../../icons/lucide_adapter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_font_weights.dart';
import '../widgets/ios_switch.dart';
import '../widgets/ios_tactile.dart';

class IncrementalBackupDialog {
  static Future<IncrementalBackupConfig?> show(
    BuildContext context, {
    DateTime? lastBackupTime,
    bool initialIncludeFiles = true,
    Future<IncrementalScope> Function(IncrementalBackupConfig config)? analyzer,
  }) {
    return showDialog<IncrementalBackupConfig>(
      context: context,
      builder: (_) => _IncrementalBackupDialogBody(
        lastBackupTime: lastBackupTime,
        initialIncludeFiles: initialIncludeFiles,
        analyzer: analyzer,
        isSheet: false,
      ),
    );
  }

  static Future<IncrementalBackupConfig?> showSheet(
    BuildContext context, {
    DateTime? lastBackupTime,
    bool initialIncludeFiles = true,
    Future<IncrementalScope> Function(IncrementalBackupConfig config)? analyzer,
  }) {
    return showModalBottomSheet<IncrementalBackupConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: _IncrementalBackupDialogBody(
          lastBackupTime: lastBackupTime,
          initialIncludeFiles: initialIncludeFiles,
          analyzer: analyzer,
          isSheet: true,
        ),
      ),
    );
  }
}

class _IncrementalBackupDialogBody extends StatefulWidget {
  const _IncrementalBackupDialogBody({
    required this.lastBackupTime,
    this.initialIncludeFiles = true,
    this.analyzer,
    this.isSheet = false,
  });
  final DateTime? lastBackupTime;
  final bool initialIncludeFiles;
  final bool isSheet;
  final Future<IncrementalScope> Function(IncrementalBackupConfig config)?
  analyzer;

  @override
  State<_IncrementalBackupDialogBody> createState() =>
      _IncrementalBackupDialogBodyState();
}

class _IncrementalBackupDialogBodyState
    extends State<_IncrementalBackupDialogBody> {
  static const _prefsIncludeSettingsKey = 'incr_include_settings_v1';
  static const _prefsUpdateBackupTimeKey = 'incr_update_backup_time_v1';

  late DateTime _since;
  bool _includeSettings = true;
  late bool _includeFiles;
  bool _updateBackupTime = true;
  IncrementalScope? _scope;
  bool _analyzing = false;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _since =
        widget.lastBackupTime ??
        DateTime.now().subtract(const Duration(days: 30));
    _includeFiles = widget.initialIncludeFiles;
    _loadPersistence();
    if (widget.analyzer != null) _rerunAnalysis();
  }

  Future<void> _loadPersistence() async {
    final prefs = SharedPreferencesAsync();
    final includeSettings =
        await prefs.getBool(_prefsIncludeSettingsKey) ?? true;
    final updateBackupTime =
        await prefs.getBool(_prefsUpdateBackupTimeKey) ?? true;
    if (!mounted) return;
    setState(() {
      _includeSettings = includeSettings;
      _updateBackupTime = updateBackupTime;
    });
  }

  String _fmt(DateTime d) => d.toIso8601String().split('T')[0];

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _rerunAnalysis() async {
    final analyzer = widget.analyzer;
    if (analyzer == null) return;
    setState(() {
      _analyzing = true;
      _scope = null;
    });
    final gen = ++_gen;
    try {
      final scope = await analyzer(
        IncrementalBackupConfig(since: _since, includeFiles: _includeFiles),
      );
      if (gen != _gen || !mounted) return;
      setState(() {
        _scope = scope;
        _analyzing = false;
      });
    } catch (_) {
      if (gen != _gen || !mounted) return;
      setState(() {
        _scope = null;
        _analyzing = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _since,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _since = picked);
      _rerunAnalysis();
    }
  }

  Future<void> _onConfirm() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_prefsIncludeSettingsKey, _includeSettings);
    await prefs.setBool(_prefsUpdateBackupTimeKey, _updateBackupTime);
    if (!mounted) return;
    Navigator.of(context).pop(
      IncrementalBackupConfig(
        since: _since,
        includeSettings: _includeSettings,
        includeFiles: _includeFiles,
        updateBackupTime: _updateBackupTime,
        scope: _scope,
      ),
    );
  }

  void _onCancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isSheet = widget.isSheet;

    if (isSheet) {
      return _buildSheetLayout(cs, l10n);
    }
    return _buildDialogLayout(cs, l10n);
  }

  Widget _buildDialogLayout(ColorScheme cs, AppLocalizations l10n) {
    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: _buildForm(cs, l10n),
        ),
      ),
    );
  }

  Widget _buildSheetLayout(ColorScheme cs, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _buildForm(cs, l10n),
        ],
      ),
    );
  }

  Widget _buildTitleRow(ConvRange range, ColorScheme cs) {
    final title = range.oldestTitle;
    if (title == null) return const SizedBox.shrink();
    final hasNewest =
        range.newestTitle != null && range.newestTitle != range.oldestTitle;
    final label = hasNewest ? '$title → ${range.newestTitle}' : title;
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: cs.onSurface.withValues(alpha: 0.5),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static const _cardBorderRadius = 8.0;

  Widget _buildPreviewCard(ColorScheme cs, AppLocalizations l10n) {
    final children = <Widget>[];

    children.add(
      Text(
        l10n.backupPageIncrementalPreviewTitle,
        style: TextStyle(
          fontSize: 12,
          fontWeight: AppFontWeights.semibold,
          color: cs.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );

    if (_analyzing && _scope == null) {
      children.add(const SizedBox(height: 6));
      children.add(
        Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.backupPageIncrementalPreviewLoading,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    } else if (_scope != null) {
      final s = _scope!;
      if (s.newConversations.count > 0) {
        children.add(const SizedBox(height: 6));
        children.add(
          Text(
            l10n.backupPageIncrementalPreviewNewConv(
              s.newConversations.count,
              s.newConversations.messageCount,
            ),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        );
        children.add(_buildTitleRow(s.newConversations, cs));
      }
      if (s.updatedConversations.count > 0) {
        children.add(const SizedBox(height: 4));
        children.add(
          Text(
            l10n.backupPageIncrementalPreviewUpdatedConv(
              s.updatedConversations.count,
              s.updatedConversations.messageCount,
            ),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        );
        children.add(_buildTitleRow(s.updatedConversations, cs));
      }
      if (s.newFileCount > 0) {
        children.add(const SizedBox(height: 4));
        children.add(
          Text(
            l10n.backupPageIncrementalPreviewFiles(
              s.newFileCount,
              _formatBytes(s.totalFileSizeBytes),
            ),
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        );
      }
    }

    if (children.length == 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(_cardBorderRadius),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildForm(ColorScheme cs, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.backupPageIncrementalTitle,
          style: TextStyle(fontSize: 15, fontWeight: AppFontWeights.semibold),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.backupPageIncrementalDescription,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                l10n.backupPageIncrementalStartDate,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            TextButton(onPressed: _pickDate, child: Text(_fmt(_since))),
            const SizedBox(width: 6),
            if (widget.lastBackupTime != null)
              Tooltip(
                message: l10n.backupPageIncrementalLastBackup,
                child: IosIconButton(
                  icon: Lucide.RefreshCw,
                  size: 18,
                  minSize: 36,
                  onTap: () {
                    setState(() => _since = widget.lastBackupTime!);
                    _rerunAnalysis();
                  },
                  semanticLabel: l10n.backupPageIncrementalLastBackup,
                ),
              ),
          ],
        ),
        if (widget.analyzer != null) _buildPreviewCard(cs, l10n),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              l10n.backupPageIncrementalIncludeSettings,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const Spacer(),
            IosSwitch(
              value: _includeSettings,
              onChanged: (v) => setState(() => _includeSettings = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              l10n.backupPageIncrementalIncludeFiles,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const Spacer(),
            IosSwitch(
              value: _includeFiles,
              onChanged: (v) {
                setState(() => _includeFiles = v);
                _rerunAnalysis();
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.backupPageIncrementalUpdateBackupTime,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ),
            IosSwitch(
              value: _updateBackupTime,
              onChanged: (v) => setState(() => _updateBackupTime = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _onCancel,
              child: Text(l10n.backupPageCancel),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _onConfirm,
              child: Text(l10n.backupPageIncrementalUpload),
            ),
          ],
        ),
      ],
    );
  }
}

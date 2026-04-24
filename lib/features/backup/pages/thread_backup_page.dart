import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../providers/thread_backup_provider.dart';
import '../services/importers/import_manager.dart';
import '../widgets/thread_list_tile.dart';

/// Main backup center page for managing unified thread backups.
///
/// Displays:
/// - Summary of all backed-up threads by source
/// - Action buttons: Import from file/paste, Export all
/// - List of all threads with source badges
class ThreadBackupPage extends StatefulWidget {
  const ThreadBackupPage({super.key});

  @override
  State<ThreadBackupPage> createState() => _ThreadBackupPageState();
}

class _ThreadBackupPageState extends State<ThreadBackupPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ThreadBackupProvider>();
      if (!provider.hasLoaded) {
        provider.loadAll();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<ThreadBackupProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.threadBackupTitle),
        actions: [
          if (provider.totalCount > 0)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: l10n.threadBackupExportAll,
              onPressed: () => _exportAll(context, provider),
            ),
          if (provider.totalCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.threadBackupDeleteAll,
              onPressed: () => _confirmDeleteAll(context, provider),
            ),
        ],
      ),
      body: _buildBody(context, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showImportOptions(context, provider),
        icon: const Icon(Icons.add),
        label: Text(l10n.threadBackupImport),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ThreadBackupProvider provider) {
    if (provider.isLoading && !provider.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadAll(),
      child: Column(
        children: [
          // Summary header
          _buildSummaryHeader(context, provider),
          // Active import state
          if (provider.importState != ImportState.idle)
            _buildImportBanner(context, provider),
          // Error banner
          if (provider.lastError != null &&
              provider.importState != ImportState.error)
            _buildErrorBanner(context, provider),
          // Thread list
          Expanded(child: _buildThreadList(context, provider)),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final breakdown = provider.sourceBreakdown;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${provider.totalCount} threads from ${provider.sourceCount} sources',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: breakdown.entries.map((e) {
              return Chip(
                label: Text('${e.key}: ${e.value}'),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildImportBanner(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    final l10n = AppLocalizations.of(context)!;

    switch (provider.importState) {
      case ImportState.parsing:
        return const LinearProgressIndicator();
      case ImportState.reviewing:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${provider.pendingImports.length} new threads ready to import'
                  '${provider.duplicatesSkipped > 0 ? ' (${provider.duplicatesSkipped} duplicates skipped)' : ''}',
                ),
              ),
              TextButton(
                onPressed: () => provider.cancelImport(),
                child: Text(l10n.threadBackupCancel),
              ),
              FilledButton(
                onPressed: () => provider.confirmImport(),
                child: Text(l10n.threadBackupConfirm),
              ),
            ],
          ),
        );
      case ImportState.complete:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${provider.pendingImports.length} threads imported successfully.',
                ),
              ),
              TextButton(
                onPressed: () => provider.resetImportState(),
                child: Text(l10n.threadBackupDismiss),
              ),
            ],
          ),
        );
      case ImportState.error:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Theme.of(context).colorScheme.errorContainer,
          child: Row(
            children: [
              const Icon(Icons.error_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(provider.lastError ?? 'Import failed'),
              ),
              TextButton(
                onPressed: () => provider.resetImportState(),
                child: Text(l10n.threadBackupDismiss),
              ),
            ],
          ),
        );
      case ImportState.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _buildErrorBanner(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(provider.lastError ?? '')),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => provider.cancelImport(),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadList(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    if (provider.threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No threads backed up yet.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to import from ChatGPT, Gemini, or others.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: provider.threads.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final thread = provider.threads[index];
        return ThreadListTile(
          thread: thread,
          onTap: () => _showThreadDetail(context, thread),
          onDelete: () => _confirmDelete(context, provider, thread.id),
        );
      },
    );
  }

  void _showThreadDetail(BuildContext context, dynamic thread) {
    // Phase 2: full thread detail view with messages
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(thread.title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Source: ${thread.source}'),
              Text('Messages: ${thread.messages.length}'),
              Text('Created: ${thread.createdAt}'),
              Text('Updated: ${thread.updatedAt}'),
              if (thread.messages.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Recent Messages:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...thread.messages.take(5).map((msg) => Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.role,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              msg.content.length > 200
                                  ? '${msg.content.substring(0, 200)}...'
                                  : msg.content,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )),
                if (thread.messages.length > 5)
                  Text('... and ${thread.messages.length - 5} more messages'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportOptions(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import from file'),
              subtitle: const Text('Pick a JSON export file'),
              onTap: () {
                Navigator.pop(ctx);
                _importFromFile(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Paste JSON'),
              subtitle: const Text('Paste export JSON directly'),
              onTap: () {
                Navigator.pop(ctx);
                _importFromPaste(context, provider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.source_outlined),
              title: const Text('Choose source...'),
              subtitle: const Text('Manually select the platform'),
              onTap: () {
                Navigator.pop(ctx);
                _showSourcePicker(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromFile(
    BuildContext context,
    ThreadBackupProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonString = await file.readAsString();
      await provider.importFromJson(jsonString);

      if (provider.importState == ImportState.reviewing && mounted) {
        AppSnackBar.show(
          context,
          'Found ${provider.pendingImports.length} new threads'
          '${provider.duplicatesSkipped > 0 ? ' (${provider.duplicatesSkipped} duplicates skipped)' : ''}.'
          ' Review and confirm to save.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Failed to import: $e');
      }
    }
  }

  void _importFromPaste(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Export JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 15,
            decoration: const InputDecoration(
              hintText: 'Paste your export JSON here...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final json = controller.text.trim();
              if (json.isEmpty) return;
              await provider.importFromJson(json);
              if (provider.importState == ImportState.reviewing && mounted) {
                AppSnackBar.show(
                  context,
                  'Found ${provider.pendingImports.length} new threads'
                  '${provider.duplicatesSkipped > 0 ? ' (${provider.duplicatesSkipped} duplicates skipped)' : ''}.'
                  ' Review and confirm to save.',
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _showSourcePicker(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select source platform',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ...DetectedSource.values
                .where((s) => s != DetectedSource.unknown)
                .map((source) => ListTile(
                      leading: _sourceIcon(source),
                      title: Text(_sourceDisplayName(source)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _importWithSource(
                          context,
                          provider,
                          source,
                        );
                      },
                    )),
          ],
        ),
      ),
    );
  }

  Future<void> _importWithSource(
    BuildContext context,
    ThreadBackupProvider provider,
    DetectedSource source,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;

      final file = File(filePath);
      final jsonString = await file.readAsString();
      await provider.importFromJsonWithSource(jsonString, source);

      if (provider.importState == ImportState.reviewing && mounted) {
        AppSnackBar.show(
          context,
          'Found ${provider.pendingImports.length} new threads'
          '${provider.duplicatesSkipped > 0 ? ' (${provider.duplicatesSkipped} duplicates skipped)' : ''}.'
          ' Review and confirm to save.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Failed to import: $e');
      }
    }
  }

  Future<void> _exportAll(
    BuildContext context,
    ThreadBackupProvider provider,
  ) async {
    try {
      final result = await FilePicker.platform.saveFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
        fileName: 'kelivo_backup_${DateTime.now().millisecondsSinceEpoch}.json',
      );

      if (result == null) return;
      await provider.exportToFile(result);
      if (mounted) {
        AppSnackBar.show(context, 'Exported ${provider.totalCount} threads to file.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Export failed: $e');
      }
    }
  }

  void _confirmDelete(
    BuildContext context,
    ThreadBackupProvider provider,
    String id,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Thread'),
        content: const Text(
            'Remove this thread from the backup? This does not affect the original chat app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteThread(id);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(
    BuildContext context,
    ThreadBackupProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Threads'),
        content: const Text(
            'Remove all backed-up threads? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteAll();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Widget _sourceIcon(DetectedSource source) {
    switch (source) {
      case DetectedSource.chatgpt:
        return const Icon(Icons.chat_bubble_outline, color: Color(0xFF10A37F));
      case DetectedSource.gemini:
        return const Icon(Icons.auto_awesome, color: Color(0xFF4285F4));
      case DetectedSource.perplexity:
        return const Icon(Icons.travel_explore, color: Color(0xFF5436DA));
      case DetectedSource.claude:
        return const Icon(Icons.psychology_outline, color: Color(0xFFD97706));
      case DetectedSource.kelivo:
        return const Icon(Icons.message_outline, color: Color(0xFF6366F1));
      case DetectedSource.unknown:
        return const Icon(Icons.forum_outlined, color: Colors.grey);
    }
  }

  String _sourceDisplayName(DetectedSource source) {
    switch (source) {
      case DetectedSource.chatgpt:
        return 'ChatGPT';
      case DetectedSource.gemini:
        return 'Gemini';
      case DetectedSource.perplexity:
        return 'Perplexity';
      case DetectedSource.claude:
        return 'Claude';
      case DetectedSource.kelivo:
        return 'Kelivo';
      case DetectedSource.unknown:
        return 'Other';
    }
  }
}

import '../widgets/desktop_labeled_control.dart';
import 'dart:io';

import 'package:Kelivo/shared/widgets/ios_time_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../features/backup/forward_compat_consent_dialog.dart';
import 'package:provider/provider.dart';

import '../../icons/lucide_adapter.dart' as lucide;
import '../../l10n/app_localizations.dart';
import '../../core/database/business_repository.dart';
import '../../core/models/backup.dart';
import '../../core/providers/backup_provider.dart';
import '../../core/providers/external_backup_auto_provider.dart';
import '../../features/backup/widgets/external_backup_controls.dart';
import '../../core/providers/backup_reminder_provider.dart';
import '../../core/providers/local_snapshot_provider.dart';
import '../../core/providers/s3_backup_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/chat/chat_service.dart';
import '../../core/services/backup/cherry_importer.dart';
import '../../core/services/backup/chatbox_importer.dart';
import '../../core/services/backup/import_toolbox.dart';
import '../../shared/widgets/ios_switch.dart';
import '../../shared/widgets/snackbar.dart';
import '../../features/backup/backup_restore_error_message.dart';
import '../../features/backup/backup_task_runner.dart';
import '../../features/backup/import_toolbox_link.dart';
import '../../features/backup/widgets/backup_progress_dialog.dart';
import '../../features/backup/backup_restart_dialog.dart';
import '../../features/backup/widgets/backup_reminder_helpers.dart';
import '../../features/backup/widgets/backup_scope_tile.dart';
import '../../features/backup/widgets/backup_encryption_tile.dart';
import '../../features/backup/widgets/storage_migration_notice_button.dart';
import '../../features/backup/pages/local_snapshots_page.dart';
import '../../core/database/startup_failure_report.dart' show formatBytes;
import '../widgets/desktop_select_dropdown.dart';
import '../../theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';
import 'package:Kelivo/shared/widgets/section_card.dart';

class DesktopBackupPane extends StatefulWidget {
  const DesktopBackupPane({super.key});
  @override
  State<DesktopBackupPane> createState() => _DesktopBackupPaneState();
}

class _DesktopBackupPaneState extends State<DesktopBackupPane> {
  bool _remoteBackupDialogActive = false;

  Future<void> _saveServerEdit(Future<void> write) async {
    try {
      await write;
    } on BackupSettingsSaveException {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppLocalizations.of(context)!.backupPageSettingsSaveFailed,
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _runRemoteBackupTask(BackupDestination destination) async {
    setState(() => _remoteBackupDialogActive = true);
    try {
      await runExternalBackup(context, destination);
    } finally {
      if (mounted) setState(() => _remoteBackupDialogActive = false);
    }
  }

  Future<void> _doImportLocal() async {
    final cfg = context.read<SettingsProvider>().webDavConfig;
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final backupProvider = context.read<BackupProvider>();
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final picked = result?.files.single;
    final path = picked?.path;
    if (path == null || !mounted) return;
    final file = File(path);
    final decision = await resolveForwardCompatibility(context, file);
    if (!mounted || decision == ForwardCompatDecision.cancelled) return;
    if (decision == ForwardCompatDecision.unreadable) {
      showAppSnackBar(context, message: l10n.backupPageSchemaTooNewMessage);
      return;
    }
    final mergeOnly = await isToolboxChatImport(file, fileName: picked!.name);
    if (!mounted) return;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (_) => _RestoreModeDialog(mergeOnly: mergeOnly),
    );
    if (mode == null) return;
    if (!mounted) return;
    final ok = await runBackupTask(
      context,
      title: l10n.backupPageImportBackupFile,
      task: (handle) => backupProvider.restoreFromLocalFile(
        file,
        cfg,
        mode: mode,
        onProgress: handle.report,
        cancelToken: handle.cancelToken,
        onPassword: backupPasswordPrompt(context),
        onForwardCompatibility: forwardCompatibilityPrompt(context),
        allowUnverifiedForwardCompatible:
            decision == ForwardCompatDecision.proceedUnverified,
      ),
    );
    if (!ok || !rootCtx.mounted) return;
    await showBackupRestartRequiredDialog(
      rootCtx,
      skippedConversations: backupProvider.skippedConversations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final (webDav: dav, :s3) = settings.backupConfigs;
    final webdavVm = context.watch<BackupProvider>();
    final s3Vm = context.watch<S3BackupProvider>();
    final busy =
        context.watch<ExternalBackupAutoProvider>().busy ||
        webdavVm.busy ||
        s3Vm.busy;
    final showHeaderBusy = busy && !_remoteBackupDialogActive;

    return Container(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: CustomScrollView(
            slivers: [
              // Title row
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.backupPageTitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFontWeights.regular,
                              color: cs.onSurface.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      StorageMigrationNoticeButton(
                        dataDirectory: context
                            .read<LocalSnapshotProvider>()
                            .appDataDirectory,
                      ),
                      if (showHeaderBusy) const SizedBox(width: 8),
                      if (showHeaderBusy)
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),

              // Backup management (applies to WebDAV and local import/export)
              SliverToBoxAdapter(
                child: SectionCard(
                  padding: const EdgeInsets.all(12),
                  radius: 18,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.backupPageBackupManagement,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFontWeights.semibold,
                                color: cs.onSurface.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    BackupScopeTile(
                      desktop: true,
                      scope: dav.scope,
                      onChanged: busy ? null : settings.setBackupScope,
                    ),
                    BackupEncryptionTile(busy: busy),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              _buildLocalBackupSliver(context, l10n, cs),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              SliverToBoxAdapter(child: _BackupReminderDesktopSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              const SliverToBoxAdapter(child: _LocalSnapshotDesktopSection()),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // WebDAV settings card with left label right input, realtime save
              SliverToBoxAdapter(
                child: SectionCard(
                  padding: const EdgeInsets.all(12),
                  radius: 18,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.backupPageWebDavServerSettings,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFontWeights.semibold,
                                color: cs.onSurface.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ServerSettingField(
                      label: l10n.backupPageWebDavServerUrl,
                      value: dav.url,
                      hint: 'https://dav.example.com/remote.php/webdav/',
                      enabled: !busy,
                      saving: settings.savingWebDavConfig,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateWebDavConfig(
                          (cfg) => cfg.copyWith(url: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageUsername,
                      value: dav.username,
                      hint: l10n.backupPageUsername,
                      enabled: !busy,
                      saving: settings.savingWebDavConfig,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateWebDavConfig(
                          (cfg) => cfg.copyWith(username: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPagePassword,
                      value: dav.password,
                      hint: '••••••••',
                      enabled: !busy,
                      saving: settings.savingWebDavConfig,
                      obscureText: true,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateWebDavConfig(
                          (cfg) => cfg.copyWith(password: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPagePath,
                      value: dav.path,
                      hint: 'kelivo_backups',
                      enabled: !busy,
                      saving: settings.savingWebDavConfig,
                      defaultValue: 'kelivo_backups',
                      onChanged: (value) => _saveServerEdit(
                        settings.updateWebDavConfig(
                          (cfg) => cfg.copyWith(path: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageUserAgent,
                      value: dav.userAgent,
                      hint: l10n.backupPageUserAgentHint,
                      enabled: !busy,
                      saving: settings.savingWebDavConfig,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateWebDavConfig(
                          (cfg) => cfg.copyWith(userAgent: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ItemRow(
                      label: l10n.backupPageWebDavBackup,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          _DeskIosButton(
                            label: l10n.backupPageTestConnection,
                            filled: false,
                            dense: true,
                            onTap: busy || settings.savingWebDavConfig
                                ? null
                                : () async {
                                    final backupProvider = context
                                        .read<BackupProvider>();
                                    await backupProvider.test(dav);
                                    if (!context.mounted) return;
                                    final rawMessage = backupProvider.message;
                                    final message =
                                        rawMessage ?? l10n.backupPageTestDone;
                                    showAppSnackBar(
                                      context,
                                      message: message,
                                      type:
                                          rawMessage != null &&
                                              rawMessage != 'OK'
                                          ? NotificationType.error
                                          : NotificationType.success,
                                    );
                                  },
                          ),
                          _DeskIosButton(
                            label: l10n.backupPageRestore,
                            filled: false,
                            dense: true,
                            onTap: busy || settings.savingWebDavConfig
                                ? null
                                : () async {
                                    final backupProvider = context
                                        .read<BackupProvider>();
                                    _showRemoteBackupsDialog(
                                      context,
                                      title:
                                          '${l10n.backupPageRemoteBackups} (WebDAV)',
                                      listRemote: (handle) =>
                                          backupProvider.listRemote(
                                            dav,
                                            onProgress: handle.report,
                                            cancelToken: handle.cancelToken,
                                          ),
                                      restoreFromItem: (it, mode, handle) async {
                                        await backupProvider.restoreFromItem(
                                          dav,
                                          it,
                                          mode: mode,
                                          onProgress: handle.report,
                                          cancelToken: handle.cancelToken,
                                          onPassword: backupPasswordPrompt(
                                            context,
                                          ),
                                          onForwardCompatibility:
                                              forwardCompatibilityPrompt(
                                                context,
                                              ),
                                        );
                                        final msg = backupProvider.message;
                                        if (msg != null && msg != 'Restored') {
                                          throw Exception(msg);
                                        }
                                      },
                                      skippedConversations: () =>
                                          backupProvider.skippedConversations,
                                      deleteAndReload: (item) => backupProvider
                                          .deleteAndReload(dav, item),
                                    );
                                  },
                          ),
                          _DeskIosButton(
                            label: l10n.backupPageBackupNow,
                            filled: true,
                            dense: true,
                            onTap: busy || settings.savingWebDavConfig
                                ? null
                                : () async {
                                    await _runRemoteBackupTask(
                                      BackupDestination.webdav,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // S3 settings card with left label right input, realtime save
              SliverToBoxAdapter(
                child: SectionCard(
                  padding: const EdgeInsets.all(12),
                  radius: 18,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.backupPageS3ServerSettings,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFontWeights.semibold,
                                color: cs.onSurface.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ServerSettingField(
                      label: l10n.backupPageS3Endpoint,
                      value: s3.endpoint,
                      hint: 'https://s3.amazonaws.com',
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(endpoint: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3Region,
                      value: s3.region,
                      hint: 'us-east-1 / auto',
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      defaultValue: 'us-east-1',
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(region: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3Bucket,
                      value: s3.bucket,
                      hint: l10n.backupPageS3Bucket,
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(bucket: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3AccessKeyId,
                      value: s3.accessKeyId,
                      hint: l10n.backupPageS3AccessKeyId,
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(accessKeyId: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3SecretAccessKey,
                      value: s3.secretAccessKey,
                      hint: '••••••••',
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      obscureText: true,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(secretAccessKey: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3SessionToken,
                      value: s3.sessionToken,
                      hint: l10n.backupPageS3SessionToken,
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      obscureText: true,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(sessionToken: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageS3Prefix,
                      value: s3.prefix,
                      hint: 'kelivo_backups',
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      defaultValue: 'kelivo_backups',
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(prefix: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ServerSettingField(
                      label: l10n.backupPageUserAgent,
                      value: s3.userAgent,
                      hint: l10n.backupPageUserAgentHint,
                      enabled: !busy,
                      saving: settings.savingS3Config,
                      onChanged: (value) => _saveServerEdit(
                        settings.updateS3Config(
                          (cfg) => cfg.copyWith(userAgent: value),
                        ),
                      ),
                    ),
                    _rowDivider(context),
                    _ItemRow(
                      label: l10n.backupPageS3PathStyle,
                      trailing: IosSwitch(
                        value: s3.pathStyle,
                        onChanged: busy || settings.savingS3Config
                            ? null
                            : (v) => _saveServerEdit(
                                settings.updateS3Config(
                                  (cfg) => cfg.copyWith(pathStyle: v),
                                ),
                              ),
                      ),
                    ),
                    _rowDivider(context),
                    _ItemRow(
                      label: l10n.backupPageS3Backup,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          _DeskIosButton(
                            label: l10n.backupPageTestConnection,
                            filled: false,
                            dense: true,
                            onTap: busy || settings.savingS3Config
                                ? null
                                : () async {
                                    final s3BackupProvider = context
                                        .read<S3BackupProvider>();
                                    await s3BackupProvider.test(s3);
                                    if (!context.mounted) return;
                                    final rawMessage = s3BackupProvider.message;
                                    final message =
                                        rawMessage ?? l10n.backupPageTestDone;
                                    showAppSnackBar(
                                      context,
                                      message: message,
                                      type:
                                          rawMessage != null &&
                                              rawMessage != 'OK'
                                          ? NotificationType.error
                                          : NotificationType.success,
                                    );
                                  },
                          ),
                          _DeskIosButton(
                            label: l10n.backupPageRestore,
                            filled: false,
                            dense: true,
                            onTap: busy || settings.savingS3Config
                                ? null
                                : () async {
                                    final s3BackupProvider = context
                                        .read<S3BackupProvider>();
                                    _showRemoteBackupsDialog(
                                      context,
                                      title:
                                          '${l10n.backupPageRemoteBackups} (S3)',
                                      listRemote: (handle) =>
                                          s3BackupProvider.listRemote(
                                            s3,
                                            onProgress: handle.report,
                                            cancelToken: handle.cancelToken,
                                          ),
                                      restoreFromItem: (it, mode, handle) async {
                                        await s3BackupProvider.restoreFromItem(
                                          s3,
                                          it,
                                          mode: mode,
                                          onProgress: handle.report,
                                          cancelToken: handle.cancelToken,
                                          onPassword: backupPasswordPrompt(
                                            context,
                                          ),
                                          onForwardCompatibility:
                                              forwardCompatibilityPrompt(
                                                context,
                                              ),
                                        );
                                        final msg = s3BackupProvider.message;
                                        if (msg != null && msg != 'Restored') {
                                          throw Exception(msg);
                                        }
                                      },
                                      skippedConversations: () =>
                                          s3BackupProvider.skippedConversations,
                                      deleteAndReload: (item) =>
                                          s3BackupProvider.deleteAndReload(
                                            s3,
                                            item,
                                          ),
                                    );
                                  },
                          ),
                          _DeskIosButton(
                            label: l10n.backupPageBackupNow,
                            filled: true,
                            dense: true,
                            onTap: busy || settings.savingS3Config
                                ? null
                                : () async {
                                    await _runRemoteBackupTask(
                                      BackupDestination.s3,
                                    );
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalBackupSliver(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme cs,
  ) {
    final busy = context.watch<ExternalBackupAutoProvider>().busy;
    return SliverToBoxAdapter(
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        radius: 18,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.backupPageLocalBackup,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: AppFontWeights.semibold,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              l10n.backupPageExportToFileSubtitle,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          if (Platform.isIOS)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                l10n.backupPageIosSystemBackupNote,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _DeskIosButton(
                label: l10n.backupPageExportToFile,
                filled: false,
                dense: true,
                onTap: busy ? null : () => runLocalFileBackup(context),
              ),
              _DeskIosButton(
                label: l10n.backupPageImportBackupFile,
                filled: false,
                dense: true,
                onTap: busy ? null : _doImportLocal,
              ),
              _DeskIosButton(
                label: l10n.backupPageImportFromCherryStudio,
                filled: false,
                dense: true,
                onTap: busy
                    ? null
                    : () async {
                        final rootCtx = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                        );
                        final path = result?.files.single.path;
                        if (path == null) return;
                        final f = File(path);
                        if (!context.mounted) return;
                        final mode = await showDialog<RestoreMode>(
                          context: context,
                          builder: (_) => _RestoreModeDialog(),
                        );
                        if (mode == null) return;
                        if (!context.mounted) return;
                        final chat = context.read<ChatService>();
                        CherryImportResult? imported;
                        final ok = await runBackupTask(
                          context,
                          title: l10n.backupPageImportFromCherryStudio,
                          errorMessage: (error) => error.toString(),
                          task: (handle) async {
                            imported =
                                await CherryImporter.importFromCherryStudio(
                                  file: f,
                                  mode: mode,
                                  scope: context
                                      .read<SettingsProvider>()
                                      .webDavConfig
                                      .scope,
                                  businessRepository: context
                                      .read<BusinessRepository>(),
                                  chatService: chat,
                                  onProgress: handle.report,
                                  cancelToken: handle.cancelToken,
                                );
                          },
                        );
                        if (!ok || imported == null || !rootCtx.mounted) return;
                        final cherry = imported!;
                        await showBackupRestartRequiredDialog(
                          rootCtx,
                          details:
                              '${l10n.backupPageImportFromCherryStudio}:\n'
                              ' • Providers: ${cherry.providers}\n'
                              ' • Assistants: ${cherry.assistants}\n'
                              ' • Conversations: ${cherry.conversations}\n'
                              ' • Messages: ${cherry.messages}\n'
                              ' • Files: ${cherry.files}',
                        );
                      },
              ),
              _DeskIosButton(
                label: l10n.backupPageImportFromChatbox,
                filled: false,
                dense: true,
                onTap: busy
                    ? null
                    : () async {
                        final rootCtx = Navigator.of(
                          context,
                          rootNavigator: true,
                        ).context;
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json', 'zip'],
                          allowMultiple: false,
                        );
                        final path = result?.files.single.path;
                        if (path == null) return;
                        final f = File(path);
                        if (!context.mounted) return;
                        final mode = await showDialog<RestoreMode>(
                          context: context,
                          builder: (_) => _RestoreModeDialog(),
                        );
                        if (mode == null) return;
                        if (!context.mounted) return;
                        final chat = context.read<ChatService>();
                        ChatboxImportResult? imported;
                        final ok = await runBackupTask(
                          context,
                          title: l10n.backupPageImportFromChatbox,
                          task: (handle) async {
                            imported = await ChatboxImporter.importFromChatbox(
                              file: f,
                              mode: mode,
                              scope: context
                                  .read<SettingsProvider>()
                                  .webDavConfig
                                  .scope,
                              businessRepository: context
                                  .read<BusinessRepository>(),
                              chatService: chat,
                              onProgress: handle.report,
                              cancelToken: handle.cancelToken,
                            );
                          },
                        );
                        if (!ok || imported == null || !rootCtx.mounted) return;
                        final chatbox = imported!;
                        await showBackupRestartRequiredDialog(
                          rootCtx,
                          details:
                              '${l10n.backupPageImportFromChatbox}:\n'
                              ' • Providers: ${chatbox.providers}\n'
                              ' • Assistants: ${chatbox.assistants}\n'
                              ' • Conversations: ${chatbox.conversations}\n'
                              ' • Messages: ${chatbox.messages}',
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _DeskIosButton(
              label: l10n.backupPageImportFromOtherApps,
              filled: false,
              dense: true,
              onTap: () => openImportToolbox(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.backupPageImportFromOtherAppsSubtitle,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LocalSnapshotDesktopSection extends StatelessWidget {
  const _LocalSnapshotDesktopSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<LocalSnapshotProvider>();

    return SectionCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            l10n.localSnapshotSectionTitle,
            style: TextStyle(fontSize: 15, fontWeight: AppFontWeights.semibold),
          ),
        ),
        _ItemRow(
          label: l10n.localSnapshotEnabledTitle,
          vpad: 2,
          trailing: IosSwitch(
            value: vm.settings.enabled,
            onChanged: (value) => context
                .read<LocalSnapshotProvider>()
                .updateSettings(vm.settings.copyWith(enabled: value)),
          ),
        ),
        _rowDivider(context),
        _ItemRow(
          label: l10n.localSnapshotManageCopies,
          trailing: _DeskIosButton(
            label: l10n.localSnapshotUsage(
              vm.copies.length,
              formatBytes(vm.totalBytes),
            ),
            filled: false,
            dense: true,
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const LocalSnapshotsPage()),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.localSnapshotEnabledSubtitle,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackupReminderDesktopSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reminder = context.watch<BackupReminderProvider>();

    return SectionCard(
      padding: const EdgeInsets.all(12),
      radius: 18,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            l10n.backupReminderSectionTitle,
            style: TextStyle(fontSize: 15, fontWeight: AppFontWeights.semibold),
          ),
        ),
        _ItemRow(
          label: l10n.backupReminderEnableTitle,
          vpad: 2,
          trailing: IosSwitch(
            value: reminder.enabled,
            onChanged: (value) async {
              final provider = context.read<BackupReminderProvider>();
              if (!value) {
                try {
                  await provider.setEnabled(false);
                } catch (error) {
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      message: backupRestoreErrorMessage(l10n, error),
                      type: NotificationType.error,
                    );
                  }
                }
                return;
              }
              final minutes = await showIosTimePicker(
                context,
                title: AppLocalizations.of(context)!.backupReminderTimeTitle,
                initialMinutes: provider.reminderMinutesOfDay,
              );
              if (minutes == null) return;
              await provider.saveSchedule(
                enabled: true,
                intervalDays: provider.intervalDays,
                reminderMinutesOfDay: minutes,
              );
            },
          ),
        ),
        const ExternalBackupCancelRow(),
        if (reminder.enabled) ...[
          _rowDivider(context),
          _ItemRow(
            label: l10n.backupReminderFrequencyTitle,
            trailing: _FrequencyDropdown(reminder: reminder),
          ),
          _rowDivider(context),
          _ItemRow(
            label: l10n.backupReminderTimeTitle,
            trailing: _DeskIosButton(
              label: backupReminderTimeLabel(
                context,
                reminder.reminderMinutesOfDay,
              ),
              filled: false,
              dense: true,
              onTap: () async {
                final provider = context.read<BackupReminderProvider>();
                final minutes = await showIosTimePicker(
                  context,
                  title: AppLocalizations.of(context)!.backupReminderTimeTitle,
                  initialMinutes: provider.reminderMinutesOfDay,
                );
                if (minutes == null) return;
                await provider.saveSchedule(
                  enabled: true,
                  intervalDays: provider.intervalDays,
                  reminderMinutesOfDay: minutes,
                );
              },
            ),
          ),
          _rowDivider(context),
          const ExternalBackupControls(desktop: true),
          _rowDivider(context),
          _ItemRow(
            label: l10n.backupReminderLastBackupTitle,
            trailing: _ReminderDetailText(
              backupReminderDateTimeLabel(context, reminder.lastBackupAt),
            ),
          ),
          _rowDivider(context),
          _ItemRow(
            label: context.watch<SettingsProvider>().autoBackupEnabled
                ? l10n.backupAutoNextTitle
                : l10n.backupReminderNextReminderTitle,
            trailing: _ReminderDetailText(
              backupReminderNextLabel(context, reminder.nextReminderAt),
            ),
          ),
        ],
      ],
    );
  }
}

class _FrequencyDropdown extends StatelessWidget {
  const _FrequencyDropdown({required this.reminder});

  final BackupReminderProvider reminder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = reminder.intervalDays;
    final preset = BackupReminderProvider.presetIntervals;
    final options = <DesktopSelectOption<int>>[
      for (final days in preset)
        DesktopSelectOption(
          value: days,
          label: backupReminderFrequencyLabel(l10n, days),
        ),
      if (!preset.contains(current))
        DesktopSelectOption(
          value: current,
          label: backupReminderFrequencyLabel(l10n, current),
        ),
      DesktopSelectOption(value: 0, label: l10n.backupReminderCustomOption),
    ];

    return DesktopSelectDropdown<int>(
      value: current,
      options: options,
      minWidth: 150,
      onSelected: (value) async {
        final provider = context.read<BackupReminderProvider>();
        final days = value == 0
            ? await showBackupReminderCustomDaysDialog(
                context,
                initialDays: provider.intervalDays,
              )
            : value;
        if (!context.mounted) return;
        if (days == null) return;
        var minutes = provider.reminderMinutesOfDay;
        minutes ??= await showIosTimePicker(
          context,
          title: AppLocalizations.of(context)!.backupReminderTimeTitle,
        );
        if (!context.mounted) return;
        if (minutes == null) return;
        await provider.saveSchedule(
          enabled: true,
          intervalDays: days,
          reminderMinutesOfDay: minutes,
        );
      },
    );
  }
}

class _ReminderDetailText extends StatelessWidget {
  const _ReminderDetailText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.68),
        ),
      ),
    );
  }
}

class _RemoteItemCard extends StatefulWidget {
  const _RemoteItemCard({
    required this.item,
    required this.onRestore,
    required this.onDelete,
  });
  final BackupFileItem item;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  @override
  State<_RemoteItemCard> createState() => _RemoteItemCardState();
}

class _RemoteItemCardState extends State<_RemoteItemCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = context.appColors.surfaceCard;
    final borderColor = _hover
        ? cs.primary.withValues(alpha: isDark ? 0.35 : 0.45)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.12 : 0.08);
    final l10n = AppLocalizations.of(context)!;
    final dateStr =
        widget.item.lastModified?.toLocal().toString().split('.').first ?? '';

    String prettySize(int size) {
      const units = ['B', 'KB', 'MB', 'GB'];
      double s = size.toDouble();
      int u = 0;
      while (s >= 1024 && u < units.length - 1) {
        s /= 1024;
        u++;
      }
      return '${s.toStringAsFixed(s >= 10 || u == 0 ? 0 : 1)} ${units[u]}';
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: baseBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(lucide.Lucide.HardDrive, size: 20, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.item.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFontWeights.semibold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prettySize(widget.item.size)}${dateStr.isNotEmpty ? ' · $dateStr' : ''}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.backupPageRestoreTooltip,
              child: _SmallIconBtn(
                icon: lucide.Lucide.Import,
                onTap: widget.onRestore,
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.backupPageDeleteTooltip,
              child: _SmallIconBtn(
                icon: lucide.Lucide.Trash2,
                onTap: widget.onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteBackupsDialog extends StatefulWidget {
  const _RemoteBackupsDialog({
    required this.title,
    required this.listRemote,
    required this.restoreFromItem,
    required this.skippedConversations,
    required this.deleteAndReload,
  });

  final String title;
  final Future<List<BackupFileItem>> Function(BackupTaskHandle handle)
  listRemote;
  final Future<void> Function(
    BackupFileItem item,
    RestoreMode mode,
    BackupTaskHandle handle,
  )
  restoreFromItem;
  final int Function() skippedConversations;
  final Future<List<BackupFileItem>> Function(BackupFileItem item)
  deleteAndReload;

  @override
  State<_RemoteBackupsDialog> createState() => _RemoteBackupsDialogState();
}

class _RemoteBackupsDialogState extends State<_RemoteBackupsDialog> {
  List<BackupFileItem> _items = const [];
  bool _loading = true;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context)!;
    await runBackupTask(
      context,
      title: l10n.backupProgressListingRemote,
      task: (handle) async {
        final list = await widget.listRemote(handle);
        // Sort by newest first (desc by lastModified), mimic mobile behavior
        list.sort((a, b) {
          final aTime = a.lastModified;
          final bTime = b.lastModified;
          if (aTime != null && bTime != null) return bTime.compareTo(aTime);
          if (aTime == null && bTime == null) {
            return b.displayName.compareTo(a.displayName);
          }
          if (aTime == null) return 1; // items with time go first
          return -1;
        });
        if (mounted) {
          setState(() {
            _items = list;
          });
        }
      },
    );
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _chooseRestoreModeAndRun(
    Future<void> Function(RestoreMode, BackupTaskHandle) action,
  ) async {
    // Use a stable context so we can still show a restart prompt even if this
    // dialog is closed while the restore task is running.
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final l10n = AppLocalizations.of(context)!;
    final mode = await showDialog<RestoreMode>(
      context: context,
      builder: (_) => _RestoreModeDialog(),
    );
    if (mode == null) return;
    if (!mounted) return;
    setState(() => _loading = true);
    final ok = await runBackupTask(
      context,
      title: l10n.backupPageImportBackupFile,
      task: (handle) => action(mode, handle),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok || !rootCtx.mounted) return;
    await showBackupRestartRequiredDialog(
      rootCtx,
      skippedConversations: widget.skippedConversations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: context.overlaySurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFontWeights.emphasis,
                      ),
                    ),
                  ),
                  _SmallIconBtn(
                    icon: lucide.Lucide.RefreshCw,
                    onTap: _loading ? () {} : _load,
                  ),
                  const SizedBox(width: 6),
                  _SmallIconBtn(
                    icon: lucide.Lucide.X,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _items.isEmpty
                    ? Center(
                        child: Text(
                          l10n.backupPageNoBackups,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : Scrollbar(
                        controller: _controller,
                        child: ListView.separated(
                          controller: _controller,
                          primary: false,
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final it = _items[i];
                            return _RemoteItemCard(
                              item: it,
                              onRestore: () => _chooseRestoreModeAndRun((
                                mode,
                                handle,
                              ) async {
                                await widget.restoreFromItem(it, mode, handle);
                              }),
                              onDelete: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dctx) => AlertDialog(
                                    backgroundColor: context.overlaySurface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Text(
                                      l10n.backupPageDeleteConfirmTitle,
                                    ),
                                    content: Text(
                                      l10n.backupPageDeleteConfirmContent(
                                        it.displayName,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(false),
                                        child: Text(l10n.backupPageCancel),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dctx).pop(true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: cs.error,
                                        ),
                                        child: Text(
                                          l10n.backupPageDeleteTooltip,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) return;

                                setState(
                                  () => _loading = true,
                                ); // Show loading inside dialog
                                try {
                                  final next = await widget.deleteAndReload(it);
                                  next.sort((a, b) {
                                    final aTime = a.lastModified;
                                    final bTime = b.lastModified;
                                    if (aTime != null && bTime != null) {
                                      return bTime.compareTo(aTime);
                                    }
                                    if (aTime == null && bTime == null) {
                                      return b.displayName.compareTo(
                                        a.displayName,
                                      );
                                    }
                                    if (aTime == null) return 1;
                                    return -1;
                                  });
                                  if (mounted) setState(() => _items = next);
                                } finally {
                                  if (mounted) setState(() => _loading = false);
                                }
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showRemoteBackupsDialog(
  BuildContext context, {
  required String title,
  required Future<List<BackupFileItem>> Function(BackupTaskHandle handle)
  listRemote,
  required Future<void> Function(
    BackupFileItem item,
    RestoreMode mode,
    BackupTaskHandle handle,
  )
  restoreFromItem,
  required int Function() skippedConversations,
  required Future<List<BackupFileItem>> Function(BackupFileItem item)
  deleteAndReload,
}) {
  showDialog(
    context: context,
    builder: (_) => _RemoteBackupsDialog(
      title: title,
      listRemote: listRemote,
      restoreFromItem: restoreFromItem,
      skippedConversations: skippedConversations,
      deleteAndReload: deleteAndReload,
    ),
  );
}

Widget _rowDivider(BuildContext context) {
  return Container(height: 1, color: context.appColors.hairline);
}

class _ServerSettingField extends StatefulWidget {
  const _ServerSettingField({
    required this.label,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.saving,
    required this.onChanged,
    this.obscureText = false,
    this.defaultValue = '',
  });

  final String label;
  final String value;
  final String hint;
  final bool enabled;
  final bool saving;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final String defaultValue;

  @override
  State<_ServerSettingField> createState() => _ServerSettingFieldState();
}

class _ServerSettingFieldState extends State<_ServerSettingField> {
  late final _controller = TextEditingController(text: widget.value);

  String _storedValue(String text) {
    if (widget.obscureText) return text;
    final value = text.trim();
    return value.isEmpty ? widget.defaultValue : value;
  }

  @override
  void didUpdateWidget(_ServerSettingField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Preserve the cursor and composing text while newer edits are in flight.
    // Once settled, a rejected edit or a write from another pane is reflected.
    if (!widget.saving && _storedValue(_controller.text) != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ItemRow(
    label: widget.label,
    trailing: SizedBox(
      width: 420,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        obscureText: widget.obscureText,
        style: const TextStyle(fontSize: 14),
        decoration: _deskInputDecoration(
          context,
        ).copyWith(hintText: widget.hint),
        onChanged: (text) => widget.onChanged(_storedValue(text)),
      ),
    ),
  );
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.label, required this.trailing, this.vpad = 8});
  final String label;
  final Widget trailing;
  final double vpad;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vpad),
      child: DesktopLabeledControl(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.88),
          ),
        ),
        control: trailing,
        controlWidth: 420,
      ),
    );
  }
}

class _RestoreModeDialog extends StatelessWidget {
  const _RestoreModeDialog({this.mergeOnly = false});

  final bool mergeOnly;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: context.overlaySurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.backupPageSelectImportMode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFontWeights.emphasis,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                mergeOnly
                    ? l10n.backupPageToolboxImportMergeOnlyHint
                    : l10n.backupPageSelectImportModeDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 12),
              if (!mergeOnly) ...[
                _RestoreModeTile(
                  title: l10n.backupPageOverwriteMode,
                  subtitle: l10n.backupPageOverwriteModeDescription,
                  onTap: () => Navigator.of(context).pop(RestoreMode.overwrite),
                ),
                const SizedBox(height: 8),
              ],
              _RestoreModeTile(
                title: l10n.backupPageMergeMode,
                subtitle: l10n.backupPageMergeModeDescription,
                onTap: () => Navigator.of(context).pop(RestoreMode.merge),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.backupPageCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestoreModeTile extends StatefulWidget {
  const _RestoreModeTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  State<_RestoreModeTile> createState() => _RestoreModeTileState();
}

class _RestoreModeTileState extends State<_RestoreModeTile> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.04))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.12),
                width: 0.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(fontWeight: AppFontWeights.emphasis),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.8),
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

class _SmallIconBtn extends StatefulWidget {
  const _SmallIconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  State<_SmallIconBtn> createState() => _SmallIconBtnState();
}

class _SmallIconBtnState extends State<_SmallIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = _hover
        ? (cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05))
        : Colors.transparent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 18, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _DeskIosButton extends StatefulWidget {
  const _DeskIosButton({
    required this.label,
    required this.filled,
    required this.dense,
    required this.onTap,
  });
  final String label;
  final bool filled;
  final bool dense;
  final VoidCallback? onTap;
  @override
  State<_DeskIosButton> createState() => _DeskIosButtonState();
}

class _DeskIosButtonState extends State<_DeskIosButton> {
  bool _hover = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = widget.filled
        ? cs.onPrimary
        : cs.onSurface.withValues(alpha: 0.9);
    final bg = widget.filled
        ? (_hover ? cs.primary.withValues(alpha: 0.92) : cs.primary)
        : (_hover
              ? (cs.onSurface.withValues(alpha: isDark ? 0.06 : 0.05))
              : Colors.transparent);
    final borderColor = widget.filled
        ? Colors.transparent
        : cs.outlineVariant.withValues(alpha: isDark ? 0.22 : 0.18);
    return Semantics(
      enabled: widget.onTap != null,
      button: true,
      child: Opacity(
        opacity: widget.onTap == null ? 0.45 : 1,
        child: IgnorePointer(
          ignoring: widget.onTap == null,
          child: MouseRegion(
            cursor: widget.onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _pressed ? 0.98 : 1.0,
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: widget.dense ? 8 : 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: AppFontWeights.semibold,
                      fontSize: widget.dense ? 13 : 14,
                    ),
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

InputDecoration _deskInputDecoration(BuildContext context) {
  // Match provider dialog style (compact), but slightly shorter height and 14px font hint
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: context.appColors.surfaceCardFill,
    hintStyle: TextStyle(
      fontSize: 14,
      color: cs.onSurface.withValues(alpha: 0.5),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.12),
        width: 0.6,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.12),
        width: 0.6,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: cs.primary.withValues(alpha: 0.35),
        width: 0.8,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

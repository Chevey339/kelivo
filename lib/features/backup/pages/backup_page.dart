import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import '../../../shared/widgets/loading_dialog_card.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../shared/animations/widgets.dart';
import '../../../core/services/haptics.dart';
import '../../../core/models/backup.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/backup_reminder_provider.dart';
import '../../../core/providers/s3_backup_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../core/services/native_file_save.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/backup/cherry_importer.dart';
import '../../../core/services/backup/chatbox_importer.dart';
import '../../../utils/platform_utils.dart';
import '../widgets/backup_reminder_helpers.dart';

// File size formatter (B, KB, MB, GB)
String _fmtBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
  return '$bytes B';
}

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupFileItem> _remote = const <BackupFileItem>[];
  List<BackupFileItem> _remoteS3 = const <BackupFileItem>[];

  Future<bool?> _confirmCherryImport(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final isZh = locale.languageCode.startsWith('zh');
    final String body = isZh
        ? '此功能目前仍处于实验阶段。\n目前仅能导入助手，对话内容，供应商和文件，\n一些供应商需要在baseurl后面添加/v1 or /v1beta。 \n为确保数据安全，建议在导入前先执行备份。\n是否已知晓并继续选择文件？'
        : 'This feature is experimental.\nTo keep your data safe, it is recommended to back up before importing.\nProceed to choose a file?';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        final onSurface60 = cs.onSurface.withValues(alpha: 0.72);
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    l10n.backupPageImportFromCherryStudio,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Padding(
                    //   padding: const EdgeInsets.only(top: 2),
                    //   child: Icon(Lucide.BadgeInfo, size: 18, color: cs.primary),
                    // ),
                    // const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        body,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: onSurface60,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _IosOutlineButton(
                        label: l10n.backupPageCancel,
                        onTap: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _IosFilledButton(
                        label: l10n.backupPageOK,
                        onTap: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<RestoreMode?> _chooseImportModeDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white10 : const Color(0xFFF7F7F9);

    return showDialog<RestoreMode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupPageSelectImportMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionCard(
              color: cardColor,
              icon: Lucide.RotateCw,
              title: l10n.backupPageOverwriteMode,
              subtitle: l10n.backupPageOverwriteModeDescription,
              onTap: () => Navigator.of(ctx).pop(RestoreMode.overwrite),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              color: cardColor,
              icon: Lucide.GitFork,
              title: l10n.backupPageMergeMode,
              subtitle: l10n.backupPageMergeModeDescription,
              onTap: () => Navigator.of(ctx).pop(RestoreMode.merge),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.backupPageCancel),
          ),
        ],
      ),
    );
  }

  Future<T> _runWithExportingOverlay<T>(
    BuildContext context,
    Future<T> Function() task,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    return _runWithLoadingOverlay(
      context,
      task,
      label: l10n.backupPageExporting,
    );
  }

  Future<T> _runWithLoadingOverlay<T>(
    BuildContext context,
    Future<T> Function() task, {
    String? label,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LoadingDialogCard(label: label),
    );
    try {
      final res = await task();
      return res;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<T> _runWithImportingOverlay<T>(
    BuildContext context,
    Future<T> Function() task,
  ) => _runWithLoadingOverlay(context, task);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BackupProvider(
            chatService: context.read<ChatService>(),
            initialConfig: settings.webDavConfig,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => S3BackupProvider(
            chatService: context.read<ChatService>(),
            initialConfig: settings.s3Config,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final vm = context.watch<BackupProvider>();
          final s3Vm = context.watch<S3BackupProvider>();
          final cfg = vm.config;
          final s3Cfg = s3Vm.config;

          // iOS-style section header
          Widget header(String text, {bool first = false}) => Padding(
            padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.8),
              ),
            ),
          );

          return Scaffold(
            appBar: AppBar(
              leading: Tooltip(
                message: l10n.settingsPageBackButton,
                child: _TactileIconButton(
                  icon: Lucide.ArrowLeft,
                  color: cs.onSurface,
                  size: 22,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              title: Text(l10n.backupPageTitle),
              actions: const [SizedBox(width: 12)],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Section 1: 备份管理
                header(l10n.backupPageBackupManagement, first: true),
                _iosSectionCard(
                  children: [
                    _iosSwitchRow(
                      context,
                      icon: Lucide.MessageSquare,
                      label: l10n.backupPageChatsLabel,
                      value: cfg.includeChats,
                      onChanged: (v) async {
                        final newCfg = cfg.copyWith(includeChats: v);
                        await settings.setWebDavConfig(newCfg);
                        vm.updateConfig(newCfg);

                        final newS3Cfg = s3Cfg.copyWith(includeChats: v);
                        await settings.setS3Config(newS3Cfg);
                        s3Vm.updateConfig(newS3Cfg);
                      },
                    ),
                    _iosDivider(context),
                    _iosSwitchRow(
                      context,
                      icon: Lucide.FileText,
                      label: l10n.backupPageFilesLabel,
                      value: cfg.includeFiles,
                      onChanged: (v) async {
                        final newCfg = cfg.copyWith(includeFiles: v);
                        await settings.setWebDavConfig(newCfg);
                        vm.updateConfig(newCfg);

                        final newS3Cfg = s3Cfg.copyWith(includeFiles: v);
                        await settings.setS3Config(newS3Cfg);
                        s3Vm.updateConfig(newS3Cfg);
                      },
                    ),
                  ],
                ),

                header(l10n.backupReminderSectionTitle),
                const _BackupReminderMobileSection(),

                // Section 2: WebDAV备份
                header(l10n.backupPageWebDavBackup),
                _iosSectionCard(
                  children: [
                    _iosNavRow(
                      context,
                      icon: Lucide.Settings,
                      label: l10n.backupPageWebDavServerSettings,
                      onTap: () =>
                          _showWebDavSettingsSheet(context, settings, vm, cfg),
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Cable,
                      label: l10n.backupPageTestConnection,
                      onTap: vm.busy
                          ? null
                          : () async {
                              await vm.test();
                              if (!context.mounted) return;
                              final rawMessage = vm.message;
                              final message =
                                  rawMessage ?? l10n.backupPageTestDone;
                              showAppSnackBar(
                                context,
                                message: message,
                                type: rawMessage != null && rawMessage != 'OK'
                                    ? NotificationType.error
                                    : NotificationType.success,
                              );
                            },
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Import,
                      label: l10n.backupPageRestore,
                      onTap: vm.busy
                          ? null
                          : () async {
                              final list = await _runWithImportingOverlay(
                                context,
                                () => vm.listRemote(),
                              );
                              // 按时间倒序排列（最新的在前）
                              list.sort((a, b) {
                                // 优先使用 lastModified
                                if (a.lastModified != null &&
                                    b.lastModified != null) {
                                  return b.lastModified!.compareTo(
                                    a.lastModified!,
                                  );
                                }
                                // 如果都没有 lastModified，按文件名倒序（文件名通常包含时间戳）
                                if (a.lastModified == null &&
                                    b.lastModified == null) {
                                  return b.displayName.compareTo(a.displayName);
                                }
                                // 有 lastModified 的排在前面
                                if (a.lastModified == null) return 1;
                                return -1;
                              });
                              setState(() => _remote = list);

                              if (!context.mounted) return;
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: cs.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) => _RemoteListSheet(
                                  items: _remote,
                                  loading: false,
                                  onDelete: (item) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.backupPageDeleteConfirmTitle,
                                        ),
                                        content: Text(
                                          l10n.backupPageDeleteConfirmContent(
                                            item.displayName,
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

                                    // 1. Close current sheet
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    // 2. Show loading dialog
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) =>
                                            const LoadingDialogCard(),
                                      );
                                    }

                                    try {
                                      final list = await vm.deleteAndReload(
                                        item,
                                      );

                                      // Close loading dialog
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      }

                                      // Sort list
                                      list.sort((a, b) {
                                        if (a.lastModified != null &&
                                            b.lastModified != null) {
                                          return b.lastModified!.compareTo(
                                            a.lastModified!,
                                          );
                                        }
                                        if (a.lastModified == null &&
                                            b.lastModified == null) {
                                          return b.displayName.compareTo(
                                            a.displayName,
                                          );
                                        }
                                        if (a.lastModified == null) return 1;
                                        return -1;
                                      });

                                      if (mounted) {
                                        setState(() => _remote = list);
                                      }

                                      if (!context.mounted) return;

                                      // Re-open the sheet by calling the same logic again.
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: cs.surface,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (ctx) => _RemoteListSheet(
                                          items: _remote,
                                          loading: false,
                                          onDelete: (item) async {
                                            // Simplified recursive delete logic for subsequent deletions
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dctx) => AlertDialog(
                                                title: Text(
                                                  l10n.backupPageDeleteConfirmTitle,
                                                ),
                                                content: Text(
                                                  l10n.backupPageDeleteConfirmContent(
                                                    item.displayName,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dctx,
                                                        ).pop(false),
                                                    child: Text(
                                                      l10n.backupPageCancel,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dctx,
                                                        ).pop(true),
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
                                            if (confirm == true) {
                                              if (!ctx.mounted) return;
                                              Navigator.of(ctx).pop();
                                              if (context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (ctx) =>
                                                      const LoadingDialogCard(),
                                                );
                                              }
                                              try {
                                                final list = await vm
                                                    .deleteAndReload(item);
                                                if (context.mounted) {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                }
                                                list.sort((a, b) {
                                                  if (a.lastModified != null &&
                                                      b.lastModified != null) {
                                                    return b.lastModified!
                                                        .compareTo(
                                                          a.lastModified!,
                                                        );
                                                  }
                                                  if (a.lastModified == null &&
                                                      b.lastModified == null) {
                                                    return b.displayName
                                                        .compareTo(
                                                          a.displayName,
                                                        );
                                                  }
                                                  if (a.lastModified == null) {
                                                    return 1;
                                                  }
                                                  return -1;
                                                });
                                                if (mounted) {
                                                  setState(
                                                    () => _remote = list,
                                                  );
                                                }
                                              } catch (_) {
                                                if (context.mounted &&
                                                    Navigator.canPop(context)) {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                }
                                              }
                                            }
                                          },
                                          onRestore: (item) async {
                                            Navigator.of(ctx).pop();
                                            if (!context.mounted) return;
                                            final mode =
                                                await _chooseImportModeDialog(
                                                  context,
                                                );
                                            if (mode == null) return;
                                            if (!context.mounted) return;
                                            try {
                                              await _runWithImportingOverlay(
                                                context,
                                                () => vm.restoreFromItem(
                                                  item,
                                                  mode: mode,
                                                ),
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              showAppSnackBar(
                                                context,
                                                message: e.toString(),
                                                type: NotificationType.error,
                                              );
                                              return;
                                            }
                                            if (!context.mounted) return;
                                            final msg = vm.message;
                                            if (msg != null &&
                                                msg != 'Restored') {
                                              showAppSnackBar(
                                                context,
                                                message: msg,
                                                type: NotificationType.error,
                                              );
                                              return;
                                            }
                                            await showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (dctx) => AlertDialog(
                                                title: Text(
                                                  l10n.backupPageRestartRequired,
                                                ),
                                                content: Text(
                                                  l10n.backupPageRestartContent,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () async {
                                                      Navigator.of(dctx).pop();
                                                      PlatformUtils.restartApp();
                                                    },
                                                    child: Text(
                                                      l10n.backupPageOK,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    } catch (e) {
                                      // If error, ensure loading dialog is closed
                                      if (context.mounted &&
                                          Navigator.canPop(context)) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      }
                                      if (context.mounted) {
                                        showAppSnackBar(
                                          context,
                                          message: e.toString(),
                                          type: NotificationType.error,
                                        );
                                      }
                                    }
                                  },
                                  onRestore: (item) async {
                                    Navigator.of(ctx).pop();

                                    if (!context.mounted) return;
                                    final mode = await _chooseImportModeDialog(
                                      context,
                                    );

                                    if (mode == null) return;
                                    if (!context.mounted) return;

                                    try {
                                      await _runWithImportingOverlay(
                                        context,
                                        () => vm.restoreFromItem(
                                          item,
                                          mode: mode,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      showAppSnackBar(
                                        context,
                                        message: e.toString(),
                                        type: NotificationType.error,
                                      );
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    final msg = vm.message;
                                    if (msg != null && msg != 'Restored') {
                                      showAppSnackBar(
                                        context,
                                        message: msg,
                                        type: NotificationType.error,
                                      );
                                      return;
                                    }
                                    await showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.backupPageRestartRequired,
                                        ),
                                        content: Text(
                                          l10n.backupPageRestartContent,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(dctx).pop();
                                              PlatformUtils.restartApp();
                                            },
                                            child: Text(l10n.backupPageOK),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Upload,
                      label: l10n.backupPageBackupNow,
                      onTap: vm.busy
                          ? null
                          : () async {
                              final reminderProvider = context
                                  .read<BackupReminderProvider>();
                              final success = await _runWithExportingOverlay(
                                context,
                                () => vm.backup(),
                              );
                              if (!context.mounted) return;
                              final rawMessage = vm.message;
                              if (success) {
                                await reminderProvider.recordBackupCompleted();
                                if (!context.mounted) return;
                              }
                              final message =
                                  rawMessage ?? l10n.backupPageBackupUploaded;
                              showAppSnackBar(
                                context,
                                message: message,
                                type: NotificationType.info,
                              );
                            },
                    ),
                  ],
                ),

                // Section 3: S3 备份
                header(l10n.backupPageS3Backup),
                _iosSectionCard(
                  children: [
                    _iosNavRow(
                      context,
                      icon: Lucide.Settings,
                      label: l10n.backupPageS3ServerSettings,
                      onTap: () =>
                          _showS3SettingsSheet(context, settings, s3Vm, s3Cfg),
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Cable,
                      label: l10n.backupPageTestConnection,
                      onTap: s3Vm.busy
                          ? null
                          : () async {
                              await s3Vm.test();
                              if (!context.mounted) return;
                              final rawMessage = s3Vm.message;
                              final message =
                                  rawMessage ?? l10n.backupPageTestDone;
                              showAppSnackBar(
                                context,
                                message: message,
                                type: rawMessage != null && rawMessage != 'OK'
                                    ? NotificationType.error
                                    : NotificationType.success,
                              );
                            },
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Import,
                      label: l10n.backupPageRestore,
                      onTap: s3Vm.busy
                          ? null
                          : () async {
                              final list = await _runWithImportingOverlay(
                                context,
                                () => s3Vm.listRemote(),
                              );
                              list.sort((a, b) {
                                if (a.lastModified != null &&
                                    b.lastModified != null) {
                                  return b.lastModified!.compareTo(
                                    a.lastModified!,
                                  );
                                }
                                if (a.lastModified == null &&
                                    b.lastModified == null) {
                                  return b.displayName.compareTo(a.displayName);
                                }
                                if (a.lastModified == null) return 1;
                                return -1;
                              });
                              setState(() => _remoteS3 = list);

                              if (!context.mounted) return;
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: cs.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (ctx) => _RemoteListSheet(
                                  items: _remoteS3,
                                  loading: false,
                                  onDelete: (item) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.backupPageDeleteConfirmTitle,
                                        ),
                                        content: Text(
                                          l10n.backupPageDeleteConfirmContent(
                                            item.displayName,
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

                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                    }

                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) =>
                                            const LoadingDialogCard(),
                                      );
                                    }

                                    try {
                                      final list = await s3Vm.deleteAndReload(
                                        item,
                                      );
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      }
                                      list.sort((a, b) {
                                        if (a.lastModified != null &&
                                            b.lastModified != null) {
                                          return b.lastModified!.compareTo(
                                            a.lastModified!,
                                          );
                                        }
                                        if (a.lastModified == null &&
                                            b.lastModified == null) {
                                          return b.displayName.compareTo(
                                            a.displayName,
                                          );
                                        }
                                        if (a.lastModified == null) return 1;
                                        return -1;
                                      });
                                      if (mounted) {
                                        setState(() => _remoteS3 = list);
                                      }
                                      if (!context.mounted) return;
                                      await showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: cs.surface,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16),
                                          ),
                                        ),
                                        builder: (ctx) => _RemoteListSheet(
                                          items: _remoteS3,
                                          loading: false,
                                          onDelete: (item) async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dctx) => AlertDialog(
                                                title: Text(
                                                  l10n.backupPageDeleteConfirmTitle,
                                                ),
                                                content: Text(
                                                  l10n.backupPageDeleteConfirmContent(
                                                    item.displayName,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dctx,
                                                        ).pop(false),
                                                    child: Text(
                                                      l10n.backupPageCancel,
                                                    ),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          dctx,
                                                        ).pop(true),
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
                                            if (confirm == true) {
                                              if (!ctx.mounted) return;
                                              Navigator.of(ctx).pop();
                                              if (context.mounted) {
                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (ctx) =>
                                                      const LoadingDialogCard(),
                                                );
                                              }
                                              try {
                                                final list = await s3Vm
                                                    .deleteAndReload(item);
                                                if (context.mounted) {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                }
                                                list.sort((a, b) {
                                                  if (a.lastModified != null &&
                                                      b.lastModified != null) {
                                                    return b.lastModified!
                                                        .compareTo(
                                                          a.lastModified!,
                                                        );
                                                  }
                                                  if (a.lastModified == null &&
                                                      b.lastModified == null) {
                                                    return b.displayName
                                                        .compareTo(
                                                          a.displayName,
                                                        );
                                                  }
                                                  if (a.lastModified == null) {
                                                    return 1;
                                                  }
                                                  return -1;
                                                });
                                                if (mounted) {
                                                  setState(
                                                    () => _remoteS3 = list,
                                                  );
                                                }
                                              } catch (_) {
                                                if (context.mounted &&
                                                    Navigator.canPop(context)) {
                                                  Navigator.of(
                                                    context,
                                                    rootNavigator: true,
                                                  ).pop();
                                                }
                                              }
                                            }
                                          },
                                          onRestore: (item) async {
                                            Navigator.of(ctx).pop();
                                            if (!context.mounted) return;
                                            final mode =
                                                await _chooseImportModeDialog(
                                                  context,
                                                );
                                            if (mode == null) return;
                                            if (!context.mounted) return;
                                            try {
                                              await _runWithImportingOverlay(
                                                context,
                                                () => s3Vm.restoreFromItem(
                                                  item,
                                                  mode: mode,
                                                ),
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              showAppSnackBar(
                                                context,
                                                message: e.toString(),
                                                type: NotificationType.error,
                                              );
                                              return;
                                            }
                                            if (!context.mounted) return;
                                            final msg = s3Vm.message;
                                            if (msg != null &&
                                                msg != 'Restored') {
                                              showAppSnackBar(
                                                context,
                                                message: msg,
                                                type: NotificationType.error,
                                              );
                                              return;
                                            }
                                            await showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (dctx) => AlertDialog(
                                                title: Text(
                                                  l10n.backupPageRestartRequired,
                                                ),
                                                content: Text(
                                                  l10n.backupPageRestartContent,
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () async {
                                                      Navigator.of(dctx).pop();
                                                      PlatformUtils.restartApp();
                                                    },
                                                    child: Text(
                                                      l10n.backupPageOK,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    } catch (e) {
                                      if (context.mounted &&
                                          Navigator.canPop(context)) {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).pop();
                                      }
                                      if (context.mounted) {
                                        showAppSnackBar(
                                          context,
                                          message: e.toString(),
                                          type: NotificationType.error,
                                        );
                                      }
                                    }
                                  },
                                  onRestore: (item) async {
                                    Navigator.of(ctx).pop();

                                    if (!context.mounted) return;
                                    final mode = await _chooseImportModeDialog(
                                      context,
                                    );
                                    if (mode == null) return;
                                    if (!context.mounted) return;

                                    try {
                                      await _runWithImportingOverlay(
                                        context,
                                        () => s3Vm.restoreFromItem(
                                          item,
                                          mode: mode,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      showAppSnackBar(
                                        context,
                                        message: e.toString(),
                                        type: NotificationType.error,
                                      );
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    final msg = s3Vm.message;
                                    if (msg != null && msg != 'Restored') {
                                      showAppSnackBar(
                                        context,
                                        message: msg,
                                        type: NotificationType.error,
                                      );
                                      return;
                                    }
                                    await showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (dctx) => AlertDialog(
                                        title: Text(
                                          l10n.backupPageRestartRequired,
                                        ),
                                        content: Text(
                                          l10n.backupPageRestartContent,
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.of(dctx).pop();
                                              PlatformUtils.restartApp();
                                            },
                                            child: Text(l10n.backupPageOK),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Upload,
                      label: l10n.backupPageBackupNow,
                      onTap: s3Vm.busy
                          ? null
                          : () async {
                              final reminderProvider = context
                                  .read<BackupReminderProvider>();
                              final success = await _runWithExportingOverlay(
                                context,
                                () => s3Vm.backup(),
                              );
                              if (!context.mounted) return;
                              final rawMessage = s3Vm.message;
                              if (success) {
                                await reminderProvider.recordBackupCompleted();
                                if (!context.mounted) return;
                              }
                              final message =
                                  rawMessage ?? l10n.backupPageBackupUploaded;
                              showAppSnackBar(
                                context,
                                message: message,
                                type: NotificationType.info,
                              );
                            },
                    ),
                  ],
                ),

                // Section 4: 本地备份
                header(l10n.backupPageLocalBackup),
                _iosSectionCard(
                  children: [
                    _iosNavRow(
                      context,
                      icon: Lucide.Export,
                      label: l10n.backupPageExportToFile,
                      onTap: () => _doExport(context, vm),
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Import2,
                      label: l10n.backupPageImportBackupFile,
                      onTap: () => _doImportLocal(context, vm),
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Box,
                      label: l10n.backupPageImportFromCherryStudio,
                      onTap: () async {
                        // 1) Warn user that Cherry import is experimental
                        final acknowledged = await _confirmCherryImport(
                          context,
                        );
                        if (acknowledged != true) return;

                        if (!context.mounted) return;
                        // Pick Cherry Studio backup (.zip or .bak)
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['zip', 'bak'],
                        );
                        final path = result?.files.single.path;
                        if (path == null) return;
                        if (!context.mounted) return;

                        final mode = await _chooseImportModeDialog(context);
                        if (mode == null) return;
                        if (!context.mounted) return;

                        await _runWithImportingOverlay(context, () async {
                          try {
                            final settings = context.read<SettingsProvider>();
                            final cs = context.read<ChatService>();
                            final file = File(path);
                            // Defer import to service
                            final res =
                                await CherryImporter.importFromCherryStudio(
                                  file: file,
                                  mode: mode,
                                  settings: settings,
                                  chatService: cs,
                                );
                            if (!context.mounted) return;
                            await showDialog(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: Text(l10n.backupPageRestartRequired),
                                content: Text(
                                  '${l10n.backupPageImportFromCherryStudio}:\n'
                                  ' • Providers: ${res.providers}\n'
                                  ' • Assistants: ${res.assistants}\n'
                                  ' • Conversations: ${res.conversations}\n'
                                  ' • Messages: ${res.messages}\n'
                                  ' • Files: ${res.files}\n\n'
                                  '${l10n.backupPageRestartContent}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(dctx).pop();
                                      PlatformUtils.restartApp();
                                    },
                                    child: Text(l10n.backupPageOK),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            showAppSnackBar(
                              context,
                              message: e.toString(),
                              type: NotificationType.error,
                            );
                          }
                        });
                      },
                    ),
                    _iosDivider(context),
                    _iosNavRow(
                      context,
                      icon: Lucide.Box,
                      label: l10n.backupPageImportFromChatbox,
                      onTap: () async {
                        // Pick Chatbox exported json
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        final path = result?.files.single.path;
                        if (path == null) return;
                        if (!context.mounted) return;

                        final mode = await _chooseImportModeDialog(context);
                        if (mode == null) return;
                        if (!context.mounted) return;

                        await _runWithImportingOverlay(context, () async {
                          try {
                            final cs = context.read<ChatService>();
                            final settings = context.read<SettingsProvider>();
                            final file = File(path);
                            final res = await ChatboxImporter.importFromChatbox(
                              file: file,
                              mode: mode,
                              settings: settings,
                              chatService: cs,
                            );
                            if (!context.mounted) return;
                            await showDialog(
                              context: context,
                              builder: (dctx) => AlertDialog(
                                title: Text(l10n.backupPageRestartRequired),
                                content: Text(
                                  '${l10n.backupPageImportFromChatbox}:\n'
                                  ' • Providers: ${res.providers}\n'
                                  ' • Assistants: ${res.assistants}\n'
                                  ' • Conversations: ${res.conversations}\n'
                                  ' • Messages: ${res.messages}\n\n'
                                  '${l10n.backupPageRestartContent}',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.of(dctx).pop();
                                      PlatformUtils.restartApp();
                                    },
                                    child: Text(l10n.backupPageOK),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            showAppSnackBar(
                              context,
                              message: e.toString(),
                              type: NotificationType.error,
                            );
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _doExport(BuildContext context, BackupProvider vm) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _runWithExportingOverlay(
      context,
      () => vm.exportToFile(),
    );
    if (!context.mounted) return;

    final isMobile = Platform.isAndroid || Platform.isIOS;
    if (isMobile) {
      try {
        final saved = await NativeFileSave.saveFileFromPath(
          sourcePath: file.path,
          fileName: file.uri.pathSegments.last,
        );
        if (saved && context.mounted) {
          await context.read<BackupReminderProvider>().recordBackupCompleted();
        }
      } catch (e) {
        if (!context.mounted) return;
        showAppSnackBar(
          context,
          message: e.toString(),
          type: NotificationType.error,
        );
      }
    } else {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: l10n.backupPageExportToFile,
        fileName: file.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (savePath != null) {
        try {
          await File(savePath).parent.create(recursive: true);
          await file.copy(savePath);
          if (context.mounted) {
            await context
                .read<BackupReminderProvider>()
                .recordBackupCompleted();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _doImportLocal(BuildContext context, BackupProvider vm) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (!context.mounted) return;

    final mode = await _chooseImportModeDialog(context);
    if (mode == null) return;
    if (!context.mounted) return;

    await _runWithImportingOverlay(
      context,
      () => vm.restoreFromLocalFile(File(path), mode: mode),
    );
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.backupPageRestartRequired),
        content: Text(l10n.backupPageRestartContent),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dctx).pop();
              PlatformUtils.restartApp();
            },
            child: Text(l10n.backupPageOK),
          ),
        ],
      ),
    );
  }

  Future<void> _showWebDavSettingsSheet(
    BuildContext context,
    SettingsProvider settings,
    BackupProvider vm,
    WebDavConfig cfg,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          _WebDavSettingsSheet(settings: settings, vm: vm, cfg: cfg),
    );
  }

  Future<void> _showS3SettingsSheet(
    BuildContext context,
    SettingsProvider settings,
    S3BackupProvider vm,
    S3Config cfg,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _S3SettingsSheet(settings: settings, vm: vm, cfg: cfg),
    );
  }
}

class _BackupReminderMobileSection extends StatelessWidget {
  const _BackupReminderMobileSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reminder = context.watch<BackupReminderProvider>();

    return _iosSectionCard(
      children: [
        _iosSwitchRow(
          context,
          icon: Lucide.Timer,
          label: l10n.backupReminderEnableTitle,
          value: reminder.enabled,
          onChanged: (value) async {
            final provider = context.read<BackupReminderProvider>();
            if (!value) {
              await provider.setEnabled(false);
              return;
            }
            final minutes = await showBackupReminderTimePicker(
              context,
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
        if (reminder.enabled) ...[
          _iosDivider(context),
          _iosNavRow(
            context,
            icon: Lucide.Repeat,
            label: l10n.backupReminderFrequencyTitle,
            detailText: backupReminderFrequencyLabel(
              l10n,
              reminder.intervalDays,
            ),
            onTap: () => _showBackupReminderFrequencySheet(context),
          ),
          _iosDivider(context),
          _iosNavRow(
            context,
            icon: Lucide.clock,
            label: l10n.backupReminderTimeTitle,
            detailText: backupReminderTimeLabel(
              context,
              reminder.reminderMinutesOfDay,
            ),
            onTap: () async {
              final provider = context.read<BackupReminderProvider>();
              final minutes = await showBackupReminderTimePicker(
                context,
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
          _iosDivider(context),
          _iosNavRow(
            context,
            icon: Lucide.CheckCircle,
            label: l10n.backupReminderLastBackupTitle,
            detailText: backupReminderDateTimeLabel(
              context,
              reminder.lastBackupAt,
            ),
          ),
          _iosDivider(context),
          _iosNavRow(
            context,
            icon: Lucide.Calendar,
            label: l10n.backupReminderNextReminderTitle,
            detailText: backupReminderNextLabel(
              context,
              reminder.nextReminderAt,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _showBackupReminderFrequencySheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final provider = context.read<BackupReminderProvider>();
  final selected = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final options = <int>[
        ...BackupReminderProvider.presetIntervals,
        if (!BackupReminderProvider.presetIntervals.contains(
          provider.intervalDays,
        ))
          provider.intervalDays,
        0,
      ];
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final days in options)
                _ReminderFrequencyTile(
                  label: days == 0
                      ? l10n.backupReminderCustomOption
                      : backupReminderFrequencyLabel(l10n, days),
                  selected: days != 0 && days == provider.intervalDays,
                  onTap: () => Navigator.of(ctx).pop(days),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (!context.mounted || selected == null) return;

  final days = selected == 0
      ? await showBackupReminderCustomDaysDialog(
          context,
          initialDays: provider.intervalDays,
        )
      : selected;
  if (!context.mounted || days == null) return;
  final providerAfterDialog = context.read<BackupReminderProvider>();
  var minutes = providerAfterDialog.reminderMinutesOfDay;
  minutes ??= await showBackupReminderTimePicker(context);
  if (!context.mounted || minutes == null) return;
  await context.read<BackupReminderProvider>().saveSchedule(
    enabled: true,
    intervalDays: days,
    reminderMinutesOfDay: minutes,
  );
}

class _ReminderFrequencyTile extends StatefulWidget {
  const _ReminderFrequencyTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ReminderFrequencyTile> createState() => _ReminderFrequencyTileState();
}

class _ReminderFrequencyTileState extends State<_ReminderFrequencyTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: widget.selected
              ? cs.primary.withValues(alpha: 0.12)
              : _pressed
              ? cs.onSurface.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(fontSize: 15, color: cs.onSurface),
              ),
            ),
            if (widget.selected)
              Icon(Lucide.Check, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

// --- iOS-style widgets ---

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.suffix,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.transparent),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary.withValues(alpha: 0.4)),
            ),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 22,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;
  @override
  State<_TactileIconButton> createState() => _TactileIconButtonState();
}

class _TactileIconButtonState extends State<_TactileIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final press = base.withValues(alpha: 0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: _pressed ? press : base,
        ),
      ),
    );
  }
}

class _TactileTextButton extends StatefulWidget {
  const _TactileTextButton({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  State<_TactileTextButton> createState() => _TactileTextButtonState();
}

class _TactileTextButtonState extends State<_TactileTextButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.color;
    final press = base.withValues(alpha: 0.7);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _pressed ? press : base,
          ),
        ),
      ),
    );
  }
}

class _TactileRow extends StatefulWidget {
  const _TactileRow({
    required this.builder,
    this.onTap,
    this.pressedScale = 1.0,
  });
  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double pressedScale;
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
      onTap: widget.onTap == null
          ? null
          : () {
              if (context.read<SettingsProvider>().hapticsOnListItemTap) {
                Haptics.soft();
              }
              widget.onTap!.call();
            },
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.builder(_pressed),
      ),
    );
  }
}

class _SmallTactileIcon extends StatefulWidget {
  const _SmallTactileIcon({
    required this.icon,
    required this.onTap,
    this.baseColor,
  });
  final IconData icon;
  final VoidCallback onTap;
  final Color? baseColor;
  @override
  State<_SmallTactileIcon> createState() => _SmallTactileIconState();
}

class _SmallTactileIconState extends State<_SmallTactileIcon> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? Theme.of(context).colorScheme.onSurface;
    final c = _pressed ? base.withValues(alpha: 0.7) : base;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(widget.icon, size: 18, color: c),
      ),
    );
  }
}

Widget _iosSectionCard({required List<Widget> children}) {
  return Builder(
    builder: (context) {
      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final isDark = theme.brightness == Brightness.dark;
      final Color bg = isDark
          ? Colors.white10
          : Colors.white.withValues(alpha: 0.96);
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.08 : 0.06),
            width: 0.6,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      );
    },
  );
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(
    height: 6,
    thickness: 0.6,
    indent: 54,
    endIndent: 12,
    color: cs.outlineVariant.withValues(alpha: 0.18),
  );
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({
    required this.pressed,
    required this.base,
    required this.builder,
  });
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed
        ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base)
        : base;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) => builder(color ?? base),
    );
  }
}

Widget _iosNavRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  VoidCallback? onTap,
  String? detailText,
}) {
  final cs = Theme.of(context).colorScheme;
  final interactive = onTap != null;
  return _TactileRow(
    onTap: onTap,
    pressedScale: 1.00,
    builder: (pressed) {
      final baseColor = cs.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      color: c,
                    ), //, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detailText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      detailText,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                if (interactive) Icon(Lucide.ChevronRight, size: 16, color: c),
              ],
            ),
          );
        },
      );
    },
  );
}

// --- Local iOS-style buttons for sheets ---
class _IosOutlineButton extends StatefulWidget {
  const _IosOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            widget.label,
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _IosFilledButton extends StatefulWidget {
  const _IosFilledButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;
  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) =>
          Future.delayed(const Duration(milliseconds: 80), () => _set(false)),
      onTapCancel: () => _set(false),
      onTap: () {
        Haptics.soft();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            widget.label,
            style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

Widget _iosSwitchRow(
  BuildContext context, {
  IconData? icon,
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: () => onChanged(!value),
    pressedScale: 1.00,
    builder: (pressed) {
      final baseColor = cs.onSurface.withValues(alpha: 0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                if (icon != null) ...[
                  SizedBox(width: 36, child: Icon(icon, size: 20, color: c)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 15, color: c)),
                ), //, fontWeight: FontWeight.w500))),
                IosSwitch(value: value, onChanged: onChanged),
              ],
            ),
          );
        },
      );
    },
  );
}

class _RemoteListSheet extends StatelessWidget {
  const _RemoteListSheet({
    required this.items,
    required this.loading,
    required this.onDelete,
    required this.onRestore,
  });
  final List<BackupFileItem> items;
  final bool loading;
  final Future<void> Function(BackupFileItem) onDelete;
  final Future<void> Function(BackupFileItem) onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      l10n.backupPageRemoteBackups,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (loading)
                    const Positioned(
                      right: 0,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: (items.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          l10n.backupPageNoBackups,
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final it = items[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white10
                                    : const Color(0xFFF7F7F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          it.displayName,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _fmtBytes(it.size),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface.withValues(
                                              alpha: 0.7,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _SmallTactileIcon(
                                    icon: Lucide.Import,
                                    onTap: () => onRestore(it),
                                  ),
                                  const SizedBox(width: 6),
                                  _SmallTactileIcon(
                                    icon: Lucide.Trash2,
                                    onTap: () => onDelete(it),
                                    baseColor: cs.error,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _TactileRow(
      pressedScale: 0.98,
      onTap: onTap,
      builder: (pressed) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlay = pressed
            ? (isDark
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.05))
            : Colors.transparent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, color),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Lucide.ChevronRight, size: 18),
            ],
          ),
        );
      },
    );
  }
}

class _WebDavSettingsSheet extends StatefulWidget {
  const _WebDavSettingsSheet({
    required this.settings,
    required this.vm,
    required this.cfg,
  });

  final SettingsProvider settings;
  final BackupProvider vm;
  final WebDavConfig cfg;

  @override
  State<_WebDavSettingsSheet> createState() => _WebDavSettingsSheetState();
}

class _WebDavSettingsSheetState extends State<_WebDavSettingsSheet> {
  late final TextEditingController _urlCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _pathCtrl;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.cfg.url);
    _userCtrl = TextEditingController(text: widget.cfg.username);
    _passCtrl = TextEditingController(text: widget.cfg.password);
    _pathCtrl = TextEditingController(
      text: widget.cfg.path.isEmpty ? 'kelivo_backups' : widget.cfg.path,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Close (X) - Title (center) - Save (text)
              Row(
                children: [
                  _TactileIconButton(
                    icon: Lucide.X,
                    color: cs.onSurface,
                    size: 20,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.backupPageWebDavServerSettings,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _TactileTextButton(
                    label: l10n.backupPageSave,
                    color: cs.primary,
                    onTap: () async {
                      final newCfg = widget.cfg.copyWith(
                        url: _urlCtrl.text.trim(),
                        username: _userCtrl.text.trim(),
                        password: _passCtrl.text,
                        path: _pathCtrl.text.trim().isEmpty
                            ? 'kelivo_backups'
                            : _pathCtrl.text.trim(),
                      );
                      await widget.settings.setWebDavConfig(newCfg);
                      widget.vm.updateConfig(newCfg);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Input fields
              _InputRow(
                label: l10n.backupPageWebDavServerUrl,
                controller: _urlCtrl,
                hint: 'https://example.com/dav',
              ),
              const SizedBox(height: 12),
              _InputRow(label: l10n.backupPageUsername, controller: _userCtrl),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPagePassword,
                controller: _passCtrl,
                obscure: !_showPassword,
                suffix: _PasswordToggleButton(
                  showPassword: _showPassword,
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPagePath,
                controller: _pathCtrl,
                hint: 'kelivo_backups',
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _S3SettingsSheet extends StatefulWidget {
  const _S3SettingsSheet({
    required this.settings,
    required this.vm,
    required this.cfg,
  });

  final SettingsProvider settings;
  final S3BackupProvider vm;
  final S3Config cfg;

  @override
  State<_S3SettingsSheet> createState() => _S3SettingsSheetState();
}

class _S3SettingsSheetState extends State<_S3SettingsSheet> {
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _bucketCtrl;
  late final TextEditingController _accessKeyCtrl;
  late final TextEditingController _secretKeyCtrl;
  late final TextEditingController _sessionTokenCtrl;
  late final TextEditingController _prefixCtrl;

  bool _showSecret = false;
  bool _showToken = false;
  bool _pathStyle = true;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = TextEditingController(text: widget.cfg.endpoint);
    _regionCtrl = TextEditingController(text: widget.cfg.region);
    _bucketCtrl = TextEditingController(text: widget.cfg.bucket);
    _accessKeyCtrl = TextEditingController(text: widget.cfg.accessKeyId);
    _secretKeyCtrl = TextEditingController(text: widget.cfg.secretAccessKey);
    _sessionTokenCtrl = TextEditingController(text: widget.cfg.sessionToken);
    _prefixCtrl = TextEditingController(
      text: widget.cfg.prefix.isEmpty ? 'kelivo_backups' : widget.cfg.prefix,
    );
    _pathStyle = widget.cfg.pathStyle;
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _regionCtrl.dispose();
    _bucketCtrl.dispose();
    _accessKeyCtrl.dispose();
    _secretKeyCtrl.dispose();
    _sessionTokenCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _TactileIconButton(
                    icon: Lucide.X,
                    color: cs.onSurface,
                    size: 20,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        l10n.backupPageS3ServerSettings,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  _TactileTextButton(
                    label: l10n.backupPageSave,
                    color: cs.primary,
                    onTap: () async {
                      final newCfg = widget.cfg.copyWith(
                        endpoint: _endpointCtrl.text.trim(),
                        region: _regionCtrl.text.trim().isEmpty
                            ? 'us-east-1'
                            : _regionCtrl.text.trim(),
                        bucket: _bucketCtrl.text.trim(),
                        accessKeyId: _accessKeyCtrl.text.trim(),
                        secretAccessKey: _secretKeyCtrl.text,
                        sessionToken: _sessionTokenCtrl.text,
                        prefix: _prefixCtrl.text.trim().isEmpty
                            ? 'kelivo_backups'
                            : _prefixCtrl.text.trim(),
                        pathStyle: _pathStyle,
                      );
                      await widget.settings.setS3Config(newCfg);
                      widget.vm.updateConfig(newCfg);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _InputRow(
                label: l10n.backupPageS3Endpoint,
                controller: _endpointCtrl,
                hint: 'https://s3.amazonaws.com',
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3Region,
                controller: _regionCtrl,
                hint: 'us-east-1 / auto',
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3Bucket,
                controller: _bucketCtrl,
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3AccessKeyId,
                controller: _accessKeyCtrl,
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3SecretAccessKey,
                controller: _secretKeyCtrl,
                obscure: !_showSecret,
                suffix: _PasswordToggleButton(
                  showPassword: _showSecret,
                  onPressed: () => setState(() => _showSecret = !_showSecret),
                ),
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3SessionToken,
                controller: _sessionTokenCtrl,
                obscure: !_showToken,
                suffix: _PasswordToggleButton(
                  showPassword: _showToken,
                  onPressed: () => setState(() => _showToken = !_showToken),
                ),
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPageS3Prefix,
                controller: _prefixCtrl,
                hint: 'kelivo_backups',
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.18),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.backupPageS3PathStyle,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    IosSwitch(
                      value: _pathStyle,
                      onChanged: (v) => setState(() => _pathStyle = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// iOS-style password toggle button (no ripple)
class _PasswordToggleButton extends StatefulWidget {
  const _PasswordToggleButton({
    required this.showPassword,
    required this.onPressed,
  });

  final bool showPassword;
  final VoidCallback onPressed;

  @override
  State<_PasswordToggleButton> createState() => _PasswordToggleButtonState();
}

class _PasswordToggleButtonState extends State<_PasswordToggleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _pressed
        ? cs.onSurface.withValues(alpha: 0.5)
        : cs.onSurface.withValues(alpha: 0.7);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        Haptics.light();
        widget.onPressed();
      },
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AnimatedIconSwap(
          child: Icon(
            widget.showPassword ? Lucide.EyeOff : Lucide.Eye,
            key: ValueKey(widget.showPassword ? 'hide' : 'show'),
            size: 20,
            color: color,
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/snackbar.dart';
import 'package:provider/provider.dart';

import '../../../icons/lucide_adapter.dart';
import '../../../shared/animations/widgets.dart';
import '../../../core/services/haptics.dart';
import '../../../core/models/backup.dart';
import '../../../core/providers/backup_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/chat/chat_service.dart';
import '../../../shared/widgets/ios_switch.dart';
import '../../../core/services/backup/cherry_importer.dart';
import '../../../core/services/backup/chatbox_importer.dart';

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
  bool _loadingRemote = false;

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
        final onSurface60 = cs.onSurface.withOpacity(0.72);
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
                      color: cs.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    l10n.backupPageImportFromCherryStudio,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        style: TextStyle(fontSize: 14, height: 1.35, color: onSurface60),
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
    final cs = Theme.of(context).colorScheme;
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

  Future<T> _runWithExportingOverlay<T>(BuildContext context, Future<T> Function() task) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(radius: 16),
                  const SizedBox(height: 12),
                  Text(
                    l10n.backupPageExporting,
                    style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Future<T> _runWithImportingOverlay<T>(BuildContext context, Future<T> Function() task) async {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CupertinoActivityIndicator(radius: 14),
            ),
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsProvider>();
    
    return ChangeNotifierProvider(
      create: (_) => BackupProvider(
        chatService: context.read<ChatService>(),
        initialConfig: settings.webDavConfig,
      ),
      child: Builder(builder: (context) {
        final vm = context.watch<BackupProvider>();
        final cfg = vm.config;

        // iOS-style section header
        Widget header(String text, {bool first = false}) => Padding(
          padding: EdgeInsets.fromLTRB(12, first ? 2 : 18, 12, 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withOpacity(0.8),
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
              _iosSectionCard(children: [
                _iosSwitchRow(
                  context,
                  icon: Lucide.MessageSquare,
                  label: l10n.backupPageChatsLabel,
                  value: cfg.includeChats,
                  onChanged: (v) async {
                    final newCfg = cfg.copyWith(includeChats: v);
                    await settings.setWebDavConfig(newCfg);
                    vm.updateConfig(newCfg);
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
                  },
                ),
              ]),

              // Section 2: WebDAV备份
              header(l10n.backupPageWebDavBackup),
              _iosSectionCard(children: [
                _iosNavRow(
                  context,
                  icon: Lucide.Settings,
                  label: l10n.backupPageWebDavServerSettings,
                  onTap: () => _showWebDavSettingsSheet(context, settings, vm, cfg),
                ),
                _iosDivider(context),
                _iosNavRow(
                  context,
                  icon: Lucide.Cable,
                  label: l10n.backupPageTestConnection,
                  onTap: vm.busy ? null : () async {
                    await vm.test();
                    if (!mounted) return;
                    final rawMessage = vm.message;
                    final message = rawMessage ?? l10n.backupPageTestDone;
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
                  onTap: vm.busy ? null : () async {
                    // 加载远程备份列表
                    setState(() => _loadingRemote = true);
                    try {
                      final list = await vm.listRemote();
                      // 按时间倒序排列（最新的在前）
                      list.sort((a, b) {
                        // 优先使用 lastModified
                        if (a.lastModified != null && b.lastModified != null) {
                          return b.lastModified!.compareTo(a.lastModified!);
                        }
                        // 如果都没有 lastModified，按文件名倒序（文件名通常包含时间戳）
                        if (a.lastModified == null && b.lastModified == null) {
                          return b.displayName.compareTo(a.displayName);
                        }
                        // 有 lastModified 的排在前面
                        if (a.lastModified == null) return 1;
                        return -1;
                      });
                      setState(() => _remote = list);
                    } finally {
                      setState(() => _loadingRemote = false);
                    }
                    
                    if (!mounted) return;
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: cs.surface,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      builder: (ctx) => _RemoteListSheet(
                        items: _remote,
                        loading: _loadingRemote,
                        onDelete: (item) async {
                          final list = await vm.deleteAndReload(item);
                          // 按时间倒序排列（最新的在前）
                          list.sort((a, b) {
                            // 优先使用 lastModified
                            if (a.lastModified != null && b.lastModified != null) {
                              return b.lastModified!.compareTo(a.lastModified!);
                            }
                            // 如果都没有 lastModified，按文件名倒序（文件名通常包含时间戳）
                            if (a.lastModified == null && b.lastModified == null) {
                              return b.displayName.compareTo(a.displayName);
                            }
                            // 有 lastModified 的排在前面
                            if (a.lastModified == null) return 1;
                            return -1;
                          });
                          setState(() => _remote = list);
                        },
                        onRestore: (item) async {
                          Navigator.of(ctx).pop();
                          
                          if (!mounted) return;
                          final mode = await _chooseImportModeDialog(context);
                          
                          if (mode == null) return;
                          
                          await _runWithImportingOverlay(context, () => vm.restoreFromItem(item, mode: mode));
                          if (!mounted) return;
                          await showDialog(
                            context: context,
                            builder: (dctx) => AlertDialog(
                              title: Text(l10n.backupPageRestartRequired),
                              content: Text(l10n.backupPageRestartContent),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(dctx).pop(), child: Text(l10n.backupPageOK)),
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
                  onTap: vm.busy ? null : () async {
                    await _runWithExportingOverlay(context, () => vm.backup());
                    if (!mounted) return;
                    final rawMessage = vm.message;
                    final message = rawMessage ?? l10n.backupPageBackupUploaded;
                    showAppSnackBar(
                      context,
                      message: message,
                      type: NotificationType.info,
                    );
                  },
                ),
              ]),

              // Section 3: 本地备份
              header(l10n.backupPageLocalBackup),
              _iosSectionCard(children: [
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
                    final acknowledged = await _confirmCherryImport(context);
                    if (acknowledged != true) return;

                    if (!mounted) return;
                    // Pick Cherry Studio backup (.zip or .bak)
                    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip', 'bak']);
                    final path = result?.files.single.path;
                    if (path == null) return;

                    final mode = await _chooseImportModeDialog(context);
                    if (mode == null) return;

                    await _runWithImportingOverlay(context, () async {
                      try {
                        final settings = context.read<SettingsProvider>();
                        final cs = context.read<ChatService>();
                        final file = File(path);
                        // Defer import to service
                        final res = await CherryImporter.importFromCherryStudio(
                          file: file,
                          mode: mode,
                          settings: settings,
                          chatService: cs,
                        );
                        if (!mounted) return;
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
                                onPressed: () => Navigator.of(dctx).pop(),
                                child: Text(l10n.backupPageOK),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
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
                    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
                    final path = result?.files.single.path;
                    if (path == null) return;

                    final mode = await _chooseImportModeDialog(context);
                    if (mode == null) return;

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
                        if (!mounted) return;
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
                                onPressed: () => Navigator.of(dctx).pop(),
                                child: Text(l10n.backupPageOK),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        showAppSnackBar(
                          context,
                          message: e.toString(),
                          type: NotificationType.error,
                        );
                      }
                    });
                  },
                ),
              ]),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _doExport(BuildContext context, BackupProvider vm) async {
    final l10n = AppLocalizations.of(context)!;
    final file = await _runWithExportingOverlay(context, () => vm.exportToFile());
    if (!mounted) return;

    await FilePicker.platform.saveFile(
      dialogTitle: l10n.backupPageExportToFile,
      fileName: file.uri.pathSegments.last,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      bytes: await file.readAsBytes(),
    );
  }

  Future<void> _doImportLocal(BuildContext context, BackupProvider vm) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = result?.files.single.path;
    if (path == null) return;
    
    if (!mounted) return;
    final mode = await _chooseImportModeDialog(context);
    
    if (mode == null) return;
    
    await _runWithImportingOverlay(context, () => vm.restoreFromLocalFile(File(path), mode: mode));
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(l10n.backupPageRestartRequired),
        content: Text(l10n.backupPageRestartContent),
        actions: [TextButton(onPressed: () => Navigator.of(dctx).pop(), child: Text(l10n.backupPageOK))],
      ),
    );
  }

  Future<void> _showWebDavSettingsSheet(BuildContext context, SettingsProvider settings, BackupProvider vm, WebDavConfig cfg) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _WebDavSettingsSheet(
        settings: settings,
        vm: vm,
        cfg: cfg,
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
    this.enabled = true,
    this.suffix,
    this.onChanged,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool enabled;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.8))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          enabled: enabled,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: isDark ? Colors.white10 : const Color(0xFFF2F3F5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary.withOpacity(0.4))),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

class _TactileIconButton extends StatefulWidget {
  const _TactileIconButton({required this.icon, required this.color, required this.onTap, this.size = 22});
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
    final press = base.withOpacity(0.7);
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
        child: Icon(widget.icon, size: widget.size, color: _pressed ? press : base),
      ),
    );
  }
}

class _TactileTextButton extends StatefulWidget {
  const _TactileTextButton({required this.label, required this.color, required this.onTap});
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
    final press = base.withOpacity(0.7);
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
  const _TactileRow({required this.builder, this.onTap, this.pressedScale = 1.0});
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
              if (context.read<SettingsProvider>().hapticsOnListItemTap) Haptics.soft();
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
  const _SmallTactileIcon({required this.icon, required this.onTap, this.baseColor});
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
    final c = _pressed ? base.withOpacity(0.7) : base;
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
  return Builder(builder: (context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color bg = isDark ? Colors.white10 : Colors.white.withOpacity(0.96);
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(isDark ? 0.08 : 0.06), width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  });
}

Widget _iosDivider(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Divider(height: 6, thickness: 0.6, indent: 54, endIndent: 12, color: cs.outlineVariant.withOpacity(0.18));
}

class _AnimatedPressColor extends StatelessWidget {
  const _AnimatedPressColor({required this.pressed, required this.base, required this.builder});
  final bool pressed;
  final Color base;
  final Widget Function(Color color) builder;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = pressed ? (Color.lerp(base, isDark ? Colors.black : Colors.white, 0.55) ?? base) : base;
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
      final baseColor = cs.onSurface.withOpacity(0.9);
      return _AnimatedPressColor(
        pressed: pressed,
        base: baseColor,
        builder: (c) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Icon(icon, size: 20, color: c),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 15, color: c),  //, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (detailText != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(detailText, style: TextStyle(fontSize: 13, color: cs.onSurface.withOpacity(0.6))),
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
  final String label; final VoidCallback onTap;
  @override State<_IosOutlineButton> createState() => _IosOutlineButtonState();
}

class _IosOutlineButtonState extends State<_IosOutlineButton> {
  bool _pressed = false;
  void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), ()=>_set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.primary.withOpacity(0.5)),
          ),
          child: Text(widget.label, style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _IosFilledButton extends StatefulWidget {
  const _IosFilledButton({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override State<_IosFilledButton> createState() => _IosFilledButtonState();
}

class _IosFilledButtonState extends State<_IosFilledButton> {
  bool _pressed = false;
  void _set(bool v){ if(_pressed!=v) setState(()=>_pressed=v);} 
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => Future.delayed(const Duration(milliseconds: 80), ()=>_set(false)),
      onTapCancel: () => _set(false),
      onTap: () { Haptics.soft(); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110), curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
          child: Text(widget.label, style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

Widget _iosSwitchRow(BuildContext context, {IconData? icon, required String label, required bool value, required ValueChanged<bool> onChanged}) {
  final cs = Theme.of(context).colorScheme;
  return _TactileRow(
    onTap: () => onChanged(!value),
    pressedScale: 1.00,
    builder: (pressed) {
      final baseColor = cs.onSurface.withOpacity(0.9);
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
                Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: c))), //, fontWeight: FontWeight.w500))),
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
  const _RemoteListSheet({required this.items, required this.loading, required this.onDelete, required this.onRestore});
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
              Container(width: 42, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(l10n.backupPageRemoteBackups, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  if (loading)
                    Positioned(
                      right: 0,
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: (items.isEmpty)
                    ? Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(l10n.backupPageNoBackups, style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
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
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : const Color(0xFFF7F7F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(it.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(_fmtBytes(it.size), style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
                                      ],
                                    ),
                                  ),
                                  _SmallTactileIcon(icon: Lucide.Import, onTap: () => onRestore(it)),
                                  const SizedBox(width: 6),
                                  _SmallTactileIcon(icon: Lucide.Trash2, onTap: () => onDelete(it), baseColor: cs.error),
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
  const _ActionCard({required this.color, required this.icon, required this.title, required this.subtitle, required this.onTap});
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
        final overlay = pressed ? (isDark ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.05)) : Colors.transparent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.alphaBlend(overlay, color),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.18)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7))),
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
    _pathCtrl = TextEditingController(text: widget.cfg.path.isEmpty ? 'kelivo_backups' : widget.cfg.path);
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
                    color: cs.onSurface.withOpacity(0.2),
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        path: _pathCtrl.text.trim().isEmpty ? 'kelivo_backups' : _pathCtrl.text.trim(),
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
              _InputRow(
                label: l10n.backupPageUsername,
                controller: _userCtrl,
              ),
              const SizedBox(height: 12),
              _InputRow(
                label: l10n.backupPagePassword,
                controller: _passCtrl,
                obscure: !_showPassword,
                suffix: _PasswordToggleButton(
                  showPassword: _showPassword,
                  onPressed: () => setState(() => _showPassword = !_showPassword),
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
    final color = _pressed ? cs.onSurface.withOpacity(0.5) : cs.onSurface.withOpacity(0.7);
    
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

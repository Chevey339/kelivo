import 'package:Kelivo/features/workspace/workspace_file_navigation.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:terminal_view/terminal_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:Kelivo/core/services/haptics.dart';
import 'package:Kelivo/core/services/workspace/file_link_resolver.dart';
import 'package:Kelivo/core/services/workspace/workspace_runtime.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/features/workspace/terminal/terminal_session_manager.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/system_terminal_card.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_key_bar.dart';
import 'package:Kelivo/features/workspace/terminal/widgets/terminal_tab_strip.dart';
import 'package:Kelivo/features/workspace/widgets/files/workspace_prompts.dart';
import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/action_sheet.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_tile_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';
import 'package:Kelivo/theme/app_font_weights.dart';

/// Full-screen in-app terminal. On desktop without a PTY, shows a system
/// terminal fallback card instead of the emulator.
class TerminalPage extends StatefulWidget {
  const TerminalPage({
    super.key,
    this.conversationId,
    this.workspaceId,
    this.hostDir,
    this.mounts = const <Mount>[],
    this.cwd = '/workspace',
    this.title,
    this.initialSessionId,
  });

  static const pinchAreaKey = ValueKey<String>('terminal-pinch');
  static const moreKey = ValueKey<String>('terminal-more');

  final String? conversationId;
  final String? workspaceId;
  final String? hostDir;
  final List<Mount> mounts;
  final String cwd;
  final String? title;
  final String? initialSessionId;

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final Map<String, TerminalController> _controllers =
      <String, TerminalController>{};
  final Map<String, StreamSubscription<Uri>> _urlSubs =
      <String, StreamSubscription<Uri>>{};
  final Map<String, VoidCallback> _selectionListeners =
      <String, VoidCallback>{};
  final GlobalKey _moreAnchorKey = GlobalKey();
  String? _activeId;
  double _pinchBaseFont = kTerminalDefaultFontSize;
  Timer? _copyDebounce;
  late final TerminalSessionManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = context.read<TerminalSessionManager>();
    _activeId =
        widget.initialSessionId ??
        (_manager.sessions.isEmpty ? null : _manager.sessions.last.id);
    _syncSessionBindings(_manager);
    _manager.addListener(_onManagerChanged);
  }

  @override
  void dispose() {
    _copyDebounce?.cancel();
    _manager.removeListener(_onManagerChanged);
    for (final sub in _urlSubs.values) {
      unawaited(sub.cancel());
    }
    _urlSubs.clear();
    for (final entry in _selectionListeners.entries) {
      _controllers[entry.key]?.removeListener(entry.value);
    }
    _selectionListeners.clear();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  void _onManagerChanged() {
    if (!mounted) return;
    final manager = context.read<TerminalSessionManager>();
    _syncSessionBindings(manager);
    if (_activeId != null && manager.byId(_activeId!) == null) {
      _activeId = manager.sessions.isEmpty ? null : manager.sessions.last.id;
    }
    setState(() {});
  }

  void _syncSessionBindings(TerminalSessionManager manager) {
    final ids = manager.sessions.map((session) => session.id).toSet();
    for (final id in List<String>.from(_urlSubs.keys)) {
      if (!ids.contains(id)) {
        unawaited(_urlSubs.remove(id)?.cancel());
      }
    }
    for (final id in List<String>.from(_controllers.keys)) {
      if (!ids.contains(id)) {
        final listener = _selectionListeners.remove(id);
        final controller = _controllers.remove(id);
        if (listener != null) controller?.removeListener(listener);
        controller?.dispose();
      }
    }
    for (final session in manager.sessions) {
      _controllers.putIfAbsent(session.id, () {
        final controller = TerminalController();
        void onSelection() =>
            _copySelection(session, controller, debounce: true);
        _selectionListeners[session.id] = onSelection;
        controller.addListener(onSelection);
        return controller;
      });
      _urlSubs.putIfAbsent(
        session.id,
        () => session.openUrlRequests.listen((uri) {
          if (!mounted) return;
          unawaited(_handleOpenUrl(session, uri));
        }),
      );
    }
  }

  TerminalSession? get _active {
    final manager = context.read<TerminalSessionManager>();
    if (_activeId != null) {
      final match = manager.byId(_activeId!);
      if (match != null) return match;
    }
    return manager.sessions.isEmpty ? null : manager.sessions.last;
  }

  String get _pageTitle {
    final title = widget.title;
    if (title != null && title.isNotEmpty) return title;
    return AppLocalizations.of(context)!.terminalTitle;
  }

  Future<void> _addSession() async {
    final runtime = context.read<WorkspaceRuntimeProvider>().runtime;
    if (runtime == null || !runtime.supportsPty) return;
    final manager = context.read<TerminalSessionManager>();
    final template = _active;
    final session = await manager.open(
      runtime: runtime,
      mounts: template?.mounts ?? widget.mounts,
      cwd: template?.cwd ?? widget.cwd,
      title: widget.title,
      hostDir: template?.hostDir ?? widget.hostDir,
      conversationId: template?.conversationId ?? widget.conversationId,
      workspaceId: template?.workspaceId ?? widget.workspaceId,
    );
    if (!mounted) return;
    setState(() => _activeId = session.id);
  }

  Future<void> _closeSession(String id) async {
    final manager = context.read<TerminalSessionManager>();
    final session = manager.byId(id);
    if (session == null) return;
    if (!await _confirmCloseIfNeeded(session)) return;
    if (!mounted) return;
    await manager.close(id);
    if (!mounted) return;
    if (manager.sessions.isEmpty) {
      Navigator.of(context).maybePop();
    }
  }

  Future<bool> _confirmCloseIfNeeded(TerminalSession session) async {
    if (!session.isAlive) return true;
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showAppDialog<bool>(
      context,
      child: Builder(
        builder: (dialogContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.terminalCloseSession,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.emphasis,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.terminalCloseSessionConfirmMessage,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                IosTileButton(
                  icon: Lucide.Trash,
                  label: l10n.terminalCloseSession,
                  backgroundColor: cs.error,
                  onTap: () => Navigator.of(dialogContext).maybePop(true),
                ),
                const SizedBox(height: 8),
                IosTileButton(
                  icon: Lucide.X,
                  label: l10n.terminalCancel,
                  onTap: () => Navigator.of(dialogContext).maybePop(false),
                ),
              ],
            ),
          );
        },
      ),
    );
    return confirmed == true;
  }

  List<_MenuAction> _overflowActions(AppLocalizations l10n) {
    return [
      _MenuAction(
        id: 'rename',
        label: l10n.terminalRename,
        icon: Lucide.Pencil,
      ),
      _MenuAction(id: 'clear', label: l10n.terminalClear, icon: Lucide.Trash2),
      _MenuAction(
        id: 'copyAll',
        label: l10n.terminalCopyAllOutput,
        icon: Lucide.Copy,
      ),
      _MenuAction(
        id: 'fontDown',
        label: l10n.terminalFontDecrease,
        icon: Lucide.AArrowDown,
      ),
      _MenuAction(
        id: 'fontUp',
        label: l10n.terminalFontIncrease,
        icon: Lucide.AArrowUp,
      ),
      _MenuAction(
        id: 'close',
        label: l10n.terminalCloseSession,
        icon: Lucide.X,
        danger: true,
      ),
    ];
  }

  Future<void> _showOverflow() async {
    Haptics.light();
    final l10n = AppLocalizations.of(context)!;
    final session = _active;
    if (session == null) return;
    final actions = _overflowActions(l10n);
    final box = _moreAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final anchor = box == null
        ? Offset.zero
        : box.localToGlobal(box.size.center(Offset.zero));
    await showAdaptiveActionMenu(
      context,
      anchor: anchor,
      title: l10n.terminalMore,
      items: [
        for (final action in actions)
          ActionSheetItem(
            icon: action.icon,
            label: action.label,
            destructive: action.danger,
            onTap: () => unawaited(_handleOverflowAction(action.id)),
          ),
      ],
    );
  }

  Future<void> _handleOverflowAction(String action) async {
    final session = _active;
    if (session == null) return;
    switch (action) {
      case 'rename':
        await _renameSession(session.id);
      case 'clear':
        session.clearScreen();
      case 'copyAll':
        await _copyAllOutput(session);
      case 'fontDown':
        context.read<TerminalSessionManager>().setFontSize(
          session.id,
          session.fontSize - 1,
        );
      case 'fontUp':
        context.read<TerminalSessionManager>().setFontSize(
          session.id,
          session.fontSize + 1,
        );
      case 'close':
        await _closeSession(session.id);
    }
  }

  Future<void> _renameSession(String id) async {
    final manager = context.read<TerminalSessionManager>();
    final session = manager.byId(id);
    if (session == null) return;
    final l10n = AppLocalizations.of(context)!;
    final name = await showWorkspaceNamePrompt(
      context: context,
      title: l10n.terminalRename,
      label: l10n.terminalNameLabel,
      hint: l10n.terminalNameLabel,
      confirmLabel: l10n.terminalConfirm,
      initial: session.title,
    );
    if (name == null || !mounted) return;
    manager.rename(id, name);
  }

  Future<void> _copyAllOutput(TerminalSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final text = session.terminal.buffer.getText();
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: l10n.terminalCopiedAll,
      type: NotificationType.success,
    );
  }

  void _copySelection(
    TerminalSession session,
    TerminalController controller, {
    bool debounce = false,
  }) {
    void copy() {
      final range = controller.selection;
      if (range == null) return;
      final text = session.terminal.buffer.getText(range);
      if (text.trim().isEmpty) return;
      unawaited(Clipboard.setData(ClipboardData(text: text)));
    }

    if (!debounce) {
      copy();
      return;
    }
    _copyDebounce?.cancel();
    _copyDebounce = Timer(const Duration(milliseconds: 350), copy);
  }

  Future<void> _paste(TerminalSession session) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    session.pasteText(text);
  }

  Future<void> _handleOpenUrl(TerminalSession session, Uri uri) async {
    final l10n = AppLocalizations.of(context)!;
    if (uri.scheme == 'kelivo') {
      final conversationId = session.conversationId ?? widget.conversationId;
      if (conversationId == null || conversationId.isEmpty) {
        showAppSnackBar(context, message: l10n.terminalNotAvailable);
        return;
      }
      final link = KelivoLink.tryParse(uri.toString());
      if (link == null) {
        showAppSnackBar(context, message: l10n.terminalNotAvailable);
        return;
      }
      await openWorkspaceLinkedFile(
        context,
        uri.toString(),
        conversationId: conversationId,
      );
      return;
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        if (!mounted) return;
        showAppSnackBar(context, message: uri.toString());
      }
      return;
    }
    showAppSnackBar(context, message: uri.toString());
  }

  Future<void> _openSystemTerminal() async {
    final runtime = context.read<WorkspaceRuntimeProvider>().runtime;
    final hostDir = widget.hostDir ?? _active?.hostDir;
    if (runtime == null || hostDir == null || hostDir.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      showAppSnackBar(context, message: l10n.terminalNotAvailable);
      return;
    }
    try {
      await runtime.openInSystemTerminal(hostDir);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final manager = context.watch<TerminalSessionManager>();
    final runtime = context.watch<WorkspaceRuntimeProvider>().runtime;
    final supportsPty = runtime?.supportsPty ?? false;
    final session = _active;
    final hostDir = widget.hostDir ?? session?.hostDir ?? widget.cwd;
    final canOpenSystem =
        runtime != null && runtime.supportsSystemTerminal && hostDir.isNotEmpty;

    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: Tooltip(
          message: l10n.settingsPageBackButton,
          child: IosIconButton(
            icon: Lucide.ArrowLeft,
            color: cs.onSurface,
            size: 22,
            minSize: 44,
            semanticLabel: l10n.settingsPageBackButton,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(_pageTitle),
        actions: [
          if (supportsPty && session != null)
            Tooltip(
              key: _moreAnchorKey,
              message: l10n.terminalMore,
              child: IosIconButton(
                key: TerminalPage.moreKey,
                icon: Lucide.Ellipsis,
                size: 22,
                minSize: 44,
                semanticLabel: l10n.terminalMore,
                onTap: () => unawaited(_showOverflow()),
              ),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (supportsPty)
            TerminalTabStrip(
              sessions: manager.sessions,
              activeId: session?.id,
              onSelect: (id) => setState(() => _activeId = id),
              onAdd: () => unawaited(_addSession()),
              onRename: (id) => unawaited(_renameSession(id)),
              onClose: (id) => unawaited(_closeSession(id)),
            ),
          Expanded(
            child: !supportsPty || session == null
                ? SystemTerminalCard(
                    hostDir: hostDir,
                    onOpen: canOpenSystem
                        ? () => unawaited(_openSystemTerminal())
                        : null,
                  )
                : _buildEmulator(session),
          ),
          if (supportsPty && session != null)
            TerminalKeyBar(
              session: session,
              onCopy: () {
                final controller = _controllers[session.id];
                if (controller != null) {
                  _copySelection(session, controller);
                }
              },
              onPaste: () => unawaited(_paste(session)),
            ),
        ],
      ).animate().fadeIn(duration: 180.ms),
    );
  }

  Widget _buildEmulator(TerminalSession session) {
    final controller = _controllers[session.id];
    return KeyedSubtree(
      key: TerminalPage.pinchAreaKey,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (_) => _pinchBaseFont = session.fontSize,
            onScaleUpdate: (details) {
              if (details.pointerCount < 2) return;
              context.read<TerminalSessionManager>().setFontSize(
                session.id,
                _pinchBaseFont * details.scale,
              );
            },
            child: TerminalView(
              session.terminal,
              controller: controller,
              autofocus: true,
              deleteDetection: true,
              backgroundOpacity: 0,
              theme: buildTerminalViewTheme(Theme.of(context).colorScheme),
              textStyle: TerminalStyle(fontSize: session.fontSize),
              keyboardAppearance: Theme.of(context).brightness,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction({
    required this.id,
    required this.label,
    required this.icon,
    this.danger = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool danger;
}

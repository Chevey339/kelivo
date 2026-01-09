import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/models/selection_action.dart';
import 'snackbar.dart';
import '../../l10n/app_localizations.dart';

/// A wrapper widget that provides a floating action bar when text is selected.
/// Only active on desktop platforms (macOS, Windows, Linux).
/// 
/// The action bar appears near the selection and provides quick actions
/// configured in settings (scripts, commands) plus a built-in Copy action.
class SelectableWithActions extends StatefulWidget {
  const SelectableWithActions({
    super.key,
    required this.child,
    this.messageId,
  });

  final Widget child;
  final String? messageId;

  @override
  State<SelectableWithActions> createState() => _SelectableWithActionsState();
}

class _SelectableWithActionsState extends State<SelectableWithActions> {
  String? _selectedText;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  Timer? _hideTimer;
  Offset? _lastTapPosition;

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  void dispose() {
    _hideOverlay();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showActionBar(Offset position) {
    _hideOverlay();
    _hideTimer?.cancel();

    final settings = context.read<SettingsProvider>();
    final actions = settings.selectionActions.where((a) => a.enabled).toList();

    _overlayEntry = OverlayEntry(
      builder: (context) => _SelectionActionBar(
        position: position,
        layerLink: _layerLink,
        selectedText: _selectedText ?? '',
        actions: actions,
        onRunAction: _runAction,
        onCopy: _copyToClipboard,
        onDismiss: _hideOverlay,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);

    // Auto-hide after 5 seconds of inactivity
    _hideTimer = Timer(const Duration(seconds: 5), _hideOverlay);
  }

  Future<void> _runAction(SelectionAction action) async {
    if (_selectedText == null || _selectedText!.isEmpty) return;

    // Cancel auto-hide timer while script runs
    _hideTimer?.cancel();

    try {
      // Run the script with selected text as argument
      final result = await Process.run(
        action.scriptPath,
        [_selectedText!],
        runInShell: true,
      );
      
      if (result.exitCode != 0 && mounted) {
        final stderr = result.stderr.toString().trim();
        showAppSnackBar(
          context,
          message: '${action.name} error: ${stderr.isNotEmpty ? stderr : 'Exit code ${result.exitCode}'}',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: 'Failed to run ${action.name}: $e',
          type: NotificationType.error,
        );
      }
    }
  }

  void _copyToClipboard() {
    if (_selectedText == null || _selectedText!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _selectedText!));
    _hideOverlay();
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        message: l10n?.chatMessageWidgetCopiedToClipboard ?? 'Copied to clipboard',
        type: NotificationType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return widget.child;
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _lastTapPosition = event.position;
        },
        onPointerMove: (event) {
          // Track pointer during selection drag
          _lastTapPosition = event.position;
        },
        onPointerUp: (event) {
          // Final position when releasing mouse
          _lastTapPosition = event.position;
        },
        child: SelectionArea(
          key: ValueKey('selectable_${widget.messageId ?? hashCode}'),
          onSelectionChanged: (content) {
            _hideTimer?.cancel();
            
            if (content != null && content.plainText.trim().isNotEmpty) {
              _selectedText = content.plainText;
              // Use the last known position or screen center as fallback
              final position = _lastTapPosition ?? 
                  Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
              
              // Debounce to let selection stabilize and avoid flicker
              _hideTimer = Timer(const Duration(milliseconds: 150), () {
                if (mounted && _selectedText != null && _selectedText!.isNotEmpty) {
                  _showActionBar(position);
                }
              });
            } else {
              _selectedText = null;
              // Delay hiding to allow clicking on the action bar
              _hideTimer = Timer(const Duration(milliseconds: 250), () {
                if (_selectedText == null || _selectedText!.isEmpty) {
                  _hideOverlay();
                }
              });
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// The floating action bar that appears on text selection.
class _SelectionActionBar extends StatefulWidget {
  const _SelectionActionBar({
    required this.position,
    required this.layerLink,
    required this.selectedText,
    required this.actions,
    required this.onRunAction,
    required this.onCopy,
    required this.onDismiss,
  });

  final Offset position;
  final LayerLink layerLink;
  final String selectedText;
  final List<SelectionAction> actions;
  final Future<void> Function(SelectionAction) onRunAction;
  final VoidCallback onCopy;
  final VoidCallback onDismiss;

  @override
  State<_SelectionActionBar> createState() => _SelectionActionBarState();
}

class _SelectionActionBarState extends State<_SelectionActionBar> {
  String? _loadingActionId;
  String? _successActionId;
  bool _isHovering = false;

  bool get _isLoading => _loadingActionId != null;

  Future<void> _handleAction(SelectionAction action) async {
    if (_isLoading) return;
    
    setState(() {
      _loadingActionId = action.id;
    });
    
    try {
      await widget.onRunAction(action);
      if (mounted) {
        setState(() {
          _loadingActionId = null;
          _successActionId = action.id;
        });
        // Show checkmark briefly then dismiss or reset
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          if (_isHovering) {
            // Reset success state so button is clickable again
            setState(() => _successActionId = null);
          } else {
            widget.onDismiss();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingActionId = null;
        });
      }
    }
  }

  IconData _getIconForAction(SelectionAction action) {
    switch (action.iconName) {
      case 'volume2': return LucideIcons.volume2;
      case 'languages': return LucideIcons.languages;
      case 'search': return LucideIcons.search;
      case 'sparkles': return LucideIcons.sparkles;
      case 'brain': return LucideIcons.brain;
      case 'terminal': return LucideIcons.terminal;
      case 'code': return LucideIcons.code;
      case 'fileText': return LucideIcons.fileText;
      case 'link': return LucideIcons.link;
      case 'share': return LucideIcons.share;
      case 'bookmark': return LucideIcons.bookmark;
      case 'zap': return LucideIcons.zap;
      case 'wand': return LucideIcons.wand;
      case 'bot': return LucideIcons.bot;
      case 'messageCircle': return LucideIcons.messageCircle;
      default: return LucideIcons.play;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final actionCount = widget.actions.length + 1; // +1 for Copy
    final barWidth = actionCount * 80.0 + 20; // Estimate width

    return Positioned(
      left: widget.position.dx - barWidth / 2,
      top: widget.position.dy - 50,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: TapRegion(
          onTapOutside: _isLoading ? null : (_) => widget.onDismiss(),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.7)
                        : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Configured actions
                      for (int i = 0; i < widget.actions.length; i++) ...[
                        _buildActionButton(widget.actions[i], cs),
                        _divider(cs),
                      ],
                      // Built-in Copy action
                      _ActionButton(
                        icon: LucideIcons.copy,
                        label: 'Copy',
                        onTap: widget.onCopy,
                        enabled: !_isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(SelectionAction action, ColorScheme cs) {
    final isLoading = _loadingActionId == action.id;
    final isSuccess = _successActionId == action.id;
    
    return _ActionButton(
      icon: isSuccess ? LucideIcons.check : (isLoading ? null : _getIconForAction(action)),
      isLoading: isLoading,
      label: isSuccess ? 'Done' : (isLoading ? 'Running...' : action.name),
      onTap: () => _handleAction(action),
      enabled: !_isLoading && !isSuccess,
      successColor: isSuccess ? Colors.green : null,
    );
  }

  Widget _divider(ColorScheme cs) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant.withOpacity(0.3),
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
    this.successColor,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final Color? successColor;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  bool _hovering = false;
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(_ActionButton old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !old.isLoading) {
      _spinController.repeat();
    } else if (!widget.isLoading && old.isLoading) {
      _spinController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = widget.successColor ?? 
        (_hovering && widget.enabled ? cs.primary : cs.onSurface.withOpacity(widget.enabled ? 0.8 : 0.4));
    
    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hovering = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovering = false) : null,
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovering && widget.enabled ? cs.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                RotationTransition(
                  turns: _spinController,
                  child: Icon(
                    LucideIcons.loader,
                    size: 16,
                    color: effectiveColor,
                  ),
                )
              else if (widget.icon != null)
                Icon(
                  widget.icon,
                  size: 16,
                  color: effectiveColor,
                ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

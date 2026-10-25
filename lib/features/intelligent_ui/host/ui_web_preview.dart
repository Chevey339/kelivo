import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/shared/widgets/snackbar.dart';

import '../widgets/genui_clipboard.dart';
import '../widgets/genui_content.dart';
import '../widgets/genui_theme.dart';
import 'ui_web_controller.dart';
import 'ui_web_document.dart';

_UiWebPreviewLease? _active;
int _latestOpen = 0;

/// A newer Open waits for both native teardown and the old route's exit before
/// creating a controller. Closing a route never clears shared site data.
Future<void> showUiWebPreview(
  BuildContext context,
  UiWebDocument document,
) async {
  if (!document.canOpen || !uiWebPreviewSupported(defaultTargetPlatform)) {
    return;
  }
  final ticket = ++_latestOpen;
  final previous = _active;
  await previous?.close();
  if (ticket != _latestOpen || !context.mounted) return;
  if (previous?.controller.closeError != null) {
    showAppSnackBar(
      context,
      message: AppLocalizations.of(context)!.genuiWebCloseFailed,
      type: NotificationType.error,
    );
    return;
  }
  final lease = _UiWebPreviewLease(document);
  _active = lease;
  final desktop = ResponsiveHelper.isDesktop(context);
  try {
    if (desktop) {
      final displayed = showAppDialog<void>(
        context,
        maxWidth: 960,
        waitForExit: true,
        onRoute: (route) {
          lease.route = route;
        },
        child: _UiWebPreviewWindow(lease: lease, desktop: true),
      );
      await Future.any([displayed, lease.route!.completed]);
    } else {
      final route = _UiWebPageRoute(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => _UiWebPreviewWindow(lease: lease, desktop: false),
      );
      lease.route = route;
      final displayed = Navigator.of(context, rootNavigator: true).push(route);
      await Future.any([displayed, route.completed]);
      await route.completed;
    }
  } finally {
    await lease.release();
  }
}

final class _UiWebPreviewLease {
  _UiWebPreviewLease(this.document);
  final UiWebDocument document;
  final UiWebController controller = UiWebController();
  TransitionRoute<void>? route;
  RawDialogRoute<void>? infoRoute;
  Future<void>? _closing;
  Future<void>? _releasing;
  Future<void> release() => _releasing ??= _release();
  Future<void> _release() async {
    await controller.close();
    controller.dispose();
    if (identical(_active, this) && controller.closeError == null) {
      _active = null;
    }
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    final info = infoRoute;
    if (info != null && info.isActive) {
      info.navigator?.removeRoute(info);
    }
    final current = route;
    if (current == null) {
      await release();
      return;
    }
    final navigator = current.navigator;
    if (navigator != null && current.isActive) {
      if (current.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(current);
      }
    }
    await current.completed;
    // Keep the real page painted throughout the exit transition. Clearing its
    // document while the route is visible exposes an empty native canvas.
    await release();
  }
}

class _UiWebPageRoute extends CupertinoPageRoute<void> {
  _UiWebPageRoute({required super.builder, required this.reduceMotion});
  final bool reduceMotion;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  @override
  Duration get reverseTransitionDuration => transitionDuration;
}

class _UiWebPreviewWindow extends StatefulWidget {
  const _UiWebPreviewWindow({required this.lease, required this.desktop});
  final _UiWebPreviewLease lease;
  final bool desktop;
  @override
  State<_UiWebPreviewWindow> createState() => _UiWebPreviewWindowState();
}

class _UiWebPreviewWindowState extends State<_UiWebPreviewWindow> {
  bool _source = false;
  final _closeFocus = FocusNode(debugLabel: 'Web preview Close');
  final _infoFocus = FocusNode(debugLabel: 'Web preview Info');
  UiWebController get _controller => widget.lease.controller;
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _controller.start(widget.lease.document);
    } catch (_) {
      /* The controller exposes a bounded failure state below. */
    }
  }

  @override
  void dispose() {
    // Navigator disposal need not complete its push() future. Native teardown
    // must also run when the containing app/router is replaced outright.
    unawaited(widget.lease.release());
    _closeFocus.dispose();
    _infoFocus.dispose();
    super.dispose();
  }

  Future<void> _showInfo() async {
    if (widget.lease.infoRoute != null) return;
    final l10n = AppLocalizations.of(context)!;
    await showAppDialog<void>(
      context,
      maxWidth: 420,
      waitForExit: true,
      onRoute: (route) => widget.lease.infoRoute = route,
      child: GenUiThemeScope(
        child: Builder(
          builder: (context) {
            final theme = GenUiTheme.of(context);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDialogHeader(title: l10n.genuiWebInfo),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      theme.md,
                      0,
                      theme.md,
                      theme.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          widget.lease.document.title,
                          style: theme.sectionTitle,
                        ),
                        SizedBox(height: theme.xs),
                        Text(l10n.genuiWebSandboxNote, style: theme.body),
                        SizedBox(height: theme.xs),
                        Text(l10n.genuiWebCspNote, style: theme.caption),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    widget.lease.infoRoute = null;
    if (mounted) _infoFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    child: Builder(
      builder: (context) {
        final theme = GenUiTheme.of(context);
        final l10n = AppLocalizations.of(context)!;
        final document = widget.lease.document;
        final headerColor = widget.desktop ? theme.card : theme.previewHeader;
        final headerInk = widget.desktop ? theme.ink : theme.previewHeaderInk;
        Widget shell = Material(
          color: widget.desktop ? theme.card : theme.previewHeader,
          child: SafeArea(
            top: false,
            bottom: !widget.desktop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: headerColor,
                  child: SafeArea(
                    top: !widget.desktop,
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: theme.xs),
                      child: Row(
                        children: [
                          IosIconButton(
                            icon: LucideIcons.x,
                            minSize: 44,
                            color: headerInk,
                            focusNode: _closeFocus,
                            tooltip: l10n.mcpPageClose,
                            onTap: () => unawaited(widget.lease.close()),
                          ),
                          SizedBox(width: theme.xs),
                          Expanded(
                            child: Text(
                              document.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.header.copyWith(color: headerInk),
                            ),
                          ),
                          IosIconButton(
                            icon: LucideIcons.info,
                            size: 18,
                            minSize: 44,
                            color: headerInk,
                            focusNode: _infoFocus,
                            tooltip: l10n.genuiWebInfo,
                            onTap: _showInfo,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (_controller.phase == UiWebNativePhase.failed ||
                          _source) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.all(theme.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_controller.phase == UiWebNativePhase.failed)
                                Text(
                                  l10n.genuiWebFailed,
                                  style: theme.body.copyWith(
                                    color: theme.error,
                                  ),
                                ),
                              Wrap(
                                spacing: theme.xs,
                                children: [
                                  IosTextButton(
                                    label: l10n.genuiViewSource,
                                    icon: LucideIcons.codeXml,
                                    onPressed: () => setState(() {
                                      _source = !_source;
                                    }),
                                  ),
                                  IosTextButton(
                                    label: l10n.genuiCopySource,
                                    icon: LucideIcons.copy,
                                    onPressed: () =>
                                        copyGenUiText(context, document.source),
                                  ),
                                ],
                              ),
                              if (_source)
                                GenUiSource(
                                  source: document.source,
                                  language: 'kelivo-web',
                                ),
                            ],
                          ),
                        );
                      }
                      return _PreviewContent(
                        ready: _controller.phase == UiWebNativePhase.ready,
                        background: headerColor,
                        foreground: headerInk,
                        child: _controller.buildView(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        if (!widget.desktop) {
          shell = AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: theme.previewHeader,
              statusBarBrightness: Brightness.dark,
            ),
            child: Scaffold(backgroundColor: headerColor, body: shell),
          );
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(widget.lease.close());
          },
          child: Focus(
            autofocus: true,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                unawaited(widget.lease.close());
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: shell,
          ),
        );
      },
    ),
  );
}

/// Mount the native view behind an opaque cover while its first document loads.
/// Revealing the cover after didFinish also gives the platform composition a
/// frame to display the page; HTML load submission alone is not paint readiness.
class _PreviewContent extends StatefulWidget {
  const _PreviewContent({
    required this.ready,
    required this.background,
    required this.foreground,
    required this.child,
  });
  final bool ready;
  final Color background, foreground;
  final Widget child;
  @override
  State<_PreviewContent> createState() => _PreviewContentState();
}

class _PreviewContentState extends State<_PreviewContent>
    with SingleTickerProviderStateMixin {
  late final _reveal =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
      )..addStatusListener((_) {
        if (mounted) setState(() {});
      });

  @override
  void initState() {
    super.initState();
    _showWhenReady();
  }

  @override
  void didUpdateWidget(_PreviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready != oldWidget.ready) _showWhenReady();
  }

  void _showWhenReady() {
    if (!widget.ready) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.ready) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _reveal.value = 1;
      } else {
        _reveal.forward();
      }
    });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: !_reveal.isCompleted,
        child: ExcludeFocus(
          excluding: !_reveal.isCompleted,
          child: ExcludeSemantics(
            excluding: !_reveal.isCompleted,
            child: widget.child,
          ),
        ),
      ),
      if (!_reveal.isCompleted)
        IgnorePointer(
          child: FadeTransition(
            opacity: ReverseAnimation(_reveal),
            child: ColoredBox(
              key: const ValueKey('genui-web-loading-cover'),
              color: widget.background,
              child: Center(
                child: CupertinoActivityIndicator(color: widget.foreground),
              ),
            ),
          ),
        ),
    ],
  );
}

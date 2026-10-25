import '../runtime/ui_surface_controller.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import '../catalog/ui_budgets.dart';
import 'genui_control_region.dart';
import 'genui_surface.dart';
import 'genui_theme.dart';

typedef GenUiSurfaceBuilder =
    GenUiSurface Function(
      Future<void> Function()? expand,
      FocusNode? expandFocus,
      bool expanded,
    );

/// A single active input tree. Inline content is removed before the route can
/// mount, and restored only after its reverse transition has disposed content.
class GenUiExpansion extends StatefulWidget {
  const GenUiExpansion({super.key, required this.surfaceBuilder});
  final GenUiSurfaceBuilder surfaceBuilder;
  @override
  State<GenUiExpansion> createState() => _GenUiExpansionState();
}

class _GenUiExpansionState extends State<GenUiExpansion> {
  final _expandFocus = FocusNode(debugLabel: 'GenUI expansion trigger');
  final _updates = ValueNotifier<int>(0);
  TransitionRoute<void>? _route;
  UiRuntimeToken? _activeToken;
  bool _expanded = false, _refreshQueued = false;
  late GenUiSurface _surface;
  ThemeData? _theme;
  MediaQueryData? _media;
  TextDirection? _direction;
  VoidCallback? _stopDispose, _stopSource;

  void _subscribe() {
    _surface = widget.surfaceBuilder(null, null, true);
    final controller = _surface.controller;
    _stopDispose = controller.listenDispose(_close);
    _stopSource = controller.listenNode('root', () {
      final token = _activeToken;
      if (token != null && !controller.accepts(token)) _close();
    });
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = Theme.of(context);
    _media = MediaQuery.of(context);
    _direction = Directionality.of(context);
    _refreshRoute();
  }

  @override
  void didUpdateWidget(GenUiExpansion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.surfaceBuilder(null, null, true);
    if (next.controller != _surface.controller) {
      _close();
      _stopDispose?.call();
      _stopSource?.call();
      _subscribe();
    } else {
      _surface = next;
    }
    _refreshRoute();
  }

  void _refreshRoute() {
    if (!_expanded || _refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      if (mounted && _expanded) _updates.value++;
    });
  }

  void _close() {
    final route = _route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route);
    });
  }

  @override
  void dispose() {
    _stopDispose?.call();
    _stopSource?.call();
    _close();
    _expandFocus.dispose();
    // The route can finish removal at frame end after the inline host unmounts.
    final route = _route;
    if (route == null) {
      _updates.dispose();
    } else {
      unawaited(route.completed.then((_) => _updates.dispose()));
    }
    super.dispose();
  }

  Widget _routeContent(bool desktop) => ListenableBuilder(
    listenable: _updates,
    builder: (context, _) => Theme(
      data: _theme!,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _media!.textScaler,
          disableAnimations: _media!.disableAnimations,
        ),
        child: Directionality(
          textDirection: _direction!,
          child: _ExpandedSurface(surface: _surface, desktop: desktop),
        ),
      ),
    ),
  );

  Future<void> _expand() async {
    if (_expanded) return;
    final desktop = !ResponsiveHelper.isMobile(context);
    final controller = _surface.controller;
    final token = controller.token;
    _activeToken = token;
    final navigator = Navigator.of(context, rootNavigator: true);
    setState(() => _expanded = true);
    // Let disposal release TextEditingController/FocusNode registrations before
    // the route creates their replacement against the same interaction owner.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    if (!controller.accepts(token) || controller != _surface.controller) {
      _activeToken = null;
      setState(() => _expanded = false);
      return;
    }
    try {
      if (desktop) {
        await showAppDialog<void>(
          context,
          maxWidth: 960,
          waitForExit: true,
          onRoute: (route) => _route = route,
          child: _routeContent(true),
        );
      } else {
        final route = _GenUiPageRoute(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => _routeContent(false),
        );
        _route = route;
        await navigator.push(route);
        await route.completed;
      }
    } finally {
      _route = null;
      _activeToken = null;
      if (mounted) {
        setState(() => _expanded = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) _expandFocus.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) => GenUiThemeScope(
    markdownTheme: _surface.markdownTheme,
    child: Builder(
      builder: (context) {
        if (_expanded) return const GenUiExpandedStub();
        return GenUiInlineViewport(
          maxHeight: ResponsiveHelper.isMobile(context)
              ? MediaQuery.sizeOf(context).height * 1.4
              : 900,
          onExpand: _expand,
          child: widget.surfaceBuilder(_expand, _expandFocus, false),
        );
      },
    ),
  );
}

class GenUiExpandedStub extends StatelessWidget {
  const GenUiExpandedStub({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(theme.md),
        decoration: BoxDecoration(
          color: theme.fill,
          borderRadius: BorderRadius.circular(theme.cardRadius),
        ),
        child: Text(
          AppLocalizations.of(context)!.genuiExpandedStub,
          style: theme.body,
        ),
      ),
    );
  }
}

class _ExpandedSurface extends StatelessWidget {
  const _ExpandedSurface({required this.surface, required this.desktop});
  final GenUiSurface surface;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GenUiTheme.of(context);
    final title = surface.title ?? l10n.genuiSurfaceTitle;
    final content = SingleChildScrollView(
      padding: EdgeInsets.all(theme.md),
      child: AppSelectionArea(
        copyByteLimit: UiBudgets.copyBytes,
        child: surface,
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: desktop
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppDialogHeader(title: title),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: theme.md),
                  child: Text(
                    l10n.genuiExpandedSharedState,
                    style: theme.caption,
                  ),
                ),
                Flexible(child: content),
              ],
            )
          : Scaffold(
              appBar: AppBar(
                title: Text(title),
                leading: IosIconButton(
                  icon: LucideIcons.chevronLeft,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(theme.md),
                      child: Text(
                        l10n.genuiExpandedSharedState,
                        style: theme.caption,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ),
    );
  }
}

/// A clipped preview, never a second vertical gesture target in the message.
/// The expanded route owns scrolling through the complete control tree.
class GenUiInlineViewport extends StatefulWidget {
  const GenUiInlineViewport({
    super.key,
    required this.maxHeight,
    required this.onExpand,
    required this.child,
  });
  final double maxHeight;
  final Future<void> Function() onExpand;
  final Widget child;
  @override
  State<GenUiInlineViewport> createState() => _GenUiInlineViewportState();
}

class _GenUiInlineViewportState extends State<GenUiInlineViewport> {
  bool _overflow = false;
  final _viewportKey = GlobalKey(debugLabel: 'GenUI inline viewport');
  @override
  Widget build(BuildContext context) {
    final theme = GenUiTheme.of(context);
    final viewport = KeyedSubtree(
      key: _viewportKey,
      child: SingleChildScrollView(
        primary: false,
        physics: const _InlinePreviewPhysics(),
        child: widget.child,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight - (_overflow ? 44 : 0),
          ),
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth != 0 ||
                  notification.metrics.axis != Axis.vertical) {
                return false;
              }
              final overflow =
                  notification.metrics.maxScrollExtent +
                      notification.metrics.viewportDimension >
                  widget.maxHeight + .5;
              if (_overflow != overflow) setState(() => _overflow = overflow);
              return false;
            },
            child: _overflow
                ? ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        theme.ink,
                        theme.ink,
                        _overflow ? theme.transparent : theme.ink,
                      ],
                      stops: const [0, .92, 1],
                    ).createShader(rect),
                    child: viewport,
                  )
                : viewport,
          ),
        ),
        if (_overflow)
          GenUiControlRegion(
            child: IosTextButton(
              label: AppLocalizations.of(context)!.genuiExpand,
              icon: LucideIcons.expand,
              onPressed: widget.onExpand,
            ),
          ),
      ],
    );
  }
}

// User drags belong to the message, but caret/accessibility showOnScreen and
// keyboard traversal must still be able to reveal a partly clipped field.
class _InlinePreviewPhysics extends NeverScrollableScrollPhysics {
  const _InlinePreviewPhysics({super.parent});
  @override
  bool get allowImplicitScrolling => true;
  @override
  _InlinePreviewPhysics applyTo(ScrollPhysics? ancestor) =>
      _InlinePreviewPhysics(parent: buildParent(ancestor));
}

class _GenUiPageRoute extends CupertinoPageRoute<void> {
  _GenUiPageRoute({required super.builder, required this.reduceMotion});
  final bool reduceMotion;
  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  @override
  Duration get reverseTransitionDuration => transitionDuration;
}

import '../runtime/ui_surface_controller.dart';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/responsive/screen_type_helper.dart';
import 'package:Kelivo/shared/widgets/app_selection_area.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import '../catalog/ui_budgets.dart';
import 'genui_surface.dart';
import 'genui_theme.dart';
import 'genui_motion.dart';
import 'genui_expansion_snapshot.dart';
import '../runtime/ui_resolved_node.dart';

typedef GenUiSurfaceBuilder =
    GenUiSurface Function(
      Future<void> Function()? expand,
      FocusNode? expandFocus,
      bool expanded,
    );

/// Move the same input tree between the message and its expanded route. The
/// handoff happens in one frame; the message retains its measured height.
class GenUiExpansion extends StatefulWidget {
  const GenUiExpansion({super.key, required this.surfaceBuilder});
  final GenUiSurfaceBuilder surfaceBuilder;
  @override
  State<GenUiExpansion> createState() => _GenUiExpansionState();
}

class _GenUiExpansionState extends State<GenUiExpansion>
    with SingleTickerProviderStateMixin {
  final _expandFocus = FocusNode(debugLabel: 'GenUI expansion trigger');
  final _contentKey = GlobalKey(debugLabel: 'GenUI shared control tree');
  late final _returnReveal =
      AnimationController(
        vsync: this,
        value: 1,
        duration: const Duration(milliseconds: 160),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _changed = const {});
          _discardSnapshot();
        }
      });
  Map<String, UiResolvedNode> _before = const {};
  Set<String> _changed = const {};
  double? _inlineHeight;
  GenUiExpansionSnapshot? _snapshot;
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
    _returnReveal.dispose();
    _snapshot?.dispose();
    // The route can finish removal at frame end after the inline host unmounts.
    final route = _route;
    if (route == null) {
      _updates.dispose();
    } else {
      unawaited(route.completed.then((_) => _updates.dispose()));
    }
    super.dispose();
  }

  Widget _sharedContent(GenUiSurface surface) => GenUiExpansionAnchor(
    key: _contentKey,
    child: GenUiReturnMotion(
      animation: _returnReveal,
      changed: _changed,
      child: surface,
    ),
  );

  void _watchRoute(TransitionRoute<void> route) {
    _route = route;
    void listen() => route.animation?.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && identical(_route, route)) {
        _restoreInline();
      }
    });
    if (route.animation == null) {
      scheduleMicrotask(listen);
    } else {
      listen();
    }
  }

  void _restoreInline() {
    if (!mounted || !_expanded) return;
    const equality = DeepCollectionEquality();
    _changed = {
      for (final entry in _surface.controller.nodes.entries)
        if (!equality.equals(
          _before[entry.key]?.properties,
          entry.value.properties,
        ))
          entry.key,
    };
    if ((_changed.isNotEmpty || _snapshot != null) &&
        !(_media?.disableAnimations ?? false)) {
      _returnReveal.forward(from: 0);
    } else {
      _changed = const {};
      _discardSnapshot();
    }
    setState(() => _expanded = false);
    // The outgoing route releases the key before this frame is finalized.
    _updates.value++;
  }

  void _discardSnapshot() {
    final previous = _snapshot;
    _snapshot = null;
    // The previous RawImage may still be painted until this frame commits.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  Widget _routeContent(bool desktop) => ListenableBuilder(
    listenable: _updates,
    builder: (context, _) => !_expanded
        ? const SizedBox.shrink()
        : Theme(
            data: _theme!,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: _media!.textScaler,
                disableAnimations: _media!.disableAnimations,
              ),
              child: Directionality(
                textDirection: _direction!,
                child: _ExpandedSurface(
                  surface: _surface,
                  content: _sharedContent(_surface),
                  desktop: desktop,
                ),
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
    final render = _contentKey.currentContext?.findRenderObject();
    _inlineHeight = render is RenderBox && render.hasSize
        ? render.size.height
        : null;
    _discardSnapshot();
    _before = Map.of(controller.nodes);
    _changed = const {};
    _returnReveal.stop();
    _returnReveal.value = 1;
    if (render is RenderGenUiExpansionAnchor) {
      _snapshot = render.capture(
        MediaQuery.of(context),
        includeBackdrop: (_surface.markdownTheme?.colors.fillBlock.a ?? 1) < 1,
      );
    }
    setState(() => _expanded = true);
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
          onRoute: _watchRoute,
          child: _routeContent(true),
        );
      } else {
        final route = _GenUiPageRoute(
          reduceMotion: MediaQuery.disableAnimationsOf(context),
          builder: (_) => _routeContent(false),
        );
        // Navigator installs the animation before the first route build.
        final pushed = navigator.push(route);
        _watchRoute(route);
        await pushed;
        await route.completed;
      }
    } finally {
      _restoreInline();
      _route = null;
      _activeToken = null;
      if (mounted) {
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
        final snapshot = _snapshot;
        final content = _expanded
            ? SizedBox(
                height: _inlineHeight,
                width: double.infinity,
                child: snapshot == null
                    ? const Align(
                        alignment: AlignmentDirectional.topStart,
                        child: GenUiExpandedStub(),
                      )
                    : Semantics(
                        label: AppLocalizations.of(context)!.genuiExpandedStub,
                        child: ExcludeSemantics(
                          child: Stack(children: [snapshot.build()]),
                        ),
                      ),
              )
            : Stack(
                children: [
                  _sharedContent(
                    widget.surfaceBuilder(_expand, _expandFocus, false),
                  ),
                  if (snapshot != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: FadeTransition(
                            key: const ValueKey('genui-return-reveal'),
                            opacity: ReverseAnimation(_returnReveal),
                            child: Stack(children: [snapshot.build()]),
                          ),
                        ),
                      ),
                    ),
                ],
              );
        if (MediaQuery.disableAnimationsOf(context)) return content;
        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: AlignmentDirectional.topStart,
          child: content,
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
  const _ExpandedSurface({
    required this.surface,
    required this.content,
    required this.desktop,
  });
  final GenUiSurface surface;
  final Widget content;
  final bool desktop;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GenUiTheme.of(context);
    final title = surface.title ?? l10n.genuiSurfaceTitle;
    final scrollContent = SingleChildScrollView(
      padding: EdgeInsets.all(theme.md),
      child: AppSelectionArea(
        copyByteLimit: UiBudgets.copyBytes,
        child: content,
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
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
                  Flexible(child: scrollContent),
                ],
              )
            : Scaffold(
                appBar: AppBar(
                  title: Text(title),
                  leading: IosIconButton(
                    icon: LucideIcons.chevronLeft,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
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
                      Expanded(child: scrollContent),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../search/settings_search_index.dart';
import '../search/settings_search_navigation.dart';
import '../widgets/settings_search_view.dart';
import '../widgets/settings_search_field.dart';
import '../widgets/custom_theme_widgets.dart';

/// A modal layer keeps the settings page still beneath the moving field.
Future<void> showMobileSettingsSearch(
  BuildContext context, {
  required SettingsSearchOrigin origin,
  required VoidCallback onColorMode,
}) async {
  final route = _SettingsSearchRoute(
    origin: origin,
    onColorMode: onColorMode,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );
  await Navigator.of(context).push<void>(route);
  // Prevent reopening until the reverse animation and overlay teardown finish.
  await route.completed;
}

class _SettingsSearchRoute extends PopupRoute<void> {
  _SettingsSearchRoute({
    required this.origin,
    required this.onColorMode,
    required this.reduceMotion,
  });
  final SettingsSearchOrigin origin;
  final VoidCallback onColorMode;
  final bool reduceMotion;

  @override
  Color? get barrierColor => null;
  @override
  bool get barrierDismissible => false;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 360);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reduceMotion ? 0 : 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => SettingsSearchPage(
    onColorMode: onColorMode,
    origin: origin,
    transition: animation,
  );
}

class SettingsSearchPage extends StatelessWidget {
  const SettingsSearchPage({
    super.key,
    required this.onColorMode,
    this.origin,
    this.transition = const AlwaysStoppedAnimation(1),
  });
  final VoidCallback onColorMode;
  final SettingsSearchOrigin? origin;
  final Animation<double> transition;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: _SettingsSearch(
      origin: origin,
      transition: transition,
      safeAreaInsets: MediaQuery.paddingOf(context),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      onSelected: (item) {
        if (item.destination == SettingsSearchDestination.colorMode) {
          onColorMode();
        } else {
          openMobileSettingsSearchResult(context, item);
        }
      },
      onClose: () => Navigator.of(context).pop(),
    ),
  );
}

Future<SettingsSearchItem?> showDesktopSettingsSearch(BuildContext context) =>
    showAppDialog<SettingsSearchItem>(
      context,
      maxWidth: 640,
      child: SizedBox(
        height: 640,
        child: Builder(
          builder: (context) => _SettingsSearch(
            onSelected: (item) => Navigator.of(context).pop(item),
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );

class _SettingsSearch extends StatefulWidget {
  const _SettingsSearch({
    required this.onSelected,
    required this.onClose,
    this.origin,
    this.transition = const AlwaysStoppedAnimation(1),
    this.safeAreaInsets = EdgeInsets.zero,
    this.backgroundColor,
  });
  final SettingsSearchOrigin? origin;
  final Animation<double> transition;
  final EdgeInsets safeAreaInsets;
  final Color? backgroundColor;
  final ValueChanged<SettingsSearchItem> onSelected;
  final VoidCallback onClose;

  @override
  State<_SettingsSearch> createState() => _SettingsSearchState();
}

class _SettingsSearchState extends State<_SettingsSearch> {
  SettingsSearchIndex? _index;
  (AppLocalizations, TargetPlatform, bool, bool)? _configuration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (logs, dynamicColor) = context.select<SettingsProvider, (bool, bool)>(
      (settings) => (
        settings.requestLogEnabled ||
            settings.flutterLogEnabled ||
            settings.contextLogEnabled,
        settings.dynamicColorSupported,
      ),
    );
    final configuration = (l10n, defaultTargetPlatform, logs, dynamicColor);
    if (_configuration != configuration) {
      _configuration = configuration;
      _index = SettingsSearchIndex(
        l10n,
        platform: defaultTargetPlatform,
        logsEnabled: logs,
        dynamicColorSupported: dynamicColor,
      );
    }
    return SettingsSearchView(
      index: _index!,
      origin: widget.origin,
      transition: widget.transition,
      safeAreaInsets: widget.safeAreaInsets,
      backgroundColor: widget.backgroundColor,
      onSelected: widget.onSelected,
      onClose: widget.onClose,
    );
  }
}

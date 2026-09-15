import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/ios_tactile.dart';
import 'settings_search_action.dart';
import 'settings_search_field.dart';

class SettingsSearchEntry extends StatelessWidget {
  const SettingsSearchEntry({super.key, required this.onTap, this.reveal = 1});
  final VoidCallback onTap;
  final double reveal;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: reveal < 0.97,
    child: ExcludeSemantics(
      excluding: reveal < 0.97,
      child: SettingsSearchAction(
        onTap: onTap,
        child: Semantics(
          button: true,
          label: AppLocalizations.of(context)!.settingsSearchHint,
          onTap: onTap,
          child: ExcludeSemantics(
            child: IosCardPress(
              onTap: onTap,
              haptics: false,
              baseColor: Colors.transparent,
              borderRadius: settingsSearchFieldRadius,
              child: SettingsSearchField(reveal: reveal),
            ),
          ),
        ),
      ),
    ),
  );
}

/// A shrinking sliver keeps the field at the top as its height disappears.
/// The list uses native scroll physics; only the header rebuilds while dragging.
class SettingsSearchList extends StatefulWidget {
  const SettingsSearchList({
    super.key,
    required this.onSearch,
    required this.children,
  });

  final Future<void> Function(SettingsSearchOrigin origin) onSearch;
  final List<Widget> children;

  @override
  State<SettingsSearchList> createState() => _SettingsSearchListState();
}

class _SettingsSearchListState extends State<SettingsSearchList> {
  final _entryKey = GlobalKey();
  ScrollController? _controller;
  bool _searching = false;

  double get _searchExtent => settingsSearchFieldHeight(context) + 16;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ScrollController(
      initialScrollOffset: MediaQuery.accessibleNavigationOf(context)
          ? 0
          : _searchExtent,
    );
  }

  Rect? _entryRect() {
    if (!mounted) return null;
    final box = _entryKey.currentContext?.findRenderObject();
    final overlay = Navigator.of(context).overlay?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || overlay == null) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  }

  Future<void> _openSearch() async {
    if (_searching) return;
    _searching = true;
    try {
      await widget.onSearch(_entryRect);
    } finally {
      _searching = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: CustomScrollView(
      controller: _controller,
      physics: _SearchRevealPhysics(
        extent: _searchExtent,
        parent: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
      slivers: [
        SliverPersistentHeader(
          delegate: _SearchHeader(
            extent: _searchExtent,
            entryKey: _entryKey,
            onTap: _openSearch,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverList.list(children: widget.children),
        ),
      ],
    ),
  );
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  const _SearchHeader({
    required this.extent,
    required this.entryKey,
    required this.onTap,
  });
  final double extent;
  final GlobalKey entryKey;
  final VoidCallback onTap;

  @override
  double get minExtent => 0;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final reveal = (1 - shrinkOffset / extent).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8 * reveal),
      child: SettingsSearchEntry(key: entryKey, reveal: reveal, onTap: onTap),
    );
  }

  @override
  bool shouldRebuild(_SearchHeader oldDelegate) => extent != oldDelegate.extent;
}

class _SearchRevealPhysics extends ScrollPhysics {
  const _SearchRevealPhysics({required this.extent, super.parent});
  final double extent;

  @override
  _SearchRevealPhysics applyTo(ScrollPhysics? ancestor) =>
      _SearchRevealPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.outOfRange || position.pixels >= extent || velocity > 300) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = velocity < -tolerance.velocity
        ? 0.0
        : velocity > tolerance.velocity
        ? extent
        : position.pixels < extent / 2
        ? 0.0
        : extent;
    if ((position.pixels - target).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }
}
